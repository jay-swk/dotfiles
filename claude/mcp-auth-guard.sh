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
