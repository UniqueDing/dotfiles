# alias

alias ra='yazi'
# alias ls='lsd --hyperlink=auto'
alias ls='eza --icons=auto'
alias l=ls
alias ll='ls -l --git -g'
alias lla='ll -a'
alias lst='ls --tree'
alias ..='cd ..'
alias ...='cd ../..'
# alias cdl='~/.config/dwm/dark-light.sh'
alias icat="kitty +kitten icat"
alias showkey="wshowkeys -a bottom -b 00000033 -m100 -F 'Hack 44'"

alias tssh="TERM=xterm ssh"
alias scpr="rsync -P --rsh=ssh"
alias lg="lazygit"
alias oc="opencode"

alias proxychains="proxychains4"
alias pc="proxychains -q"

alias f="$(pay-respects zsh)"

alias fzda="d-attach" # fzf docker attach
alias fzdirm="d-image-rm" # fzf docker image rm
alias fzdrm="d-rm" # fzf docker rm
alias fzds="d-stop-container" # fzf docker stop
alias fz="fif"
alias fze="fzf-find-edit" # fzf edit with $EDITOR
alias fzg="fzf-grep-edit" # fzf edit with $EDITOR
alias fzk="fzf-kill" # fzf kill processes

alias pS='sudo pacman -S'
alias pSs='pacman -Ss'
alias pSyu='sudo pacman -Syu'
alias pSyyu='sudo pacman -Syyu'
alias pR='sudo pacman -R'
alias pRs='sudo pacman -Rs'
alias pSi='pacman -Si'
alias pQs='pacman -Qs'
alias pQi='pacman -Qi'
alias yS='paru -S'
alias ySs='paru -Ss'
alias yR='paru -R'
alias ySyu='paru -Syu'
alias ySyyu='paru -Syyu'

alias bI='brew install'
alias bR='brew remove'
alias bS='brew search'
alias bL='brew list'
alias bF='brew info'
alias bU='brew update && brew upgrade && brew upgrade --cask'

alias aI='sudo apt install'
alias aS='apt search'
alias aR='sudo apt remove'
alias aP='sudo apt purge'
alias aL='apt list'
alias aH='apt show'
alias aU='sudo apt update && sudo apt upgrade'

alias gu='git status'
alias gm='git commit'
alias gmm='git commit -m'
alias gpa='git push origin ; git push github; git push gitee'

# alias pipU='pip3 freeze --local | grep -v '^-e' | cut -d = -f 1  | xargs -n1 pip install -U'

alias frpcc='frpc -c /etc/frp/frpc.ini'

# fzf
alias nvimf='nvim `fzf --preview "cat {}"`'

# systemd
alias sysE='systemctl enable'
alias sysD='systemctl disable'
alias sysS='systemctl start'
alias sysP='systemctl stop'
alias sysU='systemctl status'
alias sysR='systemctl restart'
alias sysuE='systemctl --user enable'
alias sysuD='systemctl --user disable'
alias sysuS='systemctl --user start'
alias sysuP='systemctl --user stop'
alias sysuU='systemctl --user status'
alias sysuR='systemctl --user restart'

alias vsway='WLR_NO_HARDWARE_CURSORS=1 sway'
alias penv='env LD_LIBRARY_PATH= PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/sbin:/usr/sbin:$HOME/.local/bin '
