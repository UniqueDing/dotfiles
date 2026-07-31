install_kanata_deepin() (
    without_nix_env sudo apt install -y curl build-essential pkg-config libayatana-appindicator3-dev

    local temporary_dir
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "$temporary_dir"' EXIT

    local cargo_home="$temporary_dir/cargo"
    local install_root="$temporary_dir/install"
    without_nix_env curl --proto '=https' --tlsv1.2 --silent --show-error --fail https://sh.rustup.rs |
        CARGO_HOME="$cargo_home" RUSTUP_HOME="$temporary_dir/rustup" sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path
    PATH="$cargo_home/bin:$PATH" CARGO_ROOT="$install_root" cargo install kanata --root "$install_root"
    sudo install -m 0755 "$install_root/bin/kanata" /usr/local/bin/kanata
    sudo install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata.service" /etc/systemd/system/kanata.service
    sudo systemctl daemon-reload

    local tray_binary="$temporary_dir/kanata-tray"
    without_nix_env curl --location --silent --show-error --fail \
        --output "$tray_binary" \
        https://github.com/rszyma/kanata-tray/releases/latest/download/kanata-tray-linux
    sudo install -m 0755 "$tray_binary" /usr/local/bin/kanata-tray

    sudo groupadd --system --force uinput
    sudo usermod -aG input,uinput "$USER"
    sudo install -m 0644 "$DOTFILES_DIR/conf/kanata/99-kanata.rules" /etc/udev/rules.d/99-kanata.rules
    sudo modprobe uinput
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    sudo ln -sfn "$DOTFILES_DIR/conf/kanata/kanata.kbd" /etc/kanata.kbd
    mkdir -p "$HOME/.config/systemd/user" "$HOME/.config/kanata-tray" "$HOME/.local/state/kanata-tray"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-tray.service" "$HOME/.config/systemd/user/kanata-tray.service"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-tray.toml" "$HOME/.config/kanata-tray/kanata-tray.toml"
    sudo systemctl disable --now kanata
    systemctl --user daemon-reload
    systemctl --user enable --now kanata-tray.service
)

install_kanata() {
    case "${DISTRIB_ID:-}" in
    Arch|EndeavourOS)
        yay -Sy --noconfirm kanata
        sudo ln -sfn "$DOTFILES_DIR/conf/kanata/kanata.kbd" /etc/kanata.kbd
        sudo systemctl enable --now kanata
        ;;
    Deepin|deepin)
        install_kanata_deepin || return
        ;;
    *)
        echo "error: kanata install is only configured for Arch/EndeavourOS/Deepin" >&2
        exit 1
        ;;
    esac
}
