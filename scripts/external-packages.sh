#!/usr/bin/env bash
# External package installers. Intended to be sourced after autostart.sh.

external_package_error() {
    printf 'error: external package: %s\n' "$*" >&2
}

external_package_temp_dir() {
    mktemp -d "${TMPDIR:-/tmp}/external-package.XXXXXX"
}

external_package_download() {
    local destination="$1" url="$2"

    curl --fail --location --show-error --output "$destination" "$url"
}

external_package_sha256() {
    local file="$1" digest

    if [[ "${OS:-}" == "Windows_NT" ]]; then
        command -v powershell.exe >/dev/null 2>&1 || return 1
        command -v cygpath >/dev/null 2>&1 || return 1
        digest="$(powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; [Console]::Write((Get-FileHash -Algorithm SHA256 -LiteralPath $args[0]).Hash.ToLowerInvariant())' "$(cygpath -aw "$file")")" || return 1
    elif command -v sha256sum >/dev/null 2>&1; then
        digest="$(sha256sum "$file")" || return 1
        digest="${digest%% *}"
    elif command -v shasum >/dev/null 2>&1; then
        digest="$(shasum -a 256 "$file")" || return 1
        digest="${digest%% *}"
    else
        return 1
    fi
    [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    printf '%s' "$digest"
}

external_package_verify_sha256() {
    local file="$1" expected="$2" label="$3" actual

    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || {
        external_package_error "invalid SHA256 configured for $label"
        return 1
    }
    actual="$(external_package_sha256 "$file")" || {
        external_package_error "could not calculate SHA256 for $label"
        return 1
    }
    actual="$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')" || return 1
    expected="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')" || return 1
    if [[ "$actual" != "$expected" ]]; then
        external_package_error "SHA256 mismatch for $label"
        return 1
    fi
}

external_package_install_clash_party_deepin() (
    set -e
    local architecture temporary_dir release_file tag_name version deb_name checksum_name deb_url checksum_url expected

    clash_party_without_nix_env() {
        local clean_path='' path_entry

        if declare -F without_nix_env >/dev/null 2>&1; then
            without_nix_env "$@"
            return
        fi
        local path_entries=()
        IFS=: read -r -a path_entries <<< "$PATH"
        for path_entry in "${path_entries[@]}"; do
            case "$path_entry" in
            "$HOME/.nix-profile"*|/nix/var/nix/profiles/*|/run/current-system/sw*|/nix/store/*) continue ;;
            esac
            if [[ -z "$clean_path" ]]; then clean_path="$path_entry"; else clean_path="$clean_path:$path_entry"; fi
        done
        env -u NIX_PATH -u NIX_PROFILES -u NIX_SSL_CERT_FILE -u NIX_REMOTE -u IN_NIX_SHELL PATH="$clean_path" "$@"
    }

    architecture="$(clash_party_without_nix_env dpkg --print-architecture)" || exit 1
    case "$architecture" in
    amd64|arm64) ;;
    *) external_package_error "unsupported Clash Party architecture: $architecture"; exit 1 ;;
    esac

    temporary_dir="$(clash_party_without_nix_env mktemp -d "${TMPDIR:-/tmp}/external-package.XXXXXX")" || exit 1
    trap 'clash_party_without_nix_env rm -rf "$temporary_dir"' EXIT
    release_file="$temporary_dir/release.json"
    clash_party_without_nix_env curl --fail --location --show-error --output "$release_file" 'https://api.github.com/repos/mihomo-party-org/clash-party/releases/latest' || exit 1
    clash_party_without_nix_env sh -c 'command -v jq >/dev/null' || { external_package_error 'jq is required to parse the Clash Party release'; exit 1; }
    tag_name="$(clash_party_without_nix_env jq -er 'select(.draft == false and .prerelease == false) | .tag_name | select(type == "string" and length > 0)' "$release_file")" || exit 1
    version="${tag_name#v}"
    [[ -n "$version" ]] || { external_package_error 'Clash Party release has an invalid tag'; exit 1; }
    deb_name="clash-party-linux-${version}-${architecture}.deb"
    checksum_name="${deb_name}.sha256"
    deb_url="$(clash_party_without_nix_env jq -er --arg name "$deb_name" '[.assets[] | select(.name == $name and .state == "uploaded") | .browser_download_url] | select(length == 1) | .[0] | select(type == "string" and length > 0)' "$release_file")" || exit 1
    checksum_url="$(clash_party_without_nix_env jq -er --arg name "$checksum_name" '[.assets[] | select(.name == $name and .state == "uploaded") | .browser_download_url] | select(length == 1) | .[0] | select(type == "string" and length > 0)' "$release_file")" || exit 1
    clash_party_without_nix_env curl --fail --location --show-error --output "$temporary_dir/$deb_name" "$deb_url" || exit 1
    clash_party_without_nix_env curl --fail --location --show-error --output "$temporary_dir/$checksum_name" "$checksum_url" || exit 1
    expected="$(< "$temporary_dir/$checksum_name")"
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || { external_package_error "invalid Clash Party checksum for $deb_name"; exit 1; }
    local actual
    actual="$(clash_party_without_nix_env sha256sum "$temporary_dir/$deb_name")" || exit 1
    actual="${actual%% *}"
    [[ "$expected" == "$actual" ]] || { external_package_error "SHA256 mismatch for $deb_name"; exit 1; }
    cd "$temporary_dir"
    clash_party_without_nix_env sudo apt install -y "./$deb_name"
)

# Public interface: install_external_package <target> <name>
install_external_package() {
    [[ $# -eq 2 ]] || { external_package_error 'usage: install_external_package <target> <name>'; return 2; }
    case "$1:$2" in
    deepin:clash-party) external_package_install_clash_party_deepin ;;
    *) external_package_error "unsupported package '$2' for target '$1'"; return 1 ;;
    esac
}
