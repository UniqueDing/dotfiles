#!/usr/bin/env bash
# Shell helpers for installing per-user autostart services.  Intended to be sourced.

_autostart_error() {
    printf 'error: autostart: %s\n' "$*" >&2
}

_autostart_os() {
    if [[ "${OS:-}" == "Windows_NT" && "${MSYSTEM:-}" == "MSYS" ]]; then
        printf '%s\n' windows
        return 0
    fi

    case "$(uname -s 2>/dev/null)" in
    Linux) printf '%s\n' linux ;;
    Darwin) printf '%s\n' darwin ;;
    *) return 1 ;;
    esac
}

_autostart_safe_value() {
    # Bash strings cannot contain NUL.  Reject all remaining control bytes,
    # including CR and LF, because every target format treats them specially.
    [[ "$1" != *[[:cntrl:]]* ]]
}

_autostart_validate() {
    local id="$1"
    local value

    [[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] || {
        _autostart_error "invalid service identifier: $id"
        return 1
    }
    shift
    for value in "$@"; do
        _autostart_safe_value "$value" || {
            _autostart_error 'working directory, executable, and arguments must not contain control characters'
            return 1
        }
    done
}

_autostart_systemd_quote() {
    local value="$1"

    _autostart_safe_value "$value" || return 1
    # systemd expands %% and $$ before executing the command.  Quote every
    # word, then escape its parser's two quote metacharacters.
    value="${value//%/%%}"
    value="${value//\$/\$\$}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

_autostart_systemd_path() {
    local value="$1"

    _autostart_safe_value "$value" && [[ "$value" == /* ]] || return 1
    [[ "$value" != *\"* && "$value" != *\'* ]] || return 1
    value="${value//%/%%}"
    value="${value//\\/\\\\}"
    value="${value// /\\x20}"
    printf '%s' "$value"
}

_autostart_xml_escape() {
    local value="$1"
    value="${value//&/\&amp;}"
    value="${value//</\&lt;}"
    value="${value//>/\&gt;}"
    value="${value//\"/\&quot;}"
    value="${value//\'/\&apos;}"
    printf '%s' "$value"
}

_autostart_install_linux() {
    local id="$1" workdir="$2" executable="$3"
    local directory candidate exec_start escaped_workdir argument
    shift 3

    directory="$HOME/.config/systemd/user"
    mkdir -p "$directory" || return 1
    candidate="$(mktemp "$directory/.${id}.XXXXXX.service")" || return 1

    exec_start="$(_autostart_systemd_quote "$executable")" || { rm -f "$candidate"; return 1; }
    escaped_workdir="$(_autostart_systemd_path "$workdir")" || { rm -f "$candidate"; return 1; }
    for argument in "$@"; do
        exec_start="$exec_start $(_autostart_systemd_quote "$argument")" || { rm -f "$candidate"; return 1; }
    done

    {
        printf '[Unit]\nDescription=%s\n\n' "$id"
        printf '[Service]\nType=simple\nWorkingDirectory=%s\nExecStart=%s\nRestart=on-failure\n\n' \
            "$escaped_workdir" "$exec_start"
        printf '[Install]\nWantedBy=default.target\n'
    } > "$candidate" || { rm -f "$candidate"; return 1; }

    if command -v systemd-analyze >/dev/null 2>&1; then
        systemd-analyze --user verify "$candidate" || { rm -f "$candidate"; return 1; }
    fi
    mv -f "$candidate" "$directory/$id.service" || { rm -f "$candidate"; return 1; }

    systemctl --user daemon-reload && \
        systemctl --user enable --now "$id.service" && \
        systemctl --user restart "$id.service" && \
        systemctl --user is-active --quiet "$id.service"
}

_autostart_install_darwin() {
    local id="$1" workdir="$2" executable="$3"
    local directory state_directory candidate uid argument
    shift 3

    directory="$HOME/Library/LaunchAgents"
    state_directory="$HOME/.local/state/$id"
    mkdir -p "$directory" "$state_directory" || return 1
    # BSD mktemp requires its template to end in X characters.
    candidate="$(mktemp "$directory/.${id}.plist.XXXXXX")" || return 1
    {
        printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
        printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        printf '%s\n' '<plist version="1.0"><dict>'
        printf '<key>Label</key><string>%s</string>\n' "$(_autostart_xml_escape "$id")"
        printf '%s\n' '<key>ProgramArguments</key><array>'
        printf '<string>%s</string>\n' "$(_autostart_xml_escape "$executable")"
        for argument in "$@"; do
            printf '<string>%s</string>\n' "$(_autostart_xml_escape "$argument")"
        done
        printf '%s\n' '</array>'
        printf '<key>WorkingDirectory</key><string>%s</string>\n' "$(_autostart_xml_escape "$workdir")"
        printf '%s\n' '<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>'
        printf '<key>StandardOutPath</key><string>%s</string>\n' "$(_autostart_xml_escape "$state_directory/stdout.log")"
        printf '<key>StandardErrorPath</key><string>%s</string>\n' "$(_autostart_xml_escape "$state_directory/stderr.log")"
        printf '%s\n' '</dict></plist>'
    } > "$candidate" || { rm -f "$candidate"; return 1; }

    plutil -lint "$candidate" || { rm -f "$candidate"; return 1; }
    mv -f "$candidate" "$directory/$id.plist" || { rm -f "$candidate"; return 1; }
    uid="$(id -u)" || return 1
    if launchctl print "gui/$uid/$id" >/dev/null 2>&1; then
        launchctl bootout "gui/$uid/$id" || return 1
    fi
    launchctl bootstrap "gui/$uid" "$directory/$id.plist" && \
        launchctl print "gui/$uid/$id" >/dev/null
}

_autostart_install_windows() {
    local id="$1" workdir="$2" executable="$3"
    local temporary script task_name workdir_win executable_win
    shift 3

    command -v powershell.exe >/dev/null 2>&1 || { _autostart_error 'powershell.exe is required'; return 1; }
    command -v cygpath >/dev/null 2>&1 || { _autostart_error 'cygpath is required under MSYS'; return 1; }
    workdir_win="$(cygpath -aw "$workdir")" || return 1
    executable_win="$(cygpath -aw "$executable")" || return 1
    temporary="$(mktemp "${TMPDIR:-/tmp}/autostart.XXXXXX.ps1")" || return 1
    script="$(cygpath -aw "$temporary")" || { rm -f "$temporary"; return 1; }
    task_name="dotfiles-$id"

    # Values are passed as native argv after -File, never interpolated into
    # PowerShell source.  The remaining-arguments parameter retains every
    # executable argument as a distinct string, including empty arguments.
    printf '%s\n' \
        'param(' \
        '  [string]$TaskName,' \
        '  [string]$WorkingDirectory,' \
        '  [string]$Executable,' \
        '  [Parameter(ValueFromRemainingArguments = $true)]' \
        '  [string[]]$Arguments' \
        ')' \
        '$ErrorActionPreference = "Stop"' \
        'function Quote-WindowsArgument([string]$Value) {' \
        '  if ($Value.Length -eq 0) { return "\"\"" }' \
        '  if ($Value -notmatch "[\s\"]") { return $Value }' \
        '  $result = New-Object System.Text.StringBuilder; [void]$result.Append([char]34)' \
        '  $slashes = 0; foreach ($character in $Value.ToCharArray()) {' \
        '    if ($character -eq [char]92) { $slashes++; continue }' \
        '    if ($character -eq [char]34) { [void]$result.Append(([string][char]92) * ($slashes * 2 + 1)); [void]$result.Append($character); $slashes = 0; continue }' \
        '    if ($slashes) { [void]$result.Append(([string][char]92) * $slashes); $slashes = 0 }; [void]$result.Append($character)' \
        '  }; if ($slashes) { [void]$result.Append(([string][char]92) * ($slashes * 2)) }; [void]$result.Append([char]34)' \
        '  return $result.ToString()' \
        '}' \
        '$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value' \
        '$fullTaskName = "$TaskName-$sid"' \
        '$argumentLine = [string]::Join(" ", @($Arguments | ForEach-Object { Quote-WindowsArgument ([string]$_) }))' \
        '$action = New-ScheduledTaskAction -Execute $Executable -Argument $argumentLine -WorkingDirectory $WorkingDirectory' \
        '$trigger = New-ScheduledTaskTrigger -AtLogOn -User $sid' \
        '$principal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Limited' \
        '$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew' \
        '$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings' \
        'Register-ScheduledTask -TaskName $fullTaskName -InputObject $task -Force | Out-Null' \
        'Start-ScheduledTask -TaskName $fullTaskName' \
        'Get-ScheduledTask -TaskName $fullTaskName | Out-Null' > "$temporary" || { rm -f "$temporary"; return 1; }
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$script" \
        "$task_name" "$workdir_win" "$executable_win" "$@"
    local result=$?
    rm -f "$temporary"
    return "$result"
}

# Public interface: install_user_autostart <id> <workdir> <executable> [arguments...]
install_user_autostart() {
    [[ $# -ge 3 ]] || { _autostart_error 'usage: install_user_autostart <id> <workdir> <executable> [arguments...]'; return 2; }
    _autostart_validate "$@" || return 1
    case "$(_autostart_os)" in
    linux) _autostart_install_linux "$@" ;;
    darwin) _autostart_install_darwin "$@" ;;
    windows) _autostart_install_windows "$@" ;;
    *) _autostart_error 'unsupported operating system'; return 1 ;;
    esac
}
