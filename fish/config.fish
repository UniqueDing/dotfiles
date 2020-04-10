alias l ls
alias ra ranger
alias y yay
alias ys='yay -S'
alias yss='yay -Ss'
alias yr='yay -R'
alias yr='yay -R'
alias yu='yay -Syyu'

function mkcd
    mkdir $argv
    cd $argv
end


set EDITOR 'vim'
set PATH $PATH /home/uniqueding/.local/bin /home/uniqueding/Android/Sdk/tools/bin
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
