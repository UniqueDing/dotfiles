# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

plugins=(
	git
	bundler
	dotenv
	osx
	rake
	rbenv
	ruby
)

### Added by Zinit's installer
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
	print -P "%F{33}▓▒░ %F{220}Installing %F{33}DHARMA%F{220} Initiative Plugin Manager (%F{33}zdharma/zinit%F{220})…%f"
	command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
	command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
		print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
		print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
	zinit-zsh/z-a-rust \
	zinit-zsh/z-a-as-monitor \
	zinit-zsh/z-a-patch-dl \
	zinit-zsh/z-a-bin-gem-node

### End of Zinit's installer chunk
zinit light romkatv/powerlevel10k

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

## Fast-syntax-highlighting & autosuggestions
zinit wait lucid for \
	atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay" \
	zdharma/fast-syntax-highlighting \
	atload"!_zsh_autosuggest_start" \
	zsh-users/zsh-autosuggestions \
	blockf \
	zsh-users/zsh-completions

# zlua
zinit wait='1' lucid light-mode for \
	skywind3000/z.lua \
	wfxr/forgit

# zsh-autopair
# fzf-marks, at slot 0, for quick Ctrl-G accessibility
zinit wait lucid for \
	hlissner/zsh-autopair \
	urbainvaes/fzf-marks

# oh-my-zsh
zinit wait="1" lucid for \
	OMZ::lib/git.zsh \
	OMZ::plugins/sudo/sudo.plugin.zsh

# zinit ice lucid wait='0'
# zinit light Aloxaf/fzf-tab
zinit ice depth=1;
zinit light romkatv/powerlevel10k

# thefuck
eval $(thefuck --alias)

# default
export EDITOR=nvim
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
export PATH=$PATH::/home/uniqueding/.local/bin
bindkey -e

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source /etc/profile
source ~/.config/zsh/alias.sh
source ~/.config/zsh/fun.sh
