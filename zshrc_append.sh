
# ============================================
# Modern CLI Tools Configuration (zsh, OMZ-free)
# ============================================
# OMZ(oh-my-zsh) 없이 brew 플러그인만으로 구성 — 쉘 시작 속도 최적화
# bootstrap.sh가 아래 brew 패키지를 자동 설치:
#   zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions

# ---------- Editor ----------
export EDITOR="micro"
export VISUAL="micro"

# ---------- Brew prefix (zsh 플러그인 경로용) ----------
if [[ -z "${BREW_PREFIX:-}" ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
        BREW_PREFIX="/opt/homebrew"        # Apple Silicon
    elif [[ -x /usr/local/bin/brew ]]; then
        BREW_PREFIX="/usr/local"            # Intel Mac
    else
        BREW_PREFIX=""
    fi
fi

# ---------- zsh-completions (자동완성 데이터베이스 확장) ----------
if [[ -n "$BREW_PREFIX" && -d "$BREW_PREFIX/share/zsh-completions" ]]; then
    fpath=("$BREW_PREFIX/share/zsh-completions" $fpath)
fi
autoload -Uz compinit && compinit -i

# ---------- zsh-autosuggestions (회색 힌트, →/End로 수락) ----------
if [[ -n "$BREW_PREFIX" && -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# ---------- Starship prompt ----------
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ---------- zoxide (smart cd) : z <keyword> ----------
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ---------- fzf (fuzzy finder) ----------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# ---------- eza (modern ls) ----------
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --level=2 --icons'
    alias l='eza -l --icons --group-directories-first'
fi

# ---------- bat (modern cat) ----------
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi
export BAT_THEME="Dracula"
export MANPAGER="sh -c 'col -bx | bat -l man -p 2>/dev/null || col -bx | less'"

# ---------- dust / fd ----------
command -v dust &>/dev/null && alias du='dust'

# ---------- btop / lazygit ----------
command -v lazygit &>/dev/null && alias g='lazygit'
command -v btop &>/dev/null && alias top='btop'

# ---------- Directory shortcuts ----------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ---------- Git aliases ----------
# OMZ git 플러그인 대체 — 자주 쓰는 것만 엄선
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git pull'
alias gps='git push'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -m'
alias gca='git commit --amend'
alias gst='git stash'
alias gstp='git stash pop'

# ---------- Safety aliases (원본은 유지, 안전 버전은 별칭으로) ----------
# 기본 rm/cp/mv는 그대로 — 자동화/스크립트 호환
# 실수 방지하고 싶을 때 아래 i-변형 사용
alias rmi='rm -i'
alias cpi='cp -i'
alias mvi='mv -i'

# ---------- Quality-of-life ----------
alias reload='source ~/.zshrc && echo "🔄 zsh 설정 재로드"'
alias cls='clear'
alias path='echo $PATH | tr ":" "\n"'
alias ports='lsof -i -P -n | grep LISTEN'
alias myip='curl -s ifconfig.me; echo'
alias localip="ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null"
alias weather='curl -s "wttr.in/Seoul?format=3"'
alias now='date "+%Y-%m-%d %H:%M:%S"'

# ---------- Functions ----------
# mkcd: 디렉토리 만들고 바로 진입
mkcd() {
    [ $# -lt 1 ] && { echo "사용법: mkcd <디렉토리>"; return 1; }
    mkdir -p -- "$1" && cd -- "$1"
}

# extract: 거의 모든 압축파일 자동 해제
extract() {
    [ -z "$1" ] && { echo "사용법: extract <파일>"; return 1; }
    [ ! -f "$1" ] && { echo "'$1' 파일을 찾을 수 없습니다"; return 1; }
    case "$1" in
        *.tar.bz2)   tar xjf "$1"   ;;
        *.tar.gz)    tar xzf "$1"   ;;
        *.tar.xz)    tar xJf "$1"   ;;
        *.bz2)       bunzip2 "$1"   ;;
        *.rar)       unrar x "$1"   ;;
        *.gz)        gunzip "$1"    ;;
        *.tar)       tar xf "$1"    ;;
        *.tbz2)      tar xjf "$1"   ;;
        *.tgz)       tar xzf "$1"   ;;
        *.zip)       unzip "$1"     ;;
        *.Z)         uncompress "$1";;
        *.7z)        7z x "$1"      ;;
        *)           echo "'$1'은 지원하지 않는 형식입니다" ;;
    esac
}

# yazi 래퍼 (y 입력 시 종료한 디렉토리로 자동 cd)
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ---------- History ----------
HISTSIZE=50000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"
setopt APPEND_HISTORY          # 여러 세션 히스토리 머지
setopt SHARE_HISTORY           # 세션 간 실시간 공유
setopt HIST_IGNORE_DUPS        # 연속 중복 무시
setopt HIST_IGNORE_ALL_DUPS    # 전체 중복 제거
setopt HIST_IGNORE_SPACE       # 공백 시작 명령 저장 안 함
setopt HIST_REDUCE_BLANKS      # 불필요한 공백 정리
setopt HIST_VERIFY             # !! 확장 시 바로 실행 안 하고 확인

# ---------- zsh options (QoL) ----------
setopt AUTO_CD                 # 디렉토리 이름만 입력해도 cd
setopt AUTO_PUSHD              # cd 시 자동으로 pushd
setopt PUSHD_IGNORE_DUPS       # 중복 스택 제거
setopt EXTENDED_GLOB           # **, ^ 같은 확장 globbing
setopt INTERACTIVE_COMMENTS    # 대화형에서도 # 주석 허용
setopt CORRECT                 # 명령 오타 교정 제안

# ---------- zsh-syntax-highlighting (반드시 '맨 마지막'에 source) ----------
# 다른 설정이 override하지 않도록 파일 하단에 위치
if [[ -n "$BREW_PREFIX" && -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
