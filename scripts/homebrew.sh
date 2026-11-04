#!/usr/bin/env bash
# Safe to source for paths; only direct execution manages the bundle.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"

homebrew_is_deepin() (
    [[ "$(uname -s)" == Linux && -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == deepin ]]
)

homebrew_bin() {
    local binary candidate
    binary=$(command -v brew || true)
    if [[ -z "$binary" ]]; then
        for candidate in /home/linuxbrew/.linuxbrew/bin/brew /opt/homebrew/bin/brew /usr/local/bin/brew; do
            if [[ -x "$candidate" ]]; then binary=$candidate; break; fi
        done
    fi
    [[ -n "$binary" ]] || { printf 'error: install Homebrew first\n' >&2; return 1; }
    printf '%s\n' "$binary"
}

homebrew_prefix() {
    local binary formula=${1:-} prefix
    if [[ $(id -u) == 0 ]]; then
        # Read standard payloads; never execute user Brew as root.
        case "$(uname -s)/$(uname -m)" in
            Linux/*) prefix=/home/linuxbrew/.linuxbrew;;
            Darwin/arm64|Darwin/aarch64) prefix=/opt/homebrew;;
            Darwin/x86_64) prefix=/usr/local;;
            *) printf 'error: unsupported native Homebrew prefix\n' >&2; return 1;;
        esac
        if [[ -n "$formula" ]]; then printf '%s/opt/%s\n' "$prefix" "${formula##*/}"
        else printf '%s\n' "$prefix"; fi
        return
    fi
    binary=$(homebrew_bin) || return 1
    if [[ -n "$formula" ]]; then "$binary" --prefix "$formula"; else "$binary" --prefix; fi
}

homebrew_main() {
    local BREW_BIN system tap desktop directory destination
    BREW_BIN="$(homebrew_bin)" || return 1
    [[ $(id -u) != 0 ]] || { printf 'error: run Homebrew as your ordinary user\n' >&2; return 1; }
    system=$(uname -s)
    if [[ "$system" == Linux || "$system" == Darwin ]]; then
        tap="$("$BREW_BIN" --repository)/Library/Taps/uniqueding/homebrew-dotfiles"
        if [[ ! -e "$tap" && ! -L "$tap" ]]; then
            mkdir -p "${tap%/*}"
            mkdir "$tap"
            printf '%s\n' "$DOTFILES_DIR" > "$tap/.dotfiles-local-tap"
            git init -q "$tap"
            ln -s "$DOTFILES_DIR/Formula" "$tap/Formula"
        fi
        # Separate metadata prevents Brew updates from changing this checkout.
        [[ ! -L "$tap" && -d "$tap/.git" && -f "$tap/.dotfiles-local-tap" &&
           "$(<"$tap/.dotfiles-local-tap")" == "$DOTFILES_DIR" && -L "$tap/Formula" &&
           "$(readlink "$tap/Formula")" == "$DOTFILES_DIR/Formula" ]] || {
            printf 'error: refusing to replace an existing or incomplete local tap: %s\n' "$tap" >&2
            return 1
        }
        [[ -z "$(git -C "$tap" remote)" ]] || {
            printf 'error: local tap must not have Git remotes: %s\n' "$tap" >&2
            return 1
        }
    fi

    [[ $# -gt 0 ]] || set -- install --no-upgrade
    "$BREW_BIN" bundle "$@" --file "$DOTFILES_DIR/Brewfile" || return $?

    if [[ "$system" == Linux && "$1" == install ]]; then
        desktop="$("$BREW_BIN" --prefix)/opt/clash-party-linux/share/applications/clash-party-linux.desktop"
        if [[ -f "$desktop" ]]; then
            directory="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
            destination="$directory/clash-party-linux.desktop"
            if [[ -L "$destination" && "$(readlink "$destination")" == "$desktop" ]]; then
                :
            elif [[ -e "$destination" || -L "$destination" ]]; then
                printf 'error: refusing to replace desktop entry: %s\n' "$destination" >&2
                return 1
            else
                mkdir -p "$directory"
                ln -s "$desktop" "$destination"
            fi
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    homebrew_main "$@"
fi
