#!/usr/bin/env bash
set -euo pipefail

# Maintains the repository's Kanata installation. This script deliberately
# does not migrate or remove other keyboard remappers.
DOTFILES_DIR="${DOTFILES_DIR:-$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
KANATA_VERSION=v1.12.0
KANATA_SYSTEM_BINARY=/usr/local/bin/kanata

kanata_error() { printf 'kanata: error: %s\n' "$*" >&2; }
kanata_info() { printf 'kanata: %s\n' "$*" >&2; }

kanata_usage() {
    cat <<'EOF'
Usage: kanata/kanata.sh <install|check|start|stop|restart|status> [target]

Targets: linux, macos, windows (legacy Linux aliases: arch, other)
Install prepares the platform software, deploys the current configuration,
enables managed startup definitions, and starts Kanata/controller. Other actions are explicit.
EOF
}

kanata_require_commands() {
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null 2>&1 || {
            kanata_error "required command is missing: $command_name"
            return 1
        }
    done
}

kanata_version_matches() {
    local text="$1" expected="${2#v}"
    [[ "$text" =~ (^|[^[:alnum:].])v?([0-9]+\.[0-9]+\.[0-9]+)($|[[:space:],:]) ]] || return 1
    [[ "${BASH_REMATCH[2]}" == "$expected" ]]
}

kanata_windows_localappdata() {
    local path
    [[ -n "${LOCALAPPDATA:-}" ]] || { kanata_error 'LOCALAPPDATA is not set'; return 1; }
    kanata_require_commands cygpath || return 1
    path="$(cygpath -u -a -- "$LOCALAPPDATA")" || { kanata_error 'could not normalize LOCALAPPDATA'; return 1; }
    [[ "$path" == /* && "$path" != *$'\n'* && "$path" != / ]] || {
        kanata_error 'LOCALAPPDATA did not normalize to a POSIX absolute path'
        return 1
    }
    printf '%s\n' "$path"
}

kanata_macos_native_binary() {
    local candidate="$1" dependencies
    kanata_require_commands otool || return 1
    [[ "$candidate" != *'/nix/store/'* ]] || { kanata_error 'Nix-store macOS dependencies are not accepted'; return 1; }
    dependencies="$(otool -L "$candidate" 2>&1)" || { kanata_error "otool could not inspect macOS binary: $candidate"; return 1; }
    [[ "$dependencies" != *'/nix/store/'* ]] || { kanata_error "Nix-store runtime dependency is not accepted: $candidate"; return 1; }
}

kanata_platform() {
    case "$(uname -s)" in
    Linux) printf '%s\n' linux ;;
    Darwin) printf '%s\n' macos ;;
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' windows ;;
    *) kanata_error "unsupported operating system: $(uname -s)"; return 1 ;;
    esac
}

kanata_is_arch_linux() {
    [[ "$(uname -s)" == Linux && -f /etc/arch-release ]]
}

kanata_resolve_target() {
    local target="${1:-$(kanata_platform)}"
    case "$target" in
    arch|other|linux) target=linux ;;
    macos|windows) ;;
    *) kanata_error "unknown target: $target"; return 1 ;;
    esac
    printf '%s\n' "$target"
}

kanata_require_host_target() {
    local target="$1" host
    host="$(kanata_platform)" || return 1
    [[ "$target" == "$host" ]] || {
        kanata_error "$target actions must run on a $target host (current host: $host)"
        return 1
    }
}

kanata_make_tempdir() {
    local directory
    directory="$(mktemp -d "${TMPDIR:-/tmp}/kanata.XXXXXX")" || return 1
    chmod 0700 "$directory" || return 1
    printf '%s\n' "$directory"
}

kanata_stage_config() {
    local platform="$1" directory="$2" source
    case "$platform" in
    linux) source="$DOTFILES_DIR/kanata/config/kanata-linux.kbd" ;;
    macos) source="$DOTFILES_DIR/kanata/config/kanata-macos.kbd" ;;
    windows) source="$DOTFILES_DIR/kanata/config/kanata-windows.kbd" ;;
    *) return 1 ;;
    esac
    [[ -f "$source" && ! -L "$source" && -f "$DOTFILES_DIR/kanata/config/kanata-common.kbd" && ! -L "$DOTFILES_DIR/kanata/config/kanata-common.kbd" ]] || {
        kanata_error "configuration source is missing or unsafe for $platform"
        return 1
    }
    mkdir -p -- "$directory" || return 1
    install -m 0600 "$source" "$directory/kanata.kbd" || return 1
    install -m 0600 "$DOTFILES_DIR/kanata/config/kanata-common.kbd" "$directory/kanata-common.kbd" || return 1
}

kanata_check_binary() {
    local binary="$1" config="$2" version expected="${3:-}"
    [[ -f "$binary" && -x "$binary" ]] || { kanata_error "Kanata executable is not available: $binary"; return 1; }
    if ! version="$("$binary" --version 2>&1)"; then
        kanata_error "Kanata --version failed: ${version:0:300}"
        return 1
    fi
    if [[ -n "$expected" ]] && ! kanata_version_matches "$version" "$expected"; then
        kanata_error "unexpected Kanata version; expected $expected"
        return 1
    fi
    "$binary" --check --cfg "$config" >&2 || {
        kanata_error "Kanata rejected the staged $config configuration"
        return 1
    }
}

kanata_config_check() (
    local platform="$1" binary config_dir config
    config_dir="$(kanata_make_tempdir)" || return 1
    trap 'status=$?; trap - EXIT; rm -rf -- "$config_dir"; exit "$status"' EXIT
    kanata_stage_config "$platform" "$config_dir/config" || return 1
    config="$config_dir/config/kanata.kbd"
    binary="$(kanata_find_binary "$platform")" || {
        kanata_error "no compatible installed Kanata found; run install first"
        return 1
    }
    if [[ "$platform" == windows ]]; then config="$(cygpath -w -- "$config")"; fi
    kanata_check_binary "$binary" "$config"
)

kanata_find_binary() {
    local platform="$1" candidate root path count=0 found=''
    case "$platform" in
    linux)
        if kanata_is_arch_linux; then
            [[ -x /usr/bin/kanata ]] || return 1
            printf '%s\n' /usr/bin/kanata
            return 0
        fi
        if [[ -x "$KANATA_SYSTEM_BINARY" ]]; then printf '%s\n' "$KANATA_SYSTEM_BINARY"; return 0; fi
        candidate="$(command -v kanata 2>/dev/null || true)"
        [[ -n "$candidate" && -x "$candidate" ]] || return 1
        printf '%s\n' "$candidate"
        ;;
    macos)
        candidate="$(command -v kanata 2>/dev/null || true)"
        if [[ -z "$candidate" ]] && command -v brew >/dev/null 2>&1; then
            candidate="$(brew --prefix kanata 2>/dev/null)/bin/kanata" || true
        fi
        [[ -n "$candidate" && -f "$candidate" && -x "$candidate" && "$candidate" != *'/nix/store/'* ]] || return 1
        kanata_macos_native_binary "$candidate" || return 1
        printf '%s\n' "$candidate"
        ;;
    windows)
        root="${2:-}"
        [[ -n "$root" ]] || root="$(kanata_windows_localappdata)" || return 1
        root="$root/Microsoft/WinGet/Packages"
        [[ -d "$root" ]] || return 1
        while IFS= read -r path; do
            [[ -n "$path" ]] || continue
            found="$path"; count=$((count + 1))
        done < <(find "$root" -type f -name kanata_windows_gui_winIOv2_x64.exe -print 2>/dev/null)
        [[ "$count" == 1 ]] || return 1
        cygpath -u -- "$found"
        ;;
    esac
}

kanata_macos_launchctl() { /bin/launchctl "$@"; }
kanata_macos_root_launchctl() { sudo -n /bin/launchctl "$@"; }
kanata_macos_control() { sudo -n /usr/local/libexec/kanata-control "$@"; }

kanata_macos_query_job() {
    local domain="$1" output
    if [[ "$domain" == system/* ]]; then
        if output="$(kanata_macos_root_launchctl print "$domain" 2>&1)"; then :; else
            [[ "$output" == *'Could not find service'* || "$output" == *'No such service'* ]] || {
                kanata_error "launchd query failed for $domain: ${output:0:240}"
                return 1
            }
            printf '%s\n' absent
            return 0
        fi
    elif output="$(kanata_macos_launchctl print "$domain" 2>&1)"; then :; else
        [[ "$output" == *'Could not find service'* || "$output" == *'No such service'* ]] || {
            kanata_error "launchd query failed for $domain: ${output:0:240}"
            return 1
        }
        printf '%s\n' absent
        return 0
    fi
    if [[ "$output" =~ (^|[[:space:]])state[[:space:]]=[[:space:]]running([[:space:]]|$) ||
        "$output" =~ (^|[[:space:]])pid[[:space:]]=[[:space:]][1-9][0-9]*([[:space:]]|$) ]]; then
        printf '%s\n' running
    elif [[ "$output" =~ (^|[[:space:]])state[[:space:]]=[[:space:]](waiting|exited|stopped|throttled|terminated|crashed|spawn[[:space:]]scheduled)([[:space:]]|$) ]]; then
        printf '%s\n' loaded
    else
        kanata_error "could not determine launchd state for $domain"
        return 1
    fi
}

kanata_macos_agent_loaded() {
    local output
    if output="$(kanata_macos_launchctl print "gui/$(id -u)/dev.kanata.controller" 2>&1)"; then return 0; fi
    [[ "$output" == *'Could not find service'* ]] && return 1
    kanata_error "could not query controller launchd state: ${output:0:240}"
    return 2
}

kanata_macos_start() {
    local state
    if kanata_macos_agent_loaded; then
        state=0
    else
        state=$?
        (( state == 1 )) || return 1
    fi
    kanata_macos_control start || { kanata_error 'Kanata start failed; confirm sudoers authorization and VirtualHID readiness'; return 1; }
    if (( state == 0 )); then
        kanata_macos_launchctl kickstart -k "gui/$(id -u)/dev.kanata.controller" || return 1
    else
        kanata_macos_launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/dev.kanata.controller.plist" || return 1
    fi
}

kanata_macos_stop() {
    local state
    if kanata_macos_agent_loaded; then
        kanata_macos_launchctl bootout "gui/$(id -u)/dev.kanata.controller" || return 1
    else
        state=$?
        (( state == 1 )) || return 1
    fi
    kanata_macos_control stop
}

kanata_macos_restart() {
    local state
    if kanata_macos_agent_loaded; then
        state=0
    else
        state=$?
        (( state == 1 )) || return 1
    fi
    kanata_macos_control restart || return 1
    if (( state == 0 )); then kanata_macos_launchctl kickstart -k "gui/$(id -u)/dev.kanata.controller"; else
        kanata_macos_launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/dev.kanata.controller.plist"
    fi
}

kanata_macos_status() {
    local system_state controller_state
    if [[ -x /usr/local/libexec/kanata-control ]]; then
        kanata_macos_control status || return 1
    else
        system_state="$(kanata_macos_query_job system/dev.kanata.kanata)" || return 1
        case "$system_state" in
        running) printf '%s\n' 'Kanata: running' ;;
        loaded) printf '%s\n' 'Kanata: stopped' ;;
        absent) printf '%s\n' 'Kanata: not installed' ;;
        esac
    fi
    controller_state="$(kanata_macos_query_job "gui/$(id -u)/dev.kanata.controller")" || return 1
    case "$controller_state" in
    running) printf '%s\n' 'controller: running' ;;
    loaded) printf '%s\n' 'controller: loaded but stopped' ;;
    absent) printf '%s\n' 'controller: not installed' ;;
    esac
}
kanata_windows_task_query() {
    local state
    state="$(powershell.exe -NoProfile -NonInteractive -Command '
        $ErrorActionPreference = "Stop"
        try {
            $service = New-Object -ComObject Schedule.Service
            $service.Connect()
            $task = $service.GetFolder("\Dotfiles").GetTask("Kanata")
            [Console]::Write($task.State)
        } catch {
            $exception = $_.Exception
            while ($null -ne $exception) {
                $code = [long]$exception.HResult
                if ($code -eq -2147024894 -or $code -eq -2147216625) {
                [Console]::Write("NOT_FOUND")
                    exit 0
                }
                $exception = $exception.InnerException
            }
            [Console]::Error.WriteLine($_.Exception.Message)
            exit 1
        }' 2>/dev/null | tr -d '\r\n')" || return 2
    case "$state" in
    NOT_FOUND) return 1 ;;
    0) kanata_error 'Windows task state is unknown'; return 2 ;;
    1|2|3|4) printf '%s\n' "$state"; return 0 ;;
    *) return 2 ;;
    esac
}

kanata_windows_task_present() { kanata_windows_task_query >/dev/null; }
kanata_windows_schtasks() { schtasks.exe "$@"; }

kanata_windows_task_wait_stopped() {
    local attempt state status
    for ((attempt = 0; attempt < 8; attempt++)); do
        if state="$(kanata_windows_task_query)"; then
            case "$state" in
            1|2) return 0 ;;
            3|4) sleep 0.25 || { kanata_error 'could not wait for the Kanata task to stop'; return 1; } ;;
            *) kanata_error "Kanata task entered an unknown state: $state"; return 1 ;;
            esac
        else
            status=$?
            (( status == 1 )) && return 0
            kanata_error 'could not confirm that the Kanata task stopped'
            return 1
        fi
    done
    kanata_error 'timed out waiting for the Kanata task to stop'
    return 1
}

kanata_windows_status() {
    local state status
    if state="$(kanata_windows_task_query)"; then
        kanata_windows_schtasks //Query //TN '\Dotfiles\Kanata' //FO LIST || return 1
        printf 'Kanata task state: %s\n' "$state"
    else
        status=$?
        if (( status == 1 )); then printf '%s\n' 'Kanata task: not installed'; else kanata_error 'could not reliably query Kanata task state'; return 1; fi
    fi
}

kanata_windows_start() {
    kanata_windows_task_present || { kanata_error 'Kanata task is not installed or its state could not be queried'; return 1; }
    kanata_windows_schtasks //Run //TN '\Dotfiles\Kanata'
}

kanata_windows_stop() {
    local state status
    if state="$(kanata_windows_task_query)"; then
        case "$state" in
        1|2) return 0 ;;
        3|4) ;;
        *) kanata_error "Kanata task is in an unknown state: $state"; return 1 ;;
        esac
    else
        status=$?
        (( status == 1 )) && return 0
        kanata_error 'could not reliably query Kanata task state'
        return 1
    fi
    kanata_windows_schtasks //End //TN '\Dotfiles\Kanata' || return 1
    kanata_windows_task_wait_stopped
}

kanata_windows_restart() { kanata_windows_stop && kanata_windows_start; }


kanata_linux_status() {
    local load active controller_load controller_active
    load="$(systemctl show kanata.service -p LoadState --value)" || return 1
    if [[ "$load" == not-found ]]; then printf '%s\n' 'Kanata: not installed'; else
        [[ "$load" == loaded ]] || { kanata_error "unexpected Kanata LoadState: $load"; return 1; }
        active="$(systemctl show kanata.service -p ActiveState --value)" || return 1
        [[ "$active" =~ ^(active|inactive|failed|activating|deactivating|reloading|maintenance)$ ]] || { kanata_error "unexpected Kanata ActiveState: $active"; return 1; }
        printf 'Kanata: %s\n' "$active"
    fi
    controller_load="$(systemctl --user show kanata-controller.service -p LoadState --value)" || return 1
    if [[ "$controller_load" == not-found ]]; then printf '%s\n' 'controller: not installed'; else
        [[ "$controller_load" == loaded ]] || { kanata_error "unexpected controller LoadState: $controller_load"; return 1; }
        controller_active="$(systemctl --user show kanata-controller.service -p ActiveState --value)" || return 1
        [[ "$controller_active" =~ ^(active|inactive|failed|activating|deactivating|reloading|maintenance)$ ]] || { kanata_error "unexpected controller ActiveState: $controller_active"; return 1; }
        printf 'controller: %s\n' "$controller_active"
    fi
}

kanata_linux_action() {
    local action="$1" load controller_load active
    case "$action" in
    start)
        load="$(systemctl show kanata.service -p LoadState --value)" || return 1
        [[ "$load" == loaded ]] || { kanata_error 'system Kanata service is not installed'; return 1; }
        systemctl start kanata.service || return 1
        controller_load="$(systemctl --user show kanata-controller.service -p LoadState --value)" || return 1
        [[ "$controller_load" == loaded ]] || { kanata_error 'Kanata controller service is not installed'; return 1; }
        systemctl --user start kanata-controller.service || { kanata_error 'Kanata is running but the tray controller failed to start'; return 1; }
        ;;
    stop)
        controller_load="$(systemctl --user show kanata-controller.service -p LoadState --value)" || return 1
        [[ "$controller_load" == loaded || "$controller_load" == not-found ]] || { kanata_error "unexpected controller LoadState: $controller_load"; return 1; }
        if [[ "$controller_load" == loaded ]]; then
            active="$(systemctl --user show kanata-controller.service -p ActiveState --value)" || return 1
            [[ "$active" =~ ^(active|inactive|failed|activating|deactivating|reloading|maintenance)$ ]] || { kanata_error "unexpected controller ActiveState: $active"; return 1; }
            systemctl --user stop kanata-controller.service || return 1
        fi
        load="$(systemctl show kanata.service -p LoadState --value)" || return 1
        [[ "$load" == loaded || "$load" == not-found ]] || { kanata_error "unexpected Kanata LoadState: $load"; return 1; }
        if [[ "$load" == loaded ]]; then
            active="$(systemctl show kanata.service -p ActiveState --value)" || return 1
            [[ "$active" =~ ^(active|inactive|failed|activating|deactivating|reloading|maintenance)$ ]] || { kanata_error "unexpected Kanata ActiveState: $active"; return 1; }
            sudo systemctl stop kanata.service || return 1
        fi
        ;;
    restart)
        load="$(systemctl show kanata.service -p LoadState --value)" || return 1
        [[ "$load" == loaded ]] || { kanata_error 'system Kanata service is not installed'; return 1; }
        sudo systemctl restart kanata.service || return 1
        controller_load="$(systemctl --user show kanata-controller.service -p LoadState --value)" || return 1
        [[ "$controller_load" == loaded ]] || { kanata_error 'Kanata controller service is not installed'; return 1; }
        systemctl --user restart kanata-controller.service
        ;;
    status) kanata_linux_status ;;
    esac
}


kanata_platform_install() {
    local target="$1"
    bash "$DOTFILES_DIR/kanata/kanata-install.sh" "$target"
}

kanata_platform_action() {
    local platform="$1" action="$2"
    case "$platform" in
    linux) kanata_linux_action "$action" ;;
    macos)
        case "$action" in
        start) kanata_macos_start ;;
        stop) kanata_macos_stop ;;
        restart) kanata_macos_restart ;;
        status) kanata_macos_status ;;
        esac
        ;;
    windows)
        case "$action" in
        start) kanata_windows_start ;;
        stop) kanata_windows_stop ;;
        restart) kanata_windows_restart ;;
        status) kanata_windows_status ;;
        esac
        ;;
    esac
}

kanata_main() {
    local action="${1:-}" target platform
    [[ $# -gt 0 ]] || { kanata_usage >&2; return 2; }
    shift
    case "$action" in
    help|-h|--help) [[ $# == 0 ]] || { kanata_error 'help takes no arguments'; return 2; }; kanata_usage ;;
    install)
        [[ $# -le 1 ]] || { kanata_error 'install accepts at most one target'; return 2; }
        target="$(kanata_resolve_target "${1:-}")" || return 2
        kanata_require_host_target "$target" || return 2
        kanata_platform_install "$target"
        ;;
    check)
        [[ $# == 0 ]] || { kanata_error 'check takes no arguments'; return 2; }
        platform="$(kanata_platform)" || return 2
        kanata_config_check "$platform"
        ;;
    start|stop|restart|status)
        [[ $# == 0 ]] || { kanata_error "$action takes no arguments"; return 2; }
        platform="$(kanata_platform)" || return 2
        kanata_platform_action "$platform" "$action"
        ;;
    *) kanata_error "unknown action: $action"; kanata_usage >&2; return 2 ;;
    esac
}

install_kanata() {
    local action="${1:-install}" target="${2:-}"
    shift || true
    case "$action" in
    install) [[ $# -le 1 ]] || { kanata_error 'build.sh kanata accepts one target'; return 2; }; kanata_main install "$target" ;;
    *) kanata_error 'build.sh kanata only supports install; use kanata/kanata.sh for other actions'; return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    kanata_main "$@"
fi
