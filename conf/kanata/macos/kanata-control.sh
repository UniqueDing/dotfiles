#!/bin/bash

set -u

service='system/dev.kanata.kanata'
plist='/Library/LaunchDaemons/dev.kanata.kanata.plist'

# Results: 0=running, 1=loaded but not running, 2=absent, 3=query error.
query_service() {
    local output status
    if output="$(/bin/launchctl print "$service" 2>&1)"; then
        QUERY_OUTPUT=$output
        if [[ "$output" =~ (^|[[:space:]])state[[:space:]]=[[:space:]]running([[:space:]]|$) ||
            "$output" =~ (^|[[:space:]])pid[[:space:]]=[[:space:]][1-9][0-9]*([[:space:]]|$) ]]; then
            return 0
        fi
        [[ "$output" =~ (^|[[:space:]])state[[:space:]]=[[:space:]](stopped|waiting|exited)([[:space:]]|$) ]] || return 3
        return 1
    fi
    status=$?
    QUERY_OUTPUT=$output
    if [[ "$output" == *'Could not find service'* && "$output" == *'dev.kanata.kanata'* ]]; then
        return 2
    fi
    return 3
}

is_absent_error() {
    [[ "$1" == *'Could not find service'* ||
        "$1" == *'No such process'* ||
        "$1" == *'No such service'* ]]
}

stop_service() {
    local attempt output state status
    output="$(/bin/launchctl disable "$service" 2>&1)" || {
        status=$?
        is_absent_error "$output" || return "$status"
    }
    output="$(/bin/launchctl bootout system "$plist" 2>&1)" || {
        status=$?
        is_absent_error "$output" || return "$status"
    }
    for ((attempt = 0; attempt < 20; attempt++)); do
        query_service; state=$?
        case "$state" in
        2) return 0 ;;
        3) return 1 ;;
        esac
        /bin/sleep 0.25
    done
    return 1
}

start_service() {
    local attempt state
    /bin/launchctl enable "$service" || return 1
    query_service; state=$?
    case "$state" in
    2) /bin/launchctl bootstrap system "$plist" || return 1 ;;
    3) return 1 ;;
    0|1) ;;
    esac
    /bin/launchctl kickstart "$service" || return 1
    for ((attempt = 0; attempt < 20; attempt++)); do
        query_service; state=$?
        case "$state" in
        0) return 0 ;;
        3) return 1 ;;
        esac
        /bin/sleep 0.25
    done
    return 1
}

[[ $# -eq 1 ]] || exit 2
case "$1" in
status)
    query_service
    case "$?" in
    0)
        printf '%s\n' "$QUERY_OUTPUT"
        ;;
    1)
        printf '%s\n' 'state = stopped'
        ;;
    2)
        printf '%s\n' 'state = stopped'
        ;;
    3)
        printf '%s\n' "$QUERY_OUTPUT" >&2
        exit 1
        ;;
    esac
    ;;
start)
    start_service
    ;;
stop)
    stop_service
    ;;
restart)
    stop_service && start_service
    ;;
*)
    exit 2
    ;;
esac
