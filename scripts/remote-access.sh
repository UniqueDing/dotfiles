#!/usr/bin/env bash
set -euo pipefail
umask 077
say() { printf "remote: %s\n" "$*"; }
die() { printf "remote: error: %s\n" "$*" >&2; exit 1; }
config_guidance() {
    printf '%s\n' 'Prepare ~/.config/.links/ under the configuration owner home: xray.json (required), frpc-NAME.toml (optional).'
}
missing_config() { printf 'remote: error: missing %s\n' "$1" >&2; config_guidance >&2; exit 1; }
action=${1:-help}
[[ $# == 0 ]] || shift
case "$action" in
    help|-h|--help)
        [[ $# == 0 ]] || die "help takes no options"
        echo "Commands: install check start stop restart enable disable status logs; option: --dry-run"
        config_guidance
        exit;;
    install|check|start|stop|restart|enable|disable|status|logs) ;;
    *) die "unknown command: $action";;
esac
dry=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry=1;;
        *) die "unknown option: $1";;
    esac
    shift
done
case "$(uname -s)" in
    Linux) platform=linux;;
    Darwin) platform=darwin;;
    *) die "Linux and macOS only";;
esac
owner=${SUDO_USER:-$(id -un)}
[[ "$owner" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ && "$owner" != root ]] || die "a non-root configuration owner is required"
uid=$(id -u "$owner") || die "unknown owner"
[[ "$uid" =~ ^[0-9]+$ && "$uid" != 0 ]] || die "invalid owner"
caller_uid=$(id -u) || die "cannot determine caller identity"
[[ "$caller_uid" == 0 || "$caller_uid" == "$uid" ]] || die "caller must be root or the configuration owner"
if [[ "$platform" == linux ]]; then
    (( uid >= 1000 )) || die "configuration owner must be a regular user"
    record=$(getent passwd "$owner") || die "cannot read account metadata"
    IFS=: read -r name password account_uid group gecos home shell <<< "$record"
    [[ "$name" == "$owner" && "$account_uid" == "$uid" ]] || die "inconsistent account metadata"
    [[ "$home" == "/home/$owner" ]] || die "unsupported home path"
    statinfo() { stat -c "%u %a" "$1"; }
    as_owner() {
        if [[ "$caller_uid" == "$uid" ]]; then "$@"; else runuser -u "$owner" -- "$@"; fi
    }
    service_dir=/etc/systemd/system
    distro=$(awk '
        /^ID=/ {
            count++
            value=substr($0,4)
            if (value ~ /^"[a-z]+"$/ || value ~ /^\047[a-z]+\047$/) value=substr(value,2,length(value)-2)
        }
        END { if (count != 1 || value !~ /^[a-z]+$/) exit 1; print value }
    ' /etc/os-release) || die "cannot determine Linux distribution"
    case "$distro" in
        arch)
            xray=/usr/bin/xray
            frpc=/usr/bin/frpc
            assets=/usr/share/xray;;
        deepin)
            xray=/home/linuxbrew/.linuxbrew/opt/xray/libexec/xray
            frpc=/home/linuxbrew/.linuxbrew/opt/frpc/bin/frpc
            assets=/home/linuxbrew/.linuxbrew/opt/xray/share/xray;;
        *) die "Linux supports Deepin and Arch only";;
    esac
    home_parent=/home
else
    (( uid >= 500 )) || die "configuration owner must be a regular user"
    home=$(/usr/bin/dscl . -read "/Users/$owner" NFSHomeDirectory) || die "cannot read account metadata"
    home=${home#NFSHomeDirectory: }
    [[ "$home" == "/Users/$owner" ]] || die "unsupported home path"
    statinfo() { stat -f "%u %Lp" "$1"; }
    as_owner() {
        if [[ "$caller_uid" == "$uid" ]]; then "$@"; else /usr/bin/sudo -u "$owner" -- "$@"; fi
    }
    service_dir=/Library/LaunchDaemons
    home_parent=/Users
    case "$(uname -m)" in
        arm64) prefix=/opt/homebrew;;
        x86_64) prefix=/usr/local;;
        *) die "unsupported architecture";;
    esac
    xray=$prefix/opt/xray/libexec/xray
    frpc=$prefix/opt/frpc/bin/frpc
    assets=$prefix/opt/xray/share/xray
fi
safe_dir() {
    local path=$1 expected=$2 actual mode
    [[ -d "$path" && ! -L "$path" ]] || die "unsafe directory: $path"
    read -r actual mode < <(statinfo "$path")
    [[ "$actual" == "$expected" ]] && (( (8#$mode & 022) == 0 )) || die "unsafe directory ownership or mode: $path"
}
safe_config_file() {
    local path=$1 actual mode
    [[ -f "$path" && ! -L "$path" ]] || die "unsafe configuration file: $path"
    read -r actual mode < <(statinfo "$path")
    [[ "$actual" == "$uid" && "$mode" == 600 ]] || die "configuration must be owner-only: $path"
}
[[ -d "$home_parent" && ! -L "$home_parent" && -d "$home" && ! -L "$home" ]] || die "unsafe home directory"
if [[ "$action" == install ]]; then
    safe_dir / 0
    safe_dir "$home_parent" 0
    read -r actual mode < <(statinfo "$home")
    [[ "$actual" == "$uid" ]] || die "unsafe home directory owner: $home"
fi
config=$home/.config/.links
if [[ ( "$action" == install || "$action" == check ) && ! -L "$home/.config" && ( ! -e "$home/.config" || -d "$home/.config" ) && ! -e "$config" && ! -L "$config" ]]; then
    missing_config "configuration directory: $config"
fi
if [[ "$action" == install ]]; then
    safe_dir "$home/.config" "$uid"
    safe_dir "$config" "$uid"
else
    [[ -d "$home/.config" && ! -L "$home/.config" && -d "$config" && ! -L "$config" ]] || die "unsafe configuration directory"
fi
shopt -s nullglob dotglob
ids=(xray)
for path in "$config"/*; do
    name=${path##*/}
    case "$name" in
        xray.json|.DS_Store) ;;
        *)
            if [[ ! "$name" =~ ^frpc-[A-Za-z0-9_-]+\.toml$ ]]; then
                [[ "$action" != install && "$action" != check ]] || die "unexpected configuration entry"
                continue
            fi
            ids+=("${name%.toml}");;
    esac
done
if [[ "$dry" == 1 ]]; then
    say "would $action for $owner using $config (no writes or service calls)"
    exit
fi
case "$action" in
    install|start|stop|restart|enable|disable)
        [[ "$caller_uid" == 0 ]] || die "run as root explicitly";;
esac
if [[ "$action" == install || "$action" == check ]]; then
    if [[ ! -e "$config/xray.json" && ! -L "$config/xray.json" ]]; then
        missing_config "configuration file: $config/xray.json"
    fi
    if [[ "$action" == install ]]; then
        read -r actual mode < <(statinfo "$config")
        [[ "$mode" == 700 ]] || die "configuration directory must be mode 0700"
        safe_config_file "$config/xray.json"
    else
        [[ -f "$config/xray.json" && ! -L "$config/xray.json" ]] || die "unsafe configuration file: $config/xray.json"
    fi
    for id in "${ids[@]}"; do
        [[ "$id" == xray ]] && continue
        if [[ "$action" == install ]]; then
            safe_config_file "$config/$id.toml"
        else
            [[ -f "$config/$id.toml" && ! -L "$config/$id.toml" ]] || die "unsafe configuration file: $config/$id.toml"
        fi
    done
    [[ -x "$xray" && -d "$assets" ]] || die "required Xray program or assets are missing"
    if (( ${#ids[@]} > 1 )); then
        [[ -x "$frpc" ]] || die "required frpc program is missing"
    fi
    as_owner env "HOME=$home" "XRAY_LOCATION_ASSET=$assets" "$xray" run -test -c "$config/xray.json" >/dev/null 2>&1 || die "Xray configuration validation failed"
    for id in "${ids[@]}"; do
        [[ "$id" == xray ]] && continue
        as_owner env "HOME=$home" "$frpc" verify -c "$config/$id.toml" >/dev/null 2>&1 || die "frpc configuration validation failed: $id"
    done
    if [[ "$action" == check ]]; then
        say "configuration valid"
        exit
    fi
fi
service_path() {
    if [[ "$platform" == linux ]]; then
        printf "%s/remote-access-%s.service\n" "$service_dir" "$1"
    else
        printf "%s/com.remote-access.%s.plist\n" "$service_dir" "$1"
    fi
}
service_label() {
    if [[ "$platform" == linux ]]; then printf "remote-access-%s.service\n" "$1"
    else printf "com.remote-access.%s\n" "$1"; fi
}
safe_dir "$service_dir" 0
if [[ "$action" == install || "$action" == start || "$action" == stop || "$action" == restart || "$action" == enable || "$action" == disable ]]; then
    lock=/var/run/remote-access-thin.lock
    mkdir -m 700 "$lock" 2>/dev/null || die "another command is running or lock exists: $lock"
    trap 'rmdir -- "$lock"' EXIT
fi
launchd_query() {
    local label=$1 path=$2 jobpath
    job_loaded=0
    if job=$(LC_ALL=C launchctl print "system/$label" 2>&1); then
        job_loaded=1
        jobpath=$(printf "%s\n" "$job" | awk '$1 == "path" && $2 == "=" { print $3 }')
        [[ "$jobpath" == "$path" ]] || die "unexpected loaded job path: $label"
    else
        case "$job" in
            *"Could not find service \"$label\" in domain for system"*) ;;
            *) die "cannot inspect launchd system job: $label";;
        esac
    fi
}
for id in "${ids[@]}"; do
    path=$(service_path "$id")
    label=$(service_label "$id")
    if [[ "$platform" == linux ]]; then
        state=$(systemctl show -p LoadState --value "$label") || die "cannot inspect service load state"
        drops=$(systemctl show -p DropInPaths --value "$label") || die "cannot inspect service drop-ins"
        [[ -z "$drops" && ! -e "$service_dir/$label.d" && ! -L "$service_dir/$label.d" && ! -e "/usr/lib/systemd/system/$label.d" && ! -L "/usr/lib/systemd/system/$label.d" && ! -e "/run/systemd/system/$label.d" && ! -L "/run/systemd/system/$label.d" ]] || die "service drop-in conflict: $label"
        if [[ "$action" == install ]]; then
            [[ ! -e "$path" && ! -L "$path" && "$state" == not-found ]] || die "existing service: $label"
            registered=$(systemctl list-unit-files --no-legend --no-pager) || die "cannot inspect service registration: $label"
            registered=$(printf '%s\n' "$registered" | awk -v label="$label" '$1 == label { print "found" }') || die "cannot inspect service registration: $label"
            [[ -z "$registered" ]] || die "service already registered: $label"
            for link in "$service_dir"/*.wants/"$label" "$service_dir"/*.requires/"$label" /run/systemd/system/*.wants/"$label" /run/systemd/system/*.requires/"$label" /usr/lib/systemd/system/*.wants/"$label" /usr/lib/systemd/system/*.requires/"$label"; do
                [[ ! -e "$link" && ! -L "$link" ]] || die "service already enabled: $label"
            done
        else
            [[ "$state" == loaded ]] || die "service not loaded: $label"
            fragment=$(systemctl show -p FragmentPath --value "$label") || die "cannot inspect service fragment"
            [[ "$fragment" == "$path" ]] || die "unexpected service fragment: $label"
        fi
    else
        launchd_query "$label" "$path"
        if [[ "$action" == install ]]; then
            [[ "$job_loaded" == 0 && ! -e "$path" && ! -L "$path" ]] || die "existing service: $label"
        fi
    fi
    if [[ "$action" != install ]]; then
        [[ -f "$path" && ! -L "$path" ]] || die "missing managed service: $label"
        read -r actual mode < <(statinfo "$path")
        [[ "$actual" == 0 ]] && (( (8#$mode & 022) == 0 )) || die "unsafe service: $label"
        grep -Fq "remote-access-thin-v1" "$path" || die "unmanaged service: $label"
        if [[ "$platform" == linux ]]; then
            service_user=$(systemctl show -p User --value "$label") || die "cannot inspect service user: $label"
        else
            service_user=$(/usr/bin/plutil -extract UserName raw -o - "$path") || die "cannot inspect service user: $label"
        fi
        [[ "$service_user" == "$owner" ]] || die "service owner differs from configuration owner: $label"
    fi
done
if [[ "$action" != install ]]; then
    rc=0
    for id in "${ids[@]}"; do
        label=$(service_label "$id")
        if [[ "$platform" == linux ]]; then
            if [[ "$action" == logs ]]; then
                journalctl --no-pager -n 200 -u "$label" || rc=1
            elif [[ "$action" == status ]]; then
                systemctl --no-pager --full status "$label" || rc=1
            else
                systemctl "$action" "$label" || rc=1
            fi
        else
            launchd_query "$label" "$(service_path "$id")"
            case "$action" in
                start)
                    if [[ "$job_loaded" == 1 ]]; then launchctl kickstart "system/$label" || rc=1
                    else launchctl bootstrap system "$(service_path "$id")" || rc=1; fi;;
                stop) if [[ "$job_loaded" == 1 ]]; then launchctl bootout "system/$label" || rc=1; fi;;
                restart)
                    if [[ "$job_loaded" == 1 ]]; then launchctl kickstart -k "system/$label" || rc=1
                    else launchctl bootstrap system "$(service_path "$id")" || rc=1; fi;;
                status)
                    if [[ "$job_loaded" == 1 ]]; then printf "%s\n" "$job"
                    else printf 'remote: service not loaded: %s\n' "$label" >&2; rc=1; fi;;
                logs)
                    logdir=/Library/Logs/remote-access-thin
                    safe_dir /Library/Logs 0
                    safe_dir "$logdir" 0
                    for file in "$logdir/$id.log" "$logdir/$id.err"; do
                        safe_config_file "$file"
                        tail -n 200 "$file" || rc=1
                    done;;
                *) launchctl "$action" "system/$label" || rc=1;;
            esac
        fi
    done
    exit "$rc"
fi
if [[ "$platform" == darwin ]]; then
    safe_dir /Library/Logs 0
    logdir=/Library/Logs/remote-access-thin
    if [[ -e "$logdir" || -L "$logdir" ]]; then
        safe_dir "$logdir" 0
        read -r actual mode < <(statinfo "$logdir")
        [[ "$mode" == 755 ]] || die "unsafe log directory mode"
    fi
    for id in "${ids[@]}"; do
        for file in "$logdir/$id.log" "$logdir/$id.err"; do
            [[ ! -e "$file" && ! -L "$file" ]] || die "existing log file: $file"
        done
    done
    for id in "${ids[@]}"; do
        launchctl disable "system/$(service_label "$id")" || die "could not disable job; previous changes may remain"
    done
    if [[ ! -d "$logdir" ]]; then mkdir -m 755 "$logdir" || die "cannot create log directory"; fi
    safe_dir "$logdir" 0
    for id in "${ids[@]}"; do
        for file in "$logdir/$id.log" "$logdir/$id.err"; do
            (set -o noclobber; : > "$file") || die "cannot create log; earlier changes may remain"
            chown "$owner" "$file"
            chmod 600 "$file"
        done
    done
fi
stage=$(mktemp -d "$service_dir/.remote-access-thin.XXXXXX") || die "cannot create staging directory"
trap 'rm -rf -- "$stage"; rmdir -- "$lock"' EXIT
for id in "${ids[@]}"; do
    binary=$frpc
    args="-c $config/$id.toml"
    if [[ "$id" == xray ]]; then binary=$xray; args="run -c $config/xray.json"; fi
    if [[ "$platform" == linux ]]; then
        cat > "$stage/$id" <<EOF
# remote-access-thin-v1
[Unit]
Description=Remote access thin $id
After=network-online.target
[Service]
User=$owner
Environment=HOME=$home
Environment=XRAY_LOCATION_ASSET=$assets
ExecStart=$binary $args
Restart=on-failure
UMask=0077
[Install]
WantedBy=multi-user.target
EOF
    else
        if [[ "$id" == xray ]]; then
            argv="<string>run</string><string>-c</string><string>$config/xray.json</string>"
        else
            argv="<string>-c</string><string>$config/$id.toml</string>"
        fi
        cat > "$stage/$id" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>Comment</key><string>remote-access-thin-v1</string>
<key>Label</key><string>$(service_label "$id")</string>
<key>UserName</key><string>$owner</string>
<key>ProgramArguments</key><array><string>$binary</string>$argv</array>
<key>EnvironmentVariables</key><dict><key>HOME</key><string>$home</string><key>XRAY_LOCATION_ASSET</key><string>$assets</string></dict>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>Disabled</key><true/>
<key>StandardOutPath</key><string>$logdir/$id.log</string>
<key>StandardErrorPath</key><string>$logdir/$id.err</string>
</dict></plist>
EOF
        /usr/bin/plutil -lint "$stage/$id" >/dev/null || die "invalid service definition: $id; earlier changes may remain"
    fi
    chmod 644 "$stage/$id"
done
for id in "${ids[@]}"; do
    ln "$stage/$id" "$(service_path "$id")" || die "could not register $id; earlier services or logs may remain"
done
if [[ "$platform" == linux ]]; then
    systemctl daemon-reload || die "daemon-reload failed; registered services remain"
fi
say "install complete; services are not enabled or started"
