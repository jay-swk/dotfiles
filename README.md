# Dotfiles

개인 개발 환경 설정 — 새 맥북에서 한 줄로 복원.

## 포함 내용

| 카테고리 | 내용 |
|---------|------|
| **터미널 에뮬레이터** | Ghostty (Dracula, D2Coding + JetBrainsMono Nerd Font) |
| **셸** | zsh (미니멀, OMZ-free) + bash 호환. zsh-autosuggestions/syntax-highlighting/completions |
| **프롬프트/멀티플렉서** | starship, tmux (Dracula) |
| **CLI 도구** | eza, bat, fd, fzf, ripgrep, delta, lazygit, btop, dust, zoxide, yazi |
| **폰트** | D2Coding (한글 고정폭) + JetBrainsMono Nerd Font (아이콘) |
| **VSCode** | settings.json, keybindings.json, 확장 35개 |
| **Claude Code** | settings.json, statusline, 플러그인 생태계 자동 셋업, MCP 인증 가드 |
| **Antigravity** | Google Antigravity 에디터 확장 |

## 새 맥북 설정

```bash
# 1. 클론
git clone https://github.com/jay-swk/dotfiles.git ~/dotfiles

# 2. 전체 CLI 도구 + 터미널 환경 구축
bash ~/dotfiles/bootstrap.sh

# 3. VSCode + Claude Code + 플러그인/MCP 한번에
bash ~/dotfiles/install.sh
```

## 설정 업데이트 (원본 맥북)

```bash
bash ~/dotfiles/update.sh
```

## 다른 맥북에서 동기화

```bash
cd ~/dotfiles && git pull && ./install.sh
```

## 파일 구조

```
dotfiles/
├── bootstrap.sh        # CLI 도구 + 폰트 + 셸(zsh/bash) + Ghostty 자동 셋업 (메인)
├── install.sh          # VSCode + Claude Code 설정 복사
├── update.sh           # 현재 설정 → dotfiles 내보내기
├── zshrc_append.sh     # .zshrc 추가 설정 (OMZ 없이 brew 플러그인만)
├── bashrc_append.sh    # .bashrc 추가 설정 (bash 사용자 백업용)
├── tmux.conf           # tmux 설정 (Dracula, 마우스, vi 모드)
├── starship.toml       # 프롬프트 설정
├── ghostty/
│   └── config          # Ghostty 터미널 설정 (Dracula, D2Coding)
├── claude/
│   ├── settings.json        # Claude Code 설정 (플러그인 + 훅 포함)
│   ├── statusline.sh        # 상태바 (이모지 게이지 + 비용 + 5h rate)
│   ├── setup-ecosystem.sh   # 플러그인 + MCP 자동 설치
│   └── mcp-auth-guard.sh    # MCP 인증 만료 자동 감지 훅
├── vscode/
│   ├── settings.json   # VSCode 에디터 설정
│   └── extensions.txt  # 확장 목록
├── install-antigravity.sh
└── ANTIGRAVITY.md
```

## 쉘 구성 철학 — 왜 OMZ를 안 쓰나?

`oh-my-zsh`는 훌륭하지만 **쉘 시작이 느리고**(300~500ms), 현재 스택에서는 대부분 기능이 중복됩니다.
대신 Homebrew로 꼭 필요한 3개만 직접 설치:

| 패키지 | 역할 |
|--------|------|
| `zsh-autosuggestions` | 회색 힌트 자동완성 (→/End로 수락) |
| `zsh-syntax-highlighting` | 명령어 색상 하이라이트 (오타·잘못된 명령 빨간색) |
| `zsh-completions` | 자동완성 데이터베이스 확장 |

프롬프트는 **starship**, 스마트 cd는 **zoxide**, 검색은 **fzf**가 담당 — OMZ 기능 대부분을 이미 커버합니다.
결과: 쉘 시작 **5~10배 빠름**, 의존성 최소화.

## 자주 쓰는 alias / 함수

| 명령 | 설명 |
|------|------|
| `ll`, `la`, `lt` | eza 기반 ls 변형 (git 상태 포함) |
| `g` | lazygit |
| `gs`, `gd`, `gl`, `gp`, `gco`, `gc` | git status / diff / log / pull / checkout / commit |
| `mkcd <dir>` | `mkdir -p && cd` 한 번에 |
| `extract <file>` | zip/tar/gz/rar/7z 등 자동 해제 |
| `y` | yazi 실행 후 종료한 경로로 자동 이동 |
| `reload` | 쉘 설정 재로드 |
| `path` | $PATH를 줄바꿈으로 보기 좋게 |
| `ports` | LISTEN 중인 포트 목록 |
| `myip` / `localip` | 공인 IP / 로컬 IP |
| `rmi`, `cpi`, `mvi` | 확인 프롬프트 있는 안전 버전 |
| `z <keyword>` | zoxide smart cd (히스토리 기반) |
| `..`, `...`, `....` | 상위 디렉토리 이동 단축 |

## Claude Code 생태계

`install.sh` 실행 시 자동으로 플러그인과 MCP 서버가 설치된다.

| 구성 | 역할 |
|------|------|
| **Nova** | AI 개발 품질 게이트 (plan/design/review/verify) |
| **Context7** | 최신 라이브러리 문서 자동 주입 (환각 방지) |
| **Figma** | 디자인 연동 |
| **Codex** | OpenAI Codex 연동 |
| **Playwright MCP** | E2E 브라우저 테스트 자동화 |
| **MCP 인증 가드** | 세션 시작 시 인증 만료 자동 감지 + 안내 |

### MCP 인증 관리

OAuth 기반 MCP(Figma, Notion 등)는 인증이 주기적으로 만료된다.
인증 가드 훅이 매 세션 시작 시 자동으로 만료를 감지하고, Claude가 재인증 안내를 해준다.

```bash
# 인증 상태만 확인
bash ~/.claude/setup-ecosystem.sh --auth

# 전체 상태 확인 (설치 + 인증)
bash ~/.claude/setup-ecosystem.sh --check
```

## Claude Code 상태바 미리보기

```
🧠 Opus 4.6 ┃ 🟢 ██░░░ 35% ┃ 📊 ↑234K ↓89K ┃ 💰 $1.23 ┃ ⏱️ 🟢 5h:12%
```

| 항목 | 설명 |
|------|------|
| 🧠 모델 | 현재 사용 중인 모델 |
| 🟢/🟡/🔴 게이지 | 컨텍스트 윈도우 사용률 (50%↑ 노랑, 80%↑ 빨강) |
| 📊 토큰 | 입출력 토큰 (K 단위) |
| 💰 비용 | API 환산 비용 (구독 포함, 참고용) |
| ⏱️ 5h | 5시간 rate limit 사용률 |

## 지원 OS

- macOS (Homebrew)
- Ubuntu / Debian (apt)
