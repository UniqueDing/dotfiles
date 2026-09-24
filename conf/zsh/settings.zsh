HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# emacs bindkey
bindkey -e
bindkey "\e[1~" beginning-of-line
bindkey "\e[4~" end-of-line
bindkey "\e[3~" delete-char
bindkey "\e[5~" up-line-or-history
bindkey "\e[6~" down-line-or-history

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(pay-respects zsh --alias)"

zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
source <(fzf --zsh)
