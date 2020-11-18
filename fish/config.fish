alias l ls
alias sf screenfetch
alias s sudo
alias ra ranger
alias gdb 'gdb -q'

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
alias bcI='brew cask install'
alias bR='brew remove'
alias bcR='brew cask remove'
alias bS='brew search'
alias bL='brew list'
alias bF='brew info'
function bU
	sudo brew update
	sudo brew upgrade
	sudo brew upgrade --cask
end

alias aI='sudo apt install'
alias aS='apt search'
alias aR='sudo apt remove'
alias aL='apt list'
alias aH='apt show'
function aU
	sudo apt update
	sudo apt upgrade
end

alias ga='git add'
alias gr='git rm'
alias gu='git status'
alias gm='git commit'
alias gp='git pull'
function gpa
	git push origin
	git push github
	git push gitee
end
alias gho='git push origin'
alias gph='git push github'
alias gpt='git push gitee'
alias gl='git log'
alias gc='git checkout'
alias gd='git diff'

alias musiclake='/opt/musiclake/musiclake-224.38d4ca5-linux.AppImage > /dev/null 2>&1'
alias v2ray_desktop='nohup /opt/v2ray-desktop/v2ray-desktop > /dev/null 2>&1 &'


function mkcd
    mkdir $argv
    cd $argv
end


set EDITOR 'nvim'
set PATH $PATH /home/uniqueding/.local/bin /home/uniqueding/Android/Sdk/tools/bin /home/uniqueding/Github/flutter/bin
set -U fish_key_bindings fish_vi_key_bindings

function reverse_history_search
  history | fzf --no-sort | read -l command
  if test $command
    commandline -rb $command
  end
end

function fish_mode_prompt --description 'Displays the current mode'
    # Do nothing if not in vi mode
        switch $fish_bind_mode
            case default
                set_color --bold --background blue white
            case visual
                set_color --bold --background yellow white
        end
end

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \cf forward-char
    end

#colemak
    for mode in default visual
		bind -M $mode e up-or-search
		bind -M $mode n down-or-search
		bind -M $mode i forward-char
		bind -M $mode u forward-char
		#bind -M $mode j forward-char forward-word backward-char
		#bind -M $mode j forward-bigword backward-char
    end
    bind -M default / reverse_history_search 
    bind -m insert l force-repaint
    bind -m insert L beginning-of-line force-repaint
end
