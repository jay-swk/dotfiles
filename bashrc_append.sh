
# --- 기본 에디터: micro ---
export EDITOR="micro"
export VISUAL="micro"

# ============================================
# Modern CLI Tools Configuration
# ============================================

# --- Starship prompt ---
command -v starship &>/dev/null && eval "$(starship init bash)"

# --- zoxide (smart cd) ---
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# --- fzf keybindings & completion ---
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash
# macOS fzf
[ -f "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.bash" ] && source "$(brew --prefix)/opt/fzf/shell/key-bindings.bash" 2>/dev/null
[ -f "$(brew --prefix 2>/dev/null)/opt/fzf/shell/completion.bash" ] && source "$(brew --prefix)/opt/fzf/shell/completion.bash" 2>/dev/null
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
if command -v fdfind &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
elif command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
fi
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# --- eza (modern ls) ---
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --level=2 --icons'
    alias l='eza -l --icons --group-directories-first'
fi

# --- bat (modern cat) ---
if command -v batcat &>/dev/null; then
    alias cat='batcat --paging=never'
    alias bat='batcat'
elif command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi
export BAT_THEME="Dracula"
export MANPAGER="sh -c 'col -bx | bat -l man -p 2>/dev/null || col -bx | less'"

# --- dust (modern du) ---
command -v dust &>/dev/null && alias du='dust'

# --- fd (modern find) ---
if command -v fdfind &>/dev/null; then
    alias find='fdfind'
elif command -v fd &>/dev/null && [[ "$(fd --version 2>/dev/null)" == *"fd"* ]]; then
    alias find='fd'
fi

# --- git + delta ---
# (delta is configured via .gitconfig)

# --- Useful aliases ---
command -v lazygit &>/dev/null && alias g='lazygit'
command -v btop &>/dev/null && alias top='btop'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- Git aliases ---
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

# --- Safety aliases (원본은 유지, i-변형만 별칭으로) ---
alias rmi='rm -i'
alias cpi='cp -i'
alias mvi='mv -i'

# --- Quality-of-life ---
alias reload='source ~/.bashrc && echo "🔄 bash 설정 재로드"'
alias cls='clear'
alias path='echo $PATH | tr ":" "\n"'
alias ports='lsof -i -P -n | grep LISTEN'
alias myip='curl -s ifconfig.me; echo'
alias localip="ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null"
alias weather='curl -s "wttr.in/Seoul?format=3"'
alias now='date "+%Y-%m-%d %H:%M:%S"'

# --- Functions ---
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

# --- yazi (터미널 파일 탐색기) ---
# y로 실행, 종료 시 탐색한 디렉토리로 자동 이동
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# --- History improvements ---
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s cdspell 2>/dev/null
PROMPT_COMMAND="history -a;${PROMPT_COMMAND:-}"
