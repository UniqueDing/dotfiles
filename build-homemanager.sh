#!/usr/bin/env bash

source /etc/lsb-release
bash /home/uniqueding/.nix-profile/etc/profile.d/nix.sh

set -xe

echo $1

case $1 in
nixpkgs)
    set +e
    sudo mv /etc/profile.d/nix.sh.backup-before-nix /etc/profile.d/nix.sh
    sudo mv /etc/bashrc.backup-before-nix /etc/bashrc
    sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc
    sudo mv /etc/zshrc.backup-before-nix /etc/zshrc
    set -e
    #sh <(curl -L https://nixos.org/nix/install) --daemon
    yes | sh <(curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install)
    ;;
homemanager)
    #nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    #nix-channel --update
    nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable nixpkgs
    nix-channel --update
    #export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    #nix-shell '<home-manager>' -A install
    nix-env -iA nixpkgs.home-manager
    ;;
interception)
    case "$DISTRIB_ID" in
    "Arch")
        yay -S meson interception-tools yaml-cpp cmake
        ;;
    *)
        sudo apt install -y cmake libevdev-dev libudev-dev libyaml-cpp-dev libboost-dev g++ git
        cd /tmp
        git clone https://gitlab.com/interception/linux/tools.git interception-tools
        cd interception-tools
        sudo cp udevmon.service /lib/systemd/system
        cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
        cmake --build build
        cd build && sudo make install
        ;;

    esac
    cd /tmp
    git clone https://github.com/UniqueDing/interception-vimproved.git
    cd interception-vimproved
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build build
    cd build && sudo make install && cd -
    sudo mkdir -p /etc/interception-vimproved && sudo cp config.yaml /etc/interception-vimproved

    sudo mkdir -p /etc/interception
    sudo touch /etc/interception/udevmon.yaml
    sudo tee /etc/interception/udevmon.yaml > /dev/null << EOF
- JOB: intercept -g \$DEVNODE | interception-vimproved /etc/interception-vimproved/config.yaml  | uinput -d \$DEVNODE
  DEVICE:
    NAME: ".*((k|K)(eyboard|EYBOARD)|TADA68|kb).*"
EOF
    sudo systemctl enable --now udevmon
    ;;
dotfiles)
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    home-manager switch -f home/home-light.nix
    ;;
nixgl)
    nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl && nix-channel --update
    nix-env -iA nixgl.auto.nixGLDefault   # or replace `nixGLDefault` with your desired wrapper
    ;;
theme)
    cd /tmp
    git clone https://github.com/vinceliuice/Qogir-theme.git
    cd Qogir-theme
    ./install.sh
    cd /tmp
    git clone https://github.com/vinceliuice/Qogir-icon-theme.git
    cd Qogir-icon-theme
    ./install.sh
    ;;
channel)
    sudo mkdir /etc/nix
    sudo tee -a /etc/nix/nix.conf > /dev/null << EOF
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://mirror.sjtu.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
EOF
    #sudo systemctl restart nix-daemon
    ;;
update)
    nix-channel --update
    home-manager switch -f home/home-light.nix
    ;;
font)
    ;;

esac
