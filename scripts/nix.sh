LOCAL_NIX="$DOTFILES_DIR/local.nix"

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

    curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install | sh -s -- --no-daemon --no-modify-profile
    sudo mkdir -p /etc/nix
    sudo cp "$DOTFILES_DIR/conf/nix.conf" /etc/nix/nix.conf
    sudo sed -i "s|\(Defaults\s*secure_path=.*\):.*|\1:/home/uniqueding/.nix-profile/bin\"|" /etc/sudoers
}

install_home_manager() {
    nix-channel --update
    nix-env -iA nixpkgs.home-manager
}

switch_dotfiles() {
    local profile="${1:-light}"

    home-manager switch --flake "path:$DOTFILES_DIR#$profile"
}

install_nixgl() {
    nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl
    nix-channel --update
    nix-env -iA nixgl.auto.nixGLDefault
}

update_nix() {
    nix-channel --update
    nix-env -iA nixpkgs.nix
    nix-env -iA nixpkgs.home-manager
    nix flake update "$DOTFILES_DIR"
    nix --version
}
