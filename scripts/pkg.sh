PKG_TARGET_FILE="$DOTFILES_DIR/pkg_target"

# shellcheck source=scripts/autostart.sh
source "$DOTFILES_DIR/scripts/autostart.sh"
# shellcheck source=scripts/external-packages.sh
source "$DOTFILES_DIR/scripts/external-packages.sh"

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

# Loads ordinary package names into PACKAGE_LIST and records the special entry
# in PACKAGE_HAS_CLIPROXYAPI.  Lists accept blank lines, comments, CRLF, and
# surrounding whitespace.
load_package_list() {
    local package_file="$1"
    local package

    PACKAGE_LIST=()
    PACKAGE_HAS_CLIPROXYAPI=0
    while IFS= read -r package || [[ -n "$package" ]]; do
        package="${package%$'\r'}"
        package="${package#${package%%[![:space:]]*}}"
        package="${package%${package##*[![:space:]]}}"
        [[ -z "$package" || "${package#\#}" != "$package" ]] && continue
        if [[ "$package" == "cliproxyapi" ]]; then
            PACKAGE_HAS_CLIPROXYAPI=1
        else
            PACKAGE_LIST+=("$package")
        fi
    done < "$package_file"
}

package_list_contains() {
    local needle="$1" package
    shift
    for package in "$@"; do
        [[ "$package" == "$needle" ]] && return 0
    done
    return 1
}

install_deepin_packages() {
    local package_file="$DOTFILES_DIR/package/deepin.list"

    if [[ ! -f "$package_file" ]]; then
        echo "error: deepin.list not found" >&2
        return 1
    fi
    load_package_list "$package_file"
    echo "deb https://pro-store-packages.uniontech.com/appstore eagle-pro appstore" | sudo tee /etc/apt/sources.list.d/appstoreuos.list || return 1
    without_nix_env sudo apt update || return 1
    without_nix_env sudo apt install -y curl jq || return 1
    if ((${#PACKAGE_LIST[@]} > 0)); then
        without_nix_env sudo apt install -y "${PACKAGE_LIST[@]}" || return 1
    fi
    printf '%s\n' 'clash-party installing'
    install_external_package deepin clash-party || return 1
    if (( PACKAGE_HAS_CLIPROXYAPI )); then
        printf '%s\n' 'cliproxyapi installing'
        install_external_package deepin cliproxyapi || return 1
    fi
}

install_arch_packages() {
    local package_file="$DOTFILES_DIR/package/arch.list"

    if [[ ! -f "$package_file" ]]; then
        echo "error: arch.list not found" >&2
        return 1
    fi
    load_package_list "$package_file"
    without_nix_env paru -Syu --noconfirm || return 1
    if ((${#PACKAGE_LIST[@]} > 0)); then
        without_nix_env paru -Sy --noconfirm "${PACKAGE_LIST[@]}" || return 1
    fi
    if (( PACKAGE_HAS_CLIPROXYAPI )); then
        install_external_package arch cliproxyapi || return 1
    fi
}

install_termux_packages() {
    local package_file="$DOTFILES_DIR/package/termux.list"

    if [[ ! -f "$package_file" ]]; then
        echo "error: termux.list not found" >&2
        return 1
    fi
    load_package_list "$package_file"
    if (( PACKAGE_HAS_CLIPROXYAPI )); then
        install_external_package termux cliproxyapi || return 1
    fi
    pkg update || return 1
    if ((${#PACKAGE_LIST[@]} > 0)); then
        pkg i -y "${PACKAGE_LIST[@]}" || return 1
    fi
    vs start sshd || return 1
}

install_windows_packages() {
    local package_file="$DOTFILES_DIR/package/windows.list"
    local msys_package_file="$DOTFILES_DIR/package/windows-msys2.list"
    local package
    local windows_packages=()
    local msys_packages=()
    local update_status=0

    [[ -f "$package_file" ]] || { echo "error: required WinGet list not found: $package_file" >&2; return 1; }
    [[ -f "$msys_package_file" ]] || { echo "error: required MSYS2 package list not found: $msys_package_file" >&2; return 1; }

    load_package_list "$package_file"
    for package in "${PACKAGE_LIST[@]}"; do
        [[ "$package" =~ ^[[:alnum:].-]+$ ]] || { echo "error: invalid WinGet ID in $package_file: $package" >&2; return 1; }
        package_list_contains "$package" "${windows_packages[@]}" && { echo "error: duplicate WinGet ID in $package_file: $package" >&2; return 1; }
        windows_packages+=("$package")
    done
    ((${#windows_packages[@]} > 0)) || { echo "error: WinGet list is empty: $package_file" >&2; return 1; }
    local install_cliproxyapi_requested="$PACKAGE_HAS_CLIPROXYAPI"

    load_package_list "$msys_package_file"
    for package in "${PACKAGE_LIST[@]}"; do
        [[ "$package" =~ ^[[:alnum:].-]+$ ]] || { echo "error: invalid MSYS2 package in $msys_package_file: $package" >&2; return 1; }
        package_list_contains "$package" "${msys_packages[@]}" && { echo "error: duplicate MSYS2 package in $msys_package_file: $package" >&2; return 1; }
        msys_packages+=("$package")
    done
    ((${#msys_packages[@]} > 0)) || { echo "error: MSYS2 package list is empty: $msys_package_file" >&2; return 1; }

    [[ "${MSYSTEM:-}" == "MSYS" ]] || { echo "error: run Windows package installation from an MSYS2 MSYS shell" >&2; return 1; }
    command -v powershell.exe >/dev/null 2>&1 || { echo "error: powershell.exe is required to install Windows packages" >&2; return 1; }
    pacman -Syu || update_status=$?
    if (( update_status != 0 )); then
        printf '%s\n' 'MSYS2 update did not complete. Close and reopen the MSYS shell, then rerun package setup.' >&2
        return "$update_status"
    fi
    pacman -S --needed "${msys_packages[@]}" || return 1
    for package in "${windows_packages[@]}"; do
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget install --id '$package' --exact --source winget --accept-package-agreements --accept-source-agreements" || return 1
    done
    if (( install_cliproxyapi_requested )); then
        install_external_package windows cliproxyapi || return 1
    fi
}

install_macos_packages() {
    local package_file="$DOTFILES_DIR/package/macos.list"
    local package

    [[ -f "$package_file" ]] || { echo "error: macos.list not found" >&2; return 1; }
    command -v brew >/dev/null 2>&1 || { echo "error: Homebrew (brew) is required for macOS packages" >&2; return 1; }
    load_package_list "$package_file"
    brew update || return 1
    for package in "${PACKAGE_LIST[@]}"; do
        brew install --cask "$package" || return 1
    done
    if (( PACKAGE_HAS_CLIPROXYAPI )); then
        install_external_package macos cliproxyapi || return 1
    fi
}

default_pkg_target() {
    if [[ "$(uname -s)" == "Darwin" ]]; then echo macos; return; fi
    if [[ "${OS:-}" == "Windows_NT" ]]; then echo windows; return; fi
    case "${DISTRIB_ID:-}" in
    Arch|EndeavourOS) echo arch ;;
    Deepin|deepin) echo deepin ;;
    *)
        echo "error: cannot infer package target for DISTRIB_ID='${DISTRIB_ID:-}'" >&2
        echo "usage: $0 pkg <arch|deepin|termux|windows|macos>" >&2
        return 1
        ;;
    esac
}

save_pkg_target() { printf '%s\n' "$1" > "$PKG_TARGET_FILE"; }

update_system_packages() {
    [[ -f "$PKG_TARGET_FILE" ]] || return
    local target
    target="$(< "$PKG_TARGET_FILE")"
    case "$target" in
    arch) without_nix_env paru -Syu --noconfirm ;;
    deepin) without_nix_env sudo apt update && without_nix_env sudo apt upgrade -y ;;
    termux) pkg update && pkg upgrade -y ;;
    windows) printf '%s\n' 'PowerShell: winget upgrade --all' 'MSYS2 MSYS shell: pacman -Syu' ;;
    macos)
        command -v brew >/dev/null 2>&1 || { echo "error: Homebrew (brew) is required for macOS updates" >&2; return 1; }
        brew update && brew upgrade --cask
        ;;
    esac
}

update_all() {
    # update_system_packages
    if [[ "$(uname -s)" == "Darwin" ]]; then
        command -v nix >/dev/null 2>&1 || { echo "error: Nix is required for macOS updates" >&2; return 1; }
        update_nix
        return
    fi
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "error: unsupported platform for updates: $(uname -s)" >&2
        return 1
    fi
    command -v nix-channel >/dev/null 2>&1 && update_nix
    command -v home-manager >/dev/null 2>&1 && switch_dotfiles
}

install_packages() {
    local target="$1"
    case "$target" in
    deepin) install_deepin_packages || return 1; link_linux_configs ;;
    arch) install_arch_packages || return 1; link_linux_configs ;;
    termux) install_termux_packages || return 1; link_linux_configs ;;
    windows) install_windows_packages || return 1; link_windows_configs || return 1 ;;
    macos) install_macos_packages || return 1; link_macos_configs || return 1 ;;
    *) echo "error: unknown package target: $target" >&2; return 1 ;;
    esac
}

run_pkg() {
    local target="${1:-}"
    [[ -n "$target" ]] || target="$(default_pkg_target)" || return 1
    install_packages "$target" || return 1
    save_pkg_target "$target"
}
