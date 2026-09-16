LOCAL_NIX="$DOTFILES_DIR/local.nix"

if [[ "$(uname -s)" == "Darwin" && -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
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

restore_if_exists() {
    local src="$1"
    local dst="$2"

    if [[ -e "$src" ]]; then
        sudo mv "$src" "$dst"
    fi
}

install_nixpkgs() {
    case "$(uname -s)" in
    Darwin)
        curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
        # shellcheck disable=SC1091
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        sudo nix --extra-experimental-features 'nix-command flakes' run --inputs-from "path:$DOTFILES_DIR" nix-darwin#darwin-rebuild -- switch --flake "path:$DOTFILES_DIR#uniqueding-mbp"
        ;;
    Linux)
    restore_if_exists /etc/profile.d/nix.sh.backup-before-nix /etc/profile.d/nix.sh
    restore_if_exists /etc/bashrc.backup-before-nix /etc/bashrc
    restore_if_exists /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc
    restore_if_exists /etc/zshrc.backup-before-nix /etc/zshrc

    curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install | sh -s -- --no-daemon --no-modify-profile
    sudo mkdir -p /etc/nix
    sudo cp "$DOTFILES_DIR/conf/nix.conf" /etc/nix/nix.conf
    sudo sed -i "s|\(Defaults\s*secure_path=.*\):.*|\1:/home/uniqueding/.nix-profile/bin\"|" /etc/sudoers
        ;;
    *)
        echo "error: unsupported platform for Nix installation: $(uname -s)" >&2
        return 1
        ;;
    esac
}

install_home_manager() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "error: Home Manager installation is Linux-only; macOS uses nix-darwin" >&2
        return 1
    fi
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "error: unsupported platform for Home Manager installation: $(uname -s)" >&2
        return 1
    fi
    nix-channel --update
    nix-env -iA nixpkgs.home-manager
}

switch_dotfiles() {
    local platform
    platform="$(uname -s)"

    case "$platform" in
    Linux)
        local profile="${1:-light}"
        home-manager switch --flake "path:$DOTFILES_DIR#$profile"
        ;;
    Darwin)
        if [[ -n "${1:-}" ]]; then
            echo "error: macOS does not support Home Manager profiles; use the uniqueding-mbp nix-darwin configuration" >&2
            return 1
        fi
        if command -v darwin-rebuild >/dev/null 2>&1; then
            sudo darwin-rebuild switch --flake "path:$DOTFILES_DIR#uniqueding-mbp"
        else
            local nix_bin
            nix_bin="$(command -v nix)"
            if [[ -z "$nix_bin" || "$nix_bin" != /* ]]; then
                echo "error: nix is unavailable at an absolute path after loading the Nix daemon profile" >&2
                return 1
            fi
            sudo "$nix_bin" --extra-experimental-features 'nix-command flakes' run --inputs-from "path:$DOTFILES_DIR" nix-darwin#darwin-rebuild -- switch --flake "path:$DOTFILES_DIR#uniqueding-mbp"
        fi
        ;;
    *)
        echo "error: unsupported platform for dotfiles switch: $platform" >&2
        return 1
        ;;
    esac
}

install_nixgl() {
    nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl
    nix-channel --update
    nix-env -iA nixgl.auto.nixGLDefault
}

update_nix() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        nix flake update "$DOTFILES_DIR" || return 1
        switch_dotfiles
        return
    fi
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "error: unsupported platform for Nix update: $(uname -s)" >&2
        return 1
    fi
    nix-channel --update
    nix-env -iA nixpkgs.nix
    nix-env -iA nixpkgs.home-manager
    nix flake update "$DOTFILES_DIR"
    nix --version
}
