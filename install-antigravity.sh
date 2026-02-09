#!/bin/bash

set -e

echo "🚀 Google Antigravity - VSCode 확장 설치 시작..."

# Google Antigravity CLI 확인
if ! command -v antigravity &> /dev/null && ! command -v code &> /dev/null; then
    echo "❌ Google Antigravity CLI 또는 code CLI를 찾을 수 없습니다."
    echo "💡 수동으로 설치하거나 CLI 경로를 확인하세요."
    exit 1
fi

# CLI 선택 (antigravity 우선, 없으면 code)
CLI_CMD="code"
if command -v antigravity &> /dev/null; then
    CLI_CMD="antigravity"
    echo "✅ Google Antigravity CLI 사용"
else
    echo "✅ VSCode CLI 사용 (Antigravity가 호환되는 경우)"
fi

# 확장 설치
if [ -f "$HOME/dotfiles/vscode/extensions.txt" ]; then
    echo "📦 35개 VSCode 확장 설치 중..."
    echo ""

    installed=0
    failed=0

    while IFS= read -r extension; do
        if [ -n "$extension" ]; then
            echo "  ⏳ $extension 설치 중..."
            if $CLI_CMD --install-extension "$extension" --force 2>&1 | grep -q "successfully"; then
                echo "     ✅ 설치 완료"
                ((installed++))
            else
                echo "     ⚠️ 설치 실패 또는 이미 설치됨"
                ((failed++))
            fi
        fi
    done < "$HOME/dotfiles/vscode/extensions.txt"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 설치 완료: $installed 개"
    [ $failed -gt 0 ] && echo "⚠️ 실패/스킵: $failed 개"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "❌ extensions.txt 파일을 찾을 수 없습니다."
    exit 1
fi

# VSCode 설정 복사 (Google Antigravity가 동일한 경로를 사용하는 경우)
if [ -f "$HOME/dotfiles/vscode/settings.json" ]; then
    echo ""
    echo "📁 설정 파일 복사 중..."

    # VSCode 경로 시도
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    ANTIGRAVITY_USER_DIR="$HOME/Library/Application Support/Antigravity/User"

    # Google Antigravity 경로가 있으면 사용
    if [ -d "$ANTIGRAVITY_USER_DIR" ]; then
        cp "$HOME/dotfiles/vscode/settings.json" "$ANTIGRAVITY_USER_DIR/settings.json"
        echo "✅ Antigravity settings.json 복사 완료"
    elif [ -d "$VSCODE_USER_DIR" ]; then
        cp "$HOME/dotfiles/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
        echo "✅ VSCode settings.json 복사 완료"
    else
        echo "⚠️ 설정 디렉토리를 찾을 수 없습니다. 수동으로 복사하세요."
    fi
fi

echo ""
echo "🎉 Google Antigravity 설정 완료!"
echo "💡 에디터를 재시작하면 모든 확장이 활성화됩니다."
