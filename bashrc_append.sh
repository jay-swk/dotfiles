
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
shopt -s histappend
PROMPT_COMMAND="history -a;${PROMPT_COMMAND:-}"
