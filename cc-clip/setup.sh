#!/usr/bin/env bash
# ============================================
# cc-clip 셋업 — Claude Code 로컬↔SSH 이미지 페이스트
#
# 로컬 Mac 클립보드의 이미지를 SSH 원격의 Claude Code 에
# Ctrl+V 로 그대로 페이스트하기 위한 통합 셋업.
#
# 동작 원리:
#   [로컬 Mac]                          [원격 서버]
#   cc-clip serve(18339)  ←─RemoteForward─  ~/.local/bin/xclip(shim)
#                                              ↑ Claude Code 가 호출
#
# SSH config 는 마커 기반으로 관리:
#   # >>> cc-clip managed: <host> >>>
#   Host <host>
#       RemoteForward 18339 127.0.0.1:18339
#       ControlMaster no
#       ControlPath none
#   # <<< cc-clip managed: <host> <<<
#
# 사용자가 정의한 Host <host> 블록 (HostName/User/IdentityFile) 과
# SSH 자동 머지 — 사용자 작품은 절대 건드리지 않음.
#
# 사용법:
#   bash setup.sh                        # 인터랙티브 메뉴
#   bash setup.sh --local                # Mac 에 데몬 설치 + launchd 등록
#   bash setup.sh --remote <host>        # SSH 호스트에 shim 배포 (--local 먼저)
#   bash setup.sh --check [host]         # 로컬 상태 / host 지정 시 end-to-end doctor
#   bash setup.sh --uninstall [local|remote <host>]
# ============================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "${BLUE}[*]${NC} $1"; }

REPO="ShunmeiCho/cc-clip"
INSTALL_DIR="${CC_CLIP_INSTALL_DIR:-$HOME/.local/bin}"
DEFAULT_PORT="${CC_CLIP_PORT:-18339}"
SSH_CONFIG="$HOME/.ssh/config"

# --- 플랫폼 감지 ---
detect_platform() {
    local os arch
    case "$OSTYPE" in
        darwin*) os="darwin" ;;
        linux*)  os="linux" ;;
        *) error "지원하지 않는 OS: $OSTYPE"; exit 1 ;;
    esac
    case "$(uname -m)" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64)  arch="amd64" ;;
        *) error "지원하지 않는 아키텍처: $(uname -m)"; exit 1 ;;
    esac
    echo "${os}_${arch}"
}

# --- 최신 버전 조회 ---
latest_version() {
    curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/' \
        | tr -d 'v'
}

# --- 바이너리 다운로드 + 설치 (로컬용) ---
install_binary() {
    local platform version url tmp
    platform="$(detect_platform)"
    version="${CC_CLIP_VERSION:-$(latest_version)}"
    if [ -z "$version" ]; then
        error "최신 버전 조회 실패. CC_CLIP_VERSION=0.7.0 으로 강제 지정 가능"
        return 1
    fi
    url="https://github.com/${REPO}/releases/download/v${version}/cc-clip_${version}_${platform}.tar.gz"
    tmp="$(mktemp -d)"
    trap "rm -rf $tmp" RETURN

    step "cc-clip ${version} (${platform}) 다운로드 중..."
    if ! curl -fsSL "$url" -o "$tmp/cc-clip.tar.gz"; then
        error "다운로드 실패: $url"
        return 1
    fi
    tar -xzf "$tmp/cc-clip.tar.gz" -C "$tmp"
    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$tmp/cc-clip" "$INSTALL_DIR/cc-clip"
    info "설치 완료: $INSTALL_DIR/cc-clip"

    # PATH 자동 보장 (멱등) — 다음 --remote 가 cc-clip 명령에 의존
    local line="export PATH=\"$INSTALL_DIR:\$PATH\""
    local added=0
    for rc in ~/.zshrc ~/.bashrc ~/.profile; do
        [ -f "$rc" ] || continue
        if ! grep -qxF "$line" "$rc"; then
            echo "" >> "$rc"
            echo "# cc-clip PATH (added by dotfiles/cc-clip/setup.sh)" >> "$rc"
            echo "$line" >> "$rc"
            added=$((added+1))
            info "PATH 라인 추가: $rc"
        fi
    done
    if [ "$added" -gt 0 ]; then
        warn "새 셸을 열거나 'source ~/.zshrc' 실행 후 setup.sh --remote 진행"
    fi
}

# --- 로컬 모드 ---
setup_local() {
    echo "==============================================="
    step "로컬 cc-clip 셋업 시작"
    echo "==============================================="

    # 0) Mac 의존성: pngpaste (데몬이 클립보드 PNG 추출에 사용)
    if [[ "$OSTYPE" == "darwin"* ]] && ! command -v pngpaste &>/dev/null; then
        if command -v brew &>/dev/null; then
            step "pngpaste 설치 (데몬이 클립보드 PNG 추출에 필요)..."
            brew install pngpaste
        else
            error "Mac 에 pngpaste 가 없고 brew 도 없음."
            error "수동 설치 후 재실행: https://github.com/jcsalterego/pngpaste"
            return 1
        fi
    fi

    # 1) 바이너리
    if command -v cc-clip &>/dev/null; then
        info "cc-clip 이미 설치됨: $(command -v cc-clip)"
        local cur lat
        cur=$(cc-clip version 2>/dev/null | awk '{print $2}' || echo "?")
        lat=$(latest_version || echo "?")
        if [ "$cur" != "$lat" ] && [ "$lat" != "?" ]; then
            warn "버전 $cur → $lat 업그레이드 가능. CC_CLIP_UPGRADE=1 로 재설치"
            [ "${CC_CLIP_UPGRADE:-0}" = "1" ] && install_binary
        fi
    else
        install_binary
    fi

    # 2) 포트 충돌 확인
    if lsof -nP -iTCP:${DEFAULT_PORT} -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
        warn "포트 ${DEFAULT_PORT} 이미 사용 중 — 기존 서비스 확인:"
        lsof -nP -iTCP:${DEFAULT_PORT} -sTCP:LISTEN
        warn "기존 cc-clip 이면 정상. 아니면 CC_CLIP_PORT 환경변수로 다른 포트 사용"
    fi

    # 3) 서비스 등록
    if [[ "$OSTYPE" == "darwin"* ]]; then
        step "launchd 서비스 등록"
        cc-clip service install
        sleep 1
        if cc-clip service status 2>&1 | grep -qi running; then
            info "데몬 작동 중"
        else
            warn "서비스 상태 확인 — 'cc-clip service status' 로 직접 확인"
        fi
    elif [[ "$OSTYPE" == "linux"* ]]; then
        warn "Linux 로컬은 service install 미지원. 다음 중 하나로 실행:"
        echo "    cc-clip serve &                     # foreground"
        echo "    nohup cc-clip serve >/tmp/cc-clip.log 2>&1 &"
        echo "    systemd --user unit 작성"
    fi

    echo
    info "다음 단계: bash setup.sh --remote <host>"
}

# ============================================
# SSH config 마커 관리
# ============================================
marker_start() { echo "# >>> cc-clip managed: $1 >>>"; }
marker_end()   { echo "# <<< cc-clip managed: $1 <<<"; }

has_marker() {
    [ -f "$SSH_CONFIG" ] && grep -qF "$(marker_start "$1")" "$SSH_CONFIG" 2>/dev/null
}

host_defined_in_ssh_config() {
    # ssh -G 가 hostname 을 alias 와 다르게 출력하면 정의된 것
    local host="$1" hostname
    hostname=$(ssh -G "$host" 2>/dev/null | awk '$1=="hostname"{print $2; exit}')
    [ -n "$hostname" ] && [ "$hostname" != "$host" ]
}

list_marker_hosts() {
    [ -f "$SSH_CONFIG" ] || return 0
    grep -E '^# >>> cc-clip managed:' "$SSH_CONFIG" 2>/dev/null \
        | sed -E 's/^# >>> cc-clip managed: (.+) >>>$/\1/' || true
}

list_unmanaged_18339_hosts() {
    [ -f "$SSH_CONFIG" ] || return 0
    local all managed
    all=$(awk -v port="$DEFAULT_PORT" '
        /^Host / { host=$2 }
        $1=="RemoteForward" && $2==port { print host }
    ' "$SSH_CONFIG" 2>/dev/null | sort -u || true)
    managed=$(list_marker_hosts | sort -u || true)
    [ -z "$all" ] && return 0
    comm -23 <(echo "$all") <(echo "$managed") 2>/dev/null | grep -v '^$' || true
}

add_marker_block() {
    local host="$1"
    mkdir -p "$(dirname "$SSH_CONFIG")"
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    {
        echo ""
        marker_start "$host"
        echo "Host $host"
        echo "    RemoteForward $DEFAULT_PORT 127.0.0.1:$DEFAULT_PORT"
        echo "    ControlMaster no"
        echo "    ControlPath none"
        marker_end "$host"
    } >> "$SSH_CONFIG"
}

remove_marker_block() {
    local host="$1"
    [ -f "$SSH_CONFIG" ] || return
    has_marker "$host" || return 1
    local start end backup
    start=$(marker_start "$host")
    end=$(marker_end "$host")
    backup="$SSH_CONFIG.bak.cc-clip-$(date +%Y%m%d%H%M%S)"
    cp "$SSH_CONFIG" "$backup"
    # awk 로 시작~끝 마커 사이를 제거 (마커 라인 포함)
    awk -v s="$start" -v e="$end" '
        $0 == s { skip=1; next }
        $0 == e { skip=0; next }
        !skip
    ' "$SSH_CONFIG" > "$SSH_CONFIG.tmp" && mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    info "SSH config 마커 블록 제거 (백업: $backup)"
}

# ============================================
# claude 바이너리 보호 가드
# ============================================
# 업스트림 'cc-clip connect' 의 claude 래퍼는 npm 설치를 가정한다.
# Claude Code 네이티브 설치는 ~/.local/bin/claude 가 versions/<v> 로 가는
# 심링크라, 래퍼 쓰기가 심링크를 따라가 진짜 바이너리(수백 MB)를 1KB 래퍼로
# 덮어쓴다 → 'real claude binary not found in PATH'.
# npm 설치엔 무해(no-op). 네이티브 설치에선 백업 + 클로버 시 자동 복구.

guard_claude_binary_pre() {
    local host="$1"
    step "claude 바이너리 백업 (덮어쓰기 대비)..."
    ssh "$host" 'bash -s' <<'GUARD_PRE' 2>/dev/null || warn "guard_pre: 원격 백업 스킵 (SSH/권한)"
set -u
BIN="$HOME/.local/bin/claude"
VERS="$HOME/.local/share/claude/versions"
[ -L "$BIN" ] || exit 0
tgt="$(readlink -f "$BIN" 2>/dev/null || true)"
case "$tgt" in "$VERS"/*) : ;; *) exit 0 ;; esac
sz="$(stat -c%s "$tgt" 2>/dev/null || echo 0)"
# 진짜 바이너리(>100KB)만 백업 — 래퍼(~1KB)는 무시
if [ "$sz" -gt 100000 ]; then
    cp -p "$tgt" "$VERS/.cc-clip-guard.realbak" 2>/dev/null && echo "[guard] real claude 백업 ($sz bytes)"
fi
GUARD_PRE
}

guard_claude_binary_post() {
    local host="$1"
    step "claude 바이너리 무결성 검사..."
    local out
    out=$(ssh "$host" 'bash -s' <<'GUARD_POST' 2>/dev/null
set -u
BIN="$HOME/.local/bin/claude"
VERS="$HOME/.local/share/claude/versions"
[ -e "$BIN" ] || { echo "clean"; exit 0; }
# 네이티브 설치 시그니처 게이트: versions/ 디렉토리가 있어야 네이티브 설치다.
# npm 등 다른 설치는 이 디렉토리가 없고, 래퍼가 BIN 에 regular file 로
# 정상 설치되는 게 맞으므로(= cc-clip 본래 동작) 절대 건드리지 않는다.
[ -d "$VERS" ] || { echo "clean"; exit 0; }
tgt="$(readlink -f "$BIN" 2>/dev/null || echo "$BIN")"
clob=0
if [ -f "$tgt" ]; then
    sz="$(stat -c%s "$tgt" 2>/dev/null || echo 0)"
    [ "$sz" -lt 100000 ] && grep -qa "cc-clip claude wrapper" "$tgt" 2>/dev/null && clob=1
fi
if [ "$clob" -ne 1 ]; then
    rm -f "$VERS/.cc-clip-guard.realbak" 2>/dev/null || true
    echo "clean"; exit 0
fi
# 클로버 감지 — 래퍼를 옆으로 치우고 복구
mv -f "$tgt" "$tgt.cc-clip-clobbered.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
# 1순위: versions/ 의 다른 정상 ELF 로 심링크 재연결
newest=""
for f in "$VERS"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.realbak|*.bak|*cc-clip-clobbered*) continue ;; esac
    fsz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
    [ "$fsz" -gt 100000 ] || continue
    { [ -z "$newest" ] || [ "$f" -nt "$newest" ]; } && newest="$f"
done
if [ -n "$newest" ]; then
    ln -sfn "$newest" "$BIN"
    rm -f "$VERS/.cc-clip-guard.realbak" 2>/dev/null || true
    echo "repaired:relinked:$newest"; exit 0
fi
# 2순위: pre 백업 복원
if [ -f "$VERS/.cc-clip-guard.realbak" ]; then
    cp -p "$VERS/.cc-clip-guard.realbak" "$tgt" 2>/dev/null \
        && { rm -f "$VERS/.cc-clip-guard.realbak"; echo "repaired:restored-backup:$tgt"; exit 0; }
fi
echo "FAILED"
GUARD_POST
) || true
    case "$out" in
        clean)
            info "claude 바이너리 정상 (래퍼가 안 건드림)" ;;
        repaired:*)
            warn "cc-clip 가 claude 바이너리를 덮어써서 자동 복구함:"
            echo "    ${out#repaired:}"
            warn "알림 훅(Stop/Notification)은 미설치 — 이미지 붙여넣기(xclip shim)는 정상 동작" ;;
        FAILED)
            error "claude 바이너리 덮어써짐 + 복구 실패 — 원격에서 'claude' 재실행 시 네이티브 업데이터가 재설치" ;;
        *)
            warn "guard_post: 상태 불명(SSH 실패?) — 원격 'claude --version' 수동 확인 권장" ;;
    esac
}

# ============================================
# 원격 셋업
# ============================================
setup_remote() {
    local host="${1:-}"
    if [ -z "$host" ]; then
        error "호스트 지정 필요: setup.sh --remote <host-alias>"
        return 1
    fi

    echo "==============================================="
    step "원격 호스트 셋업: $host"
    echo "==============================================="

    # 사전 조건
    if ! command -v cc-clip &>/dev/null; then
        error "로컬 cc-clip 미설치. 먼저: bash setup.sh --local"
        return 1
    fi

    # SSH config 에 호스트 alias 가 정의되어 있어야 함
    if ! host_defined_in_ssh_config "$host"; then
        error "$host 가 ~/.ssh/config 에 정의되어 있지 않습니다."
        echo
        echo "먼저 ~/.ssh/config 에 alias 를 추가하세요. 예시:"
        echo
        echo "    Host $host"
        echo "        HostName <ip-or-domain>"
        echo "        User <username>"
        echo "        IdentityFile <key-path>"
        echo
        echo "그 후 다시 실행: bash setup.sh --remote $host"
        return 1
    fi

    # 이미 마커가 있으면 멱등 처리
    if has_marker "$host"; then
        info "$host 는 이미 cc-clip 관리 중. 재설치하려면 먼저 --uninstall remote $host"
        return 0
    fi

    # 포트 충돌 사전 경고
    local conflicts
    conflicts=$(list_unmanaged_18339_hosts || true)
    if [ -n "$conflicts" ]; then
        warn "${DEFAULT_PORT} 을 이미 쓰는 호스트:"
        echo "$conflicts" | sed 's/^/    - /'
        warn "같은 서버에 동시 SSH 접속 시 두 번째 forward 가 silent fail 가능"
    fi

    # SSH 연결 확인
    step "SSH 연결 확인..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" true 2>/dev/null; then
        info "SSH 키 인증 OK"
    else
        warn "Key 인증 실패 — 패스워드 또는 ssh-add 필요할 수 있음"
        if [ "${CC_CLIP_BATCH:-0}" = "1" ] || [ ! -t 0 ]; then
            warn "비대화형 (BATCH/no-tty) — 그래도 진행 (cc-clip connect 가 자체 처리)"
        else
            read -p "그래도 진행? [y/N] " yn
            [[ "$yn" =~ ^[Yy]$ ]] || return 1
        fi
    fi

    # 가드: cc-clip connect 가 네이티브 claude 바이너리를 덮어쓰기 전 백업
    guard_claude_binary_pre "$host"

    # cc-clip connect 위임 — 바이너리/shim/토큰/deploy.json/PATH/Claude hook 자동 처리
    # (SSH config 는 안 만짐 → 우리 마커 시스템과 공존)
    step "cc-clip connect $host 실행 (전체 배포)..."
    if ! cc-clip connect "$host"; then
        error "cc-clip connect 실패"
        return 1
    fi

    # 가드: connect 가 claude 바이너리를 덮어썼는지 검사 + 클로버 시 자동 복구
    guard_claude_binary_post "$host"

    # SSH config 에 마커 블록 추가 (cc-clip 이 안 만지므로 우리가 관리)
    step "SSH config 에 마커 블록 추가..."
    add_marker_block "$host"
    info "SSH config 갱신 (마커 포함)"

    echo
    info "원격 셋업 완료: $host"
    echo
    echo "사용법:"
    echo "    ssh $host"
    echo "    claude         # 안에서 Ctrl+V 로 이미지 페이스트"
}

# ============================================
# 상태 확인
# ============================================
check_status() {
    local target_host="${1:-}"
    echo "==============================================="
    step "cc-clip 상태 점검"
    echo "==============================================="
    echo

    # 특정 호스트가 주어지면 cc-clip doctor 위임 (end-to-end 진단)
    if [ -n "$target_host" ] && command -v cc-clip &>/dev/null; then
        step "cc-clip doctor --host $target_host"
        cc-clip doctor --host "$target_host"
        echo
        echo "── SSH config 마커 상태 ──"
        if has_marker "$target_host"; then
            info "$target_host : cc-clip 마커 있음"
        else
            warn "$target_host : 마커 없음 (수동 추가됐거나 마커 박히기 전)"
        fi
        return
    fi

    echo "── 로컬 바이너리 ──"
    if command -v cc-clip &>/dev/null; then
        info "$(cc-clip version 2>/dev/null || echo cc-clip)"
        echo "    경로: $(command -v cc-clip)"
    else
        error "cc-clip 미설치"
    fi
    echo

    echo "── Mac 의존성 ──"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v pngpaste &>/dev/null; then
            info "pngpaste 설치됨 ($(pngpaste -v 2>&1 | head -1))"
        else
            error "pngpaste 미설치 — 'brew install pngpaste' (데몬이 클립보드 PNG 추출에 필요)"
        fi
    fi
    echo

    echo "── 로컬 데몬 (포트 ${DEFAULT_PORT}) ──"
    if lsof -nP -iTCP:${DEFAULT_PORT} -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
        info "데몬 작동 중"
        lsof -nP -iTCP:${DEFAULT_PORT} -sTCP:LISTEN | tail -n +2 | awk '{print "    pid="$2, "proc="$1}'
    else
        warn "데몬 미작동 — 'cc-clip service start' 또는 'cc-clip serve'"
    fi
    echo

    echo "── launchd 서비스 (macOS) ──"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v cc-clip &>/dev/null; then
        cc-clip service status 2>&1 | sed 's/^/    /'
    else
        echo "    (macOS 가 아니거나 cc-clip 미설치)"
    fi
    echo

    echo "── cc-clip 관리 호스트 (마커 기반) ──"
    local managed
    managed=$(list_marker_hosts)
    if [ -n "$managed" ]; then
        echo "$managed" | sed 's/^/    - /'
    else
        warn "(없음)"
    fi
    echo

    echo "── 마커 없이 ${DEFAULT_PORT} 쓰는 호스트 (외부/수동 추가) ──"
    local unmanaged
    unmanaged=$(list_unmanaged_18339_hosts)
    if [ -n "$unmanaged" ]; then
        echo "$unmanaged" | sed 's/^/    - /'
        warn "이 블록들은 cc-clip 관리 외 — 수동 추가했거나 외부 도구 작품"
    else
        echo "    (없음)"
    fi
    echo

    echo "── 토큰 캐시 ──"
    local token_file="$HOME/.cache/cc-clip/session.token"
    if [ -f "$token_file" ]; then
        local mtime age_days
        mtime=$(stat -f %m "$token_file" 2>/dev/null || stat -c %Y "$token_file" 2>/dev/null)
        age_days=$(( ($(date +%s) - mtime) / 86400 ))
        if [ "$age_days" -lt 25 ]; then
            info "토큰 유효 (생성 후 ${age_days}일, 만료까지 ~$((30-age_days))일)"
        else
            warn "토큰 만료 임박 (${age_days}일) — 다음 페이스트 시 재발급"
        fi
    else
        warn "토큰 미생성 — 데몬 한 번 띄우면 자동 생성"
    fi
}

# ============================================
# 제거
# ============================================
uninstall_local() {
    step "로컬 cc-clip 제거"
    if command -v cc-clip &>/dev/null; then
        cc-clip service uninstall 2>/dev/null || warn "service uninstall 실패 (이미 제거됨?)"
    fi
    rm -f "$INSTALL_DIR/cc-clip"
    rm -rf "$HOME/.cache/cc-clip"
    info "로컬 제거 완료"

    local managed
    managed=$(list_marker_hosts)
    if [ -n "$managed" ]; then
        warn "다음 호스트의 마커 블록이 SSH config 에 남아있습니다:"
        echo "$managed" | sed 's/^/    - /'
        echo "    각각 'bash setup.sh --uninstall remote <host>' 로 제거 권장"
    fi
}

uninstall_remote() {
    local host="${1:-}"
    [ -z "$host" ] && { error "호스트 지정 필요: --uninstall remote <host>"; return 1; }

    step "원격 cc-clip 제거: $host"

    # 1) SSH config 마커 블록 제거 (사용자 본인 블록은 절대 안 건드림)
    if has_marker "$host"; then
        remove_marker_block "$host"
    else
        warn "SSH config 에 cc-clip 마커 없음 — 수동 추가된 블록은 직접 정리하세요"
    fi

    # 2) 원격 shim / 바이너리 / 캐시 제거
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" true 2>/dev/null; then
        ssh "$host" '
            rm -f ~/.local/bin/xclip ~/.local/bin/wl-paste ~/.local/bin/cc-clip ~/.local/bin/cc-clip-hook
            rm -rf ~/.cache/cc-clip
        ' 2>/dev/null && info "원격 shim/바이너리/캐시 제거 완료" \
                      || warn "원격 정리 일부 실패 — SSH 로 직접 확인"
    else
        warn "$host 에 SSH 연결 실패 — 원격 정리 스킵 (SSH config 만 정리됨)"
        echo "    수동 정리: ssh $host 'rm -f ~/.local/bin/xclip ~/.local/bin/cc-clip ~/.local/bin/cc-clip-hook && rm -rf ~/.cache/cc-clip'"
    fi
}

# ============================================
# 인터랙티브 메뉴
# ============================================
menu() {
    echo "==============================================="
    echo "  cc-clip 셋업"
    echo "  로컬↔SSH Claude Code 이미지 페이스트"
    echo "==============================================="
    echo
    echo "  1) 로컬 셋업 (Mac 에 데몬)"
    echo "  2) 원격 셋업 (SSH 호스트에 shim 배포)"
    echo "  3) 상태 확인"
    echo "  4) 제거"
    echo "  q) 종료"
    echo
    read -p "선택: " choice
    case "$choice" in
        1) setup_local ;;
        2) read -p "호스트 alias (~/.ssh/config 에 정의된 이름): " h; setup_remote "$h" ;;
        3) check_status ;;
        4)
            read -p "로컬(l) / 원격(r): " m
            if [ "$m" = "l" ]; then uninstall_local
            elif [ "$m" = "r" ]; then read -p "호스트: " h; uninstall_remote "$h"
            fi
            ;;
        q|Q) exit 0 ;;
        *) error "잘못된 선택"; exit 1 ;;
    esac
}

usage() {
    sed -n '2,29p' "$0" | sed 's/^# \?//'
}

# --- 진입점 ---
main() {
    if [ $# -eq 0 ]; then
        # 비대화형 (no tty / BATCH) 이면 menu 대신 usage
        if [ ! -t 0 ] || [ "${CC_CLIP_BATCH:-0}" = "1" ]; then
            usage
            return
        fi
        menu
        return
    fi
    case "$1" in
        --local)     setup_local ;;
        --remote)    shift; setup_remote "${1:-}" ;;
        --check)     shift; check_status "${1:-}" ;;
        --uninstall)
            shift
            case "${1:-local}" in
                local)  uninstall_local ;;
                remote) shift; uninstall_remote "${1:-}" ;;
                *) error "uninstall 대상: local|remote <host>"; exit 1 ;;
            esac
            ;;
        -h|--help)   usage ;;
        *) usage; exit 1 ;;
    esac
}

main "$@"
