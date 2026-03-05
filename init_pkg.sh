#!/usr/bin/env bash
set -xe

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
    if [[ ! -f "package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list
    sudo apt update
    cat "package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r sudo apt install -y
}

_arch() {
    PACKAGE_FILE="arch.list"
    if [[ ! -f "package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    sudo paru -Syu --noconfirm
    cat "package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r sudo paru -Sy --noconfirm
}

_termux() {
    PACKAGE_FILE="termux.list"
    if [[ ! -f "package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    pkg update
    cat "package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r pkg i -y
    vs start sshd
}

case $1 in
deepin)
    _deepin
    ;;
arch)
    _arch
    ;;
termux)
    _termux
    ;;
esac
_fonts

ln -sfn $HOME/dotfiles/conf/vimrc                  $HOME/.vimrc
ln -sfn $HOME/dotfiles/conf/alacritty              $HOME/.config/alacritty
ln -sfn $HOME/dotfiles/conf/ghostty/               $HOME/.config/ghostty
ln -sfn $HOME/dotfiles/conf/kanata                 $HOME/.config/kanata
ln -sfn $HOME/dotfiles/conf/fcitx5/config          $HOME/.config/fcitx5
mkdir -p $HOME/.local/share/fcitx5
ln -sfn $HOME/dotfiles/conf/fcitx5/themes          $HOME/.local/share/fcitx5/themes
ln -sfn $HOME/dotfiles/conf/rime                   $HOME/.local/share/fcitx5/rime
#ln -sfn $HOME/dotfiles/conf/rime $HOME/.config/ibus/rime
