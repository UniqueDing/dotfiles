#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOCAL_NIX="$DOTFILES_DIR/local.nix"

if [[ -f /etc/lsb-release ]]; then
    # shellcheck disable=SC1091
    source /etc/lsb-release
else
    DISTRIB_ID="${DISTRIB_ID:-}"
fi

if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

write_local_nix() {
    cat > "$LOCAL_NIX" <<EOF
{
  dotfilesPath = "$DOTFILES_DIR";
}
EOF
}

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  nixpkgs              Install Nix and write nix.conf
  homemanager          Install Home Manager through nix-channel
  dotfiles [profile]   Switch Home Manager profile, defaults to docker
  conf                 Initialize post-switch user config
  pkg [target]         Run scripts/init_pkg.sh for target, defaults by distro
  sdk                  Run scripts/init_sdk.sh
  bw [args]            Run scripts/bw.sh with forwarded args
  all [profile]        Install Nix/Home Manager, switch profile, run conf; defaults to docker
  nixgl                Install nixGL
  theme                Install Qogir themes
  update               Update Nix, channels, flake lock, and Home Manager
  kanata               Install and enable kanata on Arch/EndeavourOS
EOF
}

require_arg() {
    local value="$1"
    local name="$2"

    if [[ -z "$value" ]]; then
        echo "error: missing $name" >&2
        usage >&2
        exit 1
    fi
}

default_pkg_target() {
    case "${DISTRIB_ID:-}" in
    Arch|EndeavourOS)
        echo arch
        ;;
    Deepin|deepin)
        echo deepin
        ;;
    *)
        echo "error: cannot infer package target for DISTRIB_ID='${DISTRIB_ID:-}'" >&2
        echo "usage: $0 pkg <arch|deepin|termux>" >&2
        exit 1
        ;;
    esac
}

restore_if_exists() {
    local src="$1"
    local dst="$2"

    if [[ -e "$src" ]]; then
        sudo mv "$src" "$dst"
    fi
}

install_nixpkgs() {
    restore_if_exists /etc/profile.d/nix.sh.backup-before-nix /etc/profile.d/nix.sh
    restore_if_exists /etc/bashrc.backup-before-nix /etc/bashrc
    restore_if_exists /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc
    restore_if_exists /etc/zshrc.backup-before-nix /etc/zshrc

    curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install | sh -s -- --no-daemon
    sudo mkdir -p /etc/nix
    sudo cp "$DOTFILES_DIR/nix.conf" /etc/nix/nix.conf
    sudo sed -i "s|\(Defaults\s*secure_path=.*\):.*|\1:/home/uniqueding/.nix-profile/bin\"|" /etc/sudoers
}

install_home_manager() {
    nix-channel --update
    nix-env -iA nixpkgs.home-manager
}

switch_dotfiles() {
    local profile="${1:-docker}"

    home-manager switch --flake "path:$DOTFILES_DIR#$profile"
}

init_conf() {
    rustup default stable || true
    pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || true
    go env -w GOPROXY=https://goproxy.io,direct || true
    mkdir -p "$HOME/.config"
    printf '%s\n' "$DOTFILES_DIR/conf" > "$HOME/.config/dotfiles"
    printf '%s\n' "${1:-}" >> "$HOME/.config/dotfiles"
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
}

install_nixgl() {
    nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl
    nix-channel --update
    nix-env -iA nixgl.auto.nixGLDefault
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

update_nix() {
    nix-channel --update
    nix-env -iA nixpkgs.nix
    nix-env -iA nixpkgs.home-manager
    nix flake update "$DOTFILES_DIR"
    nix --version
}

run_pkg() {
    local target="${1:-}"
    if [[ -z "$target" ]]; then
        target="$(default_pkg_target)"
    fi

    "$DOTFILES_DIR/scripts/init_pkg.sh" "$target"
}

run_sdk() {
    "$DOTFILES_DIR/scripts/init_sdk.sh"
}

run_bw() {
    "$DOTFILES_DIR/scripts/bw.sh" "$@"
}

install_kanata() {
    case "${DISTRIB_ID:-}" in
    Arch|EndeavourOS)
        yay -Sy --noconfirm kanata
        sudo ln -sfn "$DOTFILES_DIR/conf/kanata/kanata.kbd" /etc/kanata.kbd
        sudo systemctl enable --now kanata
        ;;
    *)
        echo "error: kanata install is only configured for Arch/EndeavourOS" >&2
        exit 1
        ;;
    esac
}

main() {
    local command="${1:-}"
    shift || true

    write_local_nix

    case "$command" in
    nixpkgs)
        install_nixpkgs
        ;;
    homemanager)
        install_home_manager
        ;;
    dotfiles)
        switch_dotfiles "${1:-}"
        ;;
    conf)
        init_conf "${1:-}"
        ;;
    pkg)
        run_pkg "${1:-}"
        ;;
    sdk)
        run_sdk
        ;;
    bw)
        run_bw "$@"
        ;;
    all)
        local profile="${1:-docker}"
        install_nixpkgs
        install_home_manager
        switch_dotfiles "$profile"
        init_conf "$profile"
        ;;
    nixgl)
        install_nixgl
        ;;
    theme)
        install_theme
        ;;
    update)
        update_nix
        ;;
    kanata)
        install_kanata
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        echo "error: unknown command '$command'" >&2
        usage >&2
        exit 1
        ;;
    esac
}

main "$@"
