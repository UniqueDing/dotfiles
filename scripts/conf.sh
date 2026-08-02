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

install_nerd_fonts() {
    FONT_VERSION="v3.4.0"

    FONT_NAMES=("FiraCode" "Hack" "JetBrainsMono" "RobotoMono" "SourceCodePro" "NotoMono")

    echo "Downloading and installing Nerd Fonts..."

    mkdir -p "$FONT_DIR"

    for FONT_NAME in "${FONT_NAMES[@]}"; do
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_VERSION/$FONT_NAME.zip"

        curl -fL "$FONT_URL" -o "$HOME/$FONT_NAME.zip"
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

install_macos_fonts() {
    FONT_DIR="$HOME/Library/Fonts"
    install_nerd_fonts
}

install_windows_fonts() {
    FONT_DIR="$LOCALAPPDATA/Microsoft/Windows/Fonts"
    install_nerd_fonts
    register_windows_fonts
}

register_windows_fonts() {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
$ErrorActionPreference = "Stop"

$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$registryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

Get-ChildItem -Path $fontDir -Include *.ttf,*.otf -Recurse | ForEach-Object {
    $fontType = if ($_.Extension -ieq ".otf") { "OpenType" } else { "TrueType" }
    $name = "$($_.BaseName) ($fontType)"
    New-ItemProperty `
        -Path $registryPath `
        -Name $name `
        -Value $_.FullName `
        -PropertyType String `
        -Force | Out-Null
}
'
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

link_macos_configs() {
    local rime_link="$HOME/Library/Rime/dotfiles-rime"

    mkdir -p "$HOME/Library/Rime"
    if [[ -e "$rime_link" && ! -L "$rime_link" ]]; then
        echo "error: refusing to replace existing Rime path: $rime_link" >&2
        return 1
    fi
    ln -sfn "$CONF_DIR/rime" "$rime_link"
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
