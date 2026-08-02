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

kanata_macos_run() {
    if declare -F without_nix_env >/dev/null 2>&1; then
        without_nix_env "$@"
    else
        "$@"
    fi
}

install_kanata_macos() (
    set -e

    if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
        echo "error: macOS Kanata installation requires Apple Silicon (Darwin arm64)" >&2
        exit 1
    fi

    local temporary_dir
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "$temporary_dir"' EXIT

    kanata_macos_run brew install kanata

    local kanata_prefix
    local kanata_binary
    kanata_prefix="$(kanata_macos_run brew --prefix kanata)"
    kanata_binary="$kanata_prefix/bin/kanata"

    local kanata_config="$HOME/.config/kanata/kanata.kbd"
    mkdir -p "$(dirname "$kanata_config")"
    ln -sfn "$DOTFILES_DIR/conf/kanata/kanata.kbd" "$kanata_config"

    local daemon_plist="$temporary_dir/dev.kanata.kanata.plist"
    cat > "$daemon_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.kanata.kanata</string>
    <key>ProgramArguments</key>
    <array>
        <string>$kanata_binary</string>
        <string>--cfg</string>
        <string>$kanata_config</string>
        <string>--no-wait</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

    local daemon_path=/Library/LaunchDaemons/dev.kanata.kanata.plist
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$daemon_plist" "$daemon_path"
    kanata_macos_run sudo launchctl bootout system/dev.kanata.kanata >/dev/null 2>&1 || true
    kanata_macos_run sudo launchctl bootstrap system "$daemon_path"

    local release_json="$temporary_dir/release.json"
    local tray_binary="$temporary_dir/kanata-tray-macos"
    local checksums_file="$temporary_dir/sha256sums"
    kanata_macos_run curl --location --silent --show-error --fail \
        --header 'Accept: application/vnd.github+json' \
        --output "$release_json" \
        https://api.github.com/repos/rszyma/kanata-tray/releases/latest

    local tray_url
    local checksums_url
    tray_url="$(kanata_macos_run jq -er \
        '[.assets[] | select(.name == "kanata-tray-macos") | .browser_download_url] | .[0] | select(type == "string" and length > 0)' \
        "$release_json")"
    checksums_url="$(kanata_macos_run jq -er \
        '[.assets[] | select(.name == "sha256sums") | .browser_download_url] | .[0] | select(type == "string" and length > 0)' \
        "$release_json")"

    kanata_macos_run curl --location --silent --show-error --fail \
        --output "$tray_binary" "$tray_url"
    kanata_macos_run curl --location --silent --show-error --fail \
        --output "$checksums_file" "$checksums_url"

    (
        cd "$temporary_dir"
        kanata_macos_run shasum -a 256 -c "$checksums_file"
    )

    local file_info
    file_info="$(kanata_macos_run file "$tray_binary")"
    if [[ "$file_info" == *universal* ]]; then
        local lipo_info
        lipo_info="$(kanata_macos_run lipo -info "$tray_binary")"
        if [[ "$lipo_info" != *arm64* ]]; then
            echo "error: kanata-tray universal binary does not contain arm64" >&2
            exit 1
        fi
    elif [[ "$file_info" != *arm64* ]]; then
        echo "error: kanata-tray binary is not arm64 or universal" >&2
        exit 1
    fi

    local tray_binary_path="$HOME/.local/bin/kanata-tray"
    local tray_config_dir="$HOME/Library/Application Support/kanata-tray"
    local tray_config="$tray_config_dir/kanata-tray.toml"
    local tray_log_dir="$HOME/Library/Logs/kanata-tray"
    local tray_agent_dir="$HOME/Library/LaunchAgents"
    local tray_plist="$tray_agent_dir/dev.kanata.tray.plist"
    mkdir -p "$HOME/.local/bin" "$tray_config_dir" "$tray_log_dir" "$tray_agent_dir"
    install -m 0755 "$tray_binary" "$tray_binary_path"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//__KANATA_EXECUTABLE__/$kanata_binary}"
        line="${line//__KANATA_CONFIG__/$kanata_config}"
        printf '%s\n' "$line"
    done < "$DOTFILES_DIR/conf/kanata/kanata-tray.macos.toml" > "$tray_config"

    cat > "$tray_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.kanata.tray</string>
    <key>ProgramArguments</key>
    <array>
        <string>$tray_binary_path</string>
        <string>--config</string>
        <string>$tray_config</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$tray_log_dir/kanata-tray.out.log</string>
    <key>StandardErrorPath</key>
    <string>$tray_log_dir/kanata-tray.err.log</string>
</dict>
</plist>
PLIST

    kanata_macos_run launchctl bootout "gui/$(id -u)/dev.kanata.tray" >/dev/null 2>&1 || true
    kanata_macos_run launchctl bootstrap "gui/$(id -u)" "$tray_plist"

    printf '%s\n' \
        'Kanata macOS manual approvals required:' \
        '  - Approve the Karabiner DriverKit/VirtualHID system extension in System Settings.' \
        '  - Grant Kanata Input Monitoring and Accessibility access in Privacy & Security.' \
        '  - Verify that kanata-tray is allowed by Gatekeeper before running it.' \
        'Gatekeeper verification (manual; quarantine is not removed automatically):' \
        "  xattr -p com.apple.quarantine '$tray_binary_path'" \
        "  spctl --assess --type execute --verbose '$tray_binary_path'"
)

install_kanata() {
    if [[ "$(uname -s)" == Darwin ]]; then
        install_kanata_macos
        return
    fi

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
