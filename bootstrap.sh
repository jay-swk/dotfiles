#!/usr/bin/env bash
# ============================================
# Terminal Bootstrap Script
# 어디서든 동일한 터미널 환경 구축
#
# 사용법:
#   curl -sL <URL> | bash
#   또는
#   bash bootstrap.sh
#
# 지원: Ubuntu/Debian, macOS
# ============================================
set -euo pipefail

# --- 색상 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# --- OS 감지 ---
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="mac"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    else
        error "지원하지 않는 OS: $OSTYPE"
        error "Ubuntu/Debian 또는 macOS만 지원합니다"
        exit 1
    fi
    info "OS 감지: $OS"
}

# --- 패키지 매니저 ---
install_pkg() {
    if [[ "$OS" == "mac" ]]; then
        brew install "$@" 2>/dev/null || true
    else
        sudo apt install -y -qq "$@" 2>/dev/null || true
    fi
}

# ============================================
# 1. 패키지 매니저 준비
# ============================================
setup_package_manager() {
    info "패키지 매니저 준비..."
    if [[ "$OS" == "mac" ]]; then
        if ! command -v brew &>/dev/null; then
            warn "Homebrew 설치 중..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew update -q
    else
        sudo apt update -qq
    fi
}

# ============================================
# 2. CLI 도구 설치
# ============================================
install_cli_tools() {
    echo ""
    info "=== CLI 도구 설치 ==="

    if [[ "$OS" == "mac" ]]; then
        # macOS — brew로 한방에
        brew install \
            eza bat fd fzf ripgrep git-delta \
            lazygit btop dust zoxide ncdu duf \
            starship tldr tree jq micro tmux yazi \
            zsh-autosuggestions zsh-syntax-highlighting zsh-completions \
            2>/dev/null || true

        # fzf 키바인딩 설치 (bash + zsh 모두)
        "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc 2>/dev/null || true

    else
        # --- apt 기본 도구 ---
        install_pkg bat fd-find fzf ripgrep ncdu duf htop btop tree jq curl wget unzip

        # --- eza (별도 레포) ---
        if ! command -v eza &>/dev/null; then
            info "eza 설치..."
            sudo mkdir -p /etc/apt/keyrings
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
            sudo apt update -qq && sudo apt install -y -qq eza
        fi

        # --- starship ---
        if ! command -v starship &>/dev/null; then
            info "starship 설치..."
            curl -sS https://starship.rs/install.sh | sudo sh -s -- -y >/dev/null
        fi

        # --- delta ---
        if ! command -v delta &>/dev/null; then
            info "delta 설치..."
            DELTA_VER="0.18.2"
            wget -q "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/git-delta_${DELTA_VER}_amd64.deb" -O /tmp/delta.deb
            sudo dpkg -i /tmp/delta.deb >/dev/null; rm -f /tmp/delta.deb
        fi

        # --- lazygit ---
        if ! command -v lazygit &>/dev/null; then
            info "lazygit 설치..."
            LAZYGIT_VER="0.44.1"
            wget -q "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VER}/lazygit_${LAZYGIT_VER}_Linux_x86_64.tar.gz" -O /tmp/lazygit.tar.gz
            tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
            sudo mv /tmp/lazygit /usr/local/bin/; rm -f /tmp/lazygit.tar.gz
        fi

        # --- dust ---
        if ! command -v dust &>/dev/null; then
            info "dust 설치..."
            DUST_VER="1.1.1"
            wget -q "https://github.com/bootandy/dust/releases/download/v${DUST_VER}/dust-v${DUST_VER}-x86_64-unknown-linux-gnu.tar.gz" -O /tmp/dust.tar.gz
            tar -xzf /tmp/dust.tar.gz -C /tmp
            sudo mv /tmp/dust-v${DUST_VER}-x86_64-unknown-linux-gnu/dust /usr/local/bin/; rm -rf /tmp/dust*
        fi

        # --- zoxide ---
        if ! command -v zoxide &>/dev/null; then
            info "zoxide 설치..."
            curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null 2>&1
        fi

        # --- micro ---
        if ! command -v micro &>/dev/null; then
            info "micro 설치..."
            curl -sL https://getmic.ro | bash >/dev/null 2>&1
            sudo mv ./micro /usr/local/bin/micro
        fi

        # --- tldr ---
        if ! command -v tldr &>/dev/null; then
            info "tldr 설치..."
            pip3 install --break-system-packages -q tldr 2>/dev/null || pip3 install -q tldr 2>/dev/null || true
        fi

        # --- yazi ---
        if ! command -v yazi &>/dev/null; then
            info "yazi 설치..."
            YAZI_VER=$(curl -sL "https://api.github.com/repos/sxyazi/yazi/releases/latest" | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')
            wget -q "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VER}/yazi-x86_64-unknown-linux-gnu.zip" -O /tmp/yazi.zip
            unzip -qo /tmp/yazi.zip -d /tmp/yazi
            sudo mv /tmp/yazi/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/
            sudo mv /tmp/yazi/yazi-x86_64-unknown-linux-gnu/ya /usr/local/bin/
            rm -rf /tmp/yazi*
        fi

        # --- tmux (최신) ---
        install_pkg tmux
    fi
}

# ============================================
# 2.5 폰트 설치 (터미널 가독성)
# ============================================
install_fonts() {
    echo ""
    info "=== 폰트 설치 ==="
    if [[ "$OS" == "mac" ]]; then
        # D2Coding: 한글 고정폭 / JetBrainsMono Nerd Font: 아이콘
        brew install --cask font-d2coding font-jetbrains-mono-nerd-font 2>/dev/null || true
        info "D2Coding, JetBrainsMono Nerd Font 설치 완료 (또는 이미 설치됨)"
    else
        # Linux: 수동 설치
        local font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"
        if ! ls "$font_dir"/D2Coding* &>/dev/null; then
            info "D2Coding 다운로드..."
            wget -q "https://github.com/naver/d2codingfont/raw/master/D2CodingAll/D2Coding-Ver1.3.2-20180524-all.zip" -O /tmp/d2coding.zip
            unzip -qo /tmp/d2coding.zip -d /tmp/d2coding
            cp /tmp/d2coding/D2CodingAll/*.ttc "$font_dir/" 2>/dev/null || true
            rm -rf /tmp/d2coding*
        fi
        if ! ls "$font_dir"/JetBrainsMono* &>/dev/null; then
            info "JetBrainsMono Nerd Font 다운로드..."
            wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -O /tmp/jbm.zip
            unzip -qo /tmp/jbm.zip -d "$font_dir" '*.ttf' 2>/dev/null || true
            rm -f /tmp/jbm.zip
        fi
        command -v fc-cache &>/dev/null && fc-cache -f "$font_dir" &>/dev/null
        info "폰트 설치 완료: $font_dir"
    fi
}

# ============================================
# 3. 설정 파일 배포
# ============================================
deploy_configs() {
    echo ""
    info "=== 설정 파일 배포 ==="
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # --- 셸 감지 ---
    local user_shell="$(basename "${SHELL:-/bin/bash}")"
    info "사용자 셸 감지: $user_shell"

    # --- .zshrc 추가 (zsh 사용자) ---
    if [[ "$user_shell" == "zsh" ]]; then
        if [[ ! -f ~/.zshrc ]]; then
            touch ~/.zshrc
            info ".zshrc 신규 생성"
        fi
        if ! grep -q "Modern CLI Tools Configuration (zsh" ~/.zshrc 2>/dev/null; then
            info ".zshrc에 도구 설정 추가..."
            cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
            cat "$SCRIPT_DIR/zshrc_append.sh" >> ~/.zshrc
        else
            warn ".zshrc 설정 이미 존재 — 스킵"
        fi
    fi

    # --- .bashrc 추가 (bash 사용자 또는 백업용) ---
    if ! grep -q "Modern CLI Tools Configuration" ~/.bashrc 2>/dev/null; then
        info ".bashrc에 도구 설정 추가..."
        cat "$SCRIPT_DIR/bashrc_append.sh" >> ~/.bashrc
    else
        warn ".bashrc 설정 이미 존재 — 스킵"
    fi

    # --- .tmux.conf ---
    if [[ -f ~/.tmux.conf ]]; then
        warn ".tmux.conf 이미 존재 — 백업 후 덮어쓰기"
        cp ~/.tmux.conf ~/.tmux.conf.bak
    fi
    cp "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
    # tmux 실행 중이면 설정 즉시 반영
    if tmux info &>/dev/null; then
        tmux source-file ~/.tmux.conf 2>/dev/null && info ".tmux.conf 실행 중인 세션에 반영 완료"
    fi
    info ".tmux.conf 배포 완료"

    # --- starship.toml ---
    mkdir -p ~/.config
    cp "$SCRIPT_DIR/starship.toml" ~/.config/starship.toml
    info "starship.toml 배포 완료"

    # --- Ghostty config ---
    if [[ -f "$SCRIPT_DIR/ghostty/config" ]]; then
        mkdir -p ~/.config/ghostty
        if [[ -f ~/.config/ghostty/config ]] && ! cmp -s "$SCRIPT_DIR/ghostty/config" ~/.config/ghostty/config; then
            cp ~/.config/ghostty/config ~/.config/ghostty/config.bak
            warn "기존 ghostty/config 백업 → config.bak"
        fi
        cp "$SCRIPT_DIR/ghostty/config" ~/.config/ghostty/config
        info "ghostty/config 배포 완료"
    fi

    # --- Claude Code 상태바 ---
    if command -v claude &>/dev/null; then
        info "Claude Code 상태바 설정..."
        mkdir -p ~/.claude
        cp "$SCRIPT_DIR/claude-statusline.sh" ~/.claude/statusline-command.sh

        # settings.json에 statusLine 추가 (기존 파일 보존)
        if [[ -f ~/.claude/settings.json ]]; then
            if ! jq -e '.statusLine' ~/.claude/settings.json &>/dev/null; then
                jq '. + {"statusLine": {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}}' \
                    ~/.claude/settings.json > /tmp/claude-settings.json && \
                    mv /tmp/claude-settings.json ~/.claude/settings.json
                info "Claude Code statusLine 설정 추가 완료"
            else
                warn "Claude Code statusLine 설정 이미 존재 — 스킵"
            fi
        else
            warn "Claude Code settings.json 없음 — Claude Code 설치 후 다시 실행하세요"
        fi
    else
        warn "Claude Code 미설치 — 상태바 설정 스킵"
    fi

    # --- git delta 설정 ---
    info "git delta 설정..."
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    git config --global delta.syntax-theme Dracula
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default
}

# ============================================
# 4. 검증
# ============================================
verify() {
    echo ""
    info "=== 설치 검증 ==="
    local tools=(eza bat fd fzf rg delta lazygit btop dust zoxide ncdu starship micro tmux yazi jq tree)
    local missing=()

    for tool in "${tools[@]}"; do
        # debian에서 이름이 다른 도구 처리
        local check="$tool"
        [[ "$OS" == "debian" && "$tool" == "bat" ]] && check="batcat"
        [[ "$OS" == "debian" && "$tool" == "fd" ]] && check="fdfind"

        if command -v "$check" &>/dev/null; then
            info "$tool"
        else
            error "$tool — 미설치"
            missing+=("$tool")
        fi
    done

    # zsh 플러그인 검증 (macOS만)
    if [[ "$OS" == "mac" && "$(basename "${SHELL:-/bin/bash}")" == "zsh" ]]; then
        local brew_prefix="$(brew --prefix 2>/dev/null)"
        for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
            if [[ -d "$brew_prefix/share/$plugin" ]]; then
                info "$plugin"
            else
                error "$plugin — 미설치"
                missing+=("$plugin")
            fi
        done
    fi

    echo ""
    if [[ ${#missing[@]} -eq 0 ]]; then
        info "🎉 모든 도구 설치 완료!"
    else
        warn "미설치 도구: ${missing[*]}"
    fi

    echo ""
    local user_shell="$(basename "${SHELL:-/bin/bash}")"
    warn "새 셸을 열거나 'source ~/.${user_shell}rc' 실행하면 모든 설정이 적용됩니다."
}

# ============================================
# 실행
# ============================================
main() {
    echo "============================================"
    echo "  Terminal Bootstrap"
    echo "============================================"
    echo ""

    detect_os
    setup_package_manager
    install_cli_tools
    install_fonts
    deploy_configs
    verify
}

main "$@"
