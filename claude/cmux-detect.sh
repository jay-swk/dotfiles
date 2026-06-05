#!/usr/bin/env bash
# SessionStart hook: cmux 호스트 환경을 감지하면 Claude에게 cmux browser 우선 사용을 지시한다.
# stdout으로 출력한 텍스트는 SessionStart additionalContext로 세션에 주입된다.

if [ -n "$CMUX_WORKSPACE_ID" ] || [ -n "$CMUX_BUNDLED_CLI_PATH" ] || [ -n "$CMUX_PANEL_ID" ]; then
  cat <<'EOF'
# cmux Host Environment Detected

You are running inside cmux (Ghostty-based macOS terminal with embedded scriptable browser).

**For any browser automation, UI/UX inspection, web scraping, or visual verification task:**

1. **PREFER `cmux browser` CLI** over puppeteer/playwright/dev-browser. The user can see the browser pane next to your terminal, making review collaborative.
2. The `cmux-browser` skill is installed — invoke it when working on browser tasks.
3. Quick reference:
   - `cmux browser open <url>` — opens browser surface (returns surface ref)
   - `cmux browser <surface> snapshot --interactive` — accessibility tree with element refs
   - `cmux browser <surface> screenshot --out <path>` — PNG capture
   - `cmux browser <surface> viewport <w> <h>` — responsive testing
   - `cmux browser <surface> console list` / `errors list` — collect runtime issues
   - `cmux docs browser` for full docs
4. Do not propose puppeteer/dev-browser/playwright unless cmux browser is insufficient for the specific task.

Workspace: $CMUX_WORKSPACE_ID
EOF
fi

exit 0
