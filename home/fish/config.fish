function fish_greeting
    # Do nothing
end

if status is-interactive
    # Commands to run in interactive sessions can go here
    if not test -e ~/.config/fish/functions/fisher.fish
        echo "Fisher is not installed. Installing Fisher..."
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
        fisher update
    end


    set -x PATH $PATH /home/uniqueding/.local/bin
    set -x LOCALE_ARCHIVE {$glibcLocales}/lib/locale/locale-archive
    set -x LS_COLORS "$(vivid generate catppuccin-mocha)"
    set -x FZF_DEFAULT_OPTS " \
    --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
    --color=selected-bg:#45475a \
    --multi"
    set -x STARSHIP_CONFIG ~/.config/starship/starship.toml
    starship init fish | source
    zoxide init fish | source

    source $HOME/.config/fish/alias.fish
end
