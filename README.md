# Dotfiles

개인 개발 환경 설정 — 새 맥북에서 한 줄로 복원.

## 포함 내용

| 카테고리 | 내용 |
|---------|------|
| **터미널** | tmux (Dracula), starship 프롬프트, bash 도구 alias |
| **CLI 도구** | eza, bat, fd, fzf, ripgrep, delta, lazygit, btop, dust, zoxide, yazi |
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
├── bootstrap.sh        # CLI 도구 설치 + 터미널 설정 (메인)
├── install.sh          # VSCode + Claude Code 설정 복사
├── update.sh           # 현재 설정 → dotfiles 내보내기
├── bashrc_append.sh    # .bashrc 추가 설정 (alias, fzf, zoxide 등)
├── tmux.conf           # tmux 설정 (Dracula, 마우스, vi 모드)
├── starship.toml       # 프롬프트 설정
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
