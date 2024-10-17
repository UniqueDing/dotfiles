# default
export BROWSER=firefox
export EDITOR=nvim
export SHELL=zsh
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
export PATH=$PATH::/home/uniqueding/.local/bin
export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
export LS_COLORS="$(vivid generate catppuccin-mocha)"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"
export STARSHIP_CONFIG=~/.config/starship/starship.toml

bindkey -e

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
