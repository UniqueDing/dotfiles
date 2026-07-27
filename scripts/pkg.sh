PKG_TARGET_FILE="$DOTFILES_DIR/pkg_target"

without_nix_env() {
    local clean_path=""
    local path_entry

    IFS=: read -r -a path_entries <<< "$PATH"
    for path_entry in "${path_entries[@]}"; do
        case "$path_entry" in
        "$HOME/.nix-profile"*|/nix/var/nix/profiles/*|/run/current-system/sw*|/nix/store/*)
            continue
            ;;
        esac

        if [[ -z "$clean_path" ]]; then
            clean_path="$path_entry"
        else
            clean_path="$clean_path:$path_entry"
        fi
    done

    env -u NIX_PATH -u NIX_PROFILES -u NIX_SSL_CERT_FILE -u NIX_REMOTE -u IN_NIX_SHELL PATH="$clean_path" "$@"
}

install_deepin_packages() {
    PACKAGE_FILE="deepin.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list
    without_nix_env sudo apt update
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r without_nix_env sudo apt install -y
}

install_arch_packages() {
    PACKAGE_FILE="arch.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    # bug
    paru -Syu --noconfirm
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r paru -Sy --noconfirm
}

install_termux_packages() {
    PACKAGE_FILE="termux.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    pkg update
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r pkg i -y
    vs start sshd
}

install_windows_packages() {
    PACKAGE_FILE="windows.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    cat "$DOTFILES_DIR/package/$PACKAGE_FILE" | grep -vE '^\s*#' | grep -vE '^\s*$' | xargs -r -I {} winget install --id "{}" --exact --accept-package-agreements --accept-source-agreements
}

default_pkg_target() {
    if [[ "${OS:-}" == "Windows_NT" ]]; then
        echo windows
        return
    fi

    case "${DISTRIB_ID:-}" in
    Arch|EndeavourOS)
        echo arch
        ;;
    Deepin|deepin)
        echo deepin
        ;;
    *)
        echo "error: cannot infer package target for DISTRIB_ID='${DISTRIB_ID:-}'" >&2
        echo "usage: $0 pkg <arch|deepin|termux|windows>" >&2
        exit 1
        ;;
    esac
}

save_pkg_target() {
    printf '%s\n' "$1" > "$PKG_TARGET_FILE"
}

update_system_packages() {
    if [[ ! -f "$PKG_TARGET_FILE" ]]; then
        return
    fi

    local target
    target="$(cat "$PKG_TARGET_FILE")"

    case "$target" in
    arch)
        without_nix_env paru -Syu --noconfirm
        ;;
    deepin)
        without_nix_env sudo apt update
        without_nix_env sudo apt upgrade -y
        ;;
    termux)
        pkg update
        pkg upgrade -y
        ;;
    windows)
        winget upgrade --all --accept-package-agreements --accept-source-agreements
        ;;
    esac
}

update_all() {
    # update_system_packages
    if command -v nix-channel >/dev/null 2>&1; then
        update_nix
    fi
    if command -v home-manager >/dev/null 2>&1; then
        switch_dotfiles
    fi
}

install_packages() {
    local target="$1"

    case "$target" in
    deepin)
        install_deepin_packages
        install_linux_fonts
        link_linux_configs
        ;;
    arch)
        install_arch_packages
        install_linux_fonts
        link_linux_configs
        ;;
    termux)
        install_termux_packages
        install_linux_fonts
        link_linux_configs
        ;;
    windows)
        install_windows_packages
        install_windows_fonts
        link_windows_configs
        ;;
    *)
        echo "error: unknown package target: $target" >&2
        exit 1
        ;;
    esac
}

run_pkg() {
    local target="${1:-}"
    if [[ -z "$target" ]]; then
        target="$(default_pkg_target)"
    fi

    install_packages "$target" || true
    save_pkg_target "$target"
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
