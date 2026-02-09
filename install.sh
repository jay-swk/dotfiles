#!/bin/bash

set -e

echo "🚀 VSCode 설정 동기화 시작..."

# VSCode 설정 디렉토리
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

# 디렉토리 생성
mkdir -p "$VSCODE_USER_DIR/snippets"

# 설정 파일 복사 (심볼릭 링크 대신 복사 사용)
if [ -f "$HOME/dotfiles/vscode/settings.json" ]; then
    echo "📁 settings.json 복사 중..."
    cp "$HOME/dotfiles/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
fi

if [ -f "$HOME/dotfiles/vscode/keybindings.json" ]; then
    echo "📁 keybindings.json 복사 중..."
    cp "$HOME/dotfiles/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
fi

# 스니펫 복사
if [ -d "$HOME/dotfiles/vscode/snippets" ]; then
    echo "📁 스니펫 복사 중..."
    for snippet in "$HOME/dotfiles/vscode/snippets"/*; do
        if [ -f "$snippet" ]; then
            cp "$snippet" "$VSCODE_USER_DIR/snippets/$(basename "$snippet")"
        fi
    done
fi

# 확장 설치
if [ -f "$HOME/dotfiles/vscode/extensions.txt" ]; then
    echo "📦 VSCode 확장 설치 중..."
    extension_count=0
    while IFS= read -r extension; do
        if [ -n "$extension" ]; then
            echo "  - $extension"
            code --install-extension "$extension" --force 2>/dev/null || echo "    ⚠️ 설치 실패"
            ((extension_count++))
        fi
    done < "$HOME/dotfiles/vscode/extensions.txt"
    echo "✅ $extension_count 개의 확장 설치 완료"
fi

echo ""
echo "✅ VSCode 설정 동기화 완료!"
echo "💡 VSCode를 재시작하면 모든 설정이 적용됩니다."
