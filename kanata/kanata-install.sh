#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
source "$DOTFILES_DIR/kanata/kanata.sh"
KANATA_LINUX_ARCHIVE_URL="https://github.com/jtroo/kanata/releases/download/$KANATA_VERSION/linux-binaries-x64.zip"
KANATA_LINUX_ARCHIVE_SHA256=0bedd91567c5d7c54679061baadc37e4f83fb71750003999bc1d11f2c9754f36
KANATA_MACOS_VHID_LABEL=org.pqrs.Karabiner-VirtualHIDDevice-Daemon
KANATA_MACOS_VHID_BINARY='/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon'
KANATA_MACOS_VHID_PLIST="/Library/LaunchDaemons/$KANATA_MACOS_VHID_LABEL.plist"
KANATA_MACOS_VHID_SOCKET_DIR='/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server'

# Copy a user-owned file atomically. One original is kept as a finite manual
# recovery copy; later installs do not overwrite that recovery file.
kanata_atomic_user_file() {
    local source="$1" destination="$2" mode="$3" parent backup temporary status
    parent="$(dirname -- "$destination")"
    mkdir -p -- "$parent" || return 1
    if [[ -f "$destination" ]]; then
        if [[ "$(kanata_platform)" == macos ]]; then
            if cmp -s "$source" "$destination"; then return 0; else status=$?; fi
        else
            if cmp -s -- "$source" "$destination"; then return 0; else status=$?; fi
        fi
        (( status == 1 )) || { kanata_error "could not compare user target: $destination"; return 1; }
    fi
    backup="$destination.pre-kanata.bak"
    if [[ -f "$destination" && ! -e "$backup" && ! -L "$backup" ]]; then
        if [[ "$(kanata_platform)" == macos ]]; then cp -p "$destination" "$backup"; else cp -p -- "$destination" "$backup"; fi || return 1
    elif [[ -e "$backup" && ! -f "$backup" || -L "$backup" ]]; then
        kanata_error "recovery path is not a regular file: $backup"
        return 1
    fi
    temporary="$(mktemp "$parent/.${destination##*/}.kanata.XXXXXX")" || return 1
    if ! install -m "$mode" "$source" "$temporary" || ! mv -f -- "$temporary" "$destination"; then
        rm -f -- "$temporary"
        return 1
    fi
}

kanata_user_file_preflight() {
    local path="$1" backup parent
    parent="$(dirname -- "$path")"
    if [[ -e "$parent" || -L "$parent" ]]; then
        [[ -d "$parent" && ! -L "$parent" ]] || { kanata_error "unsafe target directory: $parent"; return 1; }
    fi
    for path in "$path" "$path.pre-kanata.bak"; do
        if [[ -L "$path" || ( -e "$path" && ! -f "$path" ) ]]; then
            kanata_error "refusing non-regular or symlink target: $path"
            return 1
        fi
    done
}

kanata_render_template() {
    local source="$1" destination="$2" user="$3" executable="$4" config="$5" controller="$6" log_dir="$7" line
    [[ -f "$source" && ! -L "$source" ]] || { kanata_error "missing or unsafe template: $source"; return 1; }
    if ! {
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line//__KANATA_USER__/$user}"
            line="${line//__KANATA_EXECUTABLE__/$executable}"
            line="${line//__KANATA_CONFIG__/$config}"
            line="${line//__KANATA_CONTROLLER_EXECUTABLE__/$controller}"
            line="${line//__KANATA_CONTROLLER_LOG_DIR__/$log_dir}"
            printf '%s\n' "$line"
        done <"$source" >"$destination"
    }; then
        kanata_error "could not render template: $source"
        return 1
    fi
    if grep -Eq '__[A-Z_]+__' "$destination"; then
        kanata_error "unresolved template value in $destination"
        return 1
    else
        local grep_status=$?
        (( grep_status == 1 )) || { kanata_error "could not validate rendered template: $destination"; return 1; }
    fi
}

kanata_require_files() {
    local path
    for path in "$@"; do
        [[ -f "$path" && ! -L "$path" ]] || { kanata_error "required source file is missing or unsafe: $path"; return 1; }
    done
}


kanata_root_dirs_preflight() {
    sudo /bin/sh -c '
        for path do
            if [ -L "$path" ]; then
                printf "refusing symlink directory: %s\n" "$path" >&2
                exit 1
            fi
            if [ -e "$path" ] && [ ! -d "$path" ]; then
                printf "target is not a directory: %s\n" "$path" >&2
                exit 1
            fi
        done
    ' kanata-preflight "$@" || { kanata_error 'fixed target directory preflight failed'; return 1; }
}

kanata_root_files_preflight() {
    sudo /bin/sh -c '
        for path do
            for target in "$path" "$path.pre-kanata.bak"; do
                if [ -L "$target" ]; then
                    printf "refusing symlink target: %s\n" "$target" >&2
                    exit 1
                fi
                if [ -e "$target" ] && [ ! -f "$target" ]; then
                    printf "target is not a regular file: %s\n" "$target" >&2
                    exit 1
                fi
            done
        done
    ' kanata-preflight "$@" || { kanata_error 'fixed target file preflight failed'; return 1; }
}

kanata_root_ensure_dir() {
    local path="$1"
    if [[ "$(kanata_platform)" == macos ]]; then
        if sudo /bin/test -d "$path"; then return 0; fi
        sudo /usr/bin/install -d -o root -g wheel -m 0755 "$path"
    else
        if sudo test -d "$path"; then return 0; fi
        sudo install -d -o root -g root -m 0755 -- "$path"
    fi || { kanata_error "could not prepare target directory: $path"; return 1; }
}

kanata_root_install_file() {
    local source="$1" destination="$2" mode="$3" parent backup temporary status
    parent="$(dirname -- "$destination")"
    if [[ -e "$destination" ]]; then
        if [[ "$(kanata_platform)" == macos ]]; then
            if sudo /usr/bin/cmp -s "$source" "$destination"; then return 0; else status=$?; fi
        else
            if sudo cmp -s -- "$source" "$destination"; then return 0; else status=$?; fi
        fi
        if (( status != 1 )); then kanata_error "could not compare target before install: $destination"; return 1; fi
    fi
    backup="$destination.pre-kanata.bak"
    if [[ -e "$destination" && ! -e "$backup" ]]; then
        if [[ "$(kanata_platform)" == macos ]]; then
            sudo /bin/cp -p "$destination" "$backup"
        else
            sudo cp -p -- "$destination" "$backup"
        fi || { kanata_error "could not preserve first backup for $destination"; return 1; }
    fi
    if [[ "$(kanata_platform)" == macos ]]; then
        temporary="$(sudo /usr/bin/mktemp "$parent/.${destination##*/}.kanata.XXXXXX")" || { kanata_error "could not stage target: $destination"; return 1; }
        sudo /usr/bin/install -o root -g wheel -m "$mode" "$source" "$temporary" || { sudo /bin/rm -f "$temporary"; kanata_error "could not install staged target: $destination"; return 1; }
        sudo /bin/mv -f "$temporary" "$destination" || { sudo /bin/rm -f "$temporary"; kanata_error "could not atomically replace target: $destination"; return 1; }
    else
        temporary="$(sudo mktemp "$parent/.${destination##*/}.kanata.XXXXXX")" || { kanata_error "could not stage target: $destination"; return 1; }
        sudo install -o root -g root -m "$mode" -- "$source" "$temporary" || { sudo rm -f -- "$temporary"; kanata_error "could not install staged target: $destination"; return 1; }
        sudo mv -fT -- "$temporary" "$destination" || { sudo rm -f -- "$temporary"; kanata_error "could not atomically replace target: $destination"; return 1; }
    fi
}

kanata_linux_prepare_packages() {
    local -a packages=(base-devel git curl unzip binutils)
    kanata_is_arch_linux || return 0
    kanata_require_commands pacman sudo || return 1
    if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
        packages+=(rust)
    fi
    kanata_info 'Checking required Arch build/download dependencies with pacman'
    sudo pacman -S --needed --noconfirm "${packages[@]}" >&2 || {
        kanata_error 'pacman could not prepare the required build/download dependencies'
        return 1
    }
}

kanata_install_arch_packages() {
    if command -v yay >/dev/null 2>&1; then
        kanata_info 'Preparing repository Kanata with yay'
        yay -S --needed --noconfirm kanata >&2 || { kanata_error 'yay could not prepare repository Kanata'; return 1; }
    else
        kanata_require_commands pacman sudo || return 1
        kanata_info 'Preparing repository Kanata with pacman'
        sudo pacman --needed --noconfirm -S kanata >&2 || { kanata_error 'pacman could not prepare repository Kanata'; return 1; }
    fi
}

kanata_linux_gnu_target() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
    x86_64) printf '%s\n' x86_64-unknown-linux-gnu ;;
    aarch64) printf '%s\n' aarch64-unknown-linux-gnu ;;
    armv7l|armv7) printf '%s\n' armv7-unknown-linux-gnueabihf ;;
    i?86) printf '%s\n' i686-unknown-linux-gnu ;;
    *) kanata_error "no supported native GNU Rust target for Linux architecture: $arch"; return 1 ;;
    esac
}

kanata_linux_cargo_build() {
    local manifest="$1" target_dir="$2" executable="$3" target target_key build target_rustflags
    target="$(kanata_linux_gnu_target)" || return 1
    target_key="$(printf '%s' "$target" | tr 'abcdefghijklmnopqrstuvwxyz-' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_')"
    target_rustflags="CARGO_TARGET_${target_key}_RUSTFLAGS"
    build="$target_dir/$target/release/$executable"
    env -u NIX_LDFLAGS -u NIX_CFLAGS_COMPILE -u NIX_CC -u LD_LIBRARY_PATH -u LIBRARY_PATH \
        -u CARGO_BUILD_RUSTFLAGS -u CARGO_BUILD_TARGET \
        RUSTFLAGS= CARGO_ENCODED_RUSTFLAGS= CARGO_TARGET_DIR="$target_dir" CC=/usr/bin/cc CXX=/usr/bin/c++ \
        "$target_rustflags"= \
        "CARGO_TARGET_${target_key}_LINKER=/usr/bin/cc" \
        cargo build --locked --release --target "$target" \
            --config 'build.rustflags=[]' --config "target.$target.rustflags=[]" \
            --manifest-path "$manifest" >&2 || {
        kanata_error "Cargo could not build $executable for $target; install Rust with that target and native build dependencies, then retry"
        return 1
    }
    [[ -x "$build" ]] || { kanata_error "$executable build did not produce an executable"; return 1; }
    printf '%s\n' "$build"
}

kanata_linux_preflight_paths() {
    local arch="$1"
    if [[ "$arch" == 1 ]]; then
        sudo /bin/sh -c '
            for path in / /usr /usr/bin /etc /etc/systemd /etc/systemd/system; do
                [ -d "$path" ] && [ ! -L "$path" ] || { printf "required directory is unavailable: %s\n" "$path" >&2; exit 1; }
            done
        ' || { kanata_error 'Arch fixed target parent preflight failed'; return 1; }
    else
        sudo /bin/sh -c '
        for path in / /usr /etc /etc/systemd /etc/systemd/system; do
            [ -d "$path" ] && [ ! -L "$path" ] || { printf "required directory is unavailable: %s\n" "$path" >&2; exit 1; }
        done
        if [ -L /usr/local ]; then
            [ "$(readlink /usr/local)" = ../var/usrlocal ] && [ -d /var/usrlocal ] && [ ! -L /var/usrlocal ] || { printf "%s\n" "untrusted /usr/local symlink" >&2; exit 1; }
        else
            [ -d /usr/local ] || { printf "%s\n" "/usr/local is missing" >&2; exit 1; }
        fi
        ' || { kanata_error 'Linux fixed target parent preflight failed'; return 1; }
    fi
    if [[ "$arch" == 1 ]]; then
        kanata_root_dirs_preflight /etc/kanata /etc/polkit-1 /etc/polkit-1/rules.d || return 1
    else
        kanata_root_dirs_preflight /usr/local/bin /etc/kanata /etc/polkit-1 /etc/polkit-1/rules.d || return 1
    fi
    local -a target_files=(
        /etc/kanata/kanata.kbd \
        /etc/kanata/kanata-common.kbd \
        /etc/systemd/system/kanata.service \
        /etc/polkit-1/rules.d/50-kanata-controller.rules
    )
    [[ "$arch" == 1 ]] || target_files+=("$KANATA_SYSTEM_BINARY")
    kanata_root_files_preflight "${target_files[@]}"
}

kanata_linux_native_elf() {
    local binary="$1" interpreter required host sorted dynamic
    kanata_require_commands readelf getconf sort || return 1
    interpreter="$(readelf -W -l "$binary" | sed -n 's/.*Requesting program interpreter: \([^]]*\).*/\1/p')"
    [[ -n "$interpreter" && "$interpreter" != *'/nix/store/'* ]] || { kanata_error 'binary has no native Linux loader or depends on a Nix-store loader'; return 1; }
    dynamic="$(readelf -W -d "$binary" 2>/dev/null)" || return 1
    [[ "$dynamic" != *'/nix/store/'* ]] || { kanata_error 'binary embeds a Nix-store runtime search path'; return 1; }
    required="$(readelf --version-info "$binary" 2>/dev/null | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' | sort -Vu | tail -n 1 || true)"
    [[ -n "$required" ]] || return 0
    host="$(getconf GNU_LIBC_VERSION)"; host="${host##* }"
    required="${required#GLIBC_}"
    sorted="$(printf '%s\n%s\n' "$host" "$required" | sort -V | tail -n 1)"
    [[ "$sorted" == "$host" ]] || { kanata_error "binary requires GLIBC_$required; host provides $host"; return 1; }
}

kanata_linux_build_controller() {
    local work="$1" manifest="$DOTFILES_DIR/kanata/controller/Cargo.toml" build
    if ! kanata_require_commands cargo rustc readelf; then
        kanata_error 'prepare the Rust toolchain and binutils with your distribution tools, then rerun; no non-Arch package manager is invoked'
        return 1
    fi
    [[ -x /usr/bin/cc ]] || { kanata_error 'native /usr/bin/cc is required; install your distribution C compiler toolchain manually (for example build-essential), then rerun'; return 1; }
    build="$(kanata_linux_cargo_build "$manifest" "$work/controller-target" kanata-controller)" || return 1
    kanata_linux_native_elf "$build" || return 1
    printf '%s\n' "$build"
}

kanata_linux_build_source() {
    local work="$1" config="$2" source="$1/kanata-source" binary
    if ! kanata_require_commands git cargo rustc readelf getconf; then
        kanata_error 'prepare Git, the Rust toolchain, binutils, and glibc utilities with your distribution tools, then rerun; no non-Arch package manager is invoked'
        return 1
    fi
    [[ -x /usr/bin/cc ]] || { kanata_error 'native /usr/bin/cc is required; install your distribution C compiler toolchain manually (for example build-essential), then rerun'; return 1; }
    if ! git clone --quiet --depth 1 --branch "$KANATA_VERSION" "https://github.com/jtroo/kanata.git" "$source" >&2; then
        kanata_error "could not fetch Kanata source tag $KANATA_VERSION"
        return 1
    fi
    [[ "$(git -C "$source" describe --exact-match --tags HEAD 2>/dev/null)" == "$KANATA_VERSION" ]] || {
        kanata_error 'Kanata source checkout did not match the pinned release tag'
        return 1
    }
    binary="$(kanata_linux_cargo_build "$source/Cargo.toml" "$work/kanata-target" kanata)" || {
        kanata_error 'Kanata source compilation failed; software preparation may have installed build dependencies but no Kanata target was deployed'
        return 1
    }
    kanata_linux_native_elf "$binary" || return 1
    kanata_check_binary "$binary" "$config" "$KANATA_VERSION" || return 1
    printf '%s\n' "$binary"
}

# Return 10 for unavailable/incompatible precompiled runtime (source fallback
# is permitted); return 1 for integrity or configuration failures (stop).
kanata_linux_prebuilt() {
    local work="$1" config="$2" archive="$1/kanata.zip" candidate="$1/kanata-prebuilt" digest entries version
    [[ "$(uname -m)" == x86_64 ]] || return 10
    kanata_require_commands curl sha256sum unzip || return 10
    if ! curl -q --fail --location --silent --show-error --connect-timeout 15 --max-time 90 \
        --proto '=https' --tlsv1.2 --output "$archive" "$KANATA_LINUX_ARCHIVE_URL"; then
        kanata_error 'pinned precompiled download unavailable; trying the same-version source fallback'
        return 10
    fi
    digest="$(sha256sum "$archive")"; digest="${digest%% *}"
    if [[ "$digest" != "$KANATA_LINUX_ARCHIVE_SHA256" ]]; then
        kanata_error 'pinned precompiled SHA-256 mismatch; refusing the archive'
        return 1
    fi
    unzip -tqq "$archive" >&2 || { kanata_error 'verified release archive is not a valid zip'; return 1; }
    entries="$(unzip -Z1 "$archive")" || return 1
    [[ "$(printf '%s\n' "$entries" | grep -Fxc kanata_linux_x64)" == 1 ]] || {
        kanata_error 'pinned x86-64 release archive lacks its expected standard binary'
        return 1
    }
    unzip -p "$archive" kanata_linux_x64 >"$candidate" || return 1
    chmod 0700 "$candidate"
    if ! version="$("$candidate" --version 2>&1)"; then
        kanata_error "precompiled runtime incompatible; trying source fallback: ${version:0:250}"
        return 10
    fi
    kanata_version_matches "$version" "$KANATA_VERSION" || { kanata_error 'pinned precompiled binary reported an unexpected version'; return 1; }
    kanata_linux_native_elf "$candidate" || return 10
    kanata_check_binary "$candidate" "$config" "$KANATA_VERSION" || return 1
    printf '%s\n' "$candidate"
}

kanata_linux_select_binary() {
    local work="$1" config="$2" existing output status
    if [[ -x "$KANATA_SYSTEM_BINARY" ]]; then
        if output="$("$KANATA_SYSTEM_BINARY" --version 2>&1)"; then
            if ! kanata_version_matches "$output" "$KANATA_VERSION"; then
                kanata_info "existing Kanata is not $KANATA_VERSION; selecting a pinned replacement"
            elif ! kanata_linux_native_elf "$KANATA_SYSTEM_BINARY"; then
                kanata_info 'existing binary is not a compatible native Linux runtime; selecting a replacement' >&2
            else
                kanata_check_binary "$KANATA_SYSTEM_BINARY" "$config" "$KANATA_VERSION" || return 1
                printf '%s\n' "$KANATA_SYSTEM_BINARY"
                return 0
            fi
        else
            kanata_info 'existing system Kanata cannot start; trying pinned precompiled/source alternatives' >&2
        fi
    fi
    if output="$(kanata_linux_prebuilt "$work" "$config")"; then
        printf '%s\n' "$output"
        return 0
    else
        status=$?
        (( status == 10 )) || return 1
    fi
    kanata_linux_build_source "$work" "$config"
}

kanata_linux_service_state() {
    local scope="$1" unit="$2" load active
    if [[ "$scope" == user ]]; then
        load="$(systemctl --user show "$unit" -p LoadState --value)" || return 1
    else
        load="$(systemctl show "$unit" -p LoadState --value)" || return 1
    fi
    [[ "$load" == not-found ]] && { printf '%s\n' absent; return 0; }
    [[ "$load" == loaded ]] || { kanata_error "unexpected $unit LoadState: $load"; return 1; }
    if [[ "$scope" == user ]]; then
        active="$(systemctl --user show "$unit" -p ActiveState --value)" || return 1
    else
        active="$(systemctl show "$unit" -p ActiveState --value)" || return 1
    fi
    case "$active" in
    active|activating|reloading|deactivating) printf '%s\n' running ;;
    inactive|failed|maintenance) printf '%s\n' stopped ;;
    *) kanata_error "unexpected $unit ActiveState: $active"; return 1 ;;
    esac
}

kanata_linux_preflight() {
    local arch="$1" load group group_entry group_name
    kanata_require_commands sudo systemctl install mv cp cmp getent id readlink || return 1
    kanata_require_files \
        "$DOTFILES_DIR/kanata/services/linux/kanata.service" \
        "$DOTFILES_DIR/kanata/services/linux/kanata-controller.service" \
        "$DOTFILES_DIR/kanata/services/polkit/50-kanata-controller.rules" || return 1
    for group in input uinput; do
        group_entry="$(getent group "$group")" || { kanata_error "required system group is unavailable: $group"; return 1; }
        IFS=: read -r group_name _ <<<"$group_entry"
        [[ "$group_name" == "$group" ]] || { kanata_error "required system group is unavailable: $group"; return 1; }
    done
    [[ "$(id -u)" != 0 ]] || { kanata_error 'run as a normal user; sudo is used only for fixed root-owned deployment paths'; return 1; }
    systemctl --user show-environment >/dev/null || { kanata_error 'a logged-in systemd user manager is required for the tray controller'; return 1; }
    # Refuse, but never manage, a conflicting legacy per-user service.
    load="$(systemctl --user show kanata.service -p LoadState --value)" || return 1
    [[ "$load" == loaded || "$load" == not-found ]] || { kanata_error "unexpected user Kanata LoadState: $load"; return 1; }
    [[ "$load" != loaded ]] || { kanata_error 'legacy user kanata.service is loaded; disable/remove it manually before installing the system service'; return 1; }
    KANATA_LINUX_SYSTEM_STATE="$(kanata_linux_service_state system kanata.service)" || return 1
    KANATA_LINUX_CONTROLLER_STATE="$(kanata_linux_service_state user kanata-controller.service)" || return 1
    kanata_linux_preflight_paths "$arch" || return 1
    kanata_user_file_preflight "$HOME/.local/bin/kanata-controller" || return 1
    kanata_user_file_preflight "$HOME/.config/systemd/user/kanata-controller.service"
}

kanata_linux_install() (
    local work user binary runtime_binary controller system_unit user_unit polkit config root_dir
    local system_state controller_state arch=0 phase=prepare
    local -a root_dirs=()
    [[ "$(id -u)" != 0 ]] || { kanata_error 'run as a normal user; systemd runs Kanata as the configured user'; return 1; }
    work="$(kanata_make_tempdir)" || return 1
    trap '
        status=$?
        trap - EXIT
        if (( status != 0 )); then
            case "$phase" in
            prepare)
                if [[ -f /etc/arch-release ]]; then
                    kanata_error "Arch dependency preparation may have changed installed packages; no package rollback was attempted"
                else
                    kanata_error "Linux acquisition/build preparation failed; no Kanata target files or services were changed"
                fi
                ;;
            check) kanata_error "preflight failed before service changes or Kanata target writes" ;;
            stop) kanata_error "a managed systemd service may have stopped; target files are unchanged" ;;
            deploy) kanata_error "Linux target deployment may be partial; no rollback or service restoration was attempted" ;;
            start) kanata_error "targets were deployed; systemd startup may be partial and no rollback was attempted" ;;
            esac
        fi
        rm -rf -- "$work"
        exit "$status"
    ' EXIT
    kanata_linux_prepare_packages || return 1
    kanata_stage_config linux "$work/config" || return 1
    config="$work/config/kanata.kbd"
    user="$(id -un)"
    if kanata_is_arch_linux; then
        arch=1
        kanata_install_arch_packages || return 1
        binary=/usr/bin/kanata
        runtime_binary=/usr/bin/kanata
        kanata_check_binary "$binary" "$config" || return 1
    else
        binary="$(kanata_linux_select_binary "$work" "$config")" || return 1
        runtime_binary="$KANATA_SYSTEM_BINARY"
    fi
    controller="$(kanata_linux_build_controller "$work")" || return 1
    system_unit="$work/kanata.service"
    user_unit="$work/kanata-controller.service"
    polkit="$work/50-kanata-controller.rules"
    kanata_render_template "$DOTFILES_DIR/kanata/services/linux/kanata.service" "$system_unit" "$user" "$runtime_binary" /etc/kanata/kanata.kbd '' '' || return 1
    kanata_render_template "$DOTFILES_DIR/kanata/services/linux/kanata-controller.service" "$user_unit" '' '' '' "$HOME/.local/bin/kanata-controller" '' || return 1
    kanata_render_template "$DOTFILES_DIR/kanata/services/polkit/50-kanata-controller.rules" "$polkit" "$user" "$runtime_binary" /etc/kanata/kanata.kbd '' '' || return 1
    phase=check
    kanata_linux_preflight "$arch" || return 1
    system_state="$KANATA_LINUX_SYSTEM_STATE"
    controller_state="$KANATA_LINUX_CONTROLLER_STATE"
    sudo -v || { kanata_error 'sudo authorization is required for Linux system files'; return 1; }

    phase=stop
    if [[ "$controller_state" == running ]]; then
        systemctl --user stop kanata-controller.service || { kanata_error 'controller stop command failed; Kanata targets were not changed and its state may have changed'; return 1; }
    fi
    if [[ "$system_state" == running ]]; then
        sudo systemctl stop kanata.service || { kanata_error 'Kanata stop command failed; targets were not changed and its state may have changed'; return 1; }
    fi
    phase=deploy
    if [[ "$arch" == 1 ]]; then
        root_dirs=(/etc/kanata /etc/systemd/system /etc/polkit-1/rules.d)
    else
        root_dirs=(/usr/local/bin /etc/kanata /etc/systemd/system /etc/polkit-1/rules.d)
    fi
    for root_dir in "${root_dirs[@]}"; do
        kanata_root_ensure_dir "$root_dir" || { kanata_error "deployment failed at directory $root_dir"; return 1; }
    done
    if [[ "$arch" != 1 ]]; then
        kanata_root_install_file "$binary" "$KANATA_SYSTEM_BINARY" 0755 || { kanata_error 'binary deployment failed; inspect completed file operations'; return 1; }
    fi
    kanata_root_install_file "$config" /etc/kanata/kanata.kbd 0644 || { kanata_error 'configuration deployment failed'; return 1; }
    kanata_root_install_file "$work/config/kanata-common.kbd" /etc/kanata/kanata-common.kbd 0644 || { kanata_error 'common configuration deployment failed'; return 1; }
    kanata_root_install_file "$system_unit" /etc/systemd/system/kanata.service 0644 || { kanata_error 'system unit deployment failed'; return 1; }
    kanata_root_install_file "$polkit" /etc/polkit-1/rules.d/50-kanata-controller.rules 0644 || { kanata_error 'controller permission rule deployment failed'; return 1; }
    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" || { kanata_error 'user controller directory preparation failed'; return 1; }
    kanata_atomic_user_file "$controller" "$HOME/.local/bin/kanata-controller" 0755 || { kanata_error 'controller binary deployment failed'; return 1; }
    kanata_atomic_user_file "$user_unit" "$HOME/.config/systemd/user/kanata-controller.service" 0644 || { kanata_error 'controller unit deployment failed'; return 1; }
    sudo systemctl daemon-reload || { kanata_error 'system files installed but system daemon-reload failed'; return 1; }
    sudo systemctl enable kanata.service || { kanata_error 'files installed but system service enable failed'; return 1; }
    systemctl --user daemon-reload || { kanata_error 'system files installed but user daemon-reload failed'; return 1; }
    systemctl --user enable kanata-controller.service || { kanata_error 'files installed but controller enable failed'; return 1; }
    phase=start
    sudo systemctl start kanata.service || { kanata_error 'Linux files were deployed and enabled, but Kanata start failed'; return 1; }
    systemctl --user start kanata-controller.service || { kanata_error 'Kanata started, but its controller start failed'; return 1; }
    kanata_info 'Linux installation, enablement, and startup completed.'
)

kanata_macos_binary() {
    local prefix path
    command -v brew >/dev/null 2>&1 || return 1
    prefix="$(brew --prefix kanata 2>/dev/null)" || return 1
    [[ -n "$prefix" && "$prefix" != *'/nix/store/'* ]] || return 1
    path="$prefix/bin/kanata"
    [[ -f "$path" && -x "$path" ]] || return 1
    kanata_macos_native_binary "$path" || return 1
    printf '%s\n' "$path"
}

kanata_macos_require_build_tools() {
    local tool clt_path
    command -v brew >/dev/null 2>&1 || { kanata_error 'install Homebrew first; this script does not bootstrap Homebrew'; return 1; }
    for tool in cargo rustc; do
        command -v "$tool" >/dev/null 2>&1 || {
            kanata_error "Rust is required to build kanata-controller; install Rust (for example with rustup), then rerun"
            return 1
        }
    done
    command -v xcode-select >/dev/null 2>&1 || { kanata_error 'Apple Command Line Tools are required; install them with xcode-select --install'; return 1; }
    clt_path="$(xcode-select -p 2>/dev/null)" || { kanata_error 'Apple Command Line Tools are required; install them with xcode-select --install'; return 1; }
    [[ -n "$clt_path" && -x /usr/bin/clang && -x /usr/bin/clang++ ]] || { kanata_error 'Apple Command Line Tools are incomplete; install them with xcode-select --install'; return 1; }
}

kanata_macos_prepare_software() {
    brew install kanata libiconv >&2 || { kanata_error 'Homebrew could not install Kanata and libiconv'; return 1; }
}

kanata_macos_validate_vhid_binary() {
    local signature
    [[ -f "$KANATA_MACOS_VHID_BINARY" && ! -L "$KANATA_MACOS_VHID_BINARY" && -x "$KANATA_MACOS_VHID_BINARY" ]] || {
        kanata_error 'Karabiner VirtualHID daemon binary is missing, linked, or not executable'
        return 1
    }
    codesign --verify --strict --verbose=2 "$KANATA_MACOS_VHID_BINARY" >&2 || {
        kanata_error 'Karabiner VirtualHID daemon signature verification failed'
        return 1
    }
    signature="$(codesign -dv --verbose=4 "$KANATA_MACOS_VHID_BINARY" 2>&1)" || {
        kanata_error 'could not inspect the Karabiner VirtualHID daemon signature'
        return 1
    }
    grep -Fqx 'Identifier=org.pqrs.Karabiner-VirtualHIDDevice-Daemon' <<<"$signature" &&
        grep -Fqx 'TeamIdentifier=G43BCU2T37' <<<"$signature" || {
        kanata_error 'Karabiner VirtualHID daemon signature identity or Team ID did not match'
        return 1
    }
}

kanata_macos_stage_vhid_plist() {
    local destination="$1" template="$DOTFILES_DIR/kanata/services/macos/$KANATA_MACOS_VHID_LABEL.plist"
    kanata_require_files "$template" || return 1
    cp "$template" "$destination" || return 1
    grep -Fqx "    <string>$KANATA_MACOS_VHID_LABEL</string>" "$destination" || {
        kanata_error 'VirtualHID plist label did not match the fixed service label'
        return 1
    }
    grep -Fqx "        <string>$KANATA_MACOS_VHID_BINARY</string>" "$destination" || {
        kanata_error 'VirtualHID plist executable did not match the fixed vendor binary'
        return 1
    }
    plutil -lint "$destination" >/dev/null || { kanata_error 'VirtualHID plist validation failed'; return 1; }
}

kanata_macos_preflight_vhid_processes() {
    local output
    output="$(sudo ps -axo pid=,comm= 2>&1)" || {
        kanata_error "could not enumerate processes before VirtualHID refresh: ${output:0:240}"
        return 1
    }
}

kanata_macos_bootout_vhid() {
    local state="${1:-}" after
    [[ -n "$state" ]] || state="$(kanata_macos_query_job "system/$KANATA_MACOS_VHID_LABEL")" || return 1
    [[ "$state" == absent ]] && return 0
    kanata_macos_root_launchctl bootout "system/$KANATA_MACOS_VHID_LABEL" || {
        kanata_error 'could not unload the current VirtualHID launchd job'
        return 1
    }
    after="$(kanata_macos_query_job "system/$KANATA_MACOS_VHID_LABEL")" || return 1
    [[ "$after" == absent ]] || { kanata_error 'VirtualHID launchd job remained loaded after bootout'; return 1; }
}

kanata_macos_stop_manual_vhid() {
    local output line pid process attempt found
    if ! output="$(sudo ps -axo pid=,comm= 2>&1)"; then
        kanata_error "could not enumerate VirtualHID processes: ${output:0:240}"
        return 1
    fi
    found=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*([1-9][0-9]*)[[:space:]]+(.+)$ ]] || continue
        pid="${BASH_REMATCH[1]}"
        process="${BASH_REMATCH[2]}"
        [[ "$process" == "$KANATA_MACOS_VHID_BINARY" ]] || continue
        sudo kill -TERM "$pid" || { kanata_error "could not send TERM to the exact VirtualHID daemon PID $pid"; return 1; }
        found=1
    done <<<"$output"
    (( found )) || return 0
    for ((attempt = 0; attempt < 10; attempt++)); do
        sleep 1 || { kanata_error 'could not wait for the VirtualHID daemon to terminate'; return 1; }
        if ! output="$(sudo ps -axo pid=,comm= 2>&1)"; then
            kanata_error "could not recheck VirtualHID processes: ${output:0:240}"
            return 1
        fi
        found=0
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*[1-9][0-9]*[[:space:]]+(.+)$ ]] || continue
            process="${BASH_REMATCH[1]}"
            [[ "$process" == "$KANATA_MACOS_VHID_BINARY" ]] && found=1
        done <<<"$output"
        (( found == 0 )) && return 0
    done
    kanata_error 'the exact VirtualHID daemon did not terminate within 10 seconds; no KILL signal was sent'
    return 1
}

kanata_macos_verify_vhid_running() {
    local attempt state sockets
    for ((attempt = 0; attempt < 10; attempt++)); do
        state="$(kanata_macos_query_job "system/$KANATA_MACOS_VHID_LABEL")" || return 1
        if [[ "$state" == running ]] && sudo test -d "$KANATA_MACOS_VHID_SOCKET_DIR" && sudo test ! -L "$KANATA_MACOS_VHID_SOCKET_DIR"; then
            if ! sockets="$(sudo find "$KANATA_MACOS_VHID_SOCKET_DIR" -maxdepth 1 -type s -name '*.sock' -print 2>&1)"; then
                kanata_error "could not inspect VirtualHID sockets: ${sockets:0:240}"
                return 1
            fi
            [[ -n "$sockets" ]] && return 0
        fi
        sleep 1 || { kanata_error 'could not wait for the VirtualHID service readiness check'; return 1; }
    done
    kanata_error "VirtualHID did not become running with a direct UNIX socket under $KANATA_MACOS_VHID_SOCKET_DIR within 10 seconds"
    return 1
}

kanata_macos_bootstrap_vhid() {
    local domain="system/$KANATA_MACOS_VHID_LABEL" output status
    kanata_macos_root_launchctl enable "$domain" || { kanata_error 'could not enable the VirtualHID launchd job'; return 1; }
    if output="$(kanata_macos_root_launchctl bootstrap system "$KANATA_MACOS_VHID_PLIST" 2>&1)"; then
        :
    else
        status=$?
        if [[ "$output" == *disabled* || "$output" == *Disabled* ]]; then
            kanata_macos_root_launchctl enable "$domain" || { kanata_error 'could not re-enable the disabled VirtualHID launchd job'; return 1; }
            kanata_macos_root_launchctl bootstrap system "$KANATA_MACOS_VHID_PLIST" || { kanata_error 'VirtualHID bootstrap retry failed'; return 1; }
        else
            kanata_error "could not bootstrap the VirtualHID launchd job: ${output:0:240}"
            return "$status"
        fi
    fi
    kanata_macos_root_launchctl kickstart "$domain" || { kanata_error 'could not kickstart the VirtualHID daemon'; return 1; }
}

kanata_macos_install_vhid_daemon() {
    local staged="$1"
    kanata_root_install_file "$staged" "$KANATA_MACOS_VHID_PLIST" 0644 || { kanata_error 'VirtualHID plist deployment failed'; return 1; }
    kanata_macos_stop_manual_vhid || return 1
    kanata_macos_bootstrap_vhid || return 1
    kanata_macos_verify_vhid_running
}

kanata_macos_build_controller() {
    local work="$1" manifest="$DOTFILES_DIR/kanata/controller/Cargo.toml" host key iconv target_flags unit_separator encoded_flags binary
    kanata_require_files "$manifest" "$DOTFILES_DIR/kanata/controller/Cargo.lock" || return 1
    host="$(rustc -vV | sed -n 's/^host: //p')" || return 1
    [[ "$host" == *-apple-darwin ]] || { kanata_error "Rust host is not a native Apple target: $host"; return 1; }
    iconv="$(brew --prefix libiconv 2>/dev/null)" || { kanata_error 'Homebrew libiconv is required for the native controller link'; return 1; }
    [[ -n "$iconv" && "$iconv" != *'/nix/store/'* ]] || { kanata_error 'Homebrew returned an invalid libiconv prefix'; return 1; }
    key="$(printf '%s' "$host" | tr 'abcdefghijklmnopqrstuvwxyz-' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_')"
    target_flags="CARGO_TARGET_${key}_RUSTFLAGS"
    unit_separator=$'\x1f'
    encoded_flags="-C${unit_separator}link-arg=-L${iconv}/lib"
    binary="$work/controller-target/$host/release/kanata-controller"
    if ! env -u CARGO_BUILD_TARGET -u CARGO_BUILD_RUSTFLAGS -u "$target_flags" \
        CARGO_TARGET_DIR="$work/controller-target" CC=/usr/bin/clang CXX=/usr/bin/clang++ \
        CARGO_ENCODED_RUSTFLAGS="$encoded_flags" RUSTFLAGS= \
        "CARGO_TARGET_${key}_LINKER=/usr/bin/clang" \
        cargo build --locked --release --target "$host" --manifest-path "$manifest" >&2; then
        kanata_error 'Cargo could not build the native macOS tray controller'
        return 1
    fi
    [[ -x "$binary" ]] || { kanata_error 'macOS controller build did not produce an executable'; return 1; }
    kanata_macos_native_binary "$binary" || return 1
    printf '%s\n' "$binary"
}

kanata_macos_target_preflight() {
    sudo /bin/sh -c '
        for path in / /Library /Library/LaunchDaemons "/Library/Application Support"; do
            [ -d "$path" ] && [ ! -L "$path" ] || { printf "required directory is unavailable: %s\n" "$path" >&2; exit 1; }
        done
        if [ -L /etc ]; then
            target=$(readlink /etc)
            [ "$target" = private/etc ] || [ "$target" = /private/etc ] || { printf "%s\n" "untrusted /etc symlink" >&2; exit 1; }
            [ -d /private ] && [ -d /private/etc ] || exit 1
        else
            [ -d /etc ] || { printf "%s\n" "/etc is unavailable" >&2; exit 1; }
        fi
    ' || { kanata_error 'macOS fixed target parent preflight failed'; return 1; }
    kanata_root_dirs_preflight /usr/local /usr/local/libexec /etc/kanata /etc/sudoers.d || return 1
    kanata_root_files_preflight \
        /etc/kanata/kanata.kbd /etc/kanata/kanata-common.kbd \
        /Library/LaunchDaemons/dev.kanata.kanata.plist /usr/local/libexec/kanata-control /etc/sudoers.d/kanata-controller \
        "$KANATA_MACOS_VHID_PLIST"
}

kanata_macos_install() (
    local work source_binary controller config user runtime=/etc/kanata helper=/usr/local/libexec/kanata-control
    local sudoers=/etc/sudoers.d/kanata-controller system_plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
    local controller_plist controller_log task system_state controller_state vhid_state vhid_staged uid phase=prepare
    kanata_require_commands sudo launchctl brew otool plutil visudo id codesign find ps kill sleep || return 1
    [[ "$(id -u)" != 0 ]] || { kanata_error 'run as the logged-in user, not root'; return 1; }
    kanata_macos_require_build_tools || return 1
    work="$(kanata_make_tempdir)" || return 1
    trap '
        status=$?
        trap - EXIT
        if (( status != 0 )); then
            case "$phase" in
            prepare) kanata_error "Homebrew preparation may have changed installed software; no package rollback was attempted" ;;
            check) kanata_error "preflight failed before service changes or Kanata target writes; Homebrew preparation is not rolled back" ;;
            stop) kanata_error "a current managed launchd job may have been unloaded; target files are unchanged" ;;
            deploy) kanata_error "VHID or Kanata target deployment may be partial; no rollback was attempted, and any successfully started VHID daemon is retained" ;;
            start) kanata_error "targets were deployed; launchd startup may be partial, and the VHID dependency remains in place without rollback" ;;
            esac
        fi
        rm -rf -- "$work"
        exit "$status"
    ' EXIT
    kanata_macos_prepare_software || return 1
    source_binary="$(kanata_macos_binary)" || { kanata_error 'Homebrew preparation completed, but no runnable non-Nix Kanata binary was found'; return 1; }
    controller="$(kanata_macos_build_controller "$work")" || return 1
    phase=check
    user="$(id -un)"
    controller_plist="$HOME/Library/LaunchAgents/dev.kanata.controller.plist"
    controller_log="$HOME/.local/state/kanata-controller"
    kanata_require_files \
        "$DOTFILES_DIR/kanata/services/macos/dev.kanata.kanata.plist" \
        "$DOTFILES_DIR/kanata/services/macos/dev.kanata.controller.plist" \
        "$DOTFILES_DIR/kanata/services/macos/kanata-controller.sudoers.template" \
        "$DOTFILES_DIR/kanata/services/macos/$KANATA_MACOS_VHID_LABEL.plist" \
        "$DOTFILES_DIR/kanata/services/macos/kanata-control.sh" || return 1
    kanata_stage_config macos "$work/config" || return 1
    config="$work/config/kanata.kbd"
    kanata_check_binary "$source_binary" "$config" || return 1
    mkdir -p "$work/staged" || return 1
    kanata_render_template "$DOTFILES_DIR/kanata/services/macos/dev.kanata.kanata.plist" "$work/staged/kanata.plist" '' "$source_binary" "$runtime/kanata.kbd" '' '' || return 1
    kanata_render_template "$DOTFILES_DIR/kanata/services/macos/dev.kanata.controller.plist" "$work/staged/controller.plist" '' '' '' "$HOME/.local/bin/kanata-controller" "$controller_log" || return 1
    kanata_render_template "$DOTFILES_DIR/kanata/services/macos/kanata-controller.sudoers.template" "$work/staged/sudoers" "$user" '' '' '' '' || return 1
    plutil -lint "$work/staged/kanata.plist" "$work/staged/controller.plist" >/dev/null || return 1
    visudo -c -f "$work/staged/sudoers" >/dev/null || return 1
    vhid_staged="$work/staged-$KANATA_MACOS_VHID_LABEL.plist"
    kanata_macos_validate_vhid_binary || return 1
    kanata_macos_stage_vhid_plist "$vhid_staged" || return 1
    kanata_macos_target_preflight || return 1
    for task in "$HOME/.config/kanata/kanata.kbd" "$HOME/.config/kanata/kanata-common.kbd" \
        "$HOME/.local/bin/kanata-controller" "$controller_plist"; do
        kanata_user_file_preflight "$task" || return 1
    done
    if [[ -L "$controller_log" || ( -e "$controller_log" && ! -d "$controller_log" ) ]]; then
        kanata_error "controller log target is not a regular directory: $controller_log"
        return 1
    fi
    sudo -v || { kanata_error 'sudo authorization is required for fixed macOS system files'; return 1; }
    system_state="$(kanata_macos_query_job system/dev.kanata.kanata)" || return 1
    uid="$(id -u)"
    controller_state="$(kanata_macos_query_job "gui/$uid/dev.kanata.controller")" || return 1
    vhid_state="$(kanata_macos_query_job "system/$KANATA_MACOS_VHID_LABEL")" || return 1
    kanata_macos_preflight_vhid_processes || return 1

    phase=stop
    if [[ "$controller_state" != absent ]]; then
        kanata_macos_launchctl bootout "gui/$uid" "$controller_plist" || { kanata_error 'controller unload/stop failed before deployment; targets are unchanged and its state may have changed'; return 1; }
    fi
    if [[ "$system_state" != absent ]]; then
        kanata_macos_root_launchctl bootout system "$system_plist" || { kanata_error 'Kanata unload/stop failed before deployment; targets are unchanged and its state may have changed'; return 1; }
    fi
    phase=deploy
    kanata_macos_bootout_vhid "$vhid_state" || return 1
    kanata_macos_install_vhid_daemon "$vhid_staged" || return 1
    for task in "$runtime" /usr/local/libexec /etc/sudoers.d; do
        kanata_root_ensure_dir "$task" || return 1
    done
    kanata_root_install_file "$work/config/kanata.kbd" "$runtime/kanata.kbd" 0644 || { kanata_error 'Kanata configuration deployment failed'; return 1; }
    kanata_root_install_file "$work/config/kanata-common.kbd" "$runtime/kanata-common.kbd" 0644 || { kanata_error 'common configuration deployment failed'; return 1; }
    kanata_root_install_file "$work/staged/kanata.plist" "$system_plist" 0644 || { kanata_error 'Kanata launchd definition deployment failed'; return 1; }
    kanata_root_install_file "$DOTFILES_DIR/kanata/services/macos/kanata-control.sh" "$helper" 0755 || { kanata_error 'Kanata control helper deployment failed'; return 1; }
    kanata_root_install_file "$work/staged/sudoers" "$sudoers" 0440 || { kanata_error 'controller authorization rule deployment failed'; return 1; }
    mkdir -p "$HOME/.config/kanata" "$HOME/.local/bin" "$HOME/Library/LaunchAgents" "$controller_log" || { kanata_error 'user Kanata directory preparation failed'; return 1; }
    kanata_atomic_user_file "$work/config/kanata.kbd" "$HOME/.config/kanata/kanata.kbd" 0644 || { kanata_error 'user Kanata configuration deployment failed'; return 1; }
    kanata_atomic_user_file "$work/config/kanata-common.kbd" "$HOME/.config/kanata/kanata-common.kbd" 0644 || { kanata_error 'user common configuration deployment failed'; return 1; }
    kanata_atomic_user_file "$controller" "$HOME/.local/bin/kanata-controller" 0755 || { kanata_error 'user controller binary deployment failed'; return 1; }
    kanata_atomic_user_file "$work/staged/controller.plist" "$controller_plist" 0644 || { kanata_error 'controller launch agent deployment failed'; return 1; }
    phase=start
    kanata_macos_root_launchctl enable system/dev.kanata.kanata || { kanata_error 'files installed but launchd could not enable Kanata'; return 1; }
    kanata_macos_launchctl enable "gui/$(id -u)/dev.kanata.controller" || { kanata_error 'files installed but launchd could not enable the tray controller'; return 1; }
    kanata_macos_root_launchctl bootstrap system "$system_plist" || { kanata_error 'Kanata plist deployed and enabled, but launchd bootstrap failed'; return 1; }
    kanata_macos_root_launchctl kickstart system/dev.kanata.kanata || { kanata_error 'Kanata plist deployed and enabled, but Kanata did not start'; return 1; }
    kanata_macos_launchctl bootstrap "gui/$uid" "$controller_plist" || { kanata_error 'Kanata started, but the controller plist could not be bootstrapped'; return 1; }
    kanata_macos_launchctl kickstart -k "gui/$uid/dev.kanata.controller" || { kanata_error 'Kanata started, but the controller did not start'; return 1; }
    kanata_info 'macOS installation, enablement, and startup completed; approve Input Monitoring/Accessibility and DriverKit manually if prompted.'
)


kanata_windows_task_dir_preflight() {
    local data_dir="$1" parent="${2:-}"
    [[ -n "$parent" ]] || parent="$(kanata_windows_localappdata)" || return 1
    [[ "$parent" == /* && -d "$parent" && ! -L "$parent" && "$data_dir" == "$parent/kanata" ]] || {
        kanata_error 'Windows Kanata data directory must be a direct child of LOCALAPPDATA'
        return 1
    }
    [[ ! -L "$data_dir" && ( ! -e "$data_dir" || -d "$data_dir" ) ]] || {
        kanata_error 'Windows Kanata working directory is not a safe directory path'
        return 1
    }
}

kanata_windows_prepare_software() {
    command -v winget >/dev/null 2>&1 || { kanata_error 'WinGet is required; install it from Microsoft Store before running this installer'; return 1; }
    winget install --exact --id jtroo.kanata_gui --source winget \
        --accept-source-agreements --accept-package-agreements >&2 || {
        kanata_error 'WinGet could not install or verify jtroo.kanata_gui'
        return 1
    }
}

kanata_windows_render_task() {
    local template="$1" destination="$2" user="$3" command_path="$4" arguments="$5" working="$6"
    KANATA_XML_TEMPLATE="$(cygpath -w -a -- "$template")" \
    KANATA_XML_DESTINATION="$(cygpath -w -a -- "$destination")" \
    KANATA_TASK_USER="$user" KANATA_TASK_COMMAND="$command_path" \
    KANATA_TASK_ARGUMENTS="$arguments" KANATA_TASK_WORKING_DIRECTORY="$working" \
        powershell.exe -NoProfile -NonInteractive -Command '
        function Escape([string] $value) { return [System.Security.SecurityElement]::Escape($value) }
        $template = Get-Content -LiteralPath $env:KANATA_XML_TEMPLATE -Raw -ErrorAction Stop
        $values = @{ "__TASK_USER__"=$env:KANATA_TASK_USER; "__COMMAND__"=$env:KANATA_TASK_COMMAND; "__ARGUMENTS__"=$env:KANATA_TASK_ARGUMENTS; "__WORKING_DIRECTORY__"=$env:KANATA_TASK_WORKING_DIRECTORY }
        if ($values["__COMMAND__"] -notmatch "^[A-Za-z]:\\" -or -not (Test-Path -LiteralPath $values["__COMMAND__"] -PathType Leaf)) { throw "Kanata executable path is invalid" }
        $workingDirectory = $values["__WORKING_DIRECTORY__"]
        if ($workingDirectory -notmatch "^[A-Za-z]:\\") { throw "Kanata working directory must be absolute" }
        $workingParent = Split-Path -Parent $workingDirectory
        if (-not (Test-Path -LiteralPath $workingParent -PathType Container)) { throw "Kanata working parent does not exist" }
        if ((Test-Path -LiteralPath $workingDirectory) -and -not (Test-Path -LiteralPath $workingDirectory -PathType Container)) { throw "Kanata working path is not a directory" }
        if ($values["__ARGUMENTS__"] -notmatch "[A-Za-z]:\\") { throw "Kanata config path is invalid" }
        foreach ($key in $values.Keys) { $template = $template.Replace($key, (Escape $values[$key])) }
        if ($template -match "__[A-Z_]+__") { throw "unresolved Kanata task template value" }
        if ($template -notmatch "<LogonTrigger>") { throw "task must be logon-triggered" }
        $template = $template.Replace("encoding=""UTF-8""", "encoding=""UTF-16""")
        Set-Content -LiteralPath $env:KANATA_XML_DESTINATION -Value $template -Encoding Unicode -ErrorAction Stop
    '
}

kanata_windows_install() (
    local work binary existing version config user cfg_win binary_win work_win task_file data_dir config_dest common_dest local_appdata task_state task_status
    local phase=prepare
    kanata_require_commands powershell.exe schtasks.exe cygpath find sleep || return 1
    [[ -n "${LOCALAPPDATA:-}" && -n "${USERDOMAIN:-}" && -n "${USERNAME:-}" ]] || { kanata_error 'LOCALAPPDATA, USERDOMAIN and USERNAME are required'; return 1; }
    if [[ "$(powershell.exe -NoProfile -NonInteractive -Command '[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' 2>/dev/null | tr -d '\r\n')" != True ]]; then
        kanata_error 'run Git Bash as Administrator to register the elevated current-user Kanata task'
        return 1
    fi
    local_appdata="$(kanata_windows_localappdata)" || return 1
    work="$(kanata_make_tempdir)" || return 1
    trap '
        status=$?
        trap - EXIT
        if (( status != 0 )); then
            case "$phase" in
            prepare) kanata_error "WinGet preparation may have changed installed software; no package rollback was attempted" ;;
            check) kanata_error "preflight failed before task/file changes; any earlier package preparation is not rolled back" ;;
            stop) kanata_error "the current task may have stopped; target files are unchanged" ;;
            deploy) kanata_error "Windows configuration/task-folder deployment may be partial; no rollback was attempted" ;;
            start) kanata_error "the task is registered but may not be running" ;;
            esac
        fi
        rm -rf -- "$work"
        exit "$status"
    ' EXIT
    binary=''
    if existing="$(kanata_find_binary windows "$local_appdata")" && version="$("$existing" --version 2>&1)"; then
        binary="$existing"
    else
        if ! command -v winget >/dev/null 2>&1; then
            phase=check
            kanata_error 'WinGet is required to prepare Kanata; install it from Microsoft Store first'
            return 1
        fi
        kanata_windows_prepare_software || return 1
        binary="$(kanata_find_binary windows "$local_appdata")" || { kanata_error 'WinGet completed, but no unique Kanata GUI binary was found under LOCALAPPDATA'; return 1; }
        version="$("$binary" --version 2>&1)" || { kanata_error "WinGet completed, but the discovered Kanata GUI binary is not runnable: ${version:0:240}"; return 1; }
    fi
    phase=check
    kanata_require_files "$DOTFILES_DIR/kanata/services/windows/Dotfiles-Kanata.xml" || return 1
    kanata_stage_config windows "$work/config" || return 1
    cfg_win="$(cygpath -w -- "$work/config/kanata.kbd")"
    kanata_check_binary "$binary" "$cfg_win" || return 1
    data_dir="$local_appdata/kanata"; config_dest="$data_dir/kanata.kbd"; common_dest="$data_dir/kanata-common.kbd"
    user="$(powershell.exe -NoProfile -NonInteractive -Command '[Security.Principal.WindowsIdentity]::GetCurrent().Name' 2>/dev/null | tr -d '\r\n')"
    [[ -n "$user" ]] || { kanata_error 'could not determine the current Windows user'; return 1; }
    kanata_windows_task_dir_preflight "$data_dir" "$local_appdata" || return 1
    kanata_user_file_preflight "$config_dest" || return 1
    kanata_user_file_preflight "$common_dest" || return 1
    binary_win="$(cygpath -w -a -- "$binary")"; cfg_win="$(cygpath -w -a -- "$config_dest")"; work_win="$(cygpath -w -a -- "$data_dir")"
    task_file="$work/Dotfiles-Kanata.xml"
    kanata_windows_render_task "$DOTFILES_DIR/kanata/services/windows/Dotfiles-Kanata.xml" "$task_file" "$user" "$binary_win" "--cfg \"$cfg_win\"" "$work_win" || return 1
    if task_state="$(kanata_windows_task_query)"; then
        :
    else
        task_status=$?
        (( task_status == 1 )) || { kanata_error 'could not reliably query Kanata task; refusing installation'; return 1; }
        task_state=NOT_FOUND
    fi
    phase=stop
    if [[ "$task_state" == 3 || "$task_state" == 4 ]]; then
        kanata_windows_schtasks //End //TN '\Dotfiles\Kanata' || { kanata_error 'Kanata task stop command failed; target files are unchanged and task state may have changed'; return 1; }
        kanata_windows_task_wait_stopped || { kanata_error 'Kanata task did not reach a confirmed stopped state; target files were not changed'; return 1; }
    fi
    phase=deploy
    mkdir -p "$data_dir" || { kanata_error 'could not prepare the current-user Kanata data directory'; return 1; }
    kanata_atomic_user_file "$work/config/kanata.kbd" "$config_dest" 0644 || { kanata_error 'Kanata configuration deployment failed'; return 1; }
    kanata_atomic_user_file "$work/config/kanata-common.kbd" "$common_dest" 0644 || { kanata_error 'common configuration deployment failed'; return 1; }
    powershell.exe -NoProfile -NonInteractive -Command '
        $ErrorActionPreference = "Stop"
        $service = New-Object -ComObject Schedule.Service
        $service.Connect()
        try { $service.GetFolder("\Dotfiles") | Out-Null }
        catch {
            $exception = $_.Exception
            while ($null -ne $exception) {
                $code = [long]$exception.HResult
                if ($code -eq -2147024894 -or $code -eq -2147216625) {
                    $service.GetFolder("\").CreateFolder("Dotfiles") | Out-Null
                    exit 0
                }
                $exception = $exception.InnerException
            }
            throw
        }' || { kanata_error 'configuration files were deployed, but the fixed Kanata task folder could not be prepared'; return 1; }
    kanata_windows_schtasks //Create //TN '\Dotfiles\Kanata' //XML "$(cygpath -w -a -- "$task_file")" //F || { kanata_error 'configuration files were deployed, but task registration failed'; return 1; }
    phase=start
    kanata_windows_schtasks //Run //TN '\Dotfiles\Kanata' || { kanata_error 'task was registered but Kanata did not start'; return 1; }
    kanata_info 'Windows installation, task registration, and startup completed.'
)

kanata_install_main() {
    local target="${1:-}"
    [[ $# == 1 ]] || { kanata_error 'installer requires exactly one platform target'; return 2; }
    target="$(kanata_resolve_target "$target")" || return 2
    kanata_require_host_target "$target" || return 2
    case "$target" in
    linux) kanata_linux_install ;;
    macos) kanata_macos_install ;;
    windows) kanata_windows_install ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    kanata_install_main "$@"
fi
