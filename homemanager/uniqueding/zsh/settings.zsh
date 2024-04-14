# default
export BROWSER=firefox
export EDITOR=nvim
export SHELL=zsh
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
export PATH=$PATH::/home/uniqueding/.local/bin
export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
bindkey -e

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
