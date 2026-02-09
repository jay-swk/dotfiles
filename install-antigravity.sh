#!/bin/bash

set -e

echo "🚀 Google Antigravity - VSCode 확장 설치 시작..."
echo ""

# Google Antigravity CLI 경로
ANTIGRAVITY_CLI="$HOME/.antigravity/antigravity/bin/antigravity"
ANTIGRAVITY_EXTENSIONS_DIR="$HOME/.antigravity/extensions"

# Antigravity CLI 확인
if [ ! -f "$ANTIGRAVITY_CLI" ]; then
    echo "❌ Google Antigravity CLI를 찾을 수 없습니다."
    echo "💡 예상 경로: $ANTIGRAVITY_CLI"
    echo ""
    echo "Google Antigravity가 설치되어 있나요?"
    echo "- macOS: /Applications/Antigravity.app"
    echo ""
    exit 1
fi

echo "✅ Google Antigravity CLI 발견: $ANTIGRAVITY_CLI"
echo "📁 확장 디렉토리: $ANTIGRAVITY_EXTENSIONS_DIR"
echo ""

# 확장 설치
EXTENSIONS_FILE="$HOME/dotfiles/vscode/extensions.txt"

if [ ! -f "$EXTENSIONS_FILE" ]; then
    echo "❌ extensions.txt 파일을 찾을 수 없습니다: $EXTENSIONS_FILE"
    exit 1
fi

extension_count=$(wc -l < "$EXTENSIONS_FILE" | tr -d ' ')
echo "📦 $extension_count 개의 VSCode 확장 설치 시작..."
echo ""

installed=0
failed=0
current=0

while IFS= read -r extension; do
    if [ -n "$extension" ]; then
        ((current++))
        echo "[$current/$extension_count] $extension"

        # Antigravity CLI로 확장 설치
        if "$ANTIGRAVITY_CLI" --install-extension "$extension" --force > /dev/null 2>&1; then
            echo "  ✅ 설치 완료"
            ((installed++))
        else
            echo "  ⚠️ 설치 실패 또는 이미 설치됨"
            ((failed++))
        fi
        echo ""
    fi
done < "$EXTENSIONS_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 설치 성공: $installed 개"
[ $failed -gt 0 ] && echo "⚠️  실패/스킵: $failed 개"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 설정 파일 정보 표시
echo "📋 추가 설정 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "$HOME/dotfiles/vscode/settings.json" ]; then
    echo "⚙️  VSCode 설정 파일 (settings.json)"
    echo "   위치: $HOME/dotfiles/vscode/settings.json"
    echo ""
    echo "   💡 Antigravity에서 수동으로 적용:"
    echo "   1. Antigravity 열기"
    echo "   2. Cmd+, (설정 열기)"
    echo "   3. 우측 상단 '{}' 아이콘 (JSON으로 열기)"
    echo "   4. dotfiles/vscode/settings.json 내용 복사-붙여넣기"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 Google Antigravity 설정 완료!"
echo ""
echo "다음 단계:"
echo "  1. Antigravity 재시작"
echo "  2. 확장들이 자동으로 활성화됨 (~/.antigravity/extensions/)"
echo "  3. 설정 파일은 위의 안내를 참고해서 수동 적용"
echo ""
echo "확장 목록 확인: $ANTIGRAVITY_CLI --list-extensions"
echo ""
