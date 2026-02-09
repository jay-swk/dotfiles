# Dotfiles - VSCode 설정

개인 VSCode 개발 환경 설정을 관리하는 저장소입니다.

## 📦 포함된 내용

- **VSCode 확장 (35개)**
  - Claude Code, GitHub Copilot
  - Prettier, ESLint
  - Docker, Terraform
  - React, TypeScript, Python 개발 도구
- **VSCode 설정 파일**
  - settings.json (에디터 설정)
  - keybindings.json (키보드 단축키)

## 🚀 새로운 맥북에서 설정 적용하기

### VSCode 설치

```bash
# 1. 저장소 클론
cd ~
git clone https://github.com/jay-swk/dotfiles.git

# 2. 설치 스크립트 실행
chmod +x ~/dotfiles/install.sh
~/dotfiles/install.sh

# 3. VSCode 재시작
```

### Google Antigravity 설치

```bash
# 1. 저장소 클론 (이미 했다면 생략)
cd ~
git clone https://github.com/jay-swk/dotfiles.git

# 2. Antigravity 설치 스크립트 실행
chmod +x ~/dotfiles/install-antigravity.sh
~/dotfiles/install-antigravity.sh

# 3. 에디터 재시작
```

📖 **자세한 가이드**: [ANTIGRAVITY.md](ANTIGRAVITY.md) 참고

## 🔄 설정 업데이트하기 (원본 맥북)

VSCode 설정이나 확장을 변경한 후:

```bash
cd ~/dotfiles

# 확장 목록 업데이트
code --list-extensions > vscode/extensions.txt

# 설정 파일 업데이트 (필요시)
cp "$HOME/Library/Application Support/Code/User/settings.json" vscode/
cp "$HOME/Library/Application Support/Code/User/keybindings.json" vscode/ 2>/dev/null

# Git 커밋 및 푸시
git add .
git commit -m "Update VSCode settings"
git push
```

## 📥 다른 맥북에서 동기화하기

```bash
cd ~/dotfiles
git pull
./install.sh
```

## 💡 유용한 팁

### 빠른 업데이트 alias

`.zshrc`나 `.bashrc`에 추가:

```bash
alias dotfiles-update='cd ~/dotfiles && code --list-extensions > vscode/extensions.txt && cp "$HOME/Library/Application Support/Code/User/settings.json" vscode/ 2>/dev/null && git add . && git commit -m "Update settings" && git push'
```

이제 `dotfiles-update` 명령어로 한 번에 동기화!

### Claude Code 설정도 함께 관리하려면

```bash
mkdir -p ~/dotfiles/claude
cp ~/.claude/keybindings.json ~/dotfiles/claude/ 2>/dev/null

# install.sh에 추가:
# cp ~/dotfiles/claude/keybindings.json ~/.claude/
```

## 📋 설치된 확장 목록

총 35개의 확장이 포함되어 있습니다:

- anthropic.claude-code
- github.copilot
- github.copilot-chat
- esbenp.prettier-vscode
- dbaeumer.vscode-eslint
- docker.docker
- ms-azuretools.vscode-docker
- hashicorp.terraform
- 그 외 27개...

전체 목록은 [vscode/extensions.txt](vscode/extensions.txt) 참조.

## 🛠 문제 해결

### VSCode 경로가 다른 경우 (Cursor 등)

install.sh의 `VSCODE_USER_DIR` 변수를 수정:

```bash
# Cursor
VSCODE_USER_DIR="$HOME/Library/Application Support/Cursor/User"
```

### 확장 설치 실패

확장이 설치되지 않는 경우 수동으로 설치:

```bash
code --install-extension EXTENSION_ID
```

## 📝 라이선스

개인 사용 목적
