#!/usr/bin/env bash
set -euo pipefail
set -x

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONF_DIR="$DOTFILES_DIR/conf"

cat > "$DOTFILES_DIR/local.nix" <<EOF
{
  dotfilesPath = "$DOTFILES_DIR";
}
EOF

_fonts() {
    FONT_VERSION="v3.4.0"
    FONT_DIR="$HOME/.local/share/fonts"

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

    fc-cache -fv
    echo "All Nerd Fonts installation completed!"
}

_deepin() {
    PACKAGE_FILE="deepin.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list
    sudo apt update
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r sudo apt install -y
}

_arch() {
    PACKAGE_FILE="arch.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    sudo paru -Syu --noconfirm
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r sudo paru -Sy --noconfirm
}

_termux() {
    PACKAGE_FILE="termux.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    pkg update
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r pkg i -y
    vs start sshd
}

target="${1:-}"

case "$target" in
deepin)
    _deepin
    ;;
arch)
    _arch
    ;;
termux)
    _termux
    ;;
*)
    echo "error: unknown package target: $target" >&2
    exit 1
    ;;
esac
_fonts

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
