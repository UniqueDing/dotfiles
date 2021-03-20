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

alias pipU='pip3 freeze --local | grep -v '^-e' | cut -d = -f 1  | xargs -n1 pip install -U'

# update
function update(){
    yes | pSyyu
    yes | aU
    yes | bU
    zi update
    npm update
    # pipU
}


# proxy
function Pon(){
	export https_proxy=http://127.0.0.1:20171 http_proxy=http://127.0.0.1:20171 all_proxy=socks5://127.0.0.1:20170
}

function Pdown(){
	unset http_proxy
	unset https_proxy
	unset all_proxy
}

alias frpcc='frpc -c /etc/frp/frpc.ini'

alias mountnas='sudo mount.nfs nas.ding:/main ~/nas'
alias umountnas='sudo umount ~/nas'
