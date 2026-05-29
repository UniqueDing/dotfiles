CONF_DIR="$DOTFILES_DIR/conf"

init_conf() {
    rustup default stable || true
    pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || true
    go env -w GOPROXY=https://goproxy.io,direct || true
    mkdir -p "$HOME/.config"
    printf '%s\n' "$DOTFILES_DIR/conf" > "$HOME/.config/dotfiles"
    printf '%s\n' "${1:-}" >> "$HOME/.config/dotfiles"
    export TMUX_PLUGIN_MANAGER_PATH="$HOME/.local/tmux/plugins/tpm"

    if [[ ! -d "$TMUX_PLUGIN_MANAGER_PATH/.git" ]]; then
        git clone https://github.com/tmux-plugins/tpm "$TMUX_PLUGIN_MANAGER_PATH"
    fi

    "$TMUX_PLUGIN_MANAGER_PATH/bin/install_plugins" || true
    ya pkg upgrade || true
    bat cache --build || true
    ZIM_HOME="$HOME/.local/zim"
    ZIM_CONFIG_FILE="$HOME/.config/zsh/zimrc"
    curl -fsSL --create-dirs -o "${ZIM_HOME}/zimfw.zsh" \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
    zsh -c "ZIM_HOME=${ZIM_HOME} ZIM_CONFIG_FILE=${ZIM_CONFIG_FILE} source ${ZIM_HOME}/zimfw.zsh init -q" || true
    nvim --headless -c 'Lazy! sync' -c 'qa' || true
}

install_theme() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    git clone https://github.com/vinceliuice/Qogir-theme.git "$tmp_dir/Qogir-theme"
    "$tmp_dir/Qogir-theme/install.sh"
    git clone https://github.com/vinceliuice/Qogir-icon-theme.git "$tmp_dir/Qogir-icon-theme"
    "$tmp_dir/Qogir-icon-theme/install.sh"
}

install_nerd_fonts() {
    FONT_VERSION="v3.4.0"

    FONT_NAMES=("FiraCode" "Hack" "JetBrainsMono" "RobotoMono" "SourceCodePro" "NotoMono")

    echo "Downloading and installing Nerd Fonts..."

    mkdir -p "$FONT_DIR"

    for FONT_NAME in "${FONT_NAMES[@]}"; do
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_VERSION/$FONT_NAME.zip"

        wget -q --show-progress "$FONT_URL" -O "$HOME/$FONT_NAME.zip"
        if [[ $? -ne 0 ]]; then
            echo "Download failed for $FONT_NAME. Please check your network connection or font name!"
            continue
        fi

        unzip -o "$HOME/$FONT_NAME.zip" -d "$FONT_DIR"
        rm -f "$HOME/$FONT_NAME.zip"

        echo "$FONT_NAME font installed to $FONT_DIR."
    done

    echo "All Nerd Fonts installation completed!"
}

install_linux_fonts() {
    FONT_DIR="$HOME/.local/share/fonts"
    install_nerd_fonts
    fc-cache -fv
}

install_windows_fonts() {
    FONT_DIR="$LOCALAPPDATA/Microsoft/Windows/Fonts"
    install_nerd_fonts
    # If copying fonts is not enough, register them for the current user.
    # powershell.exe -NoProfile -Command 'New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "Font Name (TrueType)" -Value "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\Font.ttf" -PropertyType String -Force'
}

link_linux_configs() {
    mkdir -p "$HOME/.config" "$HOME/.local/share/fcitx5" "$HOME/.config/environment.d"

    ln -sfn "$CONF_DIR/vimrc"                   "$HOME/.vimrc"
    ln -sfn "$CONF_DIR/alacritty"               "$HOME/.config/alacritty"
    ln -sfn "$CONF_DIR/ghostty/"                "$HOME/.config/ghostty"
    ln -sfn "$CONF_DIR/kanata"                  "$HOME/.config/kanata"
    ln -sfn "$CONF_DIR/fcitx5/config"           "$HOME/.config/fcitx5"
    ln -sfn "$CONF_DIR/environment.d/fcitx.env" "$HOME/.config/environment.d/fcitx.env"
    ln -sfn "$CONF_DIR/fcitx5/themes"           "$HOME/.local/share/fcitx5/themes"
    ln -sfn "$CONF_DIR/rime"                    "$HOME/.local/share/fcitx5/rime"
    #ln -sfn $HOME/dotfiles/conf/rime $HOME/.config/ibus/rime
}

link_windows_configs() {
    mkdir -p "$APPDATA" "$LOCALAPPDATA" "$USERPROFILE/.config"

    ln -sfn "$CONF_DIR/rime"      "$APPDATA/Rime"
    ln -sfn "$CONF_DIR/nvim"      "$LOCALAPPDATA/nvim"
    ln -sfn "$CONF_DIR/lazygit"   "$APPDATA/lazygit"
    ln -sfn "$CONF_DIR/yazi"      "$APPDATA/yazi"
    ln -sfn "$CONF_DIR/starship"  "$USERPROFILE/.config/starship"
    ln -sfn "$CONF_DIR/gitconfig" "$USERPROFILE/.gitconfig"
    # If Git Bash symlinks fail on Windows, use junctions for directories instead.
    # cmd //c mklink /J "target" "source"
}
