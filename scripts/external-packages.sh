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

external_package_cliproxyapi_secret() {
    local secret

    if [[ "${OS:-}" == "Windows_NT" ]]; then
        secret="$(powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; $bytes=New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes); [Console]::Write(([BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant())')" || return 1
    elif command -v openssl >/dev/null 2>&1; then
        secret="$(openssl rand -hex 32)" || return 1
    elif [[ -r /dev/urandom ]] && command -v od >/dev/null 2>&1; then
        secret="$(od -An -N 32 -tx1 /dev/urandom | tr -d ' \n')" || return 1
    else
        return 1
    fi
    [[ "$secret" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    printf '%s' "$secret"
}

external_package_cliproxyapi_config_valid_unix() {
    [[ -f "$1" && ! -L "$1" && -r "$1" && -s "$1" ]]
}

external_package_cliproxyapi_config_valid_windows() {
    local path="$1" win_path
    win_path="$(cygpath -aw "$path")" || return 1
    powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; $item=Get-Item -LiteralPath $args[0] -Force; if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -le 0){throw "not a readable regular nonempty file"}; $stream=[IO.File]::Open($args[0],[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite); $stream.Close()' "$win_path"
}

external_package_cliproxyapi_schema_valid() {
    local config_file="$1"

    grep -q '^host:[[:space:]]*"\?127\.0\.0\.1"\?[[:space:]]*$' "$config_file" &&
        grep -q '^port:[[:space:]]*8317[[:space:]]*$' "$config_file" &&
        grep -q '^remote-management:[[:space:]]*$' "$config_file" &&
        grep -q '^  allow-remote:[[:space:]]*false[[:space:]]*$' "$config_file" &&
        grep -q '^  secret-key:[[:space:]]*"\?[[:xdigit:]]\{64\}"\?[[:space:]]*$' "$config_file" &&
        grep -q '^auth-dir:[[:space:]]*' "$config_file" &&
        grep -q '^api-keys:[[:space:]]*$' "$config_file" &&
        grep -q '^  - "\?[[:xdigit:]]\{64\}"\?[[:space:]]*$' "$config_file"
}

external_package_cliproxyapi_migrated_schema_valid() {
    local config_file="$1"

    grep -q '^host:' "$config_file" && grep -q '^api-keys:' "$config_file" && grep -q '^remote-management:' "$config_file"
}

external_package_cliproxyapi_existing_permissions_safe() {
    local config_file="$1" mode

    mode="$(stat -c '%a' "$config_file" 2>/dev/null || stat -f '%Lp' "$config_file" 2>/dev/null)" || return 1
    [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
    [[ "$mode" == 600 ]]
}

external_package_install_cliproxyapi() (
    set -e
    local target="$1" version='7.2.145' system machine asset checksum extension executable install_parent version_dir binary
    local config_dir='' config_file='' config_auth_dir='' config_auth_dir_yaml='' local_app_data='' temporary_dir='' config_temporary='' archive='' extract_dir='' found_binary='' staging_dir='' legacy_config='' api_key='' management_key='' config_origin='' config_dir_created=''

    cleanup_cliproxyapi_staging() {
        [[ -n "${temporary_dir:-}" ]] && rm -rf "${temporary_dir:-}"
        [[ -n "${config_temporary:-}" ]] && rm -f "${config_temporary:-}"
        [[ -n "${staging_dir:-}" ]] && rm -rf "${staging_dir:-}"
    }
    trap cleanup_cliproxyapi_staging EXIT

    if [[ "$target" == 'termux' ]]; then
        external_package_error 'CLIProxyAPI is unsupported on native Termux: its official binary requires glibc, not Android bionic. Use CLIProxyAPI in a proot Linux distribution instead.'
        exit 1
    fi
    system="$(uname -s 2>/dev/null)" || { external_package_error 'cannot determine operating system'; exit 1; }
    machine="$(uname -m 2>/dev/null)" || { external_package_error 'cannot determine architecture'; exit 1; }
    case "$target" in
    deepin|arch)
        [[ "$system" == Linux ]] || { external_package_error "target $target requires Linux"; exit 1; }
        extension='tar.gz'; executable='cli-proxy-api'; install_parent="$HOME/.local/opt/cliproxyapi"
        case "$machine" in
        x86_64|amd64) asset='linux_amd64'; checksum='ffb59d406af9b849ec9174154d96642a1d3ccb315f8687c56ac55202816e9b37' ;;
        aarch64|arm64) asset='linux_aarch64'; checksum='c03974b0e10f93f8104c4be6a061135c07924396fc310215802b0a22aa33ee54' ;;
        *) external_package_error "unsupported CLIProxyAPI Linux architecture: $machine"; exit 1 ;;
        esac
        config_dir="$HOME/.config/cli-proxy-api"
        ;;
    macos)
        [[ "$system" == Darwin ]] || { external_package_error 'target macos requires Darwin'; exit 1; }
        extension='tar.gz'; executable='cli-proxy-api'; install_parent="$HOME/.local/opt/cliproxyapi"
        case "$machine" in
        x86_64|amd64) asset='darwin_amd64'; checksum='2f6b37e92f1a9ec2d4ba98c491aaf941f9796b2a9937fa1b68b6cc0a65853962' ;;
        aarch64|arm64) asset='darwin_aarch64'; checksum='c711728ab6f340c69ea322544970fc2b137816adba501438d57670365c8e513d' ;;
        *) external_package_error "unsupported CLIProxyAPI macOS architecture: $machine"; exit 1 ;;
        esac
        config_dir="$HOME/.config/cli-proxy-api"
        ;;
    windows)
        [[ "${OS:-}" == Windows_NT && "${MSYSTEM:-}" == MSYS ]] || { external_package_error 'target windows requires OS=Windows_NT and an MSYS shell (MSYSTEM=MSYS)'; exit 1; }
        command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1 || { external_package_error 'powershell.exe and cygpath are required for Windows'; exit 1; }
        extension='zip'; executable='cli-proxy-api.exe'
        local_app_data="$(powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; [Console]::Write([Environment]::GetFolderPath("LocalApplicationData"))')" || exit 1
        [[ -n "$local_app_data" && "$local_app_data" != *$'\r'* && "$local_app_data" != *$'\n'* ]] || { external_package_error 'invalid LocalApplicationData path'; exit 1; }
        # LocalApplicationData is used as the per-user config root on Windows.
        config_dir="$(cygpath -u "$local_app_data")/cli-proxy-api"
        install_parent="$(cygpath -u "$local_app_data")/cli-proxy-api"
        case "$machine" in
        x86_64|amd64) asset='windows_amd64'; checksum='fc03a63675d75be8bdb3f11599a8026c7e7e593589c53e0f38647803f70791d6' ;;
        aarch64|arm64) asset='windows_aarch64'; checksum='b4dc618ee05e287216afd9afeadb7928605cdbf8bf73d288427bd2a543676865' ;;
        *) external_package_error "unsupported CLIProxyAPI Windows architecture: $machine"; exit 1 ;;
        esac
        ;;
    *) external_package_error "unsupported CLIProxyAPI target: $target"; exit 1 ;;
    esac

    version_dir="$install_parent/$version-$asset"
    binary="$version_dir/$executable"
    config_file="$config_dir/config.yaml"
    if [[ "$target" == windows ]]; then
        config_auth_dir="$(cygpath -aw "$config_dir/auth")" || exit 1
    else
        config_auth_dir="$config_dir/auth"
    fi
    config_auth_dir_yaml="${config_auth_dir//\\/\\\\}"
    config_auth_dir_yaml="${config_auth_dir_yaml//\"/\\\"}"
    if [[ -e "$version_dir" || -L "$version_dir" ]]; then
        if [[ "$target" == windows ]]; then
            external_package_cliproxyapi_config_valid_windows "$binary" || { external_package_error "existing CLIProxyAPI version directory is incomplete: $version_dir"; exit 1; }
        elif [[ ! -d "$version_dir" || -L "$version_dir" || ! -f "$binary" || -L "$binary" || ! -x "$binary" ]]; then
            external_package_error "existing CLIProxyAPI version directory is incomplete: $version_dir"
            exit 1
        fi
    else
        mkdir -p "$install_parent" || exit 1
        temporary_dir="$(external_package_temp_dir)" || exit 1
        archive="$temporary_dir/CLIProxyAPI_${version}_${asset}.${extension}"
        external_package_download "$archive" "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_${asset}.${extension}" || exit 1
        external_package_verify_sha256 "$archive" "$checksum" "$asset" || exit 1
        extract_dir="$temporary_dir/extract"
        mkdir "$extract_dir" || exit 1
        if [[ "$extension" == 'tar.gz' ]]; then tar -xzf "$archive" -C "$extract_dir"; else powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; Expand-Archive -LiteralPath $args[0] -DestinationPath $args[1]' "$(cygpath -aw "$archive")" "$(cygpath -aw "$extract_dir")"; fi || exit 1
        for found_binary in "$extract_dir/$executable" "$extract_dir"/*/"$executable" "$extract_dir"/*/*/"$executable"; do
            [[ -f "$found_binary" && ! -L "$found_binary" ]] && break
            found_binary=''
        done
        [[ -n "$found_binary" ]] || { external_package_error "CLIProxyAPI archive does not contain a regular $executable"; exit 1; }
        staging_dir="$(mktemp -d "$install_parent/.${version}-${asset}.XXXXXX")" || exit 1
        cp "$found_binary" "$staging_dir/$executable" || exit 1
        [[ "$target" == windows ]] || chmod 755 "$staging_dir/$executable"
        mv "$staging_dir" "$version_dir" || exit 1
        staging_dir=''
    fi

    if [[ -e "$config_file" || -L "$config_file" ]]; then
        if [[ "$target" == windows ]]; then external_package_cliproxyapi_config_valid_windows "$config_file"; else external_package_cliproxyapi_config_valid_unix "$config_file"; fi || { external_package_error "existing config is not a regular, readable, nonempty file: $config_file"; exit 1; }
        if [[ "$target" != windows ]] && ! external_package_cliproxyapi_existing_permissions_safe "$config_file"; then
            external_package_error "existing CLIProxyAPI config is group/world readable; repair with: chmod 600 $config_file"
            exit 1
        fi
        config_origin='existing'
    else
        if [[ "$target" == windows ]]; then
            powershell.exe -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; New-Item -ItemType Directory -Force -LiteralPath $args[0] | Out-Null' "$(cygpath -aw "$config_dir")" || exit 1
        elif [[ ! -d "$config_dir" ]]; then
            (umask 077 && mkdir -p "$config_dir") || exit 1
            chmod 700 "$config_dir" || exit 1
            config_dir_created='yes'
        fi
        legacy_config="$HOME/cliproxyapi/config.yaml"
        if [[ -f "$legacy_config" && ! -L "$legacy_config" ]]; then
            config_temporary="$(mktemp "$config_dir/.config.yaml.XXXXXX")" || exit 1
            cp "$legacy_config" "$config_temporary" || exit 1
            if [[ "$target" == windows ]]; then external_package_cliproxyapi_config_valid_windows "$config_temporary"; else external_package_cliproxyapi_config_valid_unix "$config_temporary"; fi || { external_package_error "migrated config is not a regular, readable, nonempty file: $legacy_config"; exit 1; }
            external_package_cliproxyapi_migrated_schema_valid "$config_temporary" || { external_package_error "migrated CLIProxyAPI config uses an incompatible schema; repair $legacy_config to include host, api-keys:, and remote-management: before retrying"; exit 1; }
            config_origin='migrated'
        else
            api_key="$(external_package_cliproxyapi_secret)" || { external_package_error 'could not generate CLIProxyAPI API key'; exit 1; }
            management_key="$(external_package_cliproxyapi_secret)" || { external_package_error 'could not generate CLIProxyAPI management key'; exit 1; }
            config_temporary="$(mktemp "$config_dir/.config.yaml.XXXXXX")" || exit 1
            umask 077
            printf 'host: "127.0.0.1"\nport: 8317\nremote-management:\n  allow-remote: false\n  secret-key: "%s"\nauth-dir: "%s"\napi-keys:\n  - "%s"\n' "$management_key" "$config_auth_dir_yaml" "$api_key" > "$config_temporary" || exit 1
            external_package_cliproxyapi_schema_valid "$config_temporary" || { external_package_error 'generated CLIProxyAPI config failed schema checks'; exit 1; }
            config_origin='generated'
        fi
        [[ "$target" == windows ]] || chmod 600 "$config_temporary"
        mv "$config_temporary" "$config_file" || exit 1
        config_temporary=''
    fi
    if [[ "$target" == windows ]]; then external_package_cliproxyapi_config_valid_windows "$config_file"; else external_package_cliproxyapi_config_valid_unix "$config_file"; fi || { external_package_error "CLIProxyAPI config is invalid: $config_file"; exit 1; }
    if [[ "$config_origin" == migrated ]] && ! external_package_cliproxyapi_migrated_schema_valid "$config_file"; then
        external_package_error "migrated CLIProxyAPI config uses an incompatible schema; repair $config_file to include host, api-keys:, and remote-management: before retrying"
        exit 1
    fi
    if [[ "$config_origin" == generated ]] && ! external_package_cliproxyapi_schema_valid "$config_file"; then
        external_package_error "generated CLIProxyAPI config failed schema checks; repair $config_file before retrying"
        exit 1
    fi
    declare -F install_user_autostart >/dev/null 2>&1 || { external_package_error 'install_user_autostart is unavailable; source autostart.sh first'; exit 1; }
    install_user_autostart 'cliproxyapi' "$config_dir" "$binary" '-config' "$config_file"
)

# Public interface: install_external_package <target> <name>
install_external_package() {
    [[ $# -eq 2 ]] || { external_package_error 'usage: install_external_package <target> <name>'; return 2; }
    case "$1:$2" in
    deepin:clash-party) external_package_install_clash_party_deepin ;;
    deepin:cliproxyapi|arch:cliproxyapi|macos:cliproxyapi|windows:cliproxyapi|termux:cliproxyapi) external_package_install_cliproxyapi "$1" ;;
    *) external_package_error "unsupported package '$2' for target '$1'"; return 1 ;;
    esac
}
