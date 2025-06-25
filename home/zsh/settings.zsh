# default
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(pay-respects zsh --alias)"

zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
