#!/usr/bin/env bash
set -xe


_deepin() {
    PACKAGE_FILE="deepin_package.list"
    if [[ ! -f "$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list
    sudo apt update
    xargs -a "$PACKAGE_FILE" -r sudo apt install -y
}

case $1 in
deepin)
    _deepin
    ;;
esac
