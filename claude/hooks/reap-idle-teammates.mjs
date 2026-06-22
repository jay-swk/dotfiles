#!/usr/bin/env node
// =============================================================================
// reap-idle-teammates.mjs  —  OMC native-team idle teammate reaper (Stop hook)
// =============================================================================
//
// PROBLEM
//   When a Claude Code session spawns named background sub-agents ("teammates",
//   backendType:"tmux" members in ~/.claude/teams/<team>/config.json), they do
//   NOT auto-terminate when their task finishes. They emit an idle_notification
//   ({"idleReason":"available"}) and then sit idle holding a tmux pane + a
//   claude.exe process forever, until a human manually shuts them down. OMC has
//   no built-in reaper for this case (cleanup-orphans.mjs only kills teammates
//   whose TEAM CONFIG was deleted — a different, "true orphan" case).
//
// WHAT THIS DOES (as a global Stop hook)
//   On each turn-end of the LEAD session, find that session's own teammates and
//   terminate ONLY the ones that are safe to kill:
//     reap iff  (a) the teammate tmux pane is idle  (OMC-native heuristic:
//                   pane shows a ready prompt AND has no active task), AND
//               (b) it has been *continuously* idle for >= a conservative
//                   threshold (default 15 min, env OMC_TEAMMATE_IDLE_REAP_MS).
//
// WHY IT IS SAFE (layered guards — see SAFETY below)
//   1. Scoping: only acts for the session whose id == team config leadSessionId.
//      A teammate's own Stop hook finds no team it leads → no-op. So teammates
//      never reap each other or themselves; only the lead reaps its own team.
//   2. Idle detection reuses OMC's exact paneLooksReady/paneHasActiveTask logic
//      (ported from src/team/tmux-session.ts) — a working pane ("esc to
//      interrupt") is never considered idle.
//   3. Continuous-idle threshold: first observation only STARTS the clock and
//      never kills; a pane must stay idle across the full window. "Idle but I'll
//      send it more work soon" is protected as long as work arrives < threshold.
//   4. Kill target verification: before SIGTERM we confirm the pane's process
//      command line contains BOTH --team-name <team> AND --agent-name <name>.
//      The lead / main session has no such flags, so it can never match.
//   5. Never touches the lead pane (tmuxPaneId "leader" / backendType in-process)
//      and excludes process.pid / process.ppid (the running session).
//   6. Idempotent, wrapped in try/catch, always exits 0 — never blocks Stop.
//
// CONTROLS
//   OMC_TEAMMATE_REAP_DISABLED=1   kill-switch (also honors DISABLE_OMC=1 and
//                                  OMC_SKIP_HOOKS containing reap-idle-teammates)
//   OMC_TEAMMATE_IDLE_REAP_MS=N    idle threshold ms (default 900000 = 15 min)
//   OMC_TEAMMATE_REAP_GRACE_MS=N   SIGTERM→SIGKILL grace ms (default 5000)
//   OMC_TEAMMATE_REAP_DEBUG=1      verbose stderr diagnostics
//
// CLI (manual)
//   node reap-idle-teammates.mjs --dry-run           # report only, no kills, no
//                                                    # state writes; scans all
//                                                    # teams when run w/o stdin
//   node reap-idle-teammates.mjs --dry-run --all     # force full scan
//
// ROLLBACK
//   Remove this hook entry from ~/.claude/settings.json (restore the backup
//   ~/.claude/settings.json.bak-<ts>) — the script is inert without the hook.
// =============================================================================

import { homedir } from 'node:os';
import { join, normalize, parse, sep } from 'node:path';
import {
  existsSync, readFileSync, writeFileSync, readdirSync, mkdirSync, unlinkSync,
} from 'node:fs';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

// ----- args / env --------------------------------------------------------------
const ARGS = process.argv.slice(2);
const DRY_RUN = ARGS.includes('--dry-run') || process.env.OMC_TEAMMATE_REAP_DRYRUN === '1';
const FORCE_ALL = ARGS.includes('--all');
const DEBUG = process.env.OMC_TEAMMATE_REAP_DEBUG === '1';

const IDLE_THRESHOLD_MS = clampInt(process.env.OMC_TEAMMATE_IDLE_REAP_MS, 900_000, 1_000, 24 * 60 * 60 * 1000);
const GRACE_MS = clampInt(process.env.OMC_TEAMMATE_REAP_GRACE_MS, 5_000, 500, 60_000);

function clampInt(raw, def, lo, hi) {
  const n = Number.parseInt(raw ?? '', 10);
  if (!Number.isFinite(n)) return def;
  return Math.min(hi, Math.max(lo, n));
}

function dbg(...a) { if (DEBUG) process.stderr.write(`[reap-idle-teammates] ${a.join(' ')}\n`); }

// ----- config dir / paths ------------------------------------------------------
function stripTrailingSep(p) {
  if (!p.endsWith(sep)) return p;
  return p === parse(p).root ? p : p.slice(0, -1);
}
function getClaudeConfigDir() {
  const home = homedir();
  const c = process.env.CLAUDE_CONFIG_DIR?.trim();
  if (!c) return stripTrailingSep(normalize(join(home, '.claude')));
  if (c === '~') return stripTrailingSep(normalize(home));
  if (c.startsWith('~/') || c.startsWith('~\\')) return stripTrailingSep(normalize(join(home, c.slice(2))));
  return stripTrailingSep(normalize(c));
}
const CONFIG_DIR = getClaudeConfigDir();
const TEAMS_DIR = join(CONFIG_DIR, 'teams');
const STATE_DIR = join(CONFIG_DIR, 'state', 'teammate-reaper');

// ----- tmux helpers (synchronous, bounded) ------------------------------------
function tmux(args, timeout = 1500) {
  // returns stdout string, or null on error
  try {
    return execFileSync('tmux', args, { encoding: 'utf-8', timeout, stdio: ['ignore', 'pipe', 'ignore'] });
  } catch {
    return null;
  }
}

// Single server-wide pane snapshot: paneId -> { dead, pid }.
// `tmux list-panes -a` proved reliable from a child process (display-message
// can intermittently return empty depending on $TMUX inheritance). Returns
// null when tmux is unreachable/empty so callers can treat it as 'unknown'
// (skip) rather than wrongly concluding panes are dead.
function paneSnapshot() {
  const out = tmux(['list-panes', '-a', '-F', '#{pane_id} #{pane_dead} #{pane_pid}']);
  if (out == null) return null;
  const map = new Map();
  for (const line of out.split('\n')) {
    const m = line.trim().match(/^(%\d+)\s+(\d+)\s+(\d+)$/);
    if (m) map.set(m[1], { dead: m[2] !== '0', pid: Number.parseInt(m[3], 10) });
  }
  dbg('snapshot panes', map.size);
  return map.size > 0 ? map : null;
}

function capturePane(paneId) {
  // Mirror OMC capturePaneAsync: last 80 lines, plain text.
  const out = tmux(['capture-pane', '-t', paneId, '-p', '-S', '-80']);
  return out ?? '';
}

// ----- OMC-native idle heuristics (ported verbatim from src/team/tmux-session.ts)
function paneLineLooksLikeIdlePrompt(line) {
  return /^\s*(?:[│┃║▌▐▏▕╎┆┊]\s*)?[›>❯]\s*/u.test(line);
}
function paneHasTrustPrompt(captured) {
  const lines = captured.split('\n').map(l => l.replace(/\r/g, '').trim()).filter(l => l.length > 0);
  const tail = lines.slice(-12);
  const hasDirQ = tail.some(l => /Do you trust the contents of this directory\?/i.test(l));
  const hasDirC = tail.some(l => /Yes,\s*continue|No,\s*quit|Press enter to continue/i.test(l));
  if (hasDirQ && hasDirC) return true;
  const hasHookReview = tail.some(l => /Hooks need review/i.test(l));
  const hasHookTrust = tail.some(l => /Continue without trusting/i.test(l));
  const hasHookConfirm = tail.some(l => /Press enter to confirm or esc to go back/i.test(l));
  return hasHookReview && hasHookTrust && hasHookConfirm;
}
function paneHasClaudeStartupBanner(captured) {
  const lines = captured.split('\n').map(l => l.replace(/\r/g, '').trim()).filter(l => l.length > 0).slice(-20);
  const lastPromptIndex = lines.findLastIndex(paneLineLooksLikeIdlePrompt);
  if (lastPromptIndex >= 0) return false;
  const lastBanner = lines.findLastIndex(l =>
    /bypass\s+permissions\s+on/i.test(l) || /shift\+tab\s+to\s+cycle/i.test(l) || /^⏵⏵\s+/.test(l));
  return lastBanner >= 0;
}
function paneIsBootstrapping(captured) {
  if (paneHasClaudeStartupBanner(captured)) return true;
  const lines = captured.split('\n').map(l => l.replace(/\r/g, '').trim()).filter(l => l.length > 0);
  return lines.some(l =>
    /\b(loading|initializing|starting up)\b/i.test(l)
    || /\bmodel:\s*loading\b/i.test(l)
    || /\bconnecting\s+to\b/i.test(l));
}
function paneHasActiveTask(captured) {
  const lines = captured.split('\n').map(l => l.replace(/\r/g, '').trim()).filter(l => l.length > 0);
  const tail = lines.slice(-40);
  if (tail.some(l => /\b\d+\s+background terminal running\b/i.test(l))) return true;
  if (tail.some(l => /esc to interrupt/i.test(l))) return true;
  if (tail.some(l => /\bbackground terminal running\b/i.test(l))) return true;
  if (tail.some(l => /^[·✻]\s+[A-Za-z][A-Za-z0-9''-]*(?:\s+[A-Za-z][A-Za-z0-9''-]*){0,3}(?:…|\.{3})$/u.test(l))) return true;
  return false;
}
function paneLooksReady(captured) {
  const content = captured.trimEnd();
  if (content === '') return false;
  const lines = content.split('\n').map(l => l.replace(/\r/g, '').trimEnd()).filter(l => l.trim() !== '');
  if (lines.length === 0) return false;
  if (paneHasTrustPrompt(content)) return true;
  if (paneIsBootstrapping(content)) return false;
  const last = lines[lines.length - 1];
  if (paneLineLooksLikeIdlePrompt(last)) return true;
  return lines.some(paneLineLooksLikeIdlePrompt);
}
function paneIsIdle(captured) {
  if (!captured) return false;
  return paneLooksReady(captured) && !paneHasActiveTask(captured);
}

// ----- process verification + kill (mirrors cleanup-orphans.mjs) ---------------
function processCmdline(pid) {
  try {
    return execFileSync('ps', ['-p', String(pid), '-o', 'command='], {
      encoding: 'utf-8', timeout: 1500, stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}
function reEscape(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

/** Pure: does a command line belong to teammate <name> of <team>? (testable) */
function cmdlineIsTeammate(cmd, teamName, memberName) {
  if (!cmd) return false;
  const hasTeam = new RegExp(`--team-name[=\\s]+${reEscape(teamName)}\\b`).test(cmd);
  const hasName = new RegExp(`--agent-name[=\\s]+${reEscape(memberName)}\\b`).test(cmd)
    || new RegExp(`--agent-id[=\\s]+${reEscape(memberName)}@${reEscape(teamName)}\\b`).test(cmd);
  return hasTeam && hasName;
}

/** Confirm the pid is the claude teammate <name> of <team> — never the lead. */
function isVerifiedTeammateProcess(pid, teamName, memberName) {
  return cmdlineIsTeammate(processCmdline(pid), teamName, memberName);
}

function killGraceful(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 'SIGTERM');
    // Best-effort SIGKILL escalation; unref so we never block hook exit.
    setTimeout(() => {
      try { process.kill(pid, 0); process.kill(pid, 'SIGKILL'); } catch { /* already gone */ }
    }, GRACE_MS).unref();
    return true;
  } catch {
    return false;
  }
}

// ----- per-teammate idle-since state (the staleness clock) ---------------------
function stateFile(teamName, memberName) {
  const safe = `${teamName}__${memberName}`.replace(/[^A-Za-z0-9_.-]/g, '_');
  return join(STATE_DIR, `${safe}.json`);
}
function readState(teamName, memberName) {
  try { return JSON.parse(readFileSync(stateFile(teamName, memberName), 'utf-8')); }
  catch { return null; }
}
function writeState(teamName, memberName, data) {
  try {
    if (!existsSync(STATE_DIR)) mkdirSync(STATE_DIR, { recursive: true });
    writeFileSync(stateFile(teamName, memberName), JSON.stringify(data));
  } catch { /* non-fatal */ }
}
function clearState(teamName, memberName) {
  try { const f = stateFile(teamName, memberName); if (existsSync(f)) unlinkSync(f); }
  catch { /* non-fatal */ }
}

// ----- team config loading -----------------------------------------------------
function loadAllTeams() {
  const out = [];
  let entries = [];
  try { entries = readdirSync(TEAMS_DIR, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    const cfgPath = join(TEAMS_DIR, e.name, 'config.json');
    if (!existsSync(cfgPath)) continue;
    try {
      const cfg = JSON.parse(readFileSync(cfgPath, 'utf-8'));
      if (cfg && Array.isArray(cfg.members)) out.push(cfg);
    } catch { /* skip malformed */ }
  }
  return out;
}

/** Only tmux-backed, non-leader members with a real %N pane id are candidates. */
function teammateCandidates(cfg) {
  return (cfg.members || []).filter(m =>
    m
    && m.backendType === 'tmux'
    && m.agentType !== 'team-lead'
    && typeof m.tmuxPaneId === 'string'
    && /^%\d+$/.test(m.tmuxPaneId));
}

// ----- pure decision (no I/O — unit-testable) ---------------------------------
// pane:     { dead:boolean, pid:number } | undefined   (from the tmux snapshot)
// captured: pane text                                  prev: idle-clock state|null
// opts:     { now, threshold, selfPid, selfPpid, verify(pid)->bool }
// returns:  { alive, idle, idleForMs, pid, action:'skip'|'reap', reason,
//             clock:'clear'|'start'|'keep' }  — caller performs the side effects.
function decideReap(paneId, pane, captured, prev, opts) {
  const { now, threshold, selfPid, selfPpid, verify } = opts;
  if (!pane || pane.dead) {
    return { alive: false, idle: false, idleForMs: null, pid: null, action: 'skip', reason: 'pane_gone', clock: 'clear' };
  }
  const pid = pane.pid;
  const idle = paneIsIdle(captured);
  if (!idle) {
    return { alive: true, idle: false, idleForMs: null, pid, action: 'skip', reason: 'active', clock: 'clear' };
  }
  const sameTarget = prev && prev.paneId === paneId && prev.pid === pid && Number.isFinite(prev.firstIdleAt);
  const firstIdleAt = sameTarget ? prev.firstIdleAt : now;
  const idleForMs = now - firstIdleAt;
  if (!sameTarget) {
    return { alive: true, idle: true, idleForMs, pid, action: 'skip', reason: 'idle_clock_started', clock: 'start' };
  }
  if (idleForMs < threshold) {
    return { alive: true, idle: true, idleForMs, pid, action: 'skip', clock: 'keep',
      reason: `idle_below_threshold(${Math.round(idleForMs / 1000)}s/${Math.round(threshold / 1000)}s)` };
  }
  if (!pid || pid === selfPid || pid === selfPpid) {
    return { alive: true, idle: true, idleForMs, pid, action: 'skip', reason: 'self_or_no_pid_guard', clock: 'keep' };
  }
  if (!verify(pid)) {
    return { alive: true, idle: true, idleForMs, pid, action: 'skip', reason: 'process_not_verified_teammate', clock: 'keep' };
  }
  return { alive: true, idle: true, idleForMs, pid, action: 'reap', clock: 'keep',
    reason: `idle ${Math.round(idleForMs / 1000)}s >= threshold` };
}

// ----- main --------------------------------------------------------------------
function readStdinInput() {
  let raw = '';
  try { raw = readFileSync(0, 'utf-8'); } catch { /* no stdin (manual run) */ }
  try { return JSON.parse(raw || '{}'); } catch { return {}; }
}

function emitHookOk() {
  // Side-effect-only Stop hook: emit nothing and exit 0 (allow the stop).
  // Silent success guarantees we never interfere with other Stop hooks
  // (e.g. the handoff hook's decision:"block").
}

function main() {
  // Kill switches (consistent with OMC conventions).
  if (process.env.OMC_TEAMMATE_REAP_DISABLED === '1'
    || process.env.DISABLE_OMC === '1' || process.env.DISABLE_OMC === 'true'
    || (process.env.OMC_SKIP_HOOKS || '').split(',').map(s => s.trim()).includes('reap-idle-teammates')) {
    if (!DRY_RUN) return emitHookOk();
    process.stdout.write(JSON.stringify({ disabled: true }) + '\n');
    return;
  }

  const input = readStdinInput();
  const sessionId = typeof input.session_id === 'string' ? input.session_id : null;
  const selfPid = process.pid;
  const selfPpid = process.ppid; // the claude.exe that spawned this hook = current session

  const allTeams = loadAllTeams();

  // Scoping: the lead reaps only its OWN team. Without a session id we refuse to
  // reap (fail-safe); dry-run may scan everything for inspection.
  let teams;
  if (sessionId) {
    teams = allTeams.filter(t => t.leadSessionId === sessionId);
  } else if (DRY_RUN || FORCE_ALL) {
    teams = allTeams;
  } else {
    teams = [];
  }

  const now = Date.now();
  const report = { dryRun: DRY_RUN, thresholdMs: IDLE_THRESHOLD_MS, sessionId, scannedTeams: teams.length, candidates: [], reaped: [] };

  // One server-wide pane snapshot for the whole run. If tmux is unreachable we
  // skip everything (no kills, no clock resets) rather than guess.
  const snapshot = teams.length ? paneSnapshot() : new Map();
  const tmuxUnavailable = snapshot === null;

  for (const cfg of teams) {
    for (const m of teammateCandidates(cfg)) {
      const paneId = m.tmuxPaneId;
      const entry = { team: cfg.name, name: m.name, paneId, alive: false, idle: false, idleForMs: null, action: 'skip', reason: '' };

      if (tmuxUnavailable) {
        // Cannot read tmux at all — do NOT kill, do NOT reset the idle clock.
        entry.reason = 'tmux_unavailable_skip';
        report.candidates.push(entry);
        continue;
      }

      const pane = snapshot.get(paneId);
      const captured = pane && !pane.dead ? capturePane(paneId) : '';
      const prev = readState(cfg.name, m.name);
      const d = decideReap(paneId, pane, captured, prev, {
        now, threshold: IDLE_THRESHOLD_MS, selfPid, selfPpid,
        verify: (pid) => isVerifiedTeammateProcess(pid, cfg.name, m.name),
      });
      entry.alive = d.alive;
      entry.idle = d.idle;
      entry.idleForMs = d.idleForMs;
      if (d.pid) entry.pid = d.pid;
      entry.reason = d.reason;

      // Apply idle-clock side effects (skipped entirely in dry-run).
      if (!DRY_RUN) {
        if (d.clock === 'clear') clearState(cfg.name, m.name);
        else if (d.clock === 'start') writeState(cfg.name, m.name, { paneId, pid: pane.pid, firstIdleAt: now });
      }

      if (d.action === 'reap') {
        if (DRY_RUN) {
          entry.action = 'would_reap';
          report.reaped.push({ team: cfg.name, name: m.name, paneId, pid: d.pid, idleForMs: d.idleForMs, dryRun: true });
        } else {
          const ok = killGraceful(d.pid);
          entry.action = ok ? 'reaped' : 'kill_failed';
          entry.reason = `${d.reason}; SIGTERM${ok ? '' : ' failed'}`;
          if (ok) {
            clearState(cfg.name, m.name);
            report.reaped.push({ team: cfg.name, name: m.name, paneId, pid: d.pid, idleForMs: d.idleForMs });
            dbg(`reaped ${m.name}@${cfg.name} pane=${paneId} pid=${d.pid} idle=${Math.round(d.idleForMs / 1000)}s`);
          }
        }
      }
      report.candidates.push(entry);
    }
  }

  if (DRY_RUN) {
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
  } else {
    if (report.reaped.length) {
      process.stderr.write(`[reap-idle-teammates] reaped ${report.reaped.length} idle teammate(s): `
        + report.reaped.map(r => `${r.name}(pid ${r.pid})`).join(', ') + '\n');
    }
    emitHookOk();
  }
}

// Run main() only when executed directly (not when imported by a unit test).
const isMain = (() => {
  try { return import.meta.url === pathToFileURL(process.argv[1] || '').href; }
  catch { return true; }
})();

if (isMain) {
  try {
    main();
  } catch (err) {
    // Never block the Stop hook on error.
    if (DEBUG) process.stderr.write(`[reap-idle-teammates] error: ${err && err.stack ? err.stack : err}\n`);
    // Silent allow on error — never block the Stop hook.
  }
  process.exit(0);
}

// Exported for unit testing (no side effects on import).
export { decideReap, paneIsIdle, paneLooksReady, paneHasActiveTask, cmdlineIsTeammate };
