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

# alias

alias s=sudo
alias se=sudoedit
alias ra=ranger
alias ls='exa --icons'
alias l=ls
alias ll='ls -lHg --git'
alias lla='ll -a'
alias ..='cd ..'
alias ...='cd ../..'
function mkcd(){
	mkdir $1
	cd $1
}
alias fzfh='cd ~ && { fzf ; cd - > /dev/null }'
alias fzfr='cd / && { sudo fzf ; cd - > /dev/null }'
alias cdl='~/.config/dwm/dark-light.sh'

alias pS='sudo pacman -S'
alias pSs='pacman -Ss'
alias pSyu='sudo pacman -Syu'
alias pSyyu='sudo pacman -Syyu'
alias pR='sudo pacman -R'
alias pRs='sudo pacman -Rs'
alias pSi='pacman -Si'
alias pQs='pacman -Qs'
alias pQi='pacman -Qi'
alias yS='yay -S'
alias ySs='yay -Ss'
alias yR='yay -R'
alias ySyyu='yay -Syyu'

alias bI='brew install'
alias bR='brew remove'
alias bS='brew search'
alias bL='brew list'
alias bF='brew info'
alias bU='brew update && brew upgrade && brew upgrade --cask'

alias aI='sudo apt install'
alias aS='apt search'
alias aR='sudo apt remove'
alias aL='apt list'
alias aH='apt show'
alias aU='sudo apt ugdate && sudo apt upgrade'

alias gu='git status'
alias gm='git commit'
alias gmm='git commit -m'
alias gpa='git push origin ; git push github; git push gitee'

# proxy
function Pon(){
	export https_proxy=http://127.0.0.1:20171 http_proxy=http://127.0.0.1:20171 all_proxy=socks5://127.0.0.1:20170
}

function Pdown(){
	unset http_proxy
	unset https_proxy
	unset all_proxy
}
