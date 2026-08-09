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

install_clash_party_deepin() (
    set -e

    local architecture
    architecture="$(without_nix_env dpkg --print-architecture)" || exit 1
    case "$architecture" in
    amd64|arm64)
        ;;
    *)
        echo "error: unsupported Clash Party architecture: $architecture" >&2
        exit 1
        ;;
    esac

    local temporary_dir
    temporary_dir="$(without_nix_env mktemp -d)" || exit 1
    trap 'rm -rf "$temporary_dir"' EXIT

    local release_file="$temporary_dir/release.json"
    without_nix_env curl \
        --location \
        --silent \
        --show-error \
        --fail \
        --header 'Accept: application/vnd.github+json' \
        --output "$release_file" \
        https://api.github.com/repos/mihomo-party-org/clash-party/releases/latest || exit 1

    local tag_name
    tag_name="$(without_nix_env jq -er '
        select(.draft == false and .prerelease == false)
        | .tag_name
        | select(type == "string" and length > 0)
    ' "$release_file")" || exit 1

    local version="${tag_name#v}"
    local deb_name="clash-party-linux-${version}-${architecture}.deb"
    local checksum_name="${deb_name}.sha256"
    local deb_url
    local checksum_url
    deb_url="$(without_nix_env jq -er --arg name "$deb_name" "
        [.assets[] | select(.name == \$name and .state == \"uploaded\") | .browser_download_url]
        | select(length == 1)
        | .[0]
        | select(type == \"string\" and length > 0)
    " "$release_file")" || exit 1
    checksum_url="$(without_nix_env jq -er --arg name "$checksum_name" "
        [.assets[] | select(.name == \$name and .state == \"uploaded\") | .browser_download_url]
        | select(length == 1)
        | .[0]
        | select(type == \"string\" and length > 0)
    " "$release_file")" || exit 1

    without_nix_env curl --location --silent --show-error --fail --output "$temporary_dir/$deb_name" "$deb_url" || exit 1
    without_nix_env curl --location --silent --show-error --fail --output "$temporary_dir/$checksum_name" "$checksum_url" || exit 1

    local expected_checksum
    expected_checksum="$(< "$temporary_dir/$checksum_name")"
    if [[ ! "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
        echo "error: invalid Clash Party checksum for $deb_name" >&2
        exit 1
    fi

    local actual_checksum
    actual_checksum="$(without_nix_env sha256sum "$temporary_dir/$deb_name")" || exit 1
    actual_checksum="${actual_checksum%% *}"
    if [[ "${actual_checksum,,}" != "${expected_checksum,,}" ]]; then
        echo "error: Clash Party checksum mismatch for $deb_name" >&2
        exit 1
    fi

    cd "$temporary_dir"
    without_nix_env sudo apt install -y "./$deb_name" || exit 1
)

install_deepin_packages() {
    PACKAGE_FILE="deepin.list"
    if [[ ! -f "$DOTFILES_DIR/package/$PACKAGE_FILE" ]]; then
        echo "error：$PACKAGE_FILE not exsit!"
        exit 1
    fi
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list
    without_nix_env sudo apt update || return
    without_nix_env sudo apt install -y curl jq || return

    local packages=()
    mapfile -t packages < <(grep -vE '^\s*(#|$)' "$DOTFILES_DIR/package/$PACKAGE_FILE")
    if ((${#packages[@]} > 0)); then
        without_nix_env sudo apt install -y "${packages[@]}" || return
    fi
    install_clash_party_deepin
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
    local package_file="$DOTFILES_DIR/package/windows.list"
    local msys_package_file="$DOTFILES_DIR/package/windows-msys2.list"
    local package
    local windows_packages=()
    local msys_packages=()
    local update_status=0
    declare -A seen_windows_packages=()
    declare -A seen_msys_packages=()

    if [[ ! -f "$package_file" ]]; then
        echo "error: required WinGet list not found: $package_file" >&2
        return 1
    fi
    if [[ ! -f "$msys_package_file" ]]; then
        echo "error: required MSYS2 package list not found: $msys_package_file" >&2
        return 1
    fi

    while IFS= read -r package || [[ -n "$package" ]]; do
        package="${package#${package%%[![:space:]]*}}"
        package="${package%${package##*[![:space:]]}}"
        [[ -z "$package" || "${package#\#}" != "$package" ]] && continue
        if [[ ! "$package" =~ ^[[:alnum:].-]+$ ]]; then
            echo "error: invalid WinGet ID in $package_file: $package" >&2
            return 1
        fi
        if [[ -n ${seen_windows_packages[$package]+x} ]]; then
            echo "error: duplicate WinGet ID in $package_file: $package" >&2
            return 1
        fi
        seen_windows_packages[$package]=1
        windows_packages+=("$package")
    done < "$package_file"
    if ((${#windows_packages[@]} == 0)); then
        echo "error: WinGet list is empty: $package_file" >&2
        return 1
    fi

    while IFS= read -r package || [[ -n "$package" ]]; do
        package="${package#${package%%[![:space:]]*}}"
        package="${package%${package##*[![:space:]]}}"
        [[ -z "$package" || "${package#\#}" != "$package" ]] && continue
        if [[ ! "$package" =~ ^[[:alnum:].-]+$ ]]; then
            echo "error: invalid MSYS2 package in $msys_package_file: $package" >&2
            return 1
        fi
        if [[ -n ${seen_msys_packages[$package]+x} ]]; then
            echo "error: duplicate MSYS2 package in $msys_package_file: $package" >&2
            return 1
        fi
        seen_msys_packages[$package]=1
        msys_packages+=("$package")
    done < "$msys_package_file"
    if ((${#msys_packages[@]} == 0)); then
        echo "error: MSYS2 package list is empty: $msys_package_file" >&2
        return 1
    fi

    if [[ "${MSYSTEM:-}" != "MSYS" ]]; then
        echo "error: run Windows package installation from an MSYS2 MSYS shell" >&2
        return 1
    fi
    if ! command -v powershell.exe >/dev/null 2>&1; then
        echo "error: powershell.exe is required to install Windows packages" >&2
        return 1
    fi

    pacman -Syu || update_status=$?
    if (( update_status != 0 )); then
        printf '%s\n' 'MSYS2 update did not complete. Close and reopen the MSYS shell, then rerun package setup.' >&2
        return "$update_status"
    fi
    pacman -S --needed "${msys_packages[@]}" || return 1

    for package in "${windows_packages[@]}"; do
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget install --id '$package' --exact --source winget --accept-package-agreements --accept-source-agreements" || return 1
    done
}

install_macos_packages() {
    local package_file="$DOTFILES_DIR/package/macos.list"
    local package

    if [[ ! -f "$package_file" ]]; then
        echo "error: macos.list not found" >&2
        return 1
    fi
    if ! command -v brew >/dev/null 2>&1; then
        echo "error: Homebrew (brew) is required for macOS packages" >&2
        return 1
    fi

    brew update || return 1
    while IFS= read -r package || [[ -n "$package" ]]; do
        package="${package#${package%%[![:space:]]*}}"
        package="${package%${package##*[![:space:]]}}"
        [[ -z "$package" || "${package#\#}" != "$package" ]] && continue
        brew install --cask "$package" || return 1
    done < "$package_file"
}

default_pkg_target() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo macos
        return
    fi

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
        echo "usage: $0 pkg <arch|deepin|termux|windows|macos>" >&2
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
        printf '%s\n' 'PowerShell: winget upgrade --all'
        printf '%s\n' 'MSYS2 MSYS shell: pacman -Syu'
        ;;
    macos)
        if command -v brew >/dev/null 2>&1; then
            brew update
            brew upgrade --cask
        else
            echo "error: Homebrew (brew) is required for macOS updates" >&2
            return 1
        fi
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
        link_linux_configs
        ;;
    arch)
        install_arch_packages
        link_linux_configs
        ;;
    termux)
        install_termux_packages
        link_linux_configs
        ;;
    windows)
        install_windows_packages || return 1
        link_windows_configs || return 1
        ;;
    macos)
        install_macos_packages || return 1
        link_macos_configs || return 1
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

    if [[ "$target" == "windows" ]]; then
        install_packages "$target" || return 1
        save_pkg_target "$target"
        return
    fi

    if [[ "$target" == "macos" ]]; then
        install_packages "$target" || return 1
        save_pkg_target "$target"
        return
    fi

    install_packages "$target" || true
    save_pkg_target "$target"
}
