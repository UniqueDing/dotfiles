#!/usr/bin/env bash
set -xe

_deepin() {
    PACKAGE_FILE="deepin.list"
    if [[ ! -f "package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list
    sudo apt update
    xargs -a "$PACKAGE_FILE" -r sudo apt install -y
}

_arch() {
    PACKAGE_FILE="arch.list"
    if [[ ! -f "package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    yay -Syu --noconfirm
    xargs -a "package/$PACKAGE_FILE" -r yay -Sy --noconfirm
}

case $1 in
deepin)
    _deepin
    ;;
arch)
    _arch
    ;;
esac

ln -sfn $HOME/dotfiles/home/alacritty $HOME/.config/alacritty
ln -sfn $HOME/dotfiles/home/kanata $HOME/.config/kanata
ln -sfn $HOME/dotfiles/home/fcitx5/config $HOME/.config/fcitx5
ln -sfn $HOME/dotfiles/home/fcitx5/share $HOME/.local/share/fcitx5
ln -sfn $HOME/dotfiles/home/rime $HOME/.local/share/fcitx5/rime
ln -sfn $HOME/dotfiles/home/rime $HOME/.config/ibus/rime
