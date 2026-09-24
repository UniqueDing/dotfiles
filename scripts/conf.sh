CONF_DIR="$DOTFILES_DIR/conf"

init_conf() {
    mkdir -p "$HOME/.config"
    printf '%s\n' "$DOTFILES_DIR/conf" > "$HOME/.config/dotfiles"
    printf '%s\n' "${1:-}" >> "$HOME/.config/dotfiles"

    rustup default stable || true

    pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || true

    go env -w GOPROXY=https://goproxy.io,direct || true

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

    uv tool install code-review-graph || true
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

link_rime_configs() {
    local rime_dir="$1"
    local source

    # Replace the legacy directory-level link so generated Rime data remains
    # local while versioned configuration files are linked individually.
    [[ -L "$rime_dir" ]] && rm "$rime_dir"
    mkdir -p "$rime_dir"

    for source in "$CONF_DIR/rime"/*; do
        ln -sfn "$source" "$rime_dir/${source##*/}"
    done
}

link_linux_configs() {
    mkdir -p "$HOME/.config" "$HOME/.local/share/fcitx5" "$HOME/.config/environment.d"

    ln -sfn "$CONF_DIR/vimrc"                   "$HOME/.vimrc"
    ln -sfn "$CONF_DIR/alacritty"               "$HOME/.config/alacritty"
    ln -sfn "$CONF_DIR/ghostty/"                "$HOME/.config/ghostty"
    ln -sfn "$CONF_DIR/wezterm"                 "$HOME/.config/wezterm"
    ln -sfn "$CONF_DIR/fcitx5/config"           "$HOME/.config/fcitx5"
    ln -sfn "$CONF_DIR/environment.d/fcitx.env" "$HOME/.config/environment.d/fcitx.env"
    ln -sfn "$CONF_DIR/fcitx5/themes"           "$HOME/.local/share/fcitx5/themes"
    link_rime_configs "$HOME/.local/share/fcitx5/rime"
    #ln -sfn $HOME/dotfiles/conf/rime $HOME/.config/ibus/rime
}

link_macos_configs() {
    link_rime_configs "$HOME/Library/Rime"
    mkdir -p "$HOME/.config/linearmouse"

    ln -sfn "$CONF_DIR/macos/linearmouse/linearmouse.json" \
        "$HOME/.config/linearmouse/linearmouse.json"
    ln -sfn "$CONF_DIR/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
}

link_windows_configs() {
    mkdir -p "$APPDATA" "$LOCALAPPDATA" "$USERPROFILE/.config"

    link_rime_configs "$APPDATA/Rime"
    ln -sfn "$CONF_DIR/nvim"      "$LOCALAPPDATA/nvim"
    ln -sfn "$CONF_DIR/lazygit"   "$APPDATA/lazygit"
    ln -sfn "$CONF_DIR/yazi"      "$APPDATA/yazi"
    ln -sfn "$CONF_DIR/starship"  "$USERPROFILE/.config/starship"
    ln -sfn "$CONF_DIR/gitconfig" "$USERPROFILE/.gitconfig"
    # If Git Bash symlinks fail on Windows, use junctions for directories instead.
    # cmd //c mklink /J "target" "source"
}

add_windows_terminal_git_bash() {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
$ErrorActionPreference = "Stop"

$settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) {
    $settingsPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
}

if (-not (Test-Path $settingsPath)) {
    throw "Windows Terminal settings.json not found"
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
if (-not $settings.profiles) {
    $settings | Add-Member -MemberType NoteProperty -Name profiles -Value ([pscustomobject]@{ list = @() })
}
if (-not $settings.profiles.list) {
    $settings.profiles | Add-Member -MemberType NoteProperty -Name list -Value @()
}

$commandline = "`"C:\Program Files\Git\bin\bash.exe`" --login -i"
$icon = "C:\Program Files\Git\mingw64\share\git\git-for-windows.ico"
$exists = $settings.profiles.list | Where-Object { $_.name -eq "Git Bash" }

if (-not $exists) {
    $settings.profiles.list += [pscustomobject]@{
        guid = "{00000000-0000-0000-0000-000000000001}"
        name = "Git Bash"
        commandline = $commandline
        startingDirectory = "%USERPROFILE%"
        icon = $icon
    }
}

$settings | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 $settingsPath
'
}
