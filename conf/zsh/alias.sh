# alias

alias s=sudo
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

alias proxychains="proxychains4"
alias pc="proxychains -q"

alias f="$(pay-respects zsh)"

alias nvim="env CC=gcc nvim"

alias nhome-manager="NIX_PATH=${NIX_PATH:+$NIX_PATH:}$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels home-manager"

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
alias ySyu='yay -Syu'
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
alias aP='sudo apt purge'
alias aL='apt list'
alias aH='apt show'
alias aU='sudo apt update && sudo apt upgrade'

alias sI="sudo snap install"
alias sS="snap find"
alias sR="sudo snap remove"
alias sH="snap info"
alias sL="snap list"
alias sU="sudo snap refresh"

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
alias sysT='systemctl stop'
alias sysU='systemctl status'
alias sysR='systemctl restart'
alias sysuE='systemctl --user enable'
alias sysuD='systemctl --user disable'
alias sysuS='systemctl --user start'
alias sysuT='systemctl --user stop'
alias sysuU='systemctl --user status'
alias sysuR='systemctl --user restart'

alias vsway='WLR_NO_HARDWARE_CURSORS=1 sway'
alias penv='env LD_LIBRARY_PATH= PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/sbin:/usr/sbin:$HOME/.local/bin '
