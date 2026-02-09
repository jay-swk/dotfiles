# Google Antigravity 설정 가이드

Google Antigravity에서 동일한 VSCode 확장 35개를 설치하는 방법입니다.

## 🚀 자동 설치 (권장)

```bash
# 1. dotfiles 저장소 클론 (이미 있다면 생략)
git clone https://github.com/jay-swk/dotfiles.git ~/dotfiles

# 2. Antigravity 설치 스크립트 실행
chmod +x ~/dotfiles/install-antigravity.sh
~/dotfiles/install-antigravity.sh
```

이 스크립트는:
- ✅ Google Antigravity CLI 또는 VSCode CLI 자동 감지
- ✅ 35개 확장 자동 설치
- ✅ settings.json 자동 복사

## 📦 수동 설치

### 방법 1: 확장 하나씩 설치

Google Antigravity 에디터에서:
1. 확장 마켓플레이스 열기
2. `~/dotfiles/vscode/extensions.txt` 파일 열기
3. 각 확장 ID를 검색해서 설치

### 방법 2: CLI로 설치

```bash
# extensions.txt의 각 확장을 설치
while IFS= read -r ext; do
  code --install-extension "$ext" --force
  # 또는 antigravity CLI가 있다면:
  # antigravity --install-extension "$ext" --force
done < ~/dotfiles/vscode/extensions.txt
```

### 방법 3: Settings Sync 사용

Google Antigravity가 Settings Sync를 지원한다면:
1. VSCode에서 Settings Sync 활성화
2. GitHub 계정으로 로그인
3. Google Antigravity에서 동일한 계정으로 동기화

## 🔧 설정 파일 복사

### settings.json 적용

**위치 확인 (macOS):**
```bash
# VSCode
~/Library/Application Support/Code/User/settings.json

# Google Antigravity (추정)
~/Library/Application Support/Antigravity/User/settings.json
```

**복사 방법:**
```bash
# 수동 복사
cp ~/dotfiles/vscode/settings.json "$HOME/Library/Application Support/Antigravity/User/"

# 또는 에디터에서 열어서 복사-붙여넣기
```

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

확장을 추가/제거한 후:

```bash
cd ~/dotfiles

# 확장 목록 업데이트
code --list-extensions > vscode/extensions.txt
# 또는
antigravity --list-extensions > vscode/extensions.txt

# Git 푸시
git add .
git commit -m "Update extensions"
git push
```

## 💡 문제 해결

### Google Antigravity CLI를 찾을 수 없는 경우

1. **웹 기반인 경우**: 수동으로 마켓플레이스에서 설치
2. **CLI 설치 필요**: Google Antigravity 문서 참고
3. **VSCode CLI 사용**: `code` 명령어가 호환될 수 있음

### 일부 확장이 설치 안 되는 경우

- Google Antigravity가 지원하지 않는 확장일 수 있음
- 대체 확장 찾기 또는 해당 확장 제외

### 설정이 적용 안 되는 경우

- 에디터 재시작
- 설정 파일 경로 확인
- 수동으로 설정 값 복사

## 🌐 참고 링크

- [Google Antigravity](https://antigravity.google/)
- [Google Antigravity Docs](https://antigravity.google/docs/rules)
- [Original dotfiles repo](https://github.com/jay-swk/dotfiles)
