# -----------------------------------------------------
# Exports
# -----------------------------------------------------
export EDITOR=nvim
export PATH="/usr/lib/ccache/bin/:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PATH=$PATH:~/.local/bin

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH=$BUN_INSTALL/bin:$PATH
export PATH=~/.npm-global/bin:$PATH
export PATH="/home/adam/psychopy_2024.2.4_py3.10/.bin:$PATH"

# -----------------------------------------------------
# ALIASES
# -----------------------------------------------------
alias univpn='~/scripts/univpn.sh'
alias x2go=~/scripts/startx2go.sh
alias watchsensors="watch -n 1 -d sensors"
alias on=~/scripts/on
alias sort_inbox=~/scripts/sort_inbox.sh
# -----------------------------------------------------
# General
# -----------------------------------------------------
alias c='clear'
alias nf='fastfetch'
alias pf='fastfetch'
alias ff='fastfetch'
alias ls='eza -a --icons'
alias ll='eza -al --icons'
alias lt='eza -a --tree --level=1 --icons'

# -----------------------------------------------------
# Git
# -----------------------------------------------------
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gst="git stash"
alias gsp="git stash; git pull"
alias gcheck="git checkout"
alias gcredential="git config credential.helper store"

# -----------------------------------------------------
# CUSTOMIZATION
# -----------------------------------------------------
bind -f  ~/.inputrc
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'
bind '"\e[Z":menu-complete-backward'

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"

# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# bat theeme ]
export BAT_THEME='gruvbox-dark'

# ---- Eza (better ls) -----

alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# -----------------------------------------------------
# Starship Prompt
# -----------------------------------------------------
eval "$(starship init bash)"

# -----------------------------------------------------
# Fastfetch
# -----------------------------------------------------
if [[ $(tty) == *"pts"* ]]; then
    fastfetch --config examples/13
fi


eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"


. "$HOME/.cargo/env"
