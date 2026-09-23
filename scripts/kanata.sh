#!/usr/bin/env bash

# Independent Kanata installer. Home Manager deliberately does not
# own any of these packages, configuration files, or services.

if [[ -z "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

KANATA_SYSTEM_BINARY=/usr/local/bin/kanata
KANATA_MACOS_VHID_LABEL=org.pqrs.Karabiner-VirtualHIDDevice-Daemon
KANATA_MACOS_VHID_BINARY='/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon'
KANATA_MACOS_VHID_PLIST="/Library/LaunchDaemons/$KANATA_MACOS_VHID_LABEL.plist"
KANATA_MACOS_VHID_SOCKET_DIR='/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server'

kanata_run_without_nix() {
    if declare -F without_nix_env >/dev/null 2>&1; then
        without_nix_env "$@"
    else
        "$@"
    fi
}

kanata_target() {
    local os_name
    os_name="$(uname -s)"
    case "$os_name" in
    Darwin) printf '%s\n' macos ;;
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' windows ;;
    Linux)
        case "${DISTRIB_ID:-}" in
        Deepin|deepin) printf '%s\n' other ;;
        Arch|arch|EndeavourOS) printf '%s\n' arch ;;
        *) printf '%s\n' other ;;
        esac
        ;;
    *)
        printf 'error: unsupported operating system: %s\n' "$os_name" >&2
        return 1
        ;;
    esac
}

kanata_install_arch_packages() {
    local -a packages=(kanata)
    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm "${packages[@]}"
    else
        sudo pacman -S --needed --noconfirm "${packages[@]}"
    fi
}

kanata_build_source() {
    local destination_dir="$1" source="$1/source" candidate tool
    [[ "$destination_dir" = /* && -d "$destination_dir" && "$(uname -m)" == x86_64 ]] || return 1
    [[ ! -e "$source" && ! -L "$source" ]] || return 1
    for tool in git cargo rustc file readelf getconf; do command -v "$tool" >/dev/null || return 1; done
    [[ -x /usr/bin/clang && -x /usr/bin/clang++ && -x /usr/bin/pkg-config ]] || return 1
    /usr/bin/pkg-config --modversion libudev >/dev/null || return 1
    git clone --branch v1.12.0 --depth 1 https://github.com/jtroo/kanata.git "$source" || return 1
    [[ "$(git -C "$source" describe --exact-match --tags)" == v1.12.0 ]] || return 1
    CC=/usr/bin/clang CXX=/usr/bin/clang++ PKG_CONFIG=/usr/bin/pkg-config CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=/usr/bin/clang \
        cargo build --locked --release --manifest-path "$source/Cargo.toml" || return 1
    candidate="$source/target/release/kanata"
    [[ -f "$candidate" && ! -L "$candidate" && -x "$candidate" ]] || return 1
    printf '%s\n' "$candidate"
}

kanata_verify_glibc_compatibility() {
    local binary="$1" host maximum readelf_output glibc_refs file_description
    local -a versions=()
    host="$(getconf GNU_LIBC_VERSION)" || return 1
    host="${host##* }"
    [[ "$host" =~ ^[0-9]+\.[0-9]+$ ]] || return 1
    readelf_output="$(readelf --version-info "$binary" 2>/dev/null)" || {
        file_description="$(file -b "$binary")" || return 1
        [[ "$file_description" == *'statically linked'* ]] || return 1
        return 0
    }
    if ! glibc_refs="$(printf '%s\n' "$readelf_output" | grep -oE 'GLIBC_[0-9]+\.[0-9]+')"; then
        file_description="$(file -b "$binary")" || return 1
        [[ "$file_description" == *'statically linked'* ]] || return 1
        return 0
    fi
    mapfile -t versions < <(printf '%s\n' "$glibc_refs" | cut -d_ -f2 | sort -Vu) || return 1
    ((${#versions[@]})) || return 1
    maximum="${versions[${#versions[@]} - 1]}"
    mapfile -t versions < <(printf '%s\n%s\n' "$maximum" "$host" | sort -V)
    [[ "${versions[1]}" == "$host" ]]
}

kanata_validate_candidate() {
    local candidate="$1" config="$2"
    [[ -f "$candidate" && ! -L "$candidate" && -x "$candidate" ]] || return 1
    file -b "$candidate" | grep -Eq 'ELF.*(x86-64|x86_64)' || return 1
    "$candidate" --version >/dev/null || return 1
    kanata_verify_glibc_compatibility "$candidate" || return 1
    "$candidate" --check --cfg "$config"
}

kanata_release_architecture() {
    local architecture
    architecture="$(uname -m)" || return 1
    case "$architecture" in
    x86_64) printf '%s\n' x64 ;;
    aarch64) printf '%s\n' 'error: upstream Kanata latest release has no Linux arm64 asset' >&2; return 1 ;;
    *) printf 'error: unsupported Kanata release architecture: %s\n' "$architecture" >&2; return 1 ;;
    esac
}

kanata_select_release_assets() {
    local release_json="$1"
    jq -er '
        [.assets[]? | select(.state == "uploaded" and .name == "linux-binaries-x64.zip" and (.browser_download_url | type == "string"))] as $archives |
        [.assets[]? | select(.state == "uploaded" and .name == "sha256sums" and (.browser_download_url | type == "string"))] as $checksums |
        select($archives | length == 1) | select($checksums | length == 1) |
        [$archives[0].name, $archives[0].browser_download_url, $checksums[0].name, $checksums[0].browser_download_url][]
    ' "$release_json"
}

kanata_checksum_for_asset() {
    local archive="$1" manifest="$2" filename="$3" expected
    expected="$(awk -v filename="$filename" '
        /^[[:space:]]*$/ { next }
        {
            hash = $1; name = $2; check = hash
            if (NF != 2 || length(hash) != 64 || gsub(/[[:xdigit:]]/, "", check) != 64) exit 1
            if (tolower($0) == tolower(hash) "  " filename) {
                count++
                value = tolower(hash)
            }
        }
        END { if (count != 1) exit 1; print value }
    ' "$manifest")" || {
        printf 'error: invalid or ambiguous Kanata checksum for %s\n' "$filename" >&2
        return 1
    }
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    printf '%s\n' "$expected"
}

kanata_download_release() {
    local architecture="$1" destination_dir="$2" release_json archive checksum_manifest candidate expected
    local -a asset=()
    [[ "$destination_dir" = /* && -d "$destination_dir" ]] || return 1
    declare -F external_package_download >/dev/null && declare -F external_package_verify_sha256 >/dev/null || {
        printf '%s\n' 'error: external package helpers are unavailable' >&2
        return 1
    }
    release_json="$destination_dir/release.json"
    external_package_download "$release_json" 'https://api.github.com/repos/jtroo/kanata/releases/latest' || return 1
    jq -e 'select(.draft == false and .prerelease == false) | .tag_name | select(type == "string" and length > 0)' "$release_json" >/dev/null || return 1
    jq -e '.assets | select(type == "array" and length > 0)' "$release_json" >/dev/null || return 1
    [[ "$architecture" == x64 ]] || return 1
    mapfile -t asset < <(kanata_select_release_assets "$release_json")
    [[ ${#asset[@]} -eq 4 && "${asset[0]}" == linux-binaries-x64.zip && "${asset[2]}" == sha256sums ]] || return 1
    [[ "${asset[0]}" != */* && "${asset[2]}" != */* && -n "${asset[1]}" && -n "${asset[3]}" ]] || return 1
    checksum_manifest="$destination_dir/${asset[2]}"
    archive="$destination_dir/${asset[0]}"
    external_package_download "$archive" "${asset[1]}" || return 1
    external_package_download "$checksum_manifest" "${asset[3]}" || return 1
    expected="$(kanata_checksum_for_asset "$archive" "$checksum_manifest" "${asset[0]}")" || return 1
    external_package_verify_sha256 "$archive" "$expected" "${asset[0]}" || return 1
    mapfile -t asset < <(unzip -Z1 "$archive" | grep -Fx 'kanata_linux_x64')
    [[ ${#asset[@]} -eq 1 ]] || return 1
    candidate="$destination_dir/kanata_linux_x64"
    [[ ! -e "$candidate" && ! -L "$candidate" ]] || return 1
    unzip -p "$archive" kanata_linux_x64 >"$candidate" || return 1
    chmod 0755 "$candidate" || return 1
    [[ -f "$candidate" && ! -L "$candidate" ]] || return 1
    file -b "$candidate" | grep -Eq 'ELF.*(x86-64|x86_64)' || return 1
    "$candidate" --version >/dev/null || return 1
    printf '%s\n' "$candidate"
}

kanata_find_executable() {
    local name="$1"
    local nix_profile="${2:-$HOME/.nix-profile}"
    local candidate
    for candidate in "$nix_profile/bin/$name" "/usr/local/bin/$name" "/usr/bin/$name"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    command -v "$name" 2>/dev/null || {
        printf 'error: executable not found after installation: %s\n' "$name" >&2
        return 1
    }
}

kanata_render_unit() {
    local source="$1"
    local destination="$2"
    local kanata_exec="${3:-}"
    local kanata_config="${4:-}"
    local kanata_user="${5:-}"
    local kanata_controller_exec="${6:-}"
    local kanata_controller_log_dir="${7:-}"
    local temporary_destination
    local line
    temporary_destination="$(mktemp "$(dirname -- "$destination")/.kanata-unit.XXXXXX")" || return 1
    if ! {
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//__KANATA_EXECUTABLE__/$kanata_exec}"
        line="${line//__KANATA_CONFIG__/$kanata_config}"
        line="${line//__KANATA_USER__/$kanata_user}"
        line="${line//__KANATA_CONTROLLER_EXECUTABLE__/$kanata_controller_exec}"
        line="${line//__KANATA_CONTROLLER_LOG_DIR__/$kanata_controller_log_dir}"
        printf '%s\n' "$line"
    done < "$source" > "$temporary_destination"
    chmod 0644 "$temporary_destination"
    mv -f "$temporary_destination" "$destination"
    }; then
        rm -f "$temporary_destination"
        return 1
    fi
}

kanata_build_controller() {
    local manifest="$DOTFILES_DIR/tools/kanata-controller/Cargo.toml"
    KANATA_CONTROLLER_BUILD="$DOTFILES_DIR/tools/kanata-controller/target/release/kanata-controller"
    if [[ "$(uname -s)" == Darwin ]]; then
        local libiconv_prefix
        libiconv_prefix="$(kanata_macos_run brew --prefix libiconv)" || {
            printf '%s\n' 'error: Homebrew libiconv is required to link the macOS kanata-controller' >&2
            return 1
        }
        RUSTFLAGS="-C link-arg=-L$libiconv_prefix/lib${RUSTFLAGS:+ $RUSTFLAGS}" \
            cargo build --manifest-path "$manifest" --release || {
            printf '%s\n' 'error: cargo failed to build the host kanata-controller release binary' >&2
            return 1
        }
    elif ! cargo build --manifest-path "$manifest" --release; then
        printf '%s\n' 'error: cargo failed to build the host kanata-controller release binary' >&2
        return 1
    fi
    [[ -x "$KANATA_CONTROLLER_BUILD" ]] || {
        printf 'error: controller release binary is not executable: %s\n' "$KANATA_CONTROLLER_BUILD" >&2
        return 1
    }
}

kanata_install_controller_binary() {
    local source="$1" destination="$HOME/.local/bin/kanata-controller" temporary
    mkdir -p "$(dirname -- "$destination")" || return 1
    temporary="$(mktemp "$(dirname -- "$destination")/.kanata-controller.XXXXXX")" || return 1
    if ! install -m 0755 "$source" "$temporary" || ! mv -f "$temporary" "$destination"; then
        rm -f "$temporary"
        return 1
    fi
}

kanata_safe_user() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]
}

kanata_system_executable() {
    local target="$1"
    local executable
    case "$target" in
    other)
        [[ -n "${KANATA_BUILD_DIR:-}" && -d "$KANATA_BUILD_DIR" ]] || return 1
        executable="$(kanata_build_source "$KANATA_BUILD_DIR")" || return 1
        ;;
    arch)
        kanata_install_arch_packages
        executable=/usr/bin/kanata
        [[ "$(stat -c %U "$executable")" == root && ! -w "$executable" ]] || {
            printf '%s\n' 'error: Arch Kanata executable must be root-owned and non-user-writable' >&2
            return 1
        }
        ;;
    *) printf 'error: unsupported Linux Kanata target: %s\n' "$target" >&2; return 1 ;;
    esac
    [[ "$executable" = /* && -x "$executable" ]] || {
        printf '%s\n' 'error: Kanata system executable is not an absolute executable path' >&2
        return 1
    }
    printf '%s\n' "$executable"
}

kanata_reject_unresolved_placeholders() {
    ! grep -Eq '__[A-Z_]+__' "$@"
}

kanata_prepare_system_files() {
    local kanata_exec="$1" kanata_user="$2" controller_exec="$3"
    KANATA_TXN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-kanata.XXXXXX")" || return 1
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/linux/kanata.service" "$KANATA_TXN_DIR/kanata.service" "$kanata_exec" /etc/kanata/kanata.kbd "$kanata_user" || return 1
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/polkit/50-kanata-controller.rules" "$KANATA_TXN_DIR/50-kanata-controller.rules" "$kanata_exec" /etc/kanata/kanata.kbd "$kanata_user" || return 1
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/linux/kanata-controller.service" "$KANATA_TXN_DIR/kanata-controller.service" '' '' '' "$controller_exec" || return 1
    cp "$DOTFILES_DIR/conf/kanata/kanata-linux.kbd" "$KANATA_TXN_DIR/kanata.kbd" || return 1
    cp "$DOTFILES_DIR/conf/kanata/kanata-common.kbd" "$KANATA_TXN_DIR/kanata-common.kbd" || return 1
    kanata_reject_unresolved_placeholders "$KANATA_TXN_DIR/kanata.service" "$KANATA_TXN_DIR/50-kanata-controller.rules" "$KANATA_TXN_DIR/kanata-controller.service" || { printf '%s\n' 'error: unresolved template placeholder' >&2; return 1; }
}

kanata_verify_prepared_system_files() {
    local kanata_exec="$1" candidate="${2:-}"
    if [[ -n "$candidate" ]]; then
        kanata_validate_candidate "$candidate" "$KANATA_TXN_DIR/kanata.kbd" || return 1
    else
        "$kanata_exec" --check --cfg "$KANATA_TXN_DIR/kanata.kbd" || return 1
    fi
    if ! systemd-analyze verify "$KANATA_TXN_DIR/kanata.service"; then
        return 1
    fi
    if ! systemd-analyze --user verify "$KANATA_TXN_DIR/kanata-controller.service"; then
        return 1
    fi
}

kanata_snapshot_root_file() {
    local destination="$1" name="$2"
    if sudo test -e "$destination" || sudo test -L "$destination"; then
        printf -v "KANATA_ROOT_PRESENT_$name" '%s' 1
        sudo stat -c '%a:%u:%g' "$destination" >"$KANATA_TXN_DIR/$name.meta" || return 1
        sudo cp -a "$destination" "$KANATA_TXN_DIR/$name.old" || return 1
    else
        printf -v "KANATA_ROOT_PRESENT_$name" '%s' 0
    fi
}

kanata_install_root_file() {
    local source="$1" destination="$2" temporary
    temporary="$(dirname -- "$destination")/.${destination##*/}.kanata-new.$$"
    sudo install -o root -g root -m 0644 "$source" "$temporary" && sudo mv -f "$temporary" "$destination"
}

kanata_install_release_binary() {
    local candidate="$1" temporary parent_meta parent_owner parent_mode
    sudo test -d /usr/local/bin && sudo test ! -L /usr/local/bin || return 1
    parent_meta="$(sudo stat -c '%U:%a' /usr/local/bin)" || return 1
    IFS=: read -r parent_owner parent_mode <<<"$parent_meta"
    [[ "$parent_owner" == root && "$parent_mode" =~ ^[0-7]{3,4}$ && $((8#$parent_mode & 022)) -eq 0 ]] || return 1
    temporary="$(dirname -- "$KANATA_SYSTEM_BINARY")/.${KANATA_SYSTEM_BINARY##*/}.kanata-new.$$"
    if ! sudo install -o root -g root -m 0755 "$candidate" "$temporary" || ! sudo mv -T -f "$temporary" "$KANATA_SYSTEM_BINARY"; then
        sudo rm -f "$temporary"
        return 1
    fi
    sudo test -f "$KANATA_SYSTEM_BINARY" && sudo test ! -L "$KANATA_SYSTEM_BINARY" && [[ "$(sudo stat -c '%U:%G:%a' "$KANATA_SYSTEM_BINARY")" == root:root:755 ]]
}

kanata_restore_root_file() {
    local destination="$1" name="$2" present meta mode owner group temporary
    eval "present=\${KANATA_ROOT_PRESENT_$name:-0}"
    if (( ! present )); then sudo rm -f "$destination"; return; fi
    meta="$(<"$KANATA_TXN_DIR/$name.meta")" || return 1
    IFS=: read -r mode owner group <<<"$meta"
    temporary="$(dirname -- "$destination")/.${destination##*/}.kanata-restore.$$"
    if ! sudo cp -a "$KANATA_TXN_DIR/$name.old" "$temporary" || ! sudo mv -T -f "$temporary" "$destination"; then
        sudo rm -f "$temporary"
        return 1
    fi
}

kanata_query_service() {
    # Arguments: optional --user, unit, result-prefix.  show first makes an
    # unavailable manager a hard error rather than silently treating it inactive.
    local scope="$1" unit="$2" prefix="$3" load active enabled rc output
    if [[ "$scope" == user ]]; then
        load="$(systemctl --user show "$unit" -p LoadState --value)" || return 1
        if systemctl --user is-active --quiet "$unit"; then
            rc=0
        else
            rc=$?
        fi
        case "$rc:$load" in
        0:*) active=1 ;;
        3:*) active=0 ;;
        4:not-found) active=0 ;;
        *) return 1 ;;
        esac
        if output="$(systemctl --user is-enabled "$unit" 2>&1)"; then
            rc=0
        else
            rc=$?
        fi
    else
        load="$(sudo systemctl show "$unit" -p LoadState --value)" || return 1
        if sudo systemctl is-active --quiet "$unit"; then
            rc=0
        else
            rc=$?
        fi
        case "$rc:$load" in
        0:*) active=1 ;;
        3:*) active=0 ;;
        4:not-found) active=0 ;;
        *) return 1 ;;
        esac
        if output="$(sudo systemctl is-enabled "$unit" 2>&1)"; then
            rc=0
        else
            rc=$?
        fi
    fi
    case "$output" in enabled|enabled-runtime|linked|linked-runtime|alias) enabled=1 ;; disabled|static|indirect|generated|transient|masked|not-found) enabled=0 ;; *) return 1 ;; esac
    printf -v "${prefix}_LOAD" '%s' "$load"
    printf -v "${prefix}_ACTIVE" '%s' "$active"
    printf -v "${prefix}_ENABLED" '%s' "$enabled"
}

kanata_snapshot_user_file() {
    local path="$1" name="$2"
    if [[ -e "$path" ]]; then cp -a "$path" "$KANATA_TXN_DIR/$name.old" && printf 1 >"$KANATA_TXN_DIR/$name.present"; else printf 0 >"$KANATA_TXN_DIR/$name.present"; fi
}

kanata_restore_user_file() {
    local path="$1" name="$2" temporary
    if [[ "$(<"$KANATA_TXN_DIR/$name.present")" == 1 ]]; then
        mkdir -p "$(dirname -- "$path")" || return 1
        temporary="$(mktemp "$(dirname -- "$path")/.${path##*/}.kanata-restore.XXXXXX")" || return 1
        if ! cp -a "$KANATA_TXN_DIR/$name.old" "$temporary" || ! mv -f "$temporary" "$path"; then
            rm -f "$temporary"
            return 1
        fi
    else
        rm -f "$path"
    fi
}

kanata_snapshot_user_unit() {
    kanata_snapshot_user_file "$HOME/.config/systemd/user/$1" "$1"
}

kanata_restore_user_unit() {
    kanata_restore_user_file "$HOME/.config/systemd/user/$1" "$1"
}

kanata_restore_service_state() {
    local scope="$1" unit="$2" load="$3" active="$4" enabled="$5" command_prefix=()
    if [[ "$scope" == system ]]; then
        command_prefix=(sudo systemctl)
    else
        command_prefix=(systemctl --user)
    fi
    [[ "$load" != not-found ]] || { "${command_prefix[@]}" disable --now "$unit"; return; }
    if (( enabled )); then "${command_prefix[@]}" enable "$unit" || return 1; else "${command_prefix[@]}" disable "$unit" || return 1; fi
    if (( active )); then "${command_prefix[@]}" restart "$unit" || return 1; else "${command_prefix[@]}" stop "$unit" || return 1; fi
}

kanata_rollback() {
    local failed=0
    [[ "${KANATA_SYSTEM_LOAD:-not-found}" != not-found ]] || kanata_restore_service_state system kanata.service "${KANATA_SYSTEM_LOAD:-not-found}" "${KANATA_SYSTEM_ACTIVE:-0}" "${KANATA_SYSTEM_ENABLED:-0}" || failed=1
    [[ "${KANATA_USER_LOAD:-not-found}" != not-found ]] || kanata_restore_service_state user kanata.service "${KANATA_USER_LOAD:-not-found}" "${KANATA_USER_ACTIVE:-0}" "${KANATA_USER_ENABLED:-0}" || failed=1
    [[ "${KANATA_CONTROLLER_LOAD:-not-found}" != not-found ]] || kanata_restore_service_state user kanata-controller.service "${KANATA_CONTROLLER_LOAD:-not-found}" "${KANATA_CONTROLLER_ACTIVE:-0}" "${KANATA_CONTROLLER_ENABLED:-0}" || failed=1
    [[ "${KANATA_RELEASE_BINARY_MANAGED:-0}" != 1 ]] || kanata_restore_root_file "$KANATA_SYSTEM_BINARY" executable || failed=1
    kanata_restore_root_file /etc/kanata/kanata.kbd config || failed=1
    kanata_restore_root_file /etc/kanata/kanata-common.kbd common_config || failed=1
    kanata_restore_root_file /etc/systemd/system/kanata.service system_unit || failed=1
    kanata_restore_root_file /etc/polkit-1/rules.d/50-kanata-controller.rules polkit || failed=1
    sudo systemctl daemon-reload || failed=1
    kanata_restore_user_unit kanata.service || failed=1
    kanata_restore_user_unit kanata-controller.service || failed=1
    kanata_restore_user_file "$HOME/.local/bin/kanata-controller" controller_binary || failed=1
    systemctl --user daemon-reload || failed=1
    [[ "${KANATA_SYSTEM_LOAD:-not-found}" == not-found ]] || kanata_restore_service_state system kanata.service "$KANATA_SYSTEM_LOAD" "$KANATA_SYSTEM_ACTIVE" "$KANATA_SYSTEM_ENABLED" || failed=1
    [[ "${KANATA_USER_LOAD:-not-found}" == not-found ]] || kanata_restore_service_state user kanata.service "$KANATA_USER_LOAD" "$KANATA_USER_ACTIVE" "$KANATA_USER_ENABLED" || failed=1
    [[ "${KANATA_CONTROLLER_LOAD:-not-found}" == not-found ]] || kanata_restore_service_state user kanata-controller.service "$KANATA_CONTROLLER_LOAD" "$KANATA_CONTROLLER_ACTIVE" "$KANATA_CONTROLLER_ENABLED" || failed=1
    (( ! failed )) || { printf '%s\n' 'error: rollback failed: one or more files or service states could not be restored' >&2; return 1; }
}

kanata_transaction_exit() {
    local status="$1"
    if [[ "${KANATA_TXN_READY:-0}" == 1 && "${KANATA_TXN_COMMITTED:-0}" != 1 ]]; then kanata_rollback || status=1; fi
    [[ -z "${KANATA_TXN_DIR:-}" ]] || rm -rf -- "$KANATA_TXN_DIR"
    [[ -z "${KANATA_BUILD_DIR:-}" ]] || rm -rf -- "$KANATA_BUILD_DIR"
    [[ -z "${KANATA_RELEASE_DIR:-}" ]] || rm -rf -- "$KANATA_RELEASE_DIR"
    trap - EXIT HUP INT TERM
    exit "$status"
}

kanata_verify_system_kanata() {
    local expected="$1" pid actual pids count=0
    sudo systemctl is-active --quiet kanata.service || return 1
    pid="$(sudo systemctl show kanata.service -p MainPID --value)" || return 1
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    actual="$(readlink -f "/proc/$pid/exe")" || return 1
    [[ "$actual" == "$expected" ]] || return 1
    if command -v pgrep >/dev/null 2>&1; then
        pids="$(pgrep -x kanata)"; local rc=$?
        (( rc == 0 )) || return 1
        while IFS= read -r pid; do [[ "$(readlink -f "/proc/$pid/exe")" == "$expected" ]] || return 1; ((count++)); done <<<"$pids"
        (( count == 1 )) || return 1
    fi
}

kanata_cutover_system_service() {
    local kanata_exec="$1"
    (( KANATA_USER_ACTIVE )) && systemctl --user stop kanata.service || [[ "$KANATA_USER_ACTIVE" == 0 ]] || return 1
    if (( KANATA_SYSTEM_ACTIVE )); then sudo systemctl restart kanata.service; else sudo systemctl start kanata.service; fi || return 1
    kanata_verify_system_kanata "$kanata_exec" || return 1
    (( KANATA_USER_ENABLED )) && systemctl --user disable kanata.service || [[ "$KANATA_USER_ENABLED" == 0 ]] || return 1
    rm -f "$HOME/.config/systemd/user/kanata.service" || return 1
    mkdir -p "$HOME/.config/systemd/user" || return 1
    install -m 0644 "$KANATA_TXN_DIR/kanata-controller.service" "$HOME/.config/systemd/user/kanata-controller.service" || return 1
    systemctl --user daemon-reload || return 1
    systemctl --user enable kanata-controller.service || return 1
    systemctl --user restart kanata-controller.service || return 1
    sudo systemctl enable kanata.service
}

install_kanata_system() (
    local target="${1:-}" kanata_exec kanata_candidate='' kanata_user controller_exec="$HOME/.local/bin/kanata-controller"
    [[ "$(uname -s)" == Linux && "$(id -u)" -ne 0 ]] || { printf '%s\n' 'error: kanata system migration must run on Linux as the interactive user, not root' >&2; return 1; }
    target="${target:-$(kanata_target)}"
    [[ "$target" =~ ^(other|arch)$ ]] || { printf '%s\n' 'error: kanata system migration is Linux-only' >&2; return 1; }
    KANATA_TXN_DIR=''
    KANATA_BUILD_DIR=''
    KANATA_RELEASE_DIR=''
    KANATA_TXN_READY=0
    KANATA_TXN_COMMITTED=0
    trap 'kanata_transaction_exit $?' EXIT HUP INT TERM
    kanata_user="$(id -un)"; kanata_safe_user "$kanata_user" || { printf '%s\n' 'error: current username is unsafe for policy rendering' >&2; return 1; }
    if [[ "$target" == other ]]; then
        if declare -F external_package_temp_dir >/dev/null 2>&1; then
            KANATA_BUILD_DIR="$(external_package_temp_dir)"
        else
            KANATA_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-kanata-build.XXXXXX")"
        fi
        [[ -n "$KANATA_BUILD_DIR" && -d "$KANATA_BUILD_DIR" ]] || return 1
        kanata_candidate="$(kanata_system_executable "$target")" || return 1
        kanata_exec="$KANATA_SYSTEM_BINARY"
        KANATA_RELEASE_BINARY_MANAGED=1
    else
        kanata_exec="$(kanata_system_executable "$target")" || return 1
        KANATA_RELEASE_BINARY_MANAGED=0
    fi
    kanata_build_controller || return 1
    kanata_prepare_system_files "$kanata_exec" "$kanata_user" "$controller_exec" || return 1
    [[ "$target" != other ]] || kanata_validate_candidate "$kanata_candidate" "$KANATA_TXN_DIR/kanata.kbd" || return 1
    kanata_snapshot_root_file /etc/kanata/kanata.kbd config && kanata_snapshot_root_file /etc/kanata/kanata-common.kbd common_config && kanata_snapshot_root_file /etc/systemd/system/kanata.service system_unit && kanata_snapshot_root_file /etc/polkit-1/rules.d/50-kanata-controller.rules polkit && { [[ "$KANATA_RELEASE_BINARY_MANAGED" != 1 ]] || kanata_snapshot_root_file "$KANATA_SYSTEM_BINARY" executable; } && kanata_query_service system kanata.service KANATA_SYSTEM && kanata_query_service user kanata.service KANATA_USER && kanata_query_service user kanata-controller.service KANATA_CONTROLLER && kanata_snapshot_user_unit kanata.service && kanata_snapshot_user_unit kanata-controller.service && kanata_snapshot_user_file "$controller_exec" controller_binary || return 1
    KANATA_TXN_READY=1
    { [[ "$KANATA_RELEASE_BINARY_MANAGED" != 1 ]] || kanata_install_release_binary "$kanata_candidate"; } && kanata_install_controller_binary "$KANATA_CONTROLLER_BUILD" || return 1
    kanata_verify_prepared_system_files "$kanata_exec" || return 1
    sudo install -d -o root -g root -m 0755 /etc/kanata && kanata_install_root_file "$KANATA_TXN_DIR/kanata.kbd" /etc/kanata/kanata.kbd && kanata_install_root_file "$KANATA_TXN_DIR/kanata-common.kbd" /etc/kanata/kanata-common.kbd && kanata_install_root_file "$KANATA_TXN_DIR/kanata.service" /etc/systemd/system/kanata.service && kanata_install_root_file "$KANATA_TXN_DIR/50-kanata-controller.rules" /etc/polkit-1/rules.d/50-kanata-controller.rules && sudo systemctl daemon-reload && kanata_cutover_system_service "$kanata_exec" || return 1
    KANATA_TXN_COMMITTED=1
)

kanata_macos_run() {
    if [[ "${1:-}" == brew ]] && ! command -v brew >/dev/null 2>&1; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            set -- /opt/homebrew/bin/brew "${@:2}"
        elif [[ -x /usr/local/bin/brew ]]; then
            set -- /usr/local/bin/brew "${@:2}"
        fi
    fi
    kanata_run_without_nix "$@"
}

kanata_macos_resolved_directory() {
    # Resolve under sudo: /etc is Apple's root-owned /private/etc symlink,
    # while arbitrary symlink substitutions must not become trusted parents.
    kanata_macos_run sudo /bin/sh -c 'cd -P -- "$1" && /bin/pwd -P' sh "$1"
}

kanata_macos_validate_directory() {
    local directory="$1" resolved expected metadata owner group mode
    kanata_macos_run sudo /bin/test -d "$directory" || return 1
    resolved="$(kanata_macos_resolved_directory "$directory")" || return 1
    case "$directory:$resolved" in
    /etc:/private/etc) expected=/private/etc ;;
    /etc/*:/private/etc/*) expected="/private$directory" ;;
    *) expected="$directory" ;;
    esac
    [[ "$resolved" == "$expected" ]] || return 1
    # Stat the resolved object, not the spelling used to reach it.
    metadata="$(kanata_macos_run sudo /usr/bin/stat -f '%Su:%Sg:%Lp' "$resolved")" || return 1
    IFS=: read -r owner group mode <<<"$metadata"
    [[ "$owner" == root && "$group" == wheel && "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
    (( (8#$mode & 022) == 0 ))
}

kanata_macos_validate_directories() {
    local directory
    for directory in /usr/local /usr/local/libexec /etc /etc/kanata /etc/sudoers.d /Library /Library/LaunchDaemons; do
        kanata_macos_validate_directory "$directory" || {
            printf 'error: unsafe macOS privileged directory: %s\n' "$directory" >&2
            return 1
        }
    done
}

kanata_macos_ensure_directory() {
    local directory="$1"
    if kanata_macos_run sudo /bin/test -e "$directory" || kanata_macos_run sudo /bin/test -L "$directory"; then
        kanata_macos_validate_directory "$directory"
    else
        kanata_macos_run sudo install -d -o root -g wheel -m 0755 "$directory" || return 1
        kanata_macos_validate_directory "$directory"
    fi
}

kanata_macos_validate_vhid_vendor_directory() {
    local directory="$1" resolved metadata owner mode
    kanata_macos_run sudo /bin/test -d "$directory" && kanata_macos_run sudo /bin/test ! -L "$directory" || return 1
    resolved="$(kanata_macos_resolved_directory "$directory")" || return 1
    [[ "$resolved" == "$directory" ]] || return 1
    metadata="$(kanata_macos_run sudo /usr/bin/stat -f '%Su:%Lp' "$resolved")" || return 1
    IFS=: read -r owner mode <<<"$metadata"
    [[ "$owner" == root && "$mode" =~ ^[0-7]{3,4}$ && $((8#$mode & 022)) -eq 0 ]]
}

kanata_macos_validate_vhid_binary() {
    local path parent metadata owner group mode codesign_output
    path="$KANATA_MACOS_VHID_BINARY"
    [[ "$path" == '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon' ]] || return 1
    kanata_macos_run sudo /bin/test -f "$path" && kanata_macos_run sudo /bin/test ! -L "$path" && kanata_macos_run sudo /bin/test -x "$path" || return 1
    metadata="$(kanata_macos_run sudo /usr/bin/stat -f '%Su:%Sg:%Lp' "$path")" || return 1
    IFS=: read -r owner group mode <<<"$metadata"
    [[ "$owner" == root && "$mode" =~ ^[0-7]{3,4}$ && $((8#$mode & 022)) -eq 0 ]] || return 1
    for parent in /Library '/Library/Application Support' '/Library/Application Support/org.pqrs' '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice' '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications' '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app' '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents' '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS'; do
        kanata_macos_validate_vhid_vendor_directory "$parent" || return 1
    done
    kanata_macos_run sudo /usr/bin/codesign --verify --strict --verbose=2 "$path" || return 1
    codesign_output="$(kanata_macos_run sudo /usr/bin/codesign -dv --verbose=4 "$path" 2>&1)" || return 1
    [[ "$codesign_output" == *$'Identifier=org.pqrs.Karabiner-VirtualHIDDevice-Daemon'* && "$codesign_output" == *$'TeamIdentifier=G43BCU2T37'* ]] || return 1
}

kanata_macos_vhid_loaded() {
    local output status domain="system/$KANATA_MACOS_VHID_LABEL"
    if output="$(kanata_macos_run sudo /bin/launchctl print "$domain" 2>&1)"; then return 0; fi
    status=$?
    [[ "$output" == *'Could not find service'* && "$output" == *"$KANATA_MACOS_VHID_LABEL"* ]] && return 1
    printf 'error: VirtualHID launchctl print failed (%d): %s\n' "$status" "$output" >&2; return 2
}

kanata_macos_vhid_running() {
    local output state='' pid='' status domain="system/$KANATA_MACOS_VHID_LABEL"
    if output="$(kanata_macos_run sudo /bin/launchctl print "$domain" 2>&1)"; then :; else
        status=$?; printf 'error: VirtualHID launchctl print failed (%d): %s\n' "$status" "$output" >&2; return 2
    fi
    [[ "$output" =~ (^|$'\n'|[[:space:]])state[[:space:]]=[[:space:]]([^$'\n']+)($'\n'|$) ]] && state="${BASH_REMATCH[2]}"
    [[ "$output" =~ (^|$'\n'|[[:space:]])pid[[:space:]]=[[:space:]]([0-9]+)($'\n'|$) ]] && pid="${BASH_REMATCH[2]}"
    [[ "$pid" =~ ^[1-9][0-9]*$ || "$state" == running ]] && return 0
    case "$state" in exited|stopped|waiting|throttled|'spawn scheduled'|terminated|crashed) return 1 ;; esac
    printf 'error: VirtualHID state is unknown (state: %s, pid: %s)\n' "$state" "$pid" >&2; return 2
}

kanata_macos_bootout_vhid() {
    local status
    if kanata_macos_vhid_loaded; then
        kanata_macos_run sudo /bin/launchctl bootout "system/$KANATA_MACOS_VHID_LABEL" || return 1
        kanata_macos_vhid_loaded && return 1
        status=$?; (( status == 1 )) || return "$status"
    else status=$?; (( status == 1 )) || return "$status"; fi
}

kanata_macos_stop_manual_vhid() {
    local pid command attempt found=0 output line
    if ! output="$(kanata_macos_run sudo /bin/ps -axo pid=,comm=)"; then
        printf '%s\n' 'error: cannot enumerate VirtualHID processes with ps' >&2
        return 1
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if [[ "$line" =~ ^[[:space:]]*([1-9][0-9]*)[[:space:]]+(.+)$ ]]; then
            pid="${BASH_REMATCH[1]}"
            command="${BASH_REMATCH[2]}"
        else
            continue
        fi
        [[ "$command" == "$KANATA_MACOS_VHID_BINARY" ]] || continue
        kanata_macos_run sudo /bin/kill -TERM "$pid" || return 1
        found=1
        KANATA_MACOS_MANUAL_VHID_STOPPED=1
    done <<<"$output"
    (( found )) || return 0
    for ((attempt = 0; attempt < 10; attempt++)); do
        kanata_macos_run /bin/sleep 1 || return 1
        if ! output="$(kanata_macos_run sudo /bin/ps -axo pid=,comm=)"; then
            printf '%s\n' 'error: cannot recheck VirtualHID processes with ps' >&2
            return 1
        fi
        found=0
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            if [[ "$line" =~ ^[[:space:]]*([1-9][0-9]*)[[:space:]]+(.+)$ ]]; then
                command="${BASH_REMATCH[2]}"
            else
                continue
            fi
            [[ "$command" == "$KANATA_MACOS_VHID_BINARY" ]] && found=1
        done <<<"$output"
        (( ! found )) && return 0
    done
    printf '%s\n' 'error: exact VirtualHID foreground daemon did not terminate; refusing to create a competing service' >&2; return 1
}

kanata_macos_verify_vhid_running() {
    local attempt status socket
    for ((attempt = 0; attempt < 10; attempt++)); do
        if kanata_macos_vhid_running; then
            if kanata_macos_run sudo /bin/test -d "$KANATA_MACOS_VHID_SOCKET_DIR"; then
                kanata_macos_validate_vhid_vendor_directory "$KANATA_MACOS_VHID_SOCKET_DIR" || return 1
                while IFS= read -r socket; do
                    kanata_macos_run sudo /bin/test -S "$socket" && return 0
                done < <(kanata_macos_run sudo /usr/bin/find "$KANATA_MACOS_VHID_SOCKET_DIR" -maxdepth 1 -type s -name '*.sock' -print 2>/dev/null) || return 1
            fi
        else
            status=$?; (( status == 1 )) || return "$status"
        fi
        kanata_macos_run /bin/sleep 1 || return 1
    done
    printf 'error: VirtualHID service is not ready: require running launchd job and a UNIX socket under %s\n' "$KANATA_MACOS_VHID_SOCKET_DIR" >&2; return 1
}

kanata_macos_bootstrap_vhid() {
    local output status domain="system/$KANATA_MACOS_VHID_LABEL"
    kanata_macos_run sudo /bin/launchctl enable "$domain" || return 1
    if output="$(kanata_macos_run sudo /bin/launchctl bootstrap system "$KANATA_MACOS_VHID_PLIST" 2>&1)"; then return 0; fi
    status=$?
    if [[ "$output" == *disabled* || "$output" == *Disabled* ]]; then
        kanata_macos_run sudo /bin/launchctl enable "$domain" || return 1
        kanata_macos_run sudo /bin/launchctl bootstrap system "$KANATA_MACOS_VHID_PLIST" || return 1
        return 0
    fi
    printf 'error: VirtualHID bootstrap failed (%d): %s\n' "$status" "$output" >&2; return "$status"
}

kanata_macos_install_vhid_daemon() {
    local template="$DOTFILES_DIR/conf/kanata/macos/$KANATA_MACOS_VHID_LABEL.plist"
    local staged="$KANATA_MACOS_TXN_DIR/$KANATA_MACOS_VHID_LABEL.plist"
    [[ -f "$template" && ! -L "$template" ]] || return 1
    kanata_macos_validate_vhid_binary || return 1
    /bin/cp "$template" "$staged" || return 1
    grep -Fqx "    <string>$KANATA_MACOS_VHID_LABEL</string>" "$staged" || return 1
    grep -Fqx "        <string>$KANATA_MACOS_VHID_BINARY</string>" "$staged" || return 1
    kanata_macos_run /usr/bin/plutil -lint "$staged" || return 1
    kanata_macos_bootout_vhid || return 1
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$staged" "$KANATA_MACOS_VHID_PLIST" || return 1
    # This is a durable dependency installation, intentionally independent of
    # the Kanata transaction: do not roll it back if a later Kanata step fails.
    kanata_macos_stop_manual_vhid || return 1
    kanata_macos_bootstrap_vhid || return 1
    kanata_macos_run sudo /bin/launchctl kickstart "system/$KANATA_MACOS_VHID_LABEL" || return 1
    kanata_macos_verify_vhid_running || return 1
}


kanata_macos_service_loaded() {
    local output status
    if output="$(kanata_macos_run sudo /bin/launchctl print system/dev.kanata.kanata 2>&1)"; then
        return 0
    fi
    status=$?
    if [[ "$output" == *'Could not find service'* && "$output" == *'dev.kanata.kanata'* ]]; then
        return 1
    fi
    printf 'error: launchctl print failed (%d): %s\n' "$status" "$output" >&2
    return 2
}

kanata_macos_service_running() {
    local output status state pid
    if output="$(kanata_macos_run sudo /bin/launchctl print system/dev.kanata.kanata 2>&1)"; then
        :
    else
        status=$?
        printf 'error: launchctl print for running state failed (%d): %s\n' "$status" "$output" >&2
        return 2
    fi
    if [[ "$output" =~ (^|$'\n'|[[:space:]])state[[:space:]]=[[:space:]]([^$'\n']+)($'\n'|$) ]]; then
        state="${BASH_REMATCH[2]}"
    else
        state=''
    fi
    if [[ "$output" =~ (^|$'\n'|[[:space:]])pid[[:space:]]=[[:space:]]([0-9]+)($'\n'|$) ]]; then
        pid="${BASH_REMATCH[2]}"
    else
        pid=''
    fi
    if [[ "$pid" =~ ^[1-9][0-9]*$ || "$state" == running ]]; then
        return 0
    fi
    case "$state" in
    exited|stopped|waiting|throttled|'spawn scheduled'|terminated|crashed)
        return 1
        ;;
    *)
        printf 'error: launchctl print for running state had unknown format (state: %s, pid: %s)\n' "$state" "$pid" >&2
        return 2
        ;;
    esac
}

kanata_macos_service_enabled() {
    local output status disabled='"dev.kanata.kanata"[[:space:]]*=>[[:space:]]*true'
    if output="$(kanata_macos_run sudo /bin/launchctl print-disabled system 2>&1)"; then
        :
    else
        status=$?
        printf 'error: launchctl print-disabled failed (%d): %s\n' "$status" "$output" >&2
        return 2
    fi
    # print-disabled records explicit disables; a missing fixed label is enabled.
    [[ ! "$output" =~ $disabled ]]
}

kanata_macos_snapshot_service_state() {
    local status
    KANATA_MACOS_PRIOR_LOADED=0
    KANATA_MACOS_PRIOR_ENABLED=0
    KANATA_MACOS_PRIOR_RUNNING=0
    if kanata_macos_service_enabled; then
        KANATA_MACOS_PRIOR_ENABLED=1
    else
        status=$?
        (( status == 1 )) || return "$status"
    fi
    if kanata_macos_service_loaded; then
        KANATA_MACOS_PRIOR_LOADED=1
        if kanata_macos_service_running; then
            KANATA_MACOS_PRIOR_RUNNING=1
        else
            status=$?
            (( status == 1 )) || return "$status"
        fi
    else
        status=$?
        (( status == 1 )) || return "$status"
    fi
    KANATA_MACOS_STATE_SNAPSHOTTED=1
}

kanata_macos_stop_fixed_service() {
    local attempt status
    kanata_macos_run sudo /bin/launchctl disable system/dev.kanata.kanata || return 1
    if kanata_macos_service_running; then
        kanata_macos_run sudo /bin/launchctl kill SIGTERM system/dev.kanata.kanata || return 1
    else
        status=$?
        (( status == 1 )) || return "$status"
        return 0
    fi
    # Require the fixed job to remain stopped across a short bounded poll, so
    # an old RunAtLoad/KeepAlive policy cannot silently restart it.
    for ((attempt = 0; attempt < 5; attempt++)); do
        kanata_macos_run /bin/sleep 1 || return 1
        if kanata_macos_service_running; then
            continue
        fi
        status=$?
        (( status == 1 )) || return "$status"
        # Once stopped, continue observing for the rest of the bounded window.
    done
    if kanata_macos_service_running; then
        printf '%s\n' 'error: restored launchd service did not remain stopped' >&2
        return 1
    fi
    status=$?
    (( status == 1 )) || return "$status"
}

kanata_macos_bootout_fixed_service() {
    local output status
    if kanata_macos_service_loaded; then
        :
    else
        status=$?
        (( status == 1 )) || return "$status"
        # Absence is a verified, benign bootout outcome.
        KANATA_MACOS_BOOTED_OUT=1
        return 0
    fi
    if output="$(kanata_macos_run sudo /bin/launchctl bootout system/dev.kanata.kanata 2>&1)"; then
        status=0
    else
        status=$?
    fi
    if (( status == 0 )); then
        if kanata_macos_service_loaded; then
            printf '%s\n' 'error: launchctl bootout succeeded but the fixed service is still loaded' >&2
            return 1
        fi
        status=$?
        (( status == 1 )) || return "$status"
        KANATA_MACOS_BOOTED_OUT=1
        return 0
    fi
    printf 'error: launchctl bootout failed (%d): %s\n' "$status" "$output" >&2
    return 1
}

kanata_macos_snapshot_file() {
    local destination="$1" name="$2"
    if kanata_macos_run sudo /bin/test -e "$destination" || kanata_macos_run sudo /bin/test -L "$destination"; then
        kanata_macos_run sudo /bin/test ! -L "$destination" || return 1
        printf -v "KANATA_MACOS_PRESENT_$name" '%s' 1
        kanata_macos_run sudo /bin/cp -p "$destination" "$KANATA_MACOS_TXN_DIR/$name.old" || return 1
    else
        printf -v "KANATA_MACOS_PRESENT_$name" '%s' 0
    fi
}

kanata_macos_restore_file() {
    local destination="$1" name="$2" present temporary
    eval "present=\${KANATA_MACOS_PRESENT_$name:-0}"
    if (( ! present )); then
        kanata_macos_run sudo /bin/rm -f "$destination"
        return
    fi
    temporary="${destination}.kanata-restore.$$"
    if ! kanata_macos_run sudo /bin/cp -p "$KANATA_MACOS_TXN_DIR/$name.old" "$temporary" ||
        ! kanata_macos_run sudo /bin/mv -f "$temporary" "$destination"; then
        kanata_macos_run sudo /bin/rm -f "$temporary"
        return 1
    fi
}

kanata_macos_ensure_user_directory() {
    local directory="$1"
    mkdir -p "$directory" || return 1
    [[ -d "$directory" && ! -L "$directory" && -O "$directory" ]] || {
        printf 'error: unsafe macOS user directory: %s\n' "$directory" >&2
        return 1
    }
}

kanata_macos_snapshot_user_file() {
    local destination="$1" name="$2"
    if [[ -e "$destination" || -L "$destination" ]]; then
        [[ ! -L "$destination" ]] || return 1
        printf -v "KANATA_MACOS_USER_PRESENT_$name" '%s' 1
        /bin/cp -p "$destination" "$KANATA_MACOS_TXN_DIR/$name.old" || return 1
    else
        printf -v "KANATA_MACOS_USER_PRESENT_$name" '%s' 0
    fi
}

kanata_macos_restore_user_file() {
    local destination="$1" name="$2" present temporary
    eval "present=\${KANATA_MACOS_USER_PRESENT_$name:-0}"
    if (( ! present )); then
        /bin/rm -f "$destination"
        return
    fi
    kanata_macos_ensure_user_directory "$(dirname -- "$destination")" || return 1
    temporary="$(dirname -- "$destination")/.${destination##*/}.kanata-restore.$$"
    if ! /bin/cp -p "$KANATA_MACOS_TXN_DIR/$name.old" "$temporary" || ! /bin/mv -f "$temporary" "$destination"; then
        /bin/rm -f "$temporary"
        return 1
    fi
}

kanata_macos_controller_loaded() {
    local output status domain="gui/$(id -u)/dev.kanata.controller"
    if output="$(kanata_macos_run /bin/launchctl print "$domain" 2>&1)"; then
        return 0
    fi
    status=$?
    if [[ "$output" == *'Could not find service'* && "$output" == *'dev.kanata.controller'* ]]; then
        return 1
    fi
    printf 'error: controller launchctl print failed (%d): %s\n' "$status" "$output" >&2
    return 2
}

kanata_macos_controller_running() {
    local output status state pid domain="gui/$(id -u)/dev.kanata.controller"
    if output="$(kanata_macos_run /bin/launchctl print "$domain" 2>&1)"; then
        :
    else
        status=$?
        printf 'error: controller launchctl print for running state failed (%d): %s\n' "$status" "$output" >&2
        return 2
    fi
    [[ "$output" =~ (^|$'\n'|[[:space:]])state[[:space:]]=[[:space:]]([^$'\n']+)($'\n'|$) ]] && state="${BASH_REMATCH[2]}" || state=''
    [[ "$output" =~ (^|$'\n'|[[:space:]])pid[[:space:]]=[[:space:]]([0-9]+)($'\n'|$) ]] && pid="${BASH_REMATCH[2]}" || pid=''
    [[ "$pid" =~ ^[1-9][0-9]*$ || "$state" == running ]] && return 0
    case "$state" in exited|stopped|waiting|throttled|'spawn scheduled'|terminated|crashed) return 1 ;; esac
    printf 'error: controller launchctl print had unknown format (state: %s, pid: %s)\n' "$state" "$pid" >&2
    return 2
}

kanata_macos_controller_enabled() {
    local output status disabled='"dev.kanata.controller"[[:space:]]*=>[[:space:]]*true'
    if output="$(kanata_macos_run /bin/launchctl print-disabled "gui/$(id -u)" 2>&1)"; then
        :
    else
        status=$?
        printf 'error: controller launchctl print-disabled failed (%d): %s\n' "$status" "$output" >&2
        return 2
    fi
    [[ ! "$output" =~ $disabled ]]
}

kanata_macos_controller_verify_running() {
    local attempt status
    for ((attempt = 0; attempt < 5; attempt++)); do
        if kanata_macos_controller_running; then
            return 0
        fi
        status=$?
        (( status == 1 )) || return "$status"
        kanata_macos_run /bin/sleep 1 || return 1
    done
    if kanata_macos_controller_running; then
        return 0
    fi
    status=$?
    (( status == 1 )) || return "$status"
    printf '%s\n' 'error: controller launchd service did not become running' >&2
    return 1
}

kanata_macos_stop_controller() {
    local attempt status saw_stopped=0 domain="gui/$(id -u)/dev.kanata.controller"
    # Disable first so a KeepAlive policy cannot restart the job while its
    # stopped state is being restored.
    kanata_macos_run /bin/launchctl disable "$domain" || return 1
    if kanata_macos_controller_running; then
        kanata_macos_run /bin/launchctl kill SIGTERM "$domain" || return 1
    else
        status=$?
        (( status == 1 )) || return "$status"
        saw_stopped=1
    fi
    for ((attempt = 0; attempt < 5; attempt++)); do
        kanata_macos_run /bin/sleep 1 || return 1
        if kanata_macos_controller_running; then
            if (( saw_stopped )); then
                printf '%s\n' 'error: restored controller launchd service did not remain stopped' >&2
                return 1
            fi
            continue
        fi
        status=$?
        (( status == 1 )) || return "$status"
        saw_stopped=1
    done
    (( saw_stopped )) || {
        printf '%s\n' 'error: restored controller launchd service did not stop' >&2
        return 1
    }
    if kanata_macos_controller_running; then
        printf '%s\n' 'error: restored controller launchd service did not remain stopped' >&2
        return 1
    fi
    status=$?
    (( status == 1 )) || return "$status"
}

kanata_macos_snapshot_controller_state() {
    local status
    KANATA_MACOS_CONTROLLER_PRIOR_LOADED=0
    KANATA_MACOS_CONTROLLER_PRIOR_ENABLED=0
    KANATA_MACOS_CONTROLLER_PRIOR_RUNNING=0
    if kanata_macos_controller_enabled; then
        KANATA_MACOS_CONTROLLER_PRIOR_ENABLED=1
    else
        status=$?; (( status == 1 )) || return "$status"
    fi
    if kanata_macos_controller_loaded; then
        KANATA_MACOS_CONTROLLER_PRIOR_LOADED=1
        if kanata_macos_controller_running; then
            KANATA_MACOS_CONTROLLER_PRIOR_RUNNING=1
        else
            status=$?; (( status == 1 )) || return "$status"
        fi
    else
        status=$?; (( status == 1 )) || return "$status"
    fi
    if (( KANATA_MACOS_CONTROLLER_PRIOR_LOADED == 1 &&
          KANATA_MACOS_CONTROLLER_PRIOR_ENABLED == 1 &&
          KANATA_MACOS_CONTROLLER_PRIOR_RUNNING == 0 )); then
        printf '%s\n' 'error: controller is loaded and enabled but stopped; this state cannot be safely preserved under RunAtLoad/KeepAlive. Start the controller or disable it and boot it out before rerunning the installer.' >&2
        return 1
    fi
    KANATA_MACOS_CONTROLLER_STATE_SNAPSHOTTED=1
}

kanata_macos_bootout_controller() {
    local status domain="gui/$(id -u)/dev.kanata.controller"
    if kanata_macos_controller_loaded; then
        kanata_macos_run /bin/launchctl bootout "$domain" || return 1
        if kanata_macos_controller_loaded; then return 1; fi
        status=$?; (( status == 1 )) || return "$status"
    else
        status=$?; (( status == 1 )) || return "$status"
    fi
}

kanata_macos_restore_controller() {
    local failed=0 bootstrapped=0 domain="gui/$(id -u)/dev.kanata.controller" plist="$HOME/Library/LaunchAgents/dev.kanata.controller.plist"
    [[ "${KANATA_MACOS_CONTROLLER_STATE_SNAPSHOTTED:-0}" == 1 ]] || return 0
    # Do not replace the binary or plist beneath a loaded KeepAlive agent.
    # bootout_controller verifies absence, so any failure must fail closed.
    kanata_macos_bootout_controller || return 1
    kanata_macos_restore_user_file "$HOME/.local/bin/kanata-controller" controller_binary || failed=1
    kanata_macos_restore_user_file "$plist" controller_plist || failed=1
    (( ! failed )) || return 1

    if [[ "${KANATA_MACOS_CONTROLLER_PRIOR_LOADED:-0}" != 1 ]]; then
        # An unloaded prior agent remains unloaded; only restore its disabled
        # database entry.
        if [[ "${KANATA_MACOS_CONTROLLER_PRIOR_ENABLED:-0}" == 1 ]]; then
            kanata_macos_run /bin/launchctl enable "$domain" || return 1
        else
            kanata_macos_run /bin/launchctl disable "$domain" || return 1
        fi
        return 0
    fi

    if [[ "${KANATA_MACOS_CONTROLLER_PRIOR_ENABLED:-0}" == 1 ]]; then
        kanata_macos_run /bin/launchctl enable "$domain" || return 1
        kanata_macos_run /bin/launchctl bootstrap "gui/$(id -u)" "$plist" || return 1
        bootstrapped=1
    else
        # Preserve a disabled prior state when launchd permits it. Some
        # launchd versions reject bootstrap for an explicitly disabled label;
        # enable only as the bootstrap fallback and restore disabled below.
        kanata_macos_run /bin/launchctl disable "$domain" || return 1
        if kanata_macos_run /bin/launchctl bootstrap "gui/$(id -u)" "$plist"; then
            bootstrapped=1
        else
            kanata_macos_run /bin/launchctl enable "$domain" || return 1
            kanata_macos_run /bin/launchctl bootstrap "gui/$(id -u)" "$plist" || return 1
            bootstrapped=1
        fi
    fi
    (( bootstrapped )) || return 1

    if [[ "${KANATA_MACOS_CONTROLLER_PRIOR_RUNNING:-0}" == 1 ]]; then
        kanata_macos_run /bin/launchctl enable "$domain" || return 1
        kanata_macos_run /bin/launchctl kickstart -k "$domain" || return 1
        kanata_macos_controller_verify_running || return 1
    else
        kanata_macos_stop_controller || return 1
    fi
    if [[ "${KANATA_MACOS_CONTROLLER_PRIOR_ENABLED:-0}" == 1 ]]; then
        kanata_macos_run /bin/launchctl enable "$domain" || return 1
    else
        kanata_macos_run /bin/launchctl disable "$domain" || return 1
    fi
}

kanata_macos_rollback() {
    local failed=0
    [[ "${KANATA_MACOS_STAGED:-0}" == 1 ]] || return 0
    kanata_macos_restore_controller || failed=1
    # Always remove any current/new loaded job before restoring files.
    if ! kanata_macos_bootout_fixed_service || [[ "${KANATA_MACOS_BOOTED_OUT:-0}" != 1 ]]; then
        printf '%s\n' 'error: cannot verify the fixed Kanata launchd service is absent; active artifacts were not restored. Remove or unload system/dev.kanata.kanata manually, then restore the saved files.' >&2
        return 1
    fi
    kanata_macos_restore_file /etc/kanata/kanata.kbd config || failed=1
    kanata_macos_restore_file /etc/kanata/kanata-common.kbd common_config || failed=1
    kanata_macos_restore_file /Library/LaunchDaemons/dev.kanata.kanata.plist plist || failed=1
    kanata_macos_restore_file /usr/local/libexec/kanata-control helper || failed=1
    kanata_macos_restore_file /etc/sudoers.d/kanata-controller sudoers || failed=1
    if [[ "${KANATA_MACOS_STATE_SNAPSHOTTED:-0}" == 1 ]]; then
        if [[ "${KANATA_MACOS_PRIOR_LOADED:-0}" == 1 ]]; then
            # A disabled job may reject bootstrap.  Keep the prior state first;
            # enable only for that required bootstrap fallback.
            if [[ "${KANATA_MACOS_PRIOR_ENABLED:-0}" == 1 ]]; then
                kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata || failed=1
                kanata_macos_run sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist || failed=1
            else
                kanata_macos_run sudo /bin/launchctl disable system/dev.kanata.kanata || failed=1
                if ! kanata_macos_run sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist; then
                    kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata || failed=1
                    kanata_macos_run sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist || failed=1
                fi
            fi
            if [[ "${KANATA_MACOS_PRIOR_RUNNING:-0}" == 1 ]]; then
                kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata || failed=1
                kanata_macos_run sudo /bin/launchctl kickstart system/dev.kanata.kanata || failed=1
                if [[ "${KANATA_MACOS_PRIOR_ENABLED:-0}" == 1 ]]; then
                    kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata || failed=1
                else
                    # Keep an already-running, explicitly disabled old job
                    # running while restoring its disabled state.
                    kanata_macos_run sudo /bin/launchctl disable system/dev.kanata.kanata || failed=1
                fi
            else
                kanata_macos_stop_fixed_service || failed=1
                if [[ "${KANATA_MACOS_PRIOR_ENABLED:-0}" == 1 ]]; then
                    kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata || failed=1
                else
                    kanata_macos_run sudo /bin/launchctl disable system/dev.kanata.kanata || failed=1
                fi
            fi
        elif [[ "${KANATA_MACOS_PRIOR_ENABLED:-0}" == 1 ]]; then
            kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata || failed=1
        else
            kanata_macos_run sudo /bin/launchctl disable system/dev.kanata.kanata || failed=1
        fi
    fi
    (( ! failed ))
}

kanata_macos_transaction_exit() {
    local status="$1"
    if [[ "${KANATA_MACOS_COMMITTED:-0}" != 1 ]]; then
        kanata_macos_rollback || status=1
        if [[ "${KANATA_MACOS_MANUAL_VHID_STOPPED:-0}" == 1 ]]; then
            printf '%s\n' "recovery: the prior foreground VirtualHID daemon was stopped. After resolving the installer failure, restart it manually with: sudo '$KANATA_MACOS_VHID_BINARY'" >&2
        fi
    fi
    [[ -z "${KANATA_MACOS_TXN_DIR:-}" ]] || rm -rf -- "$KANATA_MACOS_TXN_DIR"
    [[ -z "${KANATA_MACOS_STAGE_DIR:-}" ]] || kanata_macos_run sudo /bin/rm -rf -- "$KANATA_MACOS_STAGE_DIR"
    trap - EXIT HUP INT TERM
    exit "$status"
}

install_kanata_macos() (
    set -e
    [[ "$(uname -s)" == Darwin ]] || { printf '%s\n' 'error: macos target must run on macOS' >&2; exit 1; }
    KANATA_MACOS_TXN_DIR=""
    KANATA_MACOS_BOOTED_OUT=0
    KANATA_MACOS_NEW_SERVICE=0
    KANATA_MACOS_STAGE_DIR=""
    KANATA_MACOS_COMMITTED=0
    KANATA_MACOS_STAGED=0
    KANATA_MACOS_STATE_SNAPSHOTTED=0
    KANATA_MACOS_CONTROLLER_STATE_SNAPSHOTTED=0
    KANATA_MACOS_MANUAL_VHID_STOPPED=0
    trap 'kanata_macos_transaction_exit $?' EXIT HUP INT TERM
    kanata_macos_run brew install kanata libiconv
    local kanata_binary
    kanata_binary="$(kanata_macos_run brew --prefix kanata)/bin/kanata"
    [[ -f "$kanata_binary" && ! -L "$kanata_binary" && -x "$kanata_binary" ]] || {
        printf '%s\n' 'error: Homebrew Kanata binary must be a regular executable file' >&2
        exit 1
    }
    local config_dir="$HOME/.config/kanata"
    local config="$config_dir/kanata.kbd"
    mkdir -p "$config_dir"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-macos.kbd" "$config"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-common.kbd" "$config_dir/kanata-common.kbd"

    local runtime_dir=/etc/kanata helper=/usr/local/libexec/kanata-control
    local sudoers=/etc/sudoers.d/kanata-controller
    local temporary_dir temporary_plist temporary_controller_plist user
    temporary_dir="$(mktemp -d)"
    KANATA_MACOS_TXN_DIR="$temporary_dir"
    user="$(id -un)"
    kanata_safe_user "$user" || {
        printf '%s\n' 'error: current username is unsafe for policy rendering' >&2
        exit 1
    }
    mkdir -p "$temporary_dir/runtime"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-macos.kbd" "$temporary_dir/runtime/kanata.kbd"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-common.kbd" "$temporary_dir/runtime/kanata-common.kbd"
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/macos/kanata-controller.sudoers.template" \
        "$temporary_dir/sudoers" '' '' "$user"
    kanata_reject_unresolved_placeholders "$temporary_dir/sudoers" || {
        printf '%s\n' 'error: unresolved sudoers template placeholder' >&2
        exit 1
    }
    [[ -x /usr/sbin/visudo ]] || exit 1
    /usr/sbin/visudo -c -f "$temporary_dir/sudoers" || exit 1

    kanata_macos_validate_directory /usr/local
    kanata_macos_validate_directory /etc
    kanata_macos_validate_vhid_binary || {
        printf '%s\n' 'error: VirtualHID daemon must be a root-owned executable under the trusted Karabiner DriverKit path' >&2
        exit 1
    }
    kanata_macos_ensure_directory "$runtime_dir"
    kanata_macos_ensure_directory /usr/local/libexec
    kanata_macos_ensure_directory /etc/sudoers.d
    kanata_macos_validate_directories
    KANATA_MACOS_STAGED=1
    kanata_macos_snapshot_file /etc/kanata/kanata.kbd config
    kanata_macos_snapshot_file /etc/kanata/kanata-common.kbd common_config
    kanata_macos_snapshot_file /Library/LaunchDaemons/dev.kanata.kanata.plist plist
    kanata_macos_snapshot_file "$helper" helper
    kanata_macos_snapshot_file "$sudoers" sudoers
    kanata_macos_snapshot_service_state

    local controller_binary="$HOME/.local/bin/kanata-controller"
    local controller_plist="$HOME/Library/LaunchAgents/dev.kanata.controller.plist"
    local controller_log_dir="$HOME/.local/state/kanata-controller"
    local controller_domain="gui/$(id -u)/dev.kanata.controller"
    [[ "$controller_binary" == "$HOME/.local/bin/kanata-controller" && "$controller_plist" == "$HOME/Library/LaunchAgents/dev.kanata.controller.plist" && "$controller_domain" == "gui/$(id -u)/dev.kanata.controller" ]] || exit 1
    kanata_macos_ensure_user_directory "$HOME/.local/bin"
    kanata_macos_ensure_user_directory "$HOME/Library/LaunchAgents"
    kanata_macos_ensure_user_directory "$controller_log_dir"
    kanata_macos_snapshot_user_file "$controller_binary" controller_binary
    kanata_macos_snapshot_user_file "$controller_plist" controller_plist
    kanata_macos_snapshot_controller_state
    kanata_build_controller
    temporary_controller_plist="$temporary_dir/dev.kanata.controller.plist"
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/macos/dev.kanata.controller.plist" \
        "$temporary_controller_plist" '' '' '' "$controller_binary" "$controller_log_dir"
    kanata_reject_unresolved_placeholders "$temporary_controller_plist" || exit 1
    grep -Fqx '    <string>dev.kanata.controller</string>' "$temporary_controller_plist" || exit 1
    ! grep -Eq '<key>(UserName|GroupName)</key>' "$temporary_controller_plist" || exit 1
    kanata_macos_run /usr/bin/plutil -lint "$temporary_controller_plist"
    kanata_macos_bootout_controller
    kanata_install_controller_binary "$KANATA_CONTROLLER_BUILD"
    install -m 0644 "$temporary_controller_plist" "$controller_plist"

    local plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
    temporary_plist="$temporary_dir/dev.kanata.kanata.plist"
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/macos/dev.kanata.kanata.plist" \
        "$temporary_plist" "$kanata_binary" "$runtime_dir/kanata.kbd"
    kanata_reject_unresolved_placeholders "$temporary_plist" || {
        printf '%s\n' 'error: unresolved plist template placeholder' >&2
        exit 1
    }
    # Unload the fixed job before replacing any active artifact it may use.
    kanata_macos_bootout_fixed_service
    # Validate the Homebrew binary from a root-owned path without running the
    # user-owned Homebrew path through sudo.
    KANATA_MACOS_STAGE_DIR="$runtime_dir/.kanata-staging.$$"
    kanata_macos_run sudo install -d -o root -g wheel -m 0755 "$KANATA_MACOS_STAGE_DIR"
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$temporary_dir/runtime/kanata.kbd" "$KANATA_MACOS_STAGE_DIR/kanata.kbd"
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$temporary_dir/runtime/kanata-common.kbd" "$KANATA_MACOS_STAGE_DIR/kanata-common.kbd"
    kanata_macos_run sudo install -o root -g wheel -m 0755 "$kanata_binary" "$KANATA_MACOS_STAGE_DIR/kanata"
    kanata_macos_validate_directory "$KANATA_MACOS_STAGE_DIR"
    local staged_binary="$KANATA_MACOS_STAGE_DIR/kanata"
    kanata_macos_run sudo "$staged_binary" --check --cfg "$KANATA_MACOS_STAGE_DIR/kanata.kbd"
    kanata_macos_run /usr/bin/plutil -lint "$temporary_plist"
    kanata_macos_run /usr/sbin/visudo -c -f "$temporary_dir/sudoers"
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$temporary_dir/runtime/kanata.kbd" "$runtime_dir/kanata.kbd"
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$temporary_dir/runtime/kanata-common.kbd" "$runtime_dir/kanata-common.kbd"
    kanata_macos_run sudo install -o root -g wheel -m 0755 "$DOTFILES_DIR/conf/kanata/macos/kanata-control.sh" "$helper"
    kanata_macos_run sudo install -o root -g wheel -m 0440 "$temporary_dir/sudoers" "$sudoers"
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$temporary_plist" "$plist"
    [[ "$(kanata_macos_run sudo /usr/bin/stat -f '%Su:%Sg:%Lp' "$helper")" == root:wheel:755 ]] || exit 1
    [[ "$(kanata_macos_run sudo /usr/bin/stat -f '%Su:%Sg:%Lp' "$sudoers")" == root:wheel:440 ]] || exit 1
    kanata_macos_install_vhid_daemon
    # Mark before bootstrap because launchctl can load before reporting failure.
    KANATA_MACOS_NEW_SERVICE=1
    kanata_macos_run sudo /bin/launchctl bootstrap system "$plist"
    kanata_macos_run sudo /bin/launchctl enable system/dev.kanata.kanata
    kanata_macos_run sudo /bin/launchctl kickstart system/dev.kanata.kanata
    kanata_macos_service_loaded
    kanata_macos_service_running
    kanata_macos_run /bin/launchctl enable "$controller_domain"
    kanata_macos_run /bin/launchctl bootstrap "gui/$(id -u)" "$controller_plist"
    kanata_macos_run /bin/launchctl kickstart -k "$controller_domain"
    kanata_macos_controller_verify_running
    KANATA_MACOS_COMMITTED=1
    printf '%s\n' \
        'Kanata macOS manual steps:' \
        '  Approve the Karabiner DriverKit/VirtualHID extension if prompted.' \
        '  Grant Kanata Input Monitoring and Accessibility in Privacy & Security.' \
        '  For each PC external keyboard, set Option and Command in System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys.' \
        '  The Mac and PC keyboards use the same Kanata non-modifier layers; Kanata does not identify devices.'
)

kanata_windows_require_admin() {
    local elevated
    elevated="$(powershell.exe -NoProfile -NonInteractive -Command \
        '[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' \
        2>/dev/null | tr -d '\r\n')"
    [[ "$elevated" == True ]] || {
        printf '%s\n' \
            'error: Windows kanata installation requires an Administrator-elevated Git Bash/MSYS shell' \
            'Open Git Bash with Run as administrator, then rerun the kanata installer.' >&2
        return 1
    }
}

kanata_windows_current_user() {
    local current_user
    current_user="$(powershell.exe -NoProfile -NonInteractive -Command \
        '[Security.Principal.WindowsIdentity]::GetCurrent().Name' \
        2>/dev/null | tr -d '\r\n')"
    [[ "$current_user" =~ ^[^\\[:space:]]+\\[^\\[:space:]]+$ ]] || {
        printf '%s\n' 'error: could not determine the current Windows user identity' >&2
        return 1
    }
    printf '%s\n' "$current_user"
}

kanata_windows_native_path() {
    cygpath -w -a -- "$1"
}

kanata_windows_ensure_task_folder() {
    powershell.exe -NoProfile -NonInteractive -Command '
        $service = New-Object -ComObject Schedule.Service
        $service.Connect()
        $root = $service.GetFolder("\")
        try {
            $root.GetFolder("\Dotfiles") | Out-Null
        } catch {
            $root.CreateFolder("Dotfiles", $null) | Out-Null
        }
    '
}

kanata_windows_render_task() {
    local template="$1"
    local destination="$2"
    local task_user="$3"
    local command="$4"
    local arguments="$5"
    local working_directory="$6"
    local template_windows
    local destination_windows
    template_windows="$(kanata_windows_native_path "$template")"
    destination_windows="$(kanata_windows_native_path "$destination")"
    KANATA_XML_TEMPLATE="$template_windows" \
    KANATA_XML_DESTINATION="$destination_windows" \
    KANATA_TASK_USER="$task_user" \
    KANATA_TASK_COMMAND="$command" \
    KANATA_TASK_ARGUMENTS="$arguments" \
    KANATA_TASK_WORKING_DIRECTORY="$working_directory" \
        powershell.exe -NoProfile -NonInteractive -Command '
        function ConvertTo-XmlText([string] $value) {
            if ($value -match "[\x00-\x08\x0B\x0C\x0E-\x1F\r\n]") {
                throw "XML value contains a control character"
            }
            return [System.Security.SecurityElement]::Escape($value)
        }

        $template = Get-Content -LiteralPath $env:KANATA_XML_TEMPLATE -Raw -ErrorAction Stop
        $values = @{
            "__TASK_USER__" = $env:KANATA_TASK_USER
            "__COMMAND__" = $env:KANATA_TASK_COMMAND
            "__ARGUMENTS__" = $env:KANATA_TASK_ARGUMENTS
            "__WORKING_DIRECTORY__" = $env:KANATA_TASK_WORKING_DIRECTORY
        }
        foreach ($name in @("__COMMAND__", "__WORKING_DIRECTORY__")) {
            if ($values[$name] -notmatch "^[A-Za-z]:\\") {
                throw "$name must be an absolute Windows path"
            }
        }
        if (-not (Test-Path -LiteralPath $values["__COMMAND__"] -PathType Leaf)) {
            throw "__COMMAND__ must name an existing executable"
        }
        if (-not (Test-Path -LiteralPath $values["__WORKING_DIRECTORY__"] -PathType Container)) {
            throw "__WORKING_DIRECTORY__ must name an existing directory"
        }
        if ($values["__ARGUMENTS__"] -notmatch "[A-Za-z]:\\") {
            throw "__ARGUMENTS__ must contain an absolute Windows path"
        }
        foreach ($match in [regex]::Matches($values["__ARGUMENTS__"], "[A-Za-z]:\\[^\"]+")) {
            if (-not (Test-Path -LiteralPath $match.Value -PathType Leaf)) {
                throw "__ARGUMENTS__ contains a missing file path"
            }
        }
        foreach ($name in $values.Keys) {
            $template = $template.Replace($name, (ConvertTo-XmlText $values[$name]))
        }
        if ($template -match "__[A-Z_]+__") {
            throw "unresolved XML placeholder"
        }
        $source_encoding = "encoding=\"UTF-8\""
        if (($template | Select-String -SimpleMatch $source_encoding -AllMatches).Matches.Count -ne 1) {
            throw "expected exactly one UTF-8 XML declaration"
        }
        $template = $template.Replace($source_encoding, "encoding=\"UTF-16\"")
        Set-Content -LiteralPath $env:KANATA_XML_DESTINATION -Value $template -Encoding Unicode -ErrorAction Stop
    '
}

install_kanata_windows() (
    set -e
    case "$(uname -m)" in
    x86_64|amd64) ;;
    *) printf 'error: Windows Kanata installation requires x86_64/amd64, got %s\n' "$(uname -m)" >&2; exit 1 ;;
    esac
    [[ -n "${LOCALAPPDATA:-}" && -n "${USERDOMAIN:-}" && -n "${USERNAME:-}" ]] || {
        printf '%s\n' 'error: LOCALAPPDATA, USERDOMAIN, and USERNAME must be set' >&2
        exit 1
    }
    kanata_windows_require_admin
    winget install --exact --id jtroo.kanata_gui --source winget \
        --accept-source-agreements --accept-package-agreements
    local package_root="${LOCALAPPDATA}/Microsoft/WinGet/Packages"
    local kanata_filename=kanata_windows_gui_winIOv2_x64.exe
    local -a matches=()
    local absolute_package_root
    absolute_package_root="$(CDPATH= cd -- "$package_root" && pwd -P)"
    while IFS= read -r -d '' match; do matches+=("$match"); done < <(find "$absolute_package_root" -type f -name "$kanata_filename" -print0)
    [[ ${#matches[@]} -eq 1 ]] || { printf 'error: expected one %s under %s, found %d\n' "$kanata_filename" "$package_root" "${#matches[@]}" >&2; exit 1; }
    local kanata_dir="${LOCALAPPDATA}/kanata"
    local kanata_cfg="${kanata_dir}/kanata.kbd"
    mkdir -p "$kanata_dir"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-windows.kbd" "$kanata_cfg"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-common.kbd" "$kanata_dir/kanata-common.kbd"

    local run_as
    run_as="$(kanata_windows_current_user)"
    local temporary_dir
    temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-kanata.XXXXXX")"
    trap 'rm -rf -- "$temporary_dir"' EXIT
    local rendered_kanata="$temporary_dir/Dotfiles-Kanata.xml"
    local kanata_command
    local windows_kanata_cfg
    local windows_kanata_dir
    kanata_command="$(kanata_windows_native_path "${matches[0]}")"
    windows_kanata_cfg="$(kanata_windows_native_path "$kanata_cfg")"
    windows_kanata_dir="$(kanata_windows_native_path "$kanata_dir")"
    kanata_windows_render_task \
        "$DOTFILES_DIR/conf/kanata/windows/Dotfiles-Kanata.xml" \
        "$rendered_kanata" "$run_as" "$kanata_command" \
        "--cfg \"$windows_kanata_cfg\"" "$windows_kanata_dir"
    local rendered_kanata_windows
    rendered_kanata_windows="$(kanata_windows_native_path "$rendered_kanata")"
    kanata_windows_ensure_task_folder
    schtasks.exe //Create //TN "\\Dotfiles\\Kanata" //XML "$rendered_kanata_windows" //F || exit 1
    # Remove the known legacy task after Kanata registration succeeds and before start.
    local legacy_task_name='Kanata'
    schtasks.exe //Delete //TN "$legacy_task_name" //F >/dev/null 2>&1 || true
    schtasks.exe //Delete //TN "\\Dotfiles\\AutoHotkey" //F >/dev/null 2>&1 || true
    schtasks.exe //Run //TN "\\Dotfiles\\Kanata"
    printf '%s\n' \
        'Windows elevated kanata installed for the current interactive user.' \
        'Kanata runs with HighestAvailable; elevated applications are supported.' \
        'The Windows installer intentionally does not install Interception.' \
        'Protected surfaces are excluded: UAC secure desktop, login/lock screens, credential UI, and Ctrl+Alt+Del.' \
        'Inspect tasks with: schtasks /query /tn "\\Dotfiles\\Kanata" /v /fo list' \
        'Run task with: schtasks /run /tn "\\Dotfiles\\Kanata"' \
        'Recover by deleting the task: schtasks /delete /tn "\\Dotfiles\\Kanata" /f' \
        'Future Kanata upgrades are managed via winget; rerun this installer after package path changes.'
)

install_kanata() {
    local target="${1:-}"
    target="${target:-$(kanata_target)}"
    case "$target" in
    other|arch) install_kanata_system "$target" ;;
    macos) install_kanata_macos ;;
    windows) install_kanata_windows ;;
    *) printf 'error: unknown kanata target %s\n' "$target" >&2; return 1 ;;
    esac
}
