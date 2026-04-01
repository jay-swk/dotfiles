#!/usr/bin/env bash
# Claude Code Ecosystem 자동 셋업
# 어떤 맥에서든 이 스크립트 하나로 플러그인 + MCP + 인증 가드 설정
#
# 사용법: bash ~/.claude/setup-ecosystem.sh
#   --check   설치 상태만 확인 (변경 없음)
#   --auth    MCP 인증 상태만 확인 + 재인증 안내

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODE="${1:-install}"

# ── 의존성 확인 ──────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v claude >/dev/null 2>&1 || missing+=("claude")
  command -v npx >/dev/null 2>&1 || missing+=("npx")
  command -v node >/dev/null 2>&1 || missing+=("node")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}[ERROR]${NC} 필수 도구 누락: ${missing[*]}"
    echo "  claude: npm install -g @anthropic-ai/claude-code"
    echo "  npx/node: https://nodejs.org/"
    exit 1
  fi
}

# ── 플러그인 설치 ────────────────────────────────────────────
install_plugins() {
  echo -e "\n${BLUE}[1/3] 플러그인 설치${NC}"

  # 마켓플레이스 등록
  local marketplaces=(
    "nova-marketplace:TeamSPWK/nova"
    "openai-codex:openai/codex-plugin-cc"
  )

  for entry in "${marketplaces[@]}"; do
    local name="${entry%%:*}"
    local repo="${entry#*:}"
    if claude plugins marketplace list 2>/dev/null | grep -q "$name"; then
      echo -e "  ${GREEN}✓${NC} 마켓플레이스: $name"
    else
      echo -e "  ${YELLOW}+${NC} 마켓플레이스 등록: $name ($repo)"
      # settings.json에 직접 추가해야 함 — CLI에서 마켓플레이스 add가 없으므로
      echo -e "  ${YELLOW}!${NC} ~/.claude/settings.json에 수동 등록 필요: $name → $repo"
    fi
  done

  # 플러그인 목록 (이름@마켓플레이스)
  local plugins=(
    "nova@nova-marketplace"
    "figma@claude-plugins-official"
    "context7@claude-plugins-official"
    "codex@openai-codex"
  )

  for plugin in "${plugins[@]}"; do
    if claude plugins list 2>/dev/null | grep -q "$plugin"; then
      echo -e "  ${GREEN}✓${NC} $plugin"
    else
      echo -e "  ${YELLOW}+${NC} 설치 중: $plugin"
      claude plugin install "$plugin" --scope user 2>&1 | tail -1
    fi
  done
}

# ── MCP 서버 등록 ────────────────────────────────────────────
install_mcp_servers() {
  echo -e "\n${BLUE}[2/3] MCP 서버 등록${NC}"

  # Playwright MCP (stdio, 인증 불필요)
  if claude mcp list 2>/dev/null | grep -q "playwright"; then
    echo -e "  ${GREEN}✓${NC} playwright (E2E 브라우저 테스트)"
  else
    echo -e "  ${YELLOW}+${NC} playwright 등록 중..."
    claude mcp add --scope user --transport stdio playwright -- npx @playwright/mcp --headless 2>&1
    echo -e "  ${GREEN}✓${NC} playwright 등록 완료"
  fi
}

# ── MCP 인증 상태 확인 ───────────────────────────────────────
check_mcp_auth() {
  echo -e "\n${BLUE}[3/3] MCP 인증 상태 확인${NC}"

  local auth_cache="$HOME/.claude/mcp-needs-auth-cache.json"
  local has_problem=false

  # claude mcp list 출력에서 인증 상태 파싱
  local mcp_output
  mcp_output=$(claude mcp list 2>&1)

  # 서버명 추출: "서버명: URL/cmd - 상태" 형식
  # 서버명에 콜론이 포함될 수 있으므로 (plugin:figma:figma) " - " 기준으로 분리
  local needs_auth=()
  while IFS= read -r line; do
    # "Checking" 헤더나 빈 줄 스킵
    [[ -z "$line" ]] && continue
    echo "$line" | grep -q "^Checking" && continue

    # "서버명: ... - 상태" 에서 서버명 추출 (첫 번째 ": "까지)
    local server_name
    server_name=$(echo "$line" | sed 's/: .*//')

    if echo "$line" | grep -q "Needs authentication"; then
      needs_auth+=("$server_name")
    elif echo "$line" | grep -q "Connected"; then
      echo -e "  ${GREEN}✓${NC} $server_name — 연결됨"
    elif echo "$line" | grep -q "Error\|Failed\|Timeout"; then
      needs_auth+=("$server_name")
    fi
  done <<< "$mcp_output"

  # 인증 필요 서버 안내
  for server in "${needs_auth[@]}"; do
    has_problem=true
    echo -e "  ${RED}✗${NC} $server — 인증 필요"

    # 서버별 재인증 가이드
    case "$server" in
      *figma*)
        echo -e "    ${YELLOW}→ 재인증: Claude Code 세션에서 Figma 도구 호출 시 자동 OAuth 플로우${NC}"
        echo -e "    ${YELLOW}  또는: claude mcp remove 'plugin:figma:figma'${NC}"
        echo -e "    ${YELLOW}        claude plugin install figma@claude-plugins-official${NC}"
        ;;
      *Notion*|*notion*)
        echo -e "    ${YELLOW}→ 재인증: https://mcp.notion.com 방문 → 연결 갱신${NC}"
        echo -e "    ${YELLOW}  또는: claude mcp remove 'claude.ai Notion' && 재추가${NC}"
        ;;
      *context7*)
        echo -e "    ${YELLOW}→ Context7은 인증 불필요 — 네트워크/npx 문제 확인${NC}"
        echo -e "    ${YELLOW}  npx -y @upstash/context7-mcp 직접 실행해서 확인${NC}"
        ;;
      *playwright*)
        echo -e "    ${YELLOW}→ Playwright는 인증 불필요 — npx/node 문제 확인${NC}"
        echo -e "    ${YELLOW}  npx @playwright/mcp --headless 직접 실행해서 확인${NC}"
        ;;
      *)
        echo -e "    ${YELLOW}→ 해당 서비스의 OAuth/API 키를 갱신하세요${NC}"
        echo -e "    ${YELLOW}  claude mcp remove '$server' → 재등록${NC}"
        ;;
    esac
  done

  if [[ "$has_problem" == true ]]; then
    echo ""
    echo -e "  ${YELLOW}[TIP]${NC} 인증이 자주 풀리면 세션 시작 시 자동 알림이 옵니다."
    echo -e "  ${YELLOW}      ${NC} 인증 가드 훅이 설치되어 있는지 확인: ~/.claude/settings.json → hooks"
    return 1
  else
    echo -e "\n  ${GREEN}모든 MCP 서버 인증 정상${NC}"
    return 0
  fi
}

# ── SessionStart 인증 가드 훅 설치 ───────────────────────────
install_auth_guard_hook() {
  echo -e "\n${BLUE}[+] 인증 가드 훅 설치${NC}"

  local guard_script="$HOME/.claude/mcp-auth-guard.sh"

  # 가드 스크립트 생성
  cat > "$guard_script" << 'GUARD_EOF'
#!/usr/bin/env bash
# MCP 인증 상태 체크 — SessionStart 훅으로 실행
# 인증이 풀린 MCP 서버가 있으면 additionalContext로 경고 주입

set -euo pipefail

AUTH_CACHE="$HOME/.claude/mcp-needs-auth-cache.json"

# 캐시 파일이 없거나 비어있으면 정상
if [[ ! -f "$AUTH_CACHE" ]] || [[ ! -s "$AUTH_CACHE" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

# 캐시에 항목이 있으면 인증 풀린 서버 존재
RESULT=$(python3 -c "
import json, sys
try:
    with open('$AUTH_CACHE') as f:
        data = json.load(f)
    if not data:
        print(json.dumps({'additionalContext': ''}))
        sys.exit(0)
    servers = list(data.keys())
    names = ', '.join(servers)
    warn = f'⚠ MCP 인증 만료 감지: {names}. 사용자에게 재인증이 필요하다고 안내하세요. 상세 확인: bash ~/.claude/setup-ecosystem.sh --auth'
    print(json.dumps({'additionalContext': warn}))
except Exception:
    print(json.dumps({'additionalContext': ''}))
" 2>/dev/null) || RESULT='{"additionalContext":""}'

echo "$RESULT"
GUARD_EOF

  chmod +x "$guard_script"
  echo -e "  ${GREEN}✓${NC} $guard_script 생성"

  # settings.json에 훅 등록
  local settings_file="$HOME/.claude/settings.json"
  python3 << PYEOF
import json

with open("$settings_file") as f:
    settings = json.load(f)

# hooks.SessionStart 배열에 가드 추가
hooks = settings.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [])

guard_entry = {
    "type": "command",
    "command": "bash ~/.claude/mcp-auth-guard.sh"
}

# 이미 등록되어 있으면 스킵
already = any(
    h.get("command", "").endswith("mcp-auth-guard.sh")
    for h in session_hooks
    if isinstance(h, dict)
)

if not already:
    session_hooks.append(guard_entry)
    with open("$settings_file", "w") as f:
        json.dump(settings, f, indent=2)
    print("  ✓ settings.json에 SessionStart 훅 등록")
else:
    print("  ✓ SessionStart 훅 이미 등록됨")
PYEOF
}

# ── 요약 출력 ────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE} Claude Code Ecosystem 상태${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo ""
  echo "플러그인:"
  claude plugins list 2>/dev/null | grep "❯\|✔\|✗" | sed 's/^/  /'
  echo ""
  echo "MCP 서버:"
  claude mcp list 2>/dev/null | grep -v "^Checking\|^$" | sed 's/^/  /'
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo ""
  echo "다른 맥에서 동일 환경 구성:"
  echo "  1. git clone 또는 이 스크립트 복사"
  echo "  2. bash ~/.claude/setup-ecosystem.sh"
  echo "  3. 인증 필요한 MCP는 안내에 따라 로그인"
  echo ""
  echo "인증 상태만 확인:"
  echo "  bash ~/.claude/setup-ecosystem.sh --auth"
}

# ── 메인 ─────────────────────────────────────────────────────
main() {
  echo -e "${BLUE}Claude Code Ecosystem Setup${NC}"
  echo -e "──────────────────────────────────"

  check_deps

  case "$MODE" in
    --check)
      check_mcp_auth || true
      print_summary
      ;;
    --auth)
      check_mcp_auth || true
      ;;
    install|*)
      install_plugins
      install_mcp_servers
      install_auth_guard_hook
      check_mcp_auth || true
      print_summary
      ;;
  esac
}

main
