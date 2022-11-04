#!/usr/bin/env bash

set -xe

echo $1

case $1 in
install_nixpkgs)
	#sh <(curl -L https://nixos.org/nix/install) --daemon
	sh <(curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install) --daemon
	;;
install_homemanager)
	nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
	nix-channel --update
	nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable nixpkgs
	nix-channel --update
	export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
	nix-shell '<home-manager>' -A install
	;;
install_interception)
	sudo apt install -y cmake libevdev-dev libudev-dev libyaml-cpp-dev libboost-dev g++ git
	cd /tmp
	git clone https://gitlab.com/interception/linux/tools.git interception-tools
	cd interception-tools
	cp udevmon.service /lib/systemd/system
	cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
	cmake --build build
	cd build && sudo make install
        
	cd /tmp
	git clone https://gitlab.com/interception/linux/plugins/caps2esc.git
	cd caps2esc
	cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
	cmake --build build
	cd build && sudo make install
        
	mkdir -p /etc/interception
	touch /etc/interception/udevmon.yaml
	cat > /etc/interception/udevmon.yaml << EOF
- JOB: intercept -g \$DEVNODE | caps2esc -m 1 | uinput -d \$DEVNODE
  DEVICE:
    EVENTS:
      EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
EOF
	systemctl enable --now udevmon
	;;
install_dotfiles)
	export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
	home-manager switch -f homemanager/uniqueding/home-sway-light.nix
	;;
install_nixgl)
	nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl && nix-channel --update
	nix-env -iA nixgl.auto.nixGLDefault   # or replace `nixGLDefault` with your desired wrapper
	;;
esac
