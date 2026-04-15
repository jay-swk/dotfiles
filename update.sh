#!/bin/bash
# 현재 맥북의 설정을 dotfiles로 내보내기

set -e

echo "🔄 설정 내보내기..."

DOTFILES="$HOME/dotfiles"

# VSCode
echo "  📦 VSCode"
code --list-extensions > "$DOTFILES/vscode/extensions.txt" 2>/dev/null || true
cp "$HOME/Library/Application Support/Code/User/settings.json" "$DOTFILES/vscode/" 2>/dev/null || true
cp "$HOME/Library/Application Support/Code/User/keybindings.json" "$DOTFILES/vscode/" 2>/dev/null || true

# Claude Code
echo "  🤖 Claude Code"
mkdir -p "$DOTFILES/claude"
cp "$HOME/.claude/settings.json" "$DOTFILES/claude/" 2>/dev/null || true
cp "$HOME/.claude/statusline.sh" "$DOTFILES/claude/" 2>/dev/null || true
cp "$HOME/.claude/keybindings.json" "$DOTFILES/claude/" 2>/dev/null || true
cp "$HOME/.claude/setup-ecosystem.sh" "$DOTFILES/claude/" 2>/dev/null || true
cp "$HOME/.claude/mcp-auth-guard.sh" "$DOTFILES/claude/" 2>/dev/null || true

# zshrc_append (쉘 설정의 Modern CLI 섹션만 추출)
if [ -f "$HOME/.zshrc" ] && grep -q "Modern CLI Tools Configuration (zsh" "$HOME/.zshrc"; then
    echo "  🐚 zsh (Modern CLI 섹션 추출)"
    # "Modern CLI Tools Configuration (zsh" 마커 라인부터 파일 끝까지
    awk '/Modern CLI Tools Configuration \(zsh/{found=1} found' "$HOME/.zshrc" \
        | sed '1i\
' > "$DOTFILES/zshrc_append.sh"
fi

# Ghostty config
if [ -f "$HOME/.config/ghostty/config" ]; then
    echo "  👻 Ghostty"
    mkdir -p "$DOTFILES/ghostty"
    cp "$HOME/.config/ghostty/config" "$DOTFILES/ghostty/config"
fi

echo ""
cd "$DOTFILES"
git add -A
if git diff --cached --quiet; then
    echo "✅ 변경사항 없음"
else
    git diff --cached --stat
    echo ""
    read -p "커밋 & 푸시? (y/N) " yn
    if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
        git commit -m "update: $(date +%Y-%m-%d) 설정 동기화"
        git push
        echo "✅ 푸시 완료"
    else
        echo "커밋 취소 (git reset HEAD)"
        git reset HEAD
    fi
fi
