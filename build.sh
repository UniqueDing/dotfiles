#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=scripts/nix.sh
source "$DOTFILES_DIR/scripts/nix.sh"
# shellcheck source=scripts/conf.sh
source "$DOTFILES_DIR/scripts/conf.sh"
source "$DOTFILES_DIR/scripts/opencode.sh"
# shellcheck source=scripts/pkg.sh
source "$DOTFILES_DIR/scripts/pkg.sh"
# shellcheck source=scripts/font.sh
source "$DOTFILES_DIR/scripts/font.sh"
# shellcheck source=scripts/kanata.sh
source "$DOTFILES_DIR/scripts/kanata.sh"

if [[ -f /etc/lsb-release ]]; then
    # shellcheck disable=SC1091
    source /etc/lsb-release
else
    DISTRIB_ID="${DISTRIB_ID:-}"
fi

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  nixpkgs              Install Nix; macOS also bootstraps nix-darwin
  homemanager          Install Home Manager through nix-channel (Linux only)
  dotfiles [profile]   Switch Home Manager profile (Linux, defaults to light) or nix-darwin (macOS)
  conf                 Initialize post-switch user config
  pkg [target]         Install packages for target, defaults by distro
                       targets: arch, deepin, termux, windows, macos
  fonts [target]       Install fonts for target, defaults by distro
  sdk                  Run scripts/init_sdk.sh
  bw [args]            Run scripts/bw.sh with forwarded args
  all [profile]        Linux: install Nix/Home Manager and switch profile; macOS: install and switch nix-darwin
  nixgl                Install nixGL
  theme                Install Qogir themes
  windows-terminal     Add Git Bash profile to Windows Terminal
  update               Update Nix, channels, flake lock, and Home Manager
  kanata [target]      Install Kanata (Linux uses the system-service migration)
                        targets: other, arch, macos, windows
  opencode             Bootstrap OpenCode skills and oh-my-opencode-slim
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

run_sdk() {
    "$DOTFILES_DIR/scripts/init_sdk.sh"
}

run_bw() {
    "$DOTFILES_DIR/scripts/bw.sh" "$@"
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
    fonts)
        install_fonts "${1:-}"
        ;;
    sdk)
        run_sdk
        ;;
    bw)
        run_bw "$@"
        ;;
    all)
        local profile="${1:-light}"
        case "$(uname -s)" in
        Linux)
            install_nixpkgs
            install_home_manager
            switch_dotfiles "$profile"
            init_conf "$profile"
            install_fonts
            ;;
        Darwin)
            if [[ -n "${1:-}" ]]; then
                echo "error: macOS does not support Home Manager profiles; omit the profile argument" >&2
                return 1
            fi
            install_nixpkgs
            ;;
        *)
            echo "error: unsupported platform for all: $(uname -s)" >&2
            return 1
            ;;
        esac
        ;;
    nixgl)
        install_nixgl
        ;;
    theme)
        install_theme
        ;;
    windows-terminal)
        add_windows_terminal_git_bash
        ;;
    update)
        update_all
        ;;
    kanata)
        install_kanata "${1:-}"
        ;;
    opencode)
        install_opencode_environment
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
