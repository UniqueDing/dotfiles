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
    New-ItemProperty -Path $registryPath -Name $name -Value $_.FullName -PropertyType String -Force | Out-Null
}
'
}

install_fonts() {
    local target="${1:-}"
    [[ -n "$target" ]] || target="$(default_pkg_target)"
    case "$target" in
    deepin|arch|termux) install_linux_fonts ;;
    windows) install_windows_fonts ;;
    macos) install_macos_fonts ;;
    *)
        echo "error: unknown font target: $target" >&2
        return 1
        ;;
    esac
}
