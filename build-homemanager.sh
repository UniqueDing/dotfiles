#!/usr/bin/env bash

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
	yes | sh <(curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install) --daemon
	;;
homemanager)
	nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
	# nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz home-manager
	nix-channel --update
	nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable nixpkgs
	nix-channel --update
	export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
	nix-shell '<home-manager>' -A install
	;;
interception)
	sudo apt install -y cmake libevdev-dev libudev-dev libyaml-cpp-dev libboost-dev g++ git
	cd /tmp
	git clone https://gitlab.com/interception/linux/tools.git interception-tools
	cd interception-tools
	cp udevmon.service /lib/systemd/system
	cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
	cmake --build build
	cd build && sudo make install
        
	cd /tmp
	git clone https://github.com/UniqueDing/interception-vimproved.git
	cd interception-vimproved
	cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
	cmake --build build
	cd build && sudo make install
    sudo mkdir -p /etc/interception-vimproved && sudo cp config.yaml /etc/interception-vimproved
        
	mkdir -p /etc/interception
	touch /etc/interception/udevmon.yaml
	cat > /etc/interception/udevmon.yaml << EOF
- JOB: intercept -g \$DEVNODE | interception-vimproved /etc/interception-vimproved/config.yaml  | uinput -d \$DEVNODE
  DEVICE:
    NAME: ".*((k|K)(eyboard|EYBOARD)|TADA68|kb).*"
EOF
	systemctl enable --now udevmon
	;;
dotfiles)
	export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
	home-manager switch -f homemanager/uniqueding/home-light.nix
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
esac
