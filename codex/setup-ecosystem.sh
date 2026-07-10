#!/usr/bin/env bash
# Codex CLI ecosystem setup.
# Reproducible defaults for permissions, skills, plugins, MCP, and /goal.
#
# Usage:
#   bash ~/.codex/setup-ecosystem.sh
#   bash ~/.codex/setup-ecosystem.sh --check
#   bash ~/.codex/setup-ecosystem.sh --skills

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODE="${1:-install}"
CODEX_DIR="$HOME/.codex"
CONFIG_FILE="$CODEX_DIR/config.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_FILE="$SCRIPT_DIR/skills.txt"
DEFAULT_MODEL="${CODEX_MODEL:-gpt-5.6-sol}"
DEFAULT_REASONING="${CODEX_REASONING:-high}"
DEFAULT_APPROVAL_POLICY="${CODEX_APPROVAL_POLICY:-never}"
DEFAULT_SANDBOX_MODE="${CODEX_SANDBOX_MODE:-danger-full-access}"

info() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; }

ensure_dir() {
  mkdir -p "$CODEX_DIR/skills"
}

install_codex_cli() {
  echo -e "\n${BLUE}[1/4] Codex CLI${NC}"

  if command -v codex >/dev/null 2>&1; then
    info "$(codex --version 2>/dev/null | tail -1)"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    err "codex와 npm이 없습니다"
    echo "    Node.js 또는 nvm 설치 후 다시 실행하세요."
    echo "    npm install -g @openai/codex"
    exit 1
  fi

  warn "Codex CLI 설치 중: npm install -g @openai/codex"
  npm install -g @openai/codex
  info "$(codex --version 2>/dev/null | tail -1)"
}

toml_set() {
  local section="$1"
  local key="$2"
  local value="$3"
  local overwrite="${4:-true}"

  python3 - "$CONFIG_FILE" "$section" "$key" "$value" "$overwrite" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
section = sys.argv[2]
key = sys.argv[3]
value = sys.argv[4]
overwrite = sys.argv[5] == "true"

path.parent.mkdir(parents=True, exist_ok=True)
text = path.read_text() if path.exists() else ""
lines = text.splitlines()
section_re = re.compile(r"^\s*\[.*\]\s*$")
key_re = re.compile(rf"^\s*{re.escape(key)}\s*=")

def write():
    path.write_text("\n".join(lines).rstrip() + "\n")

if section:
    header = f"[{section}]"
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == header:
            start = idx
            break
    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend([header, f"{key} = {value}"])
        write()
        raise SystemExit(0)

    end = len(lines)
    for idx in range(start + 1, len(lines)):
        if section_re.match(lines[idx]):
            end = idx
            break

    for idx in range(start + 1, end):
        if key_re.match(lines[idx]):
            if overwrite:
                lines[idx] = f"{key} = {value}"
                write()
            raise SystemExit(0)

    lines.insert(end, f"{key} = {value}")
    write()
    raise SystemExit(0)

first_section = len(lines)
for idx, line in enumerate(lines):
    if section_re.match(line):
        first_section = idx
        break

for idx in range(first_section):
    if key_re.match(lines[idx]):
        if overwrite:
            lines[idx] = f"{key} = {value}"
            write()
        raise SystemExit(0)

lines.insert(first_section, f"{key} = {value}")
write()
PY
}

ensure_config() {
  echo -e "\n${BLUE}[2/4] Codex 기본 설정${NC}"
  ensure_dir

  toml_set "" "model" "\"$DEFAULT_MODEL\"" false
  toml_set "" "model_reasoning_effort" "\"$DEFAULT_REASONING\"" false
  info "기본 모델 설정 확인: $DEFAULT_MODEL / $DEFAULT_REASONING"

  toml_set "" "approval_policy" "\"$DEFAULT_APPROVAL_POLICY\"" true
  toml_set "" "sandbox_mode" "\"$DEFAULT_SANDBOX_MODE\"" true
  warn "권한 설정 적용: $DEFAULT_APPROVAL_POLICY / $DEFAULT_SANDBOX_MODE"

  if codex features list 2>/dev/null | awk '$1 == "goals" {print $3}' | grep -q '^true$'; then
    info "/goal 이미 활성화됨"
  else
    if codex features enable goals >/dev/null 2>&1; then
      info "/goal 활성화"
    else
      warn "codex features enable goals 실패 - config.toml에 직접 반영"
      toml_set "features" "goals" "true" true
    fi
  fi
}

enable_plugins() {
  echo -e "\n${BLUE}[3/4] Codex 플러그인${NC}"

  local plugins=(
    "documents@openai-primary-runtime"
    "pdf@openai-primary-runtime"
    "spreadsheets@openai-primary-runtime"
    "presentations@openai-primary-runtime"
    "template-creator@openai-primary-runtime"
    "sites@openai-bundled"
    "browser@openai-bundled"
    "chrome@openai-bundled"
    "visualize@openai-bundled"
    "gmail@openai-curated"
    "slack@openai-curated"
    "codex-security@openai-curated"
  )
  local installed_plugins
  installed_plugins="$(codex plugin list 2>/dev/null | awk '$2 ~ /^installed/ {print $1}')"

  for plugin in "${plugins[@]}"; do
    if grep -qx "$plugin" <<<"$installed_plugins"; then
      toml_set "plugins.\"$plugin\"" "enabled" "true" true
      info "$plugin already installed, enabled"
    elif codex plugin add "$plugin" --json >/dev/null 2>&1; then
      info "$plugin installed, enabled"
    else
      warn "$plugin 설치 실패 - enabled 설정만 반영"
      toml_set "plugins.\"$plugin\"" "enabled" "true" true
    fi
  done
}

install_one_skill() {
  local skill="$1"
  local dest="$CODEX_DIR/skills/$skill"
  local system_dest="$CODEX_DIR/skills/.system/$skill"
  local installer="$CODEX_DIR/skills/.system/skill-installer/scripts/install-skill-from-github.py"
  local local_cache="$CODEX_DIR/vendor_imports/skills/skills/.curated/$skill"

  if [[ -d "$dest" || -d "$system_dest" ]]; then
    info "$skill 이미 설치됨"
    return 0
  fi

  if [[ -f "$installer" ]]; then
    if python3 "$installer" --repo openai/skills --path "skills/.curated/$skill" >/tmp/codex-skill-install.log 2>&1; then
      info "$skill 설치"
      return 0
    fi
    warn "$skill GitHub 설치 실패 - local cache fallback 시도"
  fi

  if [[ -d "$local_cache" ]]; then
    cp -R "$local_cache" "$dest"
    info "$skill 설치: local cache"
    return 0
  fi

  warn "$skill 설치 실패"
  sed 's/^/    /' /tmp/codex-skill-install.log 2>/dev/null || true
}

install_skills() {
  echo -e "\n${BLUE}[4/4] Codex curated skills${NC}"

  if [[ ! -f "$SKILLS_FILE" ]]; then
    warn "skills.txt 없음: $SKILLS_FILE"
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    local skill
    skill="$(echo "$line" | sed 's/#.*//' | xargs)"
    [[ -z "$skill" ]] && continue
    install_one_skill "$skill"
  done < "$SKILLS_FILE"
}

print_summary() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE} Codex 상태${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo ""

  if command -v codex >/dev/null 2>&1; then
    echo "CLI:"
    codex --version 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "Features:"
    codex features list 2>/dev/null | awk '$1 == "goals" || $1 == "plugins" || $1 == "browser_use" || $1 == "multi_agent" || $1 == "apps" || $1 == "hooks" {print "  " $0}'
    echo ""
    echo "Permissions:"
    awk -F' *= *' '$1 == "approval_policy" || $1 == "sandbox_mode" {print "  " $1 " = " $2}' "$CONFIG_FILE"
    echo ""
    echo "Plugins:"
    codex plugin list 2>/dev/null | awk '$2 ~ /^installed/ {print "  " $1}'
    echo ""
    echo "MCP:"
    codex mcp list 2>/dev/null | sed 's/^/  /' || true
  else
    warn "codex 명령을 찾을 수 없음"
  fi

  echo ""
  echo "Skills:"
  if [[ -d "$CODEX_DIR/skills" ]]; then
    find "$CODEX_DIR/skills" -mindepth 1 -maxdepth 1 -type d -not -name ".system" -print \
      | sed "s#^$CODEX_DIR/skills/#  #"
  fi

  echo ""
  echo "적용 후 새 Codex 세션을 시작하면 신규 skills/plugins가 로드됩니다."
}

main() {
  echo -e "${BLUE}Codex Ecosystem Setup${NC}"
  echo -e "──────────────────────────────────"

  case "$MODE" in
    --check)
      print_summary
      ;;
    --skills)
      ensure_dir
      install_skills
      print_summary
      ;;
    install|*)
      install_codex_cli
      ensure_config
      enable_plugins
      install_skills
      print_summary
      ;;
  esac
}

main "$@"
