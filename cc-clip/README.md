# cc-clip — Claude Code 클립보드 over SSH

로컬 Mac 클립보드의 이미지를 SSH 원격 서버의 Claude Code 에 **Ctrl+V** 로 그대로 페이스트하기 위한 셋업.

Claude Code 자체는 SSH 환경에서 이미지 페이스트를 공식 지원하지 않는다 ([issue #42712](https://github.com/anthropics/claude-code/issues/42712) closed not-planned). 비교 조사 결과 [`cc-clip`](https://github.com/ShunmeiCho/cc-clip) (Go 정적 바이너리) 이 객관적으로 최선이라 이걸 표준으로 채택.

## 동작 원리

```
[로컬 Mac]                          [원격 서버]
cc-clip serve(18339)  ←─RemoteForward─  ~/.local/bin/xclip (bash shim)
   ↑ pbpaste                                ↑ HTTP POST → 18339
                                            ↑ Claude Code 가 spawn (Ctrl+V)
```

Claude Code 가 이미지 페이스트 시 `xclip` 을 호출 → bash shim 이 `localhost:18339` 로 HTTP 요청 → SSH RemoteForward 역터널 → 로컬 Mac 데몬이 pbpaste → PNG 반환 → 원격 `~/.claude/image-cache/` 에 저장.

## 전제

1. **Mac 사용자**: Homebrew 가 설치되어 있어야 함 (`pngpaste` 자동 설치에 필요). dotfiles `bootstrap.sh` 가 이미 깔아둠.
2. **호스트 alias**: 각 SSH 호스트는 본인 `~/.ssh/config` 에 alias 가 미리 정의되어 있어야 함:
   ```ssh-config
   Host myserver
       HostName 1.2.3.4
       User ubuntu
       IdentityFile ~/.ssh/myserver.pem
   ```
   setup.sh 가 cc-clip 옵션만 별도 마커 블록으로 추가 → SSH 가 자동 머지.
3. **SSH 키 인증** 가능해야 함 (ssh-add 또는 IdentityFile 로). 패스워드 인증도 동작은 하지만 매 단계 묻게 됨.

## 에이전트 친화 모드

다른 에이전트가 비대화형으로 실행할 때:
- TTY 미감지 시 자동 BATCH 모드 (메뉴 안 띄움, 키 인증 실패도 경고 후 계속)
- 강제로 켜려면 `CC_CLIP_BATCH=1 bash setup.sh --remote <host>`

## 빠른 시작 (3분)

```bash
# 1. Mac (한 번)
bash ~/dotfiles/cc-clip/setup.sh --local

# 2. 호스트별 (한 번씩, 원하는 만큼 반복 가능)
bash ~/dotfiles/cc-clip/setup.sh --remote myserver
bash ~/dotfiles/cc-clip/setup.sh --remote another-host
# ... N 개든 OK. 서버끼리 충돌 안 함

# 3. 사용
ssh myserver
claude     # 안에서 Ctrl+V 로 클립보드 이미지 페이스트
```

## SSH config 관리 — 여러 서버 셋업 시 안전

setup.sh 는 본인의 SSH config 를 **마커 블록**으로 관리:

```ssh-config
# 사용자 본인 작성 (그대로 보존)
Host myserver
    HostName 1.2.3.4
    User ubuntu
    IdentityFile ~/.ssh/myserver.pem

# setup.sh --remote myserver 가 추가한 영역 (절대 본인 블록 안 건드림)
# >>> cc-clip managed: myserver >>>
Host myserver
    RemoteForward 18339 127.0.0.1:18339
    ControlMaster no
    ControlPath none
# <<< cc-clip managed: myserver <<<
```

SSH 는 같은 `Host` 의 옵션들을 자동 머지 → 본인의 `HostName`/`User`/`IdentityFile` + cc-clip 의 `RemoteForward` 가 함께 적용됨.

마커의 효과:
- **추적성**: `--check` 가 마커 호스트와 외부/수동 추가된 18339 호스트를 분리해서 보여줌
- **안전한 제거**: `--uninstall remote <host>` 가 정확히 마커 영역만 잘라냄 → 본인 작품 절대 손상 X
- **멱등성**: 같은 호스트에 두 번 `--remote` 호출해도 중복 추가 안 함

### 여러 서버에 셋업 가능?

| 시나리오 | 충돌? | 비고 |
|---|---|---|
| 본인이 서버 A, B 에 동시 SSH (다른 서버) | **X** | 각 서버의 sshd 가 별도 18339 listener |
| 본인이 같은 서버에 두 세션 동시 SSH | **O** | 두 번째 forward silent fail. 회피: `CC_CLIP_PORT=18340 bash setup.sh --remote <host>` |
| 팀원과 같은 서버 공유 사용 | **O (동시 접속 시)** | 위와 동일 — 사용자별 다른 포트 권장 |
| SSH config 누적 (서버 10개 셋업) | **X** | 마커로 분리되어 어느 게 cc-clip 작품인지 명확 |

## 사용법

```bash
bash setup.sh                       # 인터랙티브 메뉴
bash setup.sh --local               # Mac 에 cc-clip 바이너리 + launchd 서비스
bash setup.sh --remote <host>       # SSH 호스트에 xclip shim 배포 (cc-clip setup 위임)
bash setup.sh --check               # 로컬 데몬 / 포트 / SSH config / 토큰 상태
bash setup.sh --uninstall local
bash setup.sh --uninstall remote <host>
```

환경변수:
- `CC_CLIP_PORT` — 데몬 포트 (기본 18339)
- `CC_CLIP_INSTALL_DIR` — 바이너리 설치 경로 (기본 `~/.local/bin`)
- `CC_CLIP_VERSION` — 강제 버전 (기본 latest)
- `CC_CLIP_UPGRADE=1` — 이미 설치돼도 재다운로드

## 알려진 함정 5개

1. **같은 서버에 동시 접속 시 18339 충돌** — 위 표 참고. 두 번째 세션의 `RemoteForward` 가 silent fail. 회피: `CC_CLIP_PORT=18340 bash setup.sh --remote <host>` 로 호스트별 다른 포트.
2. **`ControlMaster` 강제 off** — cc-clip 마커 블록은 `ControlMaster no` 를 강제. 기존 SSH multiplexing 설정과 충돌 가능 — 필요 시 다른 alias 로 분리.
3. **xclip race condition** — Claude Code 가 xclip 을 subprocess 로 spawn 하는 PTY race 가 원인 ([#42712](https://github.com/anthropics/claude-code/issues/42712)). cc-clip 의 lockfile 로 회피하지만 >5MB 큰 이미지나 빠른 연타 페이스트 시 간헐 실패 — 재시도하면 됨.
4. **원격 PATH 누락** — `~/.local/bin` 이 원격 셸 PATH 에 없으면 xclip shim 호출 실패 ("command not found"). setup.sh 가 `--remote` 시 자동으로 `~/.bashrc` + `~/.profile` 에 PATH 라인을 멱등 추가하지만, **기존 ssh 세션은 .bashrc 변경을 못 봄** → 새 ssh 세션을 열어야 적용. tmux 안에서 `default-shell` 이 비대화형이면 별도로 `setenv -g PATH ...` 도 필요.
5. **GIF / SVG / HEIC 미지원** — PNG 만. 스크린샷 위주면 무관.

(이전 "토큰 30일 만료" 항목은 setup.sh 가 첫 셋업 시 자동 sync 하고 `--check` 가 남은 일수를 항상 표시하므로 제거)

## 디버깅

```bash
# 로컬 데몬 살아있나
lsof -nP -iTCP:18339 -sTCP:LISTEN

# 원격에서 18339 reachable 한가
ssh <host> 'echo > /dev/tcp/127.0.0.1/18339 && echo OK'

# 원격 xclip 이 shim 인가 (진짜 xclip 이면 실패)
ssh <host> 'head -3 $(command -v xclip)'

# Claude Code 가 페이스트 받고 있나
ssh <host> 'ls -lat ~/.claude/image-cache/ | head'

# 토큰 / 세션 상태
ls -la ~/.cache/cc-clip/
ssh <host> 'ls -la ~/.cache/cc-clip/'

# 데몬 로그 (macOS launchd)
log show --predicate 'process == "cc-clip"' --last 10m
```

## 보안 노트

- 클립보드 데이터는 SSH 터널 안에서만 흐름 (외부 노출 X)
- 인증: Bearer 토큰 30일 슬라이딩 + per-session nonce
- 토큰은 로컬 `~/.cache/cc-clip/session.token`, 원격은 `~/.cache/cc-clip/session.token` 에 600 권한
- 원격 18339 가 외부에 노출되지 않도록 `RemoteForward 18339 127.0.0.1:18339` (loopback 바인딩) 확인

## 비교 / 왜 cc-clip 인가

| 후보 | 별 | UX | 탈락 사유 |
|---|---|---|---|
| **cc-clip** | 74 (활발) | Ctrl+V 네이티브 | — |
| clipssh | 20 | 별도 명령 1번 | UX 2-step (단, 폴백 후보) |
| claude-ssh-image-skill | 17 | `/paste-image` skill | Go 빌드 필요, 1인 메인테이너 |
| screenshot-uploader | 22 (stale) | 폴더 watch | 클립보드 아님 |
| lemonade | 724 | — | 이미지 미지원 |
| 수동 scp + 단축키 | n/a | 단축키 | 팀 표준화 어려움 |

cc-clip 의 결정적 장점: Claude Code 안에서 그대로 **Ctrl+V** → 팀원 교육 비용 0.

## 출처

- [ShunmeiCho/cc-clip](https://github.com/ShunmeiCho/cc-clip) (v0.7.0, 2026-04-28)
- [Alexander Zeitler — 기술 분석](https://alexanderzeitler.com/articles/paste-clipboard-images-into-claude-code-over-ssh/)
- [Claude Code #42712 — OSC 52/5522 not-planned](https://github.com/anthropics/claude-code/issues/42712)
