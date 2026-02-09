# Google Antigravity 설정 가이드

Google Antigravity에서 동일한 VSCode 확장 35개를 설치하는 방법입니다.

## 📁 Antigravity 디렉토리 구조

```
~/.antigravity/
├── extensions/                    # 설치된 확장들
│   ├── extensions.json           # 확장 메타데이터
│   ├── anthropic.claude-code-*/  # 개별 확장 디렉토리
│   └── ...
├── antigravity/
│   └── bin/
│       └── antigravity           # Antigravity CLI
└── argv.json                      # 설정 파일
```

**중요**: Antigravity는 `~/.antigravity/` 디렉토리에 모든 설정과 확장을 저장합니다.

## 🚀 자동 설치 (권장)

```bash
# 1. dotfiles 저장소 클론 (이미 있다면 생략)
git clone https://github.com/jay-swk/dotfiles.git ~/dotfiles

# 2. Antigravity 설치 스크립트 실행
chmod +x ~/dotfiles/install-antigravity.sh
~/dotfiles/install-antigravity.sh
```

이 스크립트는:
- ✅ `~/.antigravity/antigravity/bin/antigravity` CLI 자동 감지
- ✅ 35개 확장을 `~/.antigravity/extensions/`에 자동 설치
- ✅ 설치 진행률 표시

## 📦 수동 설치

### 방법 1: Antigravity CLI로 설치

```bash
# Antigravity CLI 경로
ANTIGRAVITY_CLI="$HOME/.antigravity/antigravity/bin/antigravity"

# extensions.txt의 각 확장을 설치
while IFS= read -r ext; do
  echo "Installing $ext..."
  "$ANTIGRAVITY_CLI" --install-extension "$ext" --force
done < ~/dotfiles/vscode/extensions.txt
```

**확장 설치 위치**: `~/.antigravity/extensions/`

### 방법 2: 에디터에서 하나씩 설치

Google Antigravity 에디터에서:
1. `Cmd+Shift+X` (확장 마켓플레이스 열기)
2. `~/dotfiles/vscode/extensions.txt` 파일 열기
3. 각 확장 ID를 검색해서 설치

## 🔧 설정 파일 적용

### settings.json 적용

Antigravity는 VSCode와 다른 설정 방식을 사용할 수 있습니다.

**방법 1: 에디터에서 직접 적용 (권장)**

1. Antigravity 열기
2. `Cmd+,` (설정 열기)
3. 우측 상단 `{}` 아이콘 클릭 (JSON으로 열기)
4. `~/dotfiles/vscode/settings.json` 내용 복사-붙여넣기

**방법 2: CLI로 확인**

```bash
# 현재 설정 확인
~/.antigravity/antigravity/bin/antigravity --list-extensions --show-versions

# 설정 디렉토리 확인
ls -la ~/.antigravity/
```

**참고**: Antigravity는 `~/.antigravity/` 디렉토리에 설정을 저장하지만,
User 설정(settings.json)은 에디터 내부에서 관리될 수 있습니다.

## 📋 포함된 확장 (35개)

### AI & Copilot
- anthropic.claude-code
- github.copilot
- github.copilot-chat

### JavaScript/TypeScript/React
- burkeholland.simple-react-snippets
- dsznajder.es7-react-js-snippets
- infeng.vscode-react-typescript
- xabikos.reactsnippets
- designbyajay.typescript-snippets
- steoates.autoimport

### Code Quality
- esbenp.prettier-vscode
- dbaeumer.vscode-eslint

### Docker & Infrastructure
- docker.docker
- ms-azuretools.vscode-docker
- ms-azuretools.vscode-containers
- ms-vscode-remote.remote-containers

### Terraform
- 4ops.terraform
- hashicorp.terraform

### Python
- ms-python.python
- ms-python.vscode-pylance
- ms-python.debugpy
- ms-python.isort
- ms-python.vscode-python-envs

### Jupyter
- ms-toolsai.jupyter
- ms-toolsai.jupyter-keymap
- ms-toolsai.jupyter-renderers
- ms-toolsai.vscode-jupyter-cell-tags
- ms-toolsai.vscode-jupyter-slideshow

### 기타
- bierner.markdown-preview-github-styles
- github.vscode-github-actions
- koichisasada.vscode-rdbg
- ms-ceintl.vscode-language-pack-ko
- nextfaze.json-parse-stringify
- olamilekanajibola.css-selector-generator
- samuel-weinhardt.vscode-jsp-lang
- zainchen.json

## 🔄 업데이트

Antigravity에서 확장을 추가/제거한 후:

```bash
cd ~/dotfiles

# Antigravity CLI 경로
ANTIGRAVITY_CLI="$HOME/.antigravity/antigravity/bin/antigravity"

# 확장 목록 업데이트
"$ANTIGRAVITY_CLI" --list-extensions > vscode/extensions.txt

# 변경사항 확인
git diff vscode/extensions.txt

# Git 푸시
git add vscode/extensions.txt
git commit -m "Update Antigravity extensions"
git push
```

**다른 환경에서 동기화:**

```bash
cd ~/dotfiles
git pull
./install-antigravity.sh  # 새로운 확장 자동 설치
```

## 💡 문제 해결

### Antigravity CLI를 찾을 수 없는 경우

```bash
# Antigravity 설치 확인
ls -la /Applications/Antigravity.app

# CLI 심볼릭 링크 확인
ls -la ~/.antigravity/antigravity/bin/

# CLI 직접 실행 테스트
~/.antigravity/antigravity/bin/antigravity --version
```

**해결 방법:**
1. Antigravity가 `/Applications/Antigravity.app`에 설치되어 있는지 확인
2. 설치되어 있다면 CLI 심볼릭 링크가 자동으로 생성됨
3. 없다면 Antigravity를 재설치

### 일부 확장이 설치 안 되는 경우

```bash
# 개별 확장 수동 설치
~/.antigravity/antigravity/bin/antigravity --install-extension EXTENSION_ID --force

# 설치된 확장 목록 확인
~/.antigravity/antigravity/bin/antigravity --list-extensions

# 확장 디렉토리 확인
ls -la ~/.antigravity/extensions/
```

**일반적인 원인:**
- Antigravity가 지원하지 않는 확장
- 네트워크 연결 문제
- 확장 ID 오타

### 설정이 적용 안 되는 경우

1. **에디터 재시작**: `Cmd+Q` 후 재실행
2. **확장 활성화 확인**: `Cmd+Shift+X`에서 확장 상태 확인
3. **수동 설정 적용**: `Cmd+,` → `{}` → settings.json 직접 편집

### 확장 디렉토리 정리

오래된 확장을 제거하려면:

```bash
# 사용하지 않는 확장 수동 삭제
rm -rf ~/.antigravity/extensions/EXTENSION_NAME-VERSION/

# 또는 CLI로 제거
~/.antigravity/antigravity/bin/antigravity --uninstall-extension EXTENSION_ID
```

## 🌐 참고 링크

- [Google Antigravity](https://antigravity.google/)
- [Google Antigravity Docs](https://antigravity.google/docs/rules)
- [Original dotfiles repo](https://github.com/jay-swk/dotfiles)
