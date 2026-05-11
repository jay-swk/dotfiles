#!/bin/bash

set -e

echo "🚀 개발 환경 동기화 시작..."

# ─── VSCode ─────────────────────────────────────────────
echo ""
echo "📦 [1/4] VSCode 설정"

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_USER_DIR/snippets"

if [ -f "$HOME/dotfiles/vscode/settings.json" ]; then
    echo "  📁 settings.json 복사"
    cp "$HOME/dotfiles/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
fi

if [ -f "$HOME/dotfiles/vscode/keybindings.json" ]; then
    echo "  📁 keybindings.json 복사"
    cp "$HOME/dotfiles/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
fi

if [ -d "$HOME/dotfiles/vscode/snippets" ]; then
    for snippet in "$HOME/dotfiles/vscode/snippets"/*; do
        [ -f "$snippet" ] && cp "$snippet" "$VSCODE_USER_DIR/snippets/$(basename "$snippet")"
    done
fi

if [ -f "$HOME/dotfiles/vscode/extensions.txt" ]; then
    echo "  📦 확장 설치 중..."
    extension_count=0
    while IFS= read -r extension; do
        if [ -n "$extension" ]; then
            code --install-extension "$extension" --force 2>/dev/null || true
            ((extension_count++))
        fi
    done < "$HOME/dotfiles/vscode/extensions.txt"
    echo "  ✅ $extension_count 개 확장 설치"
fi

# ─── Claude Code ────────────────────────────────────────
echo ""
echo "🤖 [2/4] Claude Code 설정"

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

if [ -f "$HOME/dotfiles/claude/settings.json" ]; then
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        echo "  ⚠️  기존 settings.json 발견 — 백업 후 병합"
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    fi
    echo "  📁 settings.json 복사"
    cp "$HOME/dotfiles/claude/settings.json" "$CLAUDE_DIR/settings.json"
fi

if [ -f "$HOME/dotfiles/claude/statusline.sh" ]; then
    echo "  📁 statusline.sh 복사"
    cp "$HOME/dotfiles/claude/statusline.sh" "$CLAUDE_DIR/statusline.sh"
    chmod +x "$CLAUDE_DIR/statusline.sh"
fi

if [ -f "$HOME/dotfiles/claude/keybindings.json" ]; then
    echo "  📁 keybindings.json 복사"
    cp "$HOME/dotfiles/claude/keybindings.json" "$CLAUDE_DIR/keybindings.json"
fi

if [ -f "$HOME/dotfiles/claude/mcp-auth-guard.sh" ]; then
    echo "  📁 mcp-auth-guard.sh 복사"
    cp "$HOME/dotfiles/claude/mcp-auth-guard.sh" "$CLAUDE_DIR/mcp-auth-guard.sh"
    chmod +x "$CLAUDE_DIR/mcp-auth-guard.sh"
fi

if [ -f "$HOME/dotfiles/claude/setup-ecosystem.sh" ]; then
    echo "  📁 setup-ecosystem.sh 복사"
    cp "$HOME/dotfiles/claude/setup-ecosystem.sh" "$CLAUDE_DIR/setup-ecosystem.sh"
    chmod +x "$CLAUDE_DIR/setup-ecosystem.sh"
fi

# ─── Claude Code Ecosystem ─────────────────────────────
echo ""
echo "🔌 [3/4] Claude Code 플러그인 + MCP 생태계"

if command -v claude &>/dev/null; then
    bash "$CLAUDE_DIR/setup-ecosystem.sh"
else
    echo "  ⚠️  Claude Code 미설치 — 설치 후 아래 명령 실행:"
    echo "     bash ~/.claude/setup-ecosystem.sh"
fi

# ─── Codex ──────────────────────────────────────────────
echo ""
echo "🧭 [4/4] Codex CLI + 스킬/플러그인"

CODEX_DIR="$HOME/.codex"
mkdir -p "$CODEX_DIR"

if [ -f "$HOME/dotfiles/codex/setup-ecosystem.sh" ]; then
    echo "  📁 setup-ecosystem.sh 복사"
    cp "$HOME/dotfiles/codex/setup-ecosystem.sh" "$CODEX_DIR/setup-ecosystem.sh"
    chmod +x "$CODEX_DIR/setup-ecosystem.sh"
fi

if [ -f "$HOME/dotfiles/codex/skills.txt" ]; then
    echo "  📁 skills.txt 복사"
    cp "$HOME/dotfiles/codex/skills.txt" "$CODEX_DIR/skills.txt"
fi

if [ -f "$CODEX_DIR/setup-ecosystem.sh" ]; then
    bash "$CODEX_DIR/setup-ecosystem.sh"
else
    echo "  ⚠️  Codex 설정 스크립트 없음"
fi

echo ""
echo "✅ 동기화 완료!"
echo "💡 VSCode 재시작 + 새 claude/codex 세션 시작 시 적용"
echo ""
echo "🔗 [옵션] SSH 원격 Claude Code 에 이미지 페이스트하고 싶다면:"
echo "    bash ~/dotfiles/cc-clip/setup.sh --local           # Mac 한 번"
echo "    bash ~/dotfiles/cc-clip/setup.sh --remote <host>   # 호스트별"
