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
    # sh <(curl -L https://nixos.org/nix/install) --daemon
    curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install | sh -s -- --no-daemon
    sudo mkdir /etc/nix
    sudo cp nix.conf /etc/nix/nix.conf
    sudo sed -i "s|\(Defaults\s*secure_path=.*\):.*|\1:/home/uniqueding/.nix-profile/bin\"|" /etc/sudoers
    set -e
    ;;
homemanager)
    #nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    #export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    #nix-shell '<home-manager>' -A install
    nix-channel --update
    nix-env -iA nixpkgs.home-manager
    ;;
dotfiles)
    config=$2
    home-manager switch --flake .#$config
    ;;
all)
    curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install | sh
    sudo mkdir /etc/nix
    sudo cp nix.conf /etc/nix/nix.conf
    nix-channel --update
    nix-env -iA nixpkgs.home-manager
    config=$2
    home-manager switch --flake .#$config
    set +e
    rustup default stable
    pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
    go env -w GOPROXY=https://goproxy.io,direct
    echo $PWD/conf > /home/uniqueding/.config/dotfiles
    echo $config >> /home/uniqueding/.config/dotfiles
    export TMUX_PLUGIN_MANAGER_PATH=/home/uniqueding/.local/tmux/plugins/tpm
    git clone https://github.com/tmux-plugins/tpm ~/.local/tmux/plugins/tpm
    ~/.local/tmux/plugins/tpm/bin/install_plugins
    ya pkg upgrade
    bat cache --build
    ZIM_HOME=~/.local/zim
    ZIM_CONFIG_FILE=~/.config/zsh/zimrc
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
    zsh -c "ZIM_HOME=${ZIM_HOME} ZIM_CONFIG_FILE=${ZIM_CONFIG_FILE} source ${ZIM_HOME}/zimfw.zsh init -q"
    # fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher && fisher update"
    nvim --headless -c 'Lazy! sync' -c 'qa'
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
update)
    nix-channel --update
    nix flake update
    nix-env -iA nixpkgs.home-manager
    # home-manager switch -f home/home-light.nix
    ;;
font)
    ;;
pkg)
    case "$DISTRIB_ID" in
    "Arch|EndeavourOS")
        ./init_pkg.sh arch
        ;;
    esac
    ;;
kanata)
    case "$DISTRIB_ID" in
    Arch|EndeavourOS)
        yay -Sy --noconfirm kanata
        sudo ln -sfn ./conf/kanata/kanata.kbd /etc/kanata.kbd
        sudo systemctl enable --now kanata
    esac
    ;;
esac
