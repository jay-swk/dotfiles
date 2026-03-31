#!/bin/bash

set -e

echo "🚀 개발 환경 동기화 시작..."

# ─── VSCode ─────────────────────────────────────────────
echo ""
echo "📦 [1/2] VSCode 설정"

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
echo "🤖 [2/2] Claude Code 설정"

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

echo ""
echo "✅ 동기화 완료!"
echo "💡 VSCode 재시작 + 새 claude 세션 시작 시 적용"
