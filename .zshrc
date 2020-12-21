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

zinit ice lucid wait='1'
zinit light skywind3000/z.lua
zinit ice lucid wait='0' atinit='zpcompinit'
zinit light zdharma/fast-syntax-highlighting
zinit ice lucid wait="0" atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
zinit ice lucid wait='0'
zinit light zsh-users/zsh-completions
zinit ice depth=1; 
zinit light romkatv/powerlevel10k

eval $(thefuck --alias)


alias ra=ranger
alias ls="ls --color=auto"
alias ll="ls -l"
alias lla="ls -la"
alias ...="cd ../.."
function mkcd(){
	mkdir $1
	cd $1
}

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
