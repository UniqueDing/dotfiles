#!/usr/bin/env bash

# Independent Kanata installer. Home Manager deliberately does not
# own any of these packages, configuration files, or services.

if [[ -z "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

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
        Deepin|deepin) printf '%s\n' deepin-x11 ;;
        Arch|arch|EndeavourOS) printf '%s\n' arch-x11 ;;
        *)
            printf '%s\n' 'error: specify a kanata target (deepin-x11, arch-x11, arch-kde, macos, windows)' >&2
            return 1
            ;;
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
    local temporary_destination
    local line
    temporary_destination="$(mktemp "$(dirname -- "$destination")/.kanata-unit.XXXXXX")" || return 1
    if ! {
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//__KANATA_EXECUTABLE__/$kanata_exec}"
        line="${line//__KANATA_CONFIG__/$kanata_config}"
        line="${line//__KANATA_USER__/$kanata_user}"
        printf '%s\n' "$line"
    done < "$source" > "$temporary_destination"
    chmod 0644 "$temporary_destination"
    mv -f "$temporary_destination" "$destination"
    }; then
        rm -f "$temporary_destination"
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
    deepin-x11)
        local nix_profile="$HOME/.local/state/nix/profiles/kanata"
        mkdir -p "$(dirname -- "$nix_profile")"
        nix profile add --profile "$nix_profile" nixpkgs#kanata
        executable="$(readlink -f "$HOME/.local/state/nix/profiles/kanata/bin/kanata")"
        [[ "$(stat -c %U "$executable")" == "$(id -un)" ]] || {
            printf '%s\n' 'error: Deepin Kanata executable must be owned by the current user' >&2
            return 1
        }
        ;;
    arch-x11|arch-kde)
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
    local kanata_exec="$1" kanata_user="$2"
    KANATA_TXN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-kanata.XXXXXX")" || return 1
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/systemd/kanata.service" "$KANATA_TXN_DIR/kanata.service" "$kanata_exec" /etc/kanata/kanata.kbd "$kanata_user" || return 1
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/polkit/50-kanata-controller.rules" "$KANATA_TXN_DIR/50-kanata-controller.rules" "$kanata_exec" /etc/kanata/kanata.kbd "$kanata_user" || return 1
    cp "$DOTFILES_DIR/conf/kanata/kanata-linux.kbd" "$KANATA_TXN_DIR/kanata.kbd" || return 1
    kanata_reject_unresolved_placeholders "$KANATA_TXN_DIR/kanata.service" "$KANATA_TXN_DIR/50-kanata-controller.rules" || { printf '%s\n' 'error: unresolved template placeholder' >&2; return 1; }
    "$kanata_exec" --check --cfg "$KANATA_TXN_DIR/kanata.kbd" || return 1
    systemd-analyze verify "$KANATA_TXN_DIR/kanata.service"
}

kanata_snapshot_root_file() {
    local destination="$1" name="$2"
    if sudo test -e "$destination"; then
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

kanata_restore_root_file() {
    local destination="$1" name="$2" present meta mode owner group temporary
    eval "present=\${KANATA_ROOT_PRESENT_$name:-0}"
    if (( ! present )); then sudo rm -f "$destination"; return; fi
    meta="$(<"$KANATA_TXN_DIR/$name.meta")" || return 1
    IFS=: read -r mode owner group <<<"$meta"
    temporary="$(dirname -- "$destination")/.${destination##*/}.kanata-restore.$$"
    sudo install -o "$owner" -g "$group" -m "$mode" "$KANATA_TXN_DIR/$name.old" "$temporary" && sudo mv -f "$temporary" "$destination"
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

kanata_snapshot_user_unit() {
    local name="$1" path="$HOME/.config/systemd/user/$1"
    if [[ -e "$path" ]]; then cp -a "$path" "$KANATA_TXN_DIR/$name.old" && printf 1 >"$KANATA_TXN_DIR/$name.present"; else printf 0 >"$KANATA_TXN_DIR/$name.present"; fi
}

kanata_restore_user_unit() {
    local name="$1" path="$HOME/.config/systemd/user/$1"
    if [[ "$(<"$KANATA_TXN_DIR/$name.present")" == 1 ]]; then mkdir -p "$(dirname -- "$path")" && cp -a "$KANATA_TXN_DIR/$name.old" "$path"; else rm -f "$path"; fi
}

kanata_restore_service_state() {
    local scope="$1" unit="$2" load="$3" active="$4" enabled="$5" command_prefix=()
    if [[ "$scope" == system ]]; then
        command_prefix=(sudo systemctl)
    else
        command_prefix=(systemctl --user)
    fi
    # A newly created system unit can remain active after its file is removed;
    # stop it when the pre-migration unit did not exist.
    [[ "$load" != not-found ]] || { "${command_prefix[@]}" stop "$unit"; return; }
    if (( enabled )); then "${command_prefix[@]}" enable "$unit"; else "${command_prefix[@]}" disable "$unit"; fi
    if (( active )); then "${command_prefix[@]}" start "$unit"; else "${command_prefix[@]}" stop "$unit"; fi
}

kanata_rollback() {
    local failed=0
    kanata_restore_root_file /etc/kanata/kanata.kbd config || failed=1
    kanata_restore_root_file /etc/systemd/system/kanata.service system_unit || failed=1
    kanata_restore_root_file /etc/polkit-1/rules.d/50-kanata-controller.rules polkit || failed=1
    sudo systemctl daemon-reload || failed=1
    kanata_restore_user_unit kanata.service || failed=1
    kanata_restore_user_unit kanata-tray.service || failed=1
    systemctl --user daemon-reload || failed=1
    kanata_restore_service_state system kanata.service "$KANATA_SYSTEM_LOAD" "$KANATA_SYSTEM_ACTIVE" "$KANATA_SYSTEM_ENABLED" || failed=1
    kanata_restore_service_state user kanata.service "$KANATA_USER_LOAD" "$KANATA_USER_ACTIVE" "$KANATA_USER_ENABLED" || failed=1
    kanata_restore_service_state user kanata-tray.service "$KANATA_TRAY_LOAD" "$KANATA_TRAY_ACTIVE" "$KANATA_TRAY_ENABLED" || failed=1
    (( ! failed )) || { printf '%s\n' 'error: rollback failed: one or more files or service states could not be restored' >&2; return 1; }
}

kanata_transaction_exit() {
    local status="$1"
    if [[ "${KANATA_TXN_COMMITTED:-0}" != 1 ]]; then kanata_rollback || status=1; fi
    rm -rf -- "${KANATA_TXN_DIR:-}"
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
    # The legacy tray owns an old Kanata process, so it must stop first.
    (( KANATA_TRAY_ACTIVE )) && systemctl --user stop kanata-tray.service || [[ "$KANATA_TRAY_ACTIVE" == 0 ]] || return 1
    (( KANATA_TRAY_ENABLED )) && systemctl --user disable kanata-tray.service || [[ "$KANATA_TRAY_ENABLED" == 0 ]] || return 1
    (( KANATA_USER_ACTIVE )) && systemctl --user stop kanata.service || [[ "$KANATA_USER_ACTIVE" == 0 ]] || return 1
    if (( KANATA_SYSTEM_ACTIVE )); then sudo systemctl restart kanata.service; else sudo systemctl start kanata.service; fi || return 1
    kanata_verify_system_kanata "$kanata_exec" || return 1
    (( KANATA_USER_ENABLED )) && systemctl --user disable kanata.service || [[ "$KANATA_USER_ENABLED" == 0 ]] || return 1
    rm -f "$HOME/.config/systemd/user/kanata.service" "$HOME/.config/systemd/user/kanata-tray.service" || return 1
    systemctl --user daemon-reload || return 1
    sudo systemctl enable kanata.service
}

install_kanata_system() (
    local target="${1:-}" kanata_exec kanata_user
    [[ "$(uname -s)" == Linux && "$(id -u)" -ne 0 ]] || { printf '%s\n' 'error: kanata system migration must run on Linux as the interactive user, not root' >&2; return 1; }
    target="${target:-$(kanata_target)}"
    [[ "$target" =~ ^(deepin-x11|arch-x11|arch-kde)$ ]] || { printf '%s\n' 'error: kanata system migration is Linux-only' >&2; return 1; }
    kanata_user="$(id -un)"; kanata_safe_user "$kanata_user" || { printf '%s\n' 'error: current username is unsafe for policy rendering' >&2; return 1; }
    kanata_exec="$(kanata_system_executable "$target")" || return 1
    kanata_prepare_system_files "$kanata_exec" "$kanata_user" || { rm -rf -- "${KANATA_TXN_DIR:-}"; return 1; }
    kanata_snapshot_root_file /etc/kanata/kanata.kbd config && kanata_snapshot_root_file /etc/systemd/system/kanata.service system_unit && kanata_snapshot_root_file /etc/polkit-1/rules.d/50-kanata-controller.rules polkit && kanata_query_service system kanata.service KANATA_SYSTEM && kanata_query_service user kanata.service KANATA_USER && kanata_query_service user kanata-tray.service KANATA_TRAY && kanata_snapshot_user_unit kanata.service && kanata_snapshot_user_unit kanata-tray.service || { rm -rf -- "$KANATA_TXN_DIR"; return 1; }
    KANATA_TXN_COMMITTED=0; trap 'kanata_transaction_exit $?' EXIT HUP INT TERM
    sudo install -d -o root -g root -m 0755 /etc/kanata && kanata_install_root_file "$KANATA_TXN_DIR/kanata.kbd" /etc/kanata/kanata.kbd && kanata_install_root_file "$KANATA_TXN_DIR/kanata.service" /etc/systemd/system/kanata.service && kanata_install_root_file "$KANATA_TXN_DIR/50-kanata-controller.rules" /etc/polkit-1/rules.d/50-kanata-controller.rules && sudo systemctl daemon-reload && kanata_cutover_system_service "$kanata_exec" || return 1
    KANATA_TXN_COMMITTED=1
)

kanata_macos_run() {
    kanata_run_without_nix "$@"
}

install_kanata_macos() (
    set -e
    [[ "$(uname -s)" == Darwin ]] || { printf '%s\n' 'error: macos target must run on macOS' >&2; exit 1; }
    kanata_macos_run brew install kanata
    local kanata_binary
    kanata_binary="$(kanata_macos_run brew --prefix kanata)/bin/kanata"
    local config_dir="$HOME/.config/kanata"
    local config="$config_dir/kanata.kbd"
    mkdir -p "$config_dir"
    install -m 0644 "$DOTFILES_DIR/conf/kanata/kanata-macos.kbd" "$config"

    local plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
    local temporary_plist
    temporary_plist="$(mktemp)"
    trap 'rm -f "$temporary_plist"' EXIT
    kanata_render_unit "$DOTFILES_DIR/conf/kanata/macos/dev.kanata.kanata.plist" \
        "$temporary_plist" "$kanata_binary" "$config"
    kanata_macos_run sudo install -o root -g wheel -m 0644 "$temporary_plist" "$plist"
    kanata_macos_run sudo launchctl bootout system/dev.kanata.kanata >/dev/null 2>&1 || true
    kanata_macos_run sudo launchctl bootstrap system "$plist"
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
    deepin-x11|arch-x11|arch-kde) install_kanata_system "$target" ;;
    macos) install_kanata_macos ;;
    windows) install_kanata_windows ;;
    *) printf 'error: unknown kanata target %s\n' "$target" >&2; return 1 ;;
    esac
}
