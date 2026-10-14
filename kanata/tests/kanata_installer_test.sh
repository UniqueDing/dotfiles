#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d /tmp/opencode/kanata-maintenance.XXXXXX)"
export TEST_ROOT
trap 'rm -rf -- "$TEST_ROOT"' EXIT

# Keep shell-based integration fixtures away from real host services, privilege
# helpers, package managers, and network tools. Individual tests may replace
# these with in-process mocks or fixture executables explicitly.
MOCK_GUARD_BIN="$TEST_ROOT/guard-bin"
mkdir -p "$MOCK_GUARD_BIN"
for guarded in sudo systemctl launchctl schtasks.exe powershell.exe pacman yay brew winget cargo git curl wget codesign ps kill; do
    printf '#!/usr/bin/env bash\nprintf "blocked real command: %%s\\n" "$0 $*" >&2\nexit 97\n' >"$MOCK_GUARD_BIN/$guarded"
    chmod 0700 "$MOCK_GUARD_BIN/$guarded"
done
PATH="$MOCK_GUARD_BIN:$PATH"
TMPDIR="$TEST_ROOT/tmp"
mkdir -p "$TMPDIR"
export PATH TMPDIR

# Sourcing the daily entrypoint must not load installer implementation or run
# either CLI main. The installer is loaded explicitly for deployment tests.
if ! bash -c 'source "$1/kanata/kanata.sh"; ! declare -F kanata_linux_install >/dev/null && ! declare -F kanata_install_main >/dev/null' _ "$ROOT"; then
    printf 'not ok - daily entrypoint source guard\n' >&2
    exit 1
fi
source "$ROOT/kanata/kanata-install.sh"

FAILURES=0
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "expected [$2], got [$1]"; }
assert_file() { [[ -f "$1" ]] || fail "expected fixture file: $1"; }
log_line() { awk -v needle="$2" 'index($0, needle) { print NR; exit }' "$1"; }
log_line_after() { awk -v after="$2" -v needle="$3" 'NR > after && index($0, needle) { print NR; exit }' "$1"; }
assert_before() {
    local left right
    left="$(log_line "$3" "$1")"; right="$(log_line "$3" "$2")"
    [[ -n "$left" && -n "$right" ]] && (( left < right )) || fail "expected [$1] before [$2] in $3"
}

new_sandbox() {
    MOCK_ROOT="$TEST_ROOT/root-$RANDOM-$RANDOM"
    mkdir -p "$MOCK_ROOT/usr" "$MOCK_ROOT/var/usrlocal" "$MOCK_ROOT/etc/systemd/system" \
        "$MOCK_ROOT/etc/polkit-1/rules.d" "$MOCK_ROOT/etc/kanata"
    ln -s ../var/usrlocal "$MOCK_ROOT/usr/local"
    MOCK_LOG="$TEST_ROOT/log-$RANDOM-$RANDOM"
    : >"$MOCK_LOG"
    MOCK_MUTATIONS=0
    MOCK_CMP_ERROR=0
    MOCK_MISSING_GROUP=''
    MOCK_FAIL_ROOT_MV=0
    MOCK_SYSTEM_LOAD='not-found'
    MOCK_USER_CONTROLLER_LOAD='not-found'
    MOCK_USER_KANATA_LOAD='not-found'
    MOCK_SYSTEM_STATUS='inactive'
    MOCK_CONTROLLER_STATUS='inactive'
    MOCK_QUERY_FAIL=0
    MOCK_QUERY_ERROR=''
    MOCK_QUERY_FAIL_SCOPE=''
    MOCK_QUERY_FAIL_UNIT=''
    MOCK_SYSTEM_STOP_FAIL=0
    MOCK_USER_STOP_FAIL=0
    MOCK_SYSTEM_START_FAIL=0
    MOCK_USER_START_FAIL=0
    MOCK_SYSTEM_RESTART_FAIL=0
    MOCK_USER_RESTART_FAIL=0
    MOCK_SERVICE_CHANGES=0
    MOCK_PACMAN_FAIL=0
    MOCK_MAC_SYSTEM_STATE=absent
    MOCK_MAC_CONTROLLER_STATE=absent
    MOCK_VHID_JOB_STATE_FILE="$TEST_ROOT/vhid-job-state-$RANDOM"
    printf 'absent\n' >"$MOCK_VHID_JOB_STATE_FILE"
    MOCK_VHID_JOB_STATE=absent
    MOCK_VHID_BOOTSTRAP_COUNT_FILE="$TEST_ROOT/vhid-bootstrap-count-$RANDOM"
    printf '0\n' >"$MOCK_VHID_BOOTSTRAP_COUNT_FILE"
    export MOCK_VHID_JOB_STATE_FILE MOCK_VHID_BOOTSTRAP_COUNT_FILE
    MOCK_VHID_ALIVE=0
    MOCK_VHID_QUERY_FAIL=0
    MOCK_VHID_CONFIRM_QUERY_FAIL=0
    MOCK_VHID_BOOTOUT_FAIL=0
    MOCK_VHID_BOOTSTRAP_DISABLED=0
    MOCK_VHID_BOOTSTRAP_FAIL=0
    MOCK_VHID_PS_FAIL=0
    MOCK_VHID_KILL_FAIL=0
    MOCK_VHID_STUCK=0
    MOCK_VHID_READY_QUERY_FAIL=0
    MOCK_VHID_PLIST_FAIL=0
    MOCK_CODESIGN_VERIFY_FAIL=0
    MOCK_KANATA_CONFIG_FAIL=0
    MOCK_SIGNATURE_ID=org.pqrs.Karabiner-VirtualHIDDevice-Daemon
    MOCK_SIGNATURE_TEAM=G43BCU2T37
    MOCK_TARGET_PREFLIGHT_FAIL=0
    MOCK_FAIL_ROOT_WRITE_PATH=''
    MOCK_SLEEP_COUNT=0
    KANATA_TEST_EVENT_LOG=''
    export KANATA_TEST_EVENT_LOG
    HOME="$TEST_ROOT/home-$RANDOM-$RANDOM"
    mkdir -p "$HOME"
    export HOME TMPDIR MOCK_KANATA_CONFIG_FAIL
}

set_mock_vhid_job_state() {
    MOCK_VHID_JOB_STATE="$1"
    printf '%s\n' "$1" >"$MOCK_VHID_JOB_STATE_FILE"
}

seed_linux_fixed_targets() {
    mkdir -p "$MOCK_ROOT/var/usrlocal/bin"
    printf 'preexisting-kanata\n' >"$MOCK_ROOT/var/usrlocal/bin/kanata"
    printf 'preexisting-config\n' >"$MOCK_ROOT/etc/kanata/kanata.kbd"
}

make_safe_tool_path() {
    local destination="$1" tool source
    mkdir -p "$destination"
    for tool in chmod cmp cp dirname grep install mkdir mktemp mv rm; do
        source="$(command -v "$tool")" || fail "required fixture utility is unavailable: $tool"
        ln -s "$source" "$destination/$tool"
    done
}

# Never let tests accidentally inherit root-runner identity. Install flows are
# intentionally exercised as an ordinary user and deployments remain virtual.
id() {
    case "${1:-}" in
    -u) printf '1000\n' ;;
    -un) printf 'mockuser\n' ;;
    *) command id "$@" ;;
    esac
}

getent() {
    [[ "${1:-}" == group && -n "${2:-}" ]] || return 2
    [[ "$2" != "$MOCK_MISSING_GROUP" ]] || return 2
    case "$2" in input|uinput) printf '%s:x:998:mockuser\n' "$2" ;; *) return 2 ;; esac
}

# Fail closed if a code path tries to inspect or signal host HID processes
# without the per-test fixture mocks.
pgrep() { fail 'unexpected pgrep invocation; tests must use the controlled VHID fixture'; }
ps() { fail "unexpected ps invocation outside a VHID fixture: $*"; }
kill() { fail "unexpected process signal outside a VHID fixture: $*"; }
codesign() { fail "unexpected codesign invocation outside a VHID fixture: $*"; }

virtual_path() {
    case "$1" in
    "$TEST_ROOT"/*) printf '%s\n' "$1" ;;
    /usr/local) printf '%s/usr/local\n' "$MOCK_ROOT" ;;
    /usr/local/*) printf '%s/var/usrlocal/%s\n' "$MOCK_ROOT" "${1#/usr/local/}" ;;
    /*) printf '%s%s\n' "$MOCK_ROOT" "$1" ;;
    *) fail "expected absolute fixture path: $1" ;;
    esac
}

sudo() {
    local op="${1:-}" flag path host source destination mode directory=0 negate=0 arg
    shift || true
    case "$op" in
    /bin/sh)
        local probe_script="${2:-}" path target host
        [[ "${1:-}" == -c && "${3:-}" == kanata-preflight ]] || fail 'unexpected privileged preflight shell invocation'
        if [[ "$probe_script" == *'refusing symlink directory'* ]]; then
            shift 3
            for path in "$@"; do
                host="$(virtual_path "$path")"
                [[ ! -L "$host" && ( ! -e "$host" || -d "$host" ) ]] || return 1
            done
        elif [[ "$probe_script" == *'refusing symlink target'* ]]; then
            shift 3
            for path in "$@"; do
                for target in "$path" "$path.pre-kanata.bak"; do
                    host="$(virtual_path "$target")"
                    [[ ! -L "$host" && ( ! -e "$host" || -f "$host" ) ]] || return 1
                done
            done
        else
            fail 'unexpected privileged preflight script'
        fi
        ;;
    -v) printf 'sudo-auth\n' >>"$MOCK_LOG"; return 0 ;;
    test)
        flag="${1:-}"; shift || true
        if [[ "$flag" == '!' ]]; then negate=1; flag="${1:-}"; shift || true; fi
        path="${1:-}"; host="$(virtual_path "$path")"
        case "$flag" in
        -d) [[ -d "$host" ]] ;;
        -e) [[ -e "$host" ]] ;;
        -f) [[ -f "$host" ]] ;;
        -L) [[ -L "$host" ]] ;;
        *) fail "unexpected sudo test operator: $flag" ;;
        esac
        arg=$?
        if (( negate )); then (( arg != 0 )); else (( arg == 0 )); fi
        ;;
    install)
        printf 'sudo install %s\n' "$*" >>"$MOCK_LOG"
        MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
        while (($#)); do
            case "$1" in
            -d) directory=1; shift ;;
            -o) owner="$2"; shift 2 ;;
            -g) group="$2"; shift 2 ;;
            -m) mode="$2"; shift 2 ;;
            --) shift; break ;;
            *) break ;;
            esac
        done
        if (( directory )); then
            for path in "$@"; do host="$(virtual_path "$path")"; mkdir -p "$host"; chmod "${mode:-0755}" "$host"; done
        else
            source="${1:?missing sudo install source}"; destination="${2:?missing sudo install destination}"
            host="$(virtual_path "$destination")"; command install -m "${mode:-0644}" "$source" "$host"
        fi
        ;;
    cmp)
        [[ "${1:-}" == -s ]] || fail 'unexpected sudo cmp arguments'
        shift; [[ "${1:-}" == -- ]] && shift
        source="$1"; destination="$(virtual_path "$2")"
        (( MOCK_CMP_ERROR == 0 )) || return 2
        command cmp -s "$source" "$destination"
        ;;
    cp)
        printf 'sudo cp %s\n' "$*" >>"$MOCK_LOG"
        MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
        [[ "${1:-}" == -p ]] || fail 'unexpected sudo cp mode'
        shift; [[ "${1:-}" == -- ]] && shift
        source="$(virtual_path "$1")"; destination="$(virtual_path "$2")"
        command cp -p "$source" "$destination"
        ;;
    mv)
        printf 'sudo mv %s\n' "$*" >>"$MOCK_LOG"
        MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
        (( MOCK_FAIL_ROOT_MV == 0 )) || return 1
        shift
        while [[ "${1:-}" == -* || "${1:-}" == -- ]]; do shift; done
        source="$(virtual_path "$1")"; destination="$(virtual_path "$2")"
        command mv -f "$source" "$destination"
        ;;
    rm)
        printf 'sudo rm %s\n' "$*" >>"$MOCK_LOG"
        MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
        [[ "${1:-}" == -f ]] || fail 'unexpected sudo rm arguments'
        shift; [[ "${1:-}" == -- ]] && shift
        command rm -f "$(virtual_path "$1")"
        ;;
    mktemp)
        local template="${1:?missing sudo mktemp template}" host_template temporary
        MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
        host_template="$(virtual_path "$template")"
        temporary="$(command mktemp "$host_template")" || return 1
        case "$template" in
        /usr/local/*) printf '/usr/local/%s\n' "${temporary#"$MOCK_ROOT/var/usrlocal/"}" ;;
        /*) printf '%s\n' "${temporary#"$MOCK_ROOT"}" ;;
        *) fail "unexpected sudo mktemp template: $template" ;;
        esac
        ;;
    systemctl) systemctl "$@" ;;
    pacman) pacman "$@" ;;
    *) fail "unexpected sudo operation: $op" ;;
    esac
}

systemctl() {
    local scope=system operation unit property
    if [[ "${1:-}" == --user ]]; then scope=user; shift; fi
    operation="${1:-}"; shift || true
    printf '%s %s %s\n' "$scope" "$operation" "$*" >>"$MOCK_LOG"
    if [[ -n "${KANATA_TEST_EVENT_LOG:-}" && "$operation" =~ ^(start|stop|restart|enable)$ ]]; then
        printf '%s %s %s\n' "$scope" "$operation" "$*" >>"$KANATA_TEST_EVENT_LOG"
    fi
    case "$operation" in
    show-environment) return 0 ;;
    show)
        unit="${1:-}"; shift
        property="${2:-}"
        if [[ "$property" == -p ]]; then property="${3:-}"; fi
        if [[ "$MOCK_QUERY_FAIL" == 1 && ( -z "$MOCK_QUERY_FAIL_SCOPE" || "$scope" == "$MOCK_QUERY_FAIL_SCOPE" ) && ( -z "$MOCK_QUERY_FAIL_UNIT" || "$unit" == "$MOCK_QUERY_FAIL_UNIT" ) ]]; then
            printf '%s\n' "${MOCK_QUERY_ERROR:-Access denied}" >&2
            return 1
        fi
        case "$property" in
        LoadState)
            case "$scope:$unit" in
            system:kanata.service) printf '%s\n' "$MOCK_SYSTEM_LOAD" ;;
            user:kanata-controller.service) printf '%s\n' "$MOCK_USER_CONTROLLER_LOAD" ;;
            user:kanata.service) printf '%s\n' "$MOCK_USER_KANATA_LOAD" ;;
            *) fail "installer queried an unmanaged systemd unit: $scope:$unit" ;;
            esac
            ;;
        ActiveState)
            case "$scope:$unit" in
            system:kanata.service) printf '%s\n' "$MOCK_SYSTEM_STATUS" ;;
            user:kanata-controller.service) printf '%s\n' "$MOCK_CONTROLLER_STATUS" ;;
            *) fail "installer queried an unmanaged service state: $scope:$unit" ;;
            esac
            ;;
        *) fail "unexpected systemctl property: $property" ;;
        esac
        ;;
    is-active) return 1 ;;
    start)
        [[ "$scope:$*" != user:kanata.service ]] || fail 'tests forbid managing legacy per-user Kanata units'
        if [[ "$scope:$*" == system:kanata.service ]]; then (( MOCK_SYSTEM_START_FAIL == 0 )) || return 1
        else (( MOCK_USER_START_FAIL == 0 )) || return 1; fi
        MOCK_SERVICE_CHANGES=$((MOCK_SERVICE_CHANGES + 1))
        ;;
    stop)
        [[ "$scope:$*" != user:kanata.service ]] || fail 'tests forbid managing legacy per-user Kanata units'
        if [[ "$scope:$*" == system:kanata.service ]]; then (( MOCK_SYSTEM_STOP_FAIL == 0 )) || return 1
        else (( MOCK_USER_STOP_FAIL == 0 )) || return 1; fi
        MOCK_SERVICE_CHANGES=$((MOCK_SERVICE_CHANGES + 1))
        ;;
    restart)
        [[ "$scope:$*" != user:kanata.service ]] || fail 'tests forbid managing legacy per-user Kanata units'
        if [[ "$scope:$*" == system:kanata.service ]]; then (( MOCK_SYSTEM_RESTART_FAIL == 0 )) || return 1
        else (( MOCK_USER_RESTART_FAIL == 0 )) || return 1; fi
        MOCK_SERVICE_CHANGES=$((MOCK_SERVICE_CHANGES + 1))
        ;;
    enable)
        [[ "$scope:$*" != user:kanata.service ]] || fail 'tests forbid enabling a legacy per-user Kanata unit'
        return 0
        ;;
    daemon-reload) return 0 ;;
    *) fail "unexpected systemctl operation: $scope $operation" ;;
    esac
}

test_cli_dispatch_and_unknown_actions_are_side_effect_free() (
    CALL_LOG="$TEST_ROOT/dispatch"
    : >"$CALL_LOG"
    KANATA_TEST_PLATFORM=linux
    kanata_platform() { printf '%s\n' "$KANATA_TEST_PLATFORM"; }
    kanata_require_host_target() { [[ "$1" == "$KANATA_TEST_PLATFORM" ]]; }
    kanata_platform_install() { printf 'install:%s\n' "$1" >>"$CALL_LOG"; }
    kanata_config_check() { printf 'check:%s\n' "$1" >>"$CALL_LOG"; }
    kanata_platform_action() { printf 'action:%s:%s\n' "$1" "$2" >>"$CALL_LOG"; }
    kanata_main install other || fail 'legacy build.sh Linux target did not dispatch'
    install_kanata install arch || fail 'build.sh install wrapper did not preserve the Arch target alias'
    kanata_main check || fail 'check did not dispatch'
    kanata_main start || fail 'start did not dispatch'
    kanata_main stop || fail 'stop did not dispatch'
    kanata_main restart || fail 'restart did not dispatch'
    kanata_main status || fail 'status did not dispatch'
    assert_eq "$(<"$CALL_LOG")" $'install:linux\ninstall:linux\ncheck:linux\naction:linux:start\naction:linux:stop\naction:linux:restart\naction:linux:status'
    if kanata_main remove >/dev/null 2>&1; then fail 'unknown action succeeded'; fi
    assert_eq "$(<"$CALL_LOG")" $'install:linux\ninstall:linux\ncheck:linux\naction:linux:start\naction:linux:stop\naction:linux:restart\naction:linux:status'
)

test_daily_install_wrapper_executes_dedicated_installer() (
    local log="$TEST_ROOT/daily-installer-wrapper"
    : >"$log"
    bash() { printf '%s\n' "$*" >>"$log"; }
    kanata_platform_install linux || fail 'daily install wrapper failed'
    [[ "$(<"$log")" == *"$ROOT/kanata/kanata-install.sh"* && "$(<"$log")" == *linux* ]] || fail 'daily install wrapper did not execute the installer with its target'
)

test_daily_non_install_actions_never_prepare_software() (
    new_sandbox
    local preparation_log="$TEST_ROOT/unexpected-software-preparation"
    : >"$preparation_log"
    pacman() { printf 'pacman %s\n' "$*" >>"$preparation_log"; return 1; }
    brew() { printf 'brew %s\n' "$*" >>"$preparation_log"; return 1; }
    winget() { printf 'winget %s\n' "$*" >>"$preparation_log"; return 1; }
    kanata_platform() { printf 'linux\n'; }
    kanata_config_check() { return 0; }
    MOCK_SYSTEM_LOAD=loaded MOCK_USER_CONTROLLER_LOAD=loaded
    kanata_main check || fail 'daily check failed'
    kanata_main start || fail 'daily start failed'
    kanata_main stop || fail 'daily stop failed'
    kanata_main restart || fail 'daily restart failed'
    kanata_main status >/dev/null || fail 'daily status failed'
    [[ ! -s "$preparation_log" ]] || fail 'daily action invoked a package manager'
)

test_binary_check_is_parse_only_and_stops_on_version_failure() (
    local fake="$TEST_ROOT/fake-kanata" cfg="$TEST_ROOT/fixture.kbd" log="$TEST_ROOT/check-log" output
    : >"$cfg"; : >"$log"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$TEST_CHECK_LOG"' \
        'if [[ "$1" == --version ]]; then [[ "${TEST_VERSION_FAIL:-0}" == 0 ]] && printf "%s\n" "${TEST_VERSION_TEXT:-kanata 1.12.0}"; exit "${TEST_VERSION_FAIL:-0}"; fi' \
        'if [[ "$1" == --check ]]; then exit "${TEST_CONFIG_FAIL:-0}"; fi' >"$fake"
    chmod 0700 "$fake"
    TEST_CHECK_LOG="$log" kanata_check_binary "$fake" "$cfg" v1.12.0 || fail 'valid fake binary/config rejected'
    output="$(<"$log")"
    [[ "$output" == $'--version\n--check --cfg '"$cfg" ]] || fail 'expected only --version and parse-only --check invocations'
    : >"$log"
    if TEST_CHECK_LOG="$log" TEST_VERSION_FAIL=7 kanata_check_binary "$fake" "$cfg" v1.12.0 >/dev/null 2>&1; then fail 'version failure accepted'; fi
    assert_eq "$(<"$log")" '--version'
    local bad_version
    for bad_version in 'kanata 1x12x0' 'kanata 1.12.01' 'kanata 1.12.0-dev'; do
        : >"$log"
        if TEST_CHECK_LOG="$log" TEST_VERSION_TEXT="$bad_version" kanata_check_binary "$fake" "$cfg" v1.12.0 >/dev/null 2>&1; then
            fail "non-exact version was accepted as the pinned release: $bad_version"
        fi
        assert_eq "$(<"$log")" '--version'
    done
)

test_source_fallback_only_after_prebuilt_runtime_failure() (
    local fake="$TEST_ROOT/fallback-kanata" cfg="$TEST_ROOT/fallback.kbd" output
    : >"$cfg"
    printf '%s\n' '#!/usr/bin/env bash' 'echo "kanata 1.12.0"' >"$fake"; chmod 0700 "$fake"
    KANATA_SYSTEM_BINARY="$TEST_ROOT/not-installed"
    kanata_linux_prebuilt() { return 10; }
    kanata_linux_build_source() { printf '%s\n' "$fake"; }
    output="$(kanata_linux_select_binary "$TEST_ROOT" "$cfg")" || fail 'source fallback did not run'
    assert_eq "$output" "$fake"

    local source_log="$TEST_ROOT/source-fallback-called"
    : >"$source_log"
    kanata_linux_prebuilt() { return 1; }
    kanata_linux_build_source() { printf 'called\n' >>"$source_log"; return 1; }
    if kanata_linux_select_binary "$TEST_ROOT" "$cfg" >/dev/null 2>&1; then fail 'prebuilt integrity failure was accepted'; fi
    [[ ! -s "$source_log" ]] || fail 'checksum/integrity failure incorrectly triggered source fallback'
)

test_linux_existing_binary_is_reused_only_at_pinned_version() (
    local system="$TEST_ROOT/existing-kanata" config="$TEST_ROOT/existing-config" replacement="$TEST_ROOT/replacement-kanata" output
    : >"$config"
    printf '#!/usr/bin/env bash\nprintf "kanata 1.12.0\\n"\n' >"$system"
    printf '#!/usr/bin/env bash\nprintf "kanata 1.12.0\\n"\n' >"$replacement"
    chmod 0700 "$system" "$replacement"
    KANATA_SYSTEM_BINARY="$system"
    kanata_linux_native_elf() { return 0; }
    kanata_check_binary() { [[ "$1" == "$system" ]]; }
    kanata_linux_prebuilt() { printf 'download-attempt\n' >>"$TEST_ROOT/existing-selection.log"; return 10; }
    kanata_linux_build_source() { printf '%s\n' "$replacement"; }
    : >"$TEST_ROOT/existing-selection.log"
    output="$(kanata_linux_select_binary "$TEST_ROOT" "$config")" || fail 'pinned existing binary was not reusable'
    assert_eq "$output" "$system"
    [[ ! -s "$TEST_ROOT/existing-selection.log" ]] || fail 'usable existing binary triggered a download/build'

    printf '#!/usr/bin/env bash\nprintf "kanata 1.11.9\\n"\n' >"$system"
    chmod 0700 "$system"
    output="$(kanata_linux_select_binary "$TEST_ROOT" "$config")" || fail 'wrong-version binary did not select same-release fallback'
    assert_eq "$output" "$replacement"
    [[ -s "$TEST_ROOT/existing-selection.log" ]] || fail 'wrong-version binary bypassed pinned acquisition'
)

test_linux_candidate_output_is_only_a_path() (
    local installed="$TEST_ROOT/incompatible-installed" config="$TEST_ROOT/candidate-config" candidate="$TEST_ROOT/native-candidate" output
    printf '%s\n' '#!/usr/bin/env bash' 'echo "kanata 1.12.0"' >"$installed"; chmod 0700 "$installed"
    : >"$config"; printf 'candidate\n' >"$candidate"
    KANATA_SYSTEM_BINARY="$installed"
    kanata_linux_native_elf() { return 1; }
    kanata_linux_prebuilt() { return 10; }
    kanata_linux_build_source() { printf '%s\n' "$candidate"; }
    output="$(kanata_linux_select_binary "$TEST_ROOT" "$config" 2>"$TEST_ROOT/select.stderr")" || fail 'native fallback was not selected'
    assert_eq "$output" "$candidate"
    grep -q 'native Linux runtime' "$TEST_ROOT/select.stderr" || fail 'compatibility diagnostic was not sent to stderr'
)

test_linux_source_fallback_does_not_require_pkg_config() (
    [[ -x /usr/bin/cc ]] || return 0
    local source_root="$TEST_ROOT/source-fallback" config="$TEST_ROOT/source-config" fakebin="$TEST_ROOT/source-bin"
    mkdir -p "$fakebin"; : >"$config"; export MOCK_CONTROLLER_CHECK="$TEST_ROOT/controller-check"
cat >"$fakebin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo build diagnostic on stdout\n'
[[ -z "${NIX_LDFLAGS:-}${NIX_CFLAGS_COMPILE:-}${NIX_CC:-}${LD_LIBRARY_PATH:-}${LIBRARY_PATH:-}${RUSTFLAGS:-}${CARGO_ENCODED_RUSTFLAGS:-}" ]] || exit 91
[[ -z "${CARGO_BUILD_TARGET:-}" ]] || exit 92
[[ "${CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER:-}" == /usr/bin/cc ]] || exit 95
[[ "${CARGO_BUILD_RUSTFLAGS:-}" == '' ]] || exit 96
[[ "${CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS:-}" == '' ]] || exit 97
[[ "$*" == 'build --locked --release --target x86_64-unknown-linux-gnu --config build.rustflags=[] --config target.x86_64-unknown-linux-gnu.rustflags=[] --manifest-path '* ]] || exit 94
target=''
while (($#)); do
    if [[ "$1" == --target ]]; then target="$2"; shift 2; else shift; fi
done
[[ "$target" == x86_64-unknown-linux-gnu ]] || exit 93
artifact_dir="$CARGO_TARGET_DIR/$target/release"
mkdir -p "$artifact_dir"
printf '#!/usr/bin/env bash\necho "kanata 1.12.0"\n' >"$artifact_dir/kanata"
chmod 0700 "$artifact_dir/kanata"
printf '#!/usr/bin/env bash\nexit 0\n' >"$artifact_dir/kanata-controller"
chmod 0700 "$artifact_dir/kanata-controller"
EOF
    chmod 0700 "$fakebin/cargo"
    PATH="$fakebin:/usr/bin:/bin"; export PATH
    NIX_LDFLAGS=fixture NIX_CFLAGS_COMPILE=fixture NIX_CC=fixture LD_LIBRARY_PATH=fixture LIBRARY_PATH=fixture CARGO_BUILD_TARGET=musl RUSTFLAGS=fixture CARGO_ENCODED_RUSTFLAGS=fixture CARGO_BUILD_RUSTFLAGS=fixture
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS=fixture CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=poison-linker
    export NIX_LDFLAGS NIX_CFLAGS_COMPILE NIX_CC LD_LIBRARY_PATH LIBRARY_PATH CARGO_BUILD_TARGET RUSTFLAGS CARGO_ENCODED_RUSTFLAGS CARGO_BUILD_RUSTFLAGS
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER
    git() {
        if [[ "$1" == clone ]]; then printf 'git clone diagnostic on stdout\n'; mkdir -p "${@: -1}"; return 0; fi
        if [[ "$1" == -C ]]; then printf 'v1.12.0\n'; return 0; fi
        fail "unexpected fake git command: $*"
    }
    rustc() { printf 'host: x86_64-unknown-linux-gnu\n'; }
    pkg-config() { fail 'pkg-config must not be required for the pure-Rust Kanata default build'; }
    libudev() { fail 'libudev must not be required for the pure-Rust Kanata default build'; }
    musl-gcc() { fail 'musl toolchain must not be required for native Linux build'; }
    kanata_linux_native_elf() { return 0; }
    kanata_check_binary() { printf 'checked\n' >"$MOCK_CONTROLLER_CHECK"; return 0; }
    local built
    built="$(kanata_linux_build_source "$source_root" "$config")" || fail 'pinned source build mock failed without pkg-config'
    assert_file "$built"
    [[ "$built" == "$source_root/kanata-target/x86_64-unknown-linux-gnu/release/kanata" ]] || fail 'source build stdout contained diagnostics or the candidate used an unexpected target path'
    [[ -s "$MOCK_CONTROLLER_CHECK" ]] || fail 'source build candidate did not receive version/config validation'
    local controller
    controller="$(kanata_linux_build_controller "$TEST_ROOT/controller-work" 2>"$TEST_ROOT/controller-build.stderr")" || fail 'controller build mock failed'
    assert_eq "$controller" "$TEST_ROOT/controller-work/controller-target/x86_64-unknown-linux-gnu/release/kanata-controller"
    kanata_check_binary() { printf 'reject candidate\n' >&2; return 1; }
    if kanata_linux_build_source "$source_root/rejected" "$config" >"$TEST_ROOT/rejected-candidate.out" 2>/dev/null; then fail 'source-built candidate that failed config/version validation was accepted'; fi
    [[ ! -s "$TEST_ROOT/rejected-candidate.out" ]] || fail 'rejected source candidate leaked a path to stdout'
)

test_macos_standard_etc_symlink_is_only_accepted_when_target_is_trusted() (
    kanata_platform() { printf 'macos\n'; }
    MOCK_ETC_LINK=private/etc
    sudo() {
        local op="$1"; shift
        [[ "$op" == /bin/sh && "${1:-}" == -c && "${2:-}" == *'untrusted /etc symlink'* ]] || fail "unexpected Mac target preflight: $op $*"
        case "$MOCK_ETC_LINK" in
        private/etc|/private/etc) return 0 ;;
        *) return 1 ;;
        esac
    }
    kanata_root_dirs_preflight() { return 0; }
    kanata_root_files_preflight() { return 0; }
    kanata_macos_target_preflight || fail 'standard /etc -> private/etc alias was rejected'
    MOCK_ETC_LINK=/private/etc
    kanata_macos_target_preflight || fail 'absolute /etc -> /private/etc alias was rejected'
    MOCK_ETC_LINK=untrusted/etc
    if kanata_macos_target_preflight; then fail 'untrusted /etc alias was accepted'; fi
)

test_source_guards_do_not_run_either_cli_main() (
    local output
    output="$(bash -c 'cd "$2"; source "$1/kanata/kanata.sh"; source "$1/kanata/kanata-install.sh"; declare -F kanata_main >/dev/null && declare -F kanata_install_main >/dev/null' _ "$ROOT" "$TEST_ROOT" 2>"$TEST_ROOT/source.stderr")" || fail 'source-only APIs were not defined from an unrelated working directory'
    [[ -z "$output" ]] || fail 'sourcing a CLI emitted unexpected stdout'
    [[ ! -s "$TEST_ROOT/source.stderr" ]] || fail 'sourcing a CLI emitted diagnostics or invoked a main'
)

test_template_renderer_fails_on_io_and_inspection_errors() (
    local source="$TEST_ROOT/render-template" output="$TEST_ROOT/render-output"
    printf 'User=__KANATA_USER__\n' >"$source"
    kanata_render_template "$source" "$output" mockuser '' '' '' '' || fail 'valid template did not render'
    assert_eq "$(<"$output")" 'User=mockuser'
    if kanata_render_template "$TEST_ROOT/no-such-template" "$TEST_ROOT/missing-source-output" mockuser '' '' '' '' >/dev/null 2>&1; then
        fail 'renderer accepted a missing template source'
    fi
    if kanata_render_template "$source" "$TEST_ROOT/no-such-parent/output" mockuser '' '' '' '' >/dev/null 2>&1; then
        fail 'renderer accepted an unwritable/missing output destination'
    fi
    grep() { return 2; }
    if kanata_render_template "$source" "$TEST_ROOT/grep-error-output" mockuser '' '' '' '' >/dev/null 2>&1; then
        fail 'renderer treated grep inspection failure as successful validation'
    fi
    unset -f grep
)

test_installer_main_dispatch_is_mocked_and_unknown_actions_are_noop() (
    local log="$TEST_ROOT/install-dispatch"
    : >"$log"
    kanata_platform() { printf 'linux\n'; }
    kanata_require_host_target() { [[ "$1" == linux || "$1" == macos ]]; }
    kanata_linux_install() { printf 'linux-install\n' >>"$log"; }
    kanata_macos_install() { printf 'macos-install\n' >>"$log"; }
    kanata_windows_install() { printf 'windows-install\n' >>"$log"; }
    kanata_install_main linux || fail 'installer main did not dispatch default platform'
    kanata_install_main macos || fail 'installer main did not dispatch explicit platform'
    if kanata_install_main remove >/dev/null 2>&1; then fail 'unknown installer action succeeded'; fi
    assert_eq "$(<"$log")" $'linux-install\nmacos-install'
)

test_binary_discovery_stdout_is_path_only_and_macos_rejects_bad_linkage() (
    new_sandbox
    local mac="$TEST_ROOT/mac-homebrew" controller="$HOME/.local/bin/kanata-controller" path
    mkdir -p "$mac/bin" "$(dirname -- "$controller")"
    printf 'mock\n' >"$mac/bin/kanata"; chmod 0700 "$mac/bin/kanata"
    printf 'mock\n' >"$controller"; chmod 0700 "$controller"
    kanata_platform() { printf 'macos\n'; }
    file() { printf 'Mach-O 64-bit executable\n'; }
    otool() { printf '%s: /usr/lib/libSystem.B.dylib\n' "$2"; }
    brew() { printf '/nix/store/fake-kanata\n'; }
    if kanata_macos_binary >"$TEST_ROOT/nix-kanata.out" 2>/dev/null; then fail 'Nix-store Kanata dependency was accepted on macOS'; fi
    [[ ! -s "$TEST_ROOT/nix-kanata.out" ]] || fail 'rejected Nix binary leaked a candidate path'
    brew() { printf 'brew diagnostic\n' >&2; printf '%s\n' "$mac"; }
    otool() { printf 'otool diagnostic\n' >&2; return 1; }
    if kanata_macos_binary >"$TEST_ROOT/otool-kanata.out" 2>/dev/null; then fail 'Kanata binary accepted failed otool inspection'; fi
    [[ ! -s "$TEST_ROOT/otool-kanata.out" ]] || fail 'rejected Kanata binary leaked a candidate path'
    otool() { printf '%s: /nix/store/runtime/lib.dylib\n' "$2"; }
    if kanata_macos_binary >"$TEST_ROOT/nix-dependency-kanata.out" 2>/dev/null; then fail 'Kanata binary with a Nix-store dependency was accepted'; fi
    [[ ! -s "$TEST_ROOT/nix-dependency-kanata.out" ]] || fail 'Nix-dependent Kanata leaked a candidate path'
    otool() { printf '%s: /usr/lib/libSystem.B.dylib\n' "$2"; }
    path="$(kanata_macos_binary 2>"$TEST_ROOT/mac-binary.stderr")" || fail 'macOS Kanata was not found'
    assert_eq "$path" "$mac/bin/kanata"

    otool() { printf 'otool diagnostic\n' >&2; return 1; }
    if kanata_macos_native_binary "$controller" >"$TEST_ROOT/controller.out" 2>"$TEST_ROOT/controller.err"; then fail 'controller native check accepted failed otool inspection'; fi
    [[ ! -s "$TEST_ROOT/controller.out" ]] || fail 'failed otool check wrote non-path stdout'
    otool() { printf '%s: /nix/store/runtime/lib.dylib\n' "$1"; }
    if kanata_macos_native_binary "$controller" >"$TEST_ROOT/controller.out" 2>"$TEST_ROOT/controller.err"; then fail 'controller native check accepted a Nix dependency'; fi
    otool() { printf '%s: /usr/lib/libSystem.B.dylib\n' "$1"; }
    kanata_macos_native_binary "$controller" || fail 'native macOS dependency check rejected the fixture'
)

test_windows_binary_discovery_stdout_is_path_only() (
    new_sandbox
    local path native_appdata='C:\Users\mockuser\AppData\Local' normalized="$TEST_ROOT/native-win-home" cygpath_log="$TEST_ROOT/cygpath-discovery.log"
    LOCALAPPDATA="$native_appdata"; mkdir -p "$normalized/Microsoft/WinGet/Packages/package"
    printf 'fake executable\n' >"$normalized/Microsoft/WinGet/Packages/package/kanata_windows_gui_winIOv2_x64.exe"
    export LOCALAPPDATA
    : >"$cygpath_log"
    cygpath() {
        printf '%s\n' "$*" >>"$cygpath_log"
        if [[ "$1" == -u && "$2" == -a && "$3" == -- && "$4" == "$native_appdata" ]]; then
            printf '%s\n' "$normalized"
        elif [[ "$1" == -u && "$2" == -- ]]; then
            printf 'cygpath executable diagnostic\n' >&2
            printf '/fixture/kanata.exe\n'
        else
            fail "unexpected cygpath arguments: $*"
        fi
    }
    path="$(kanata_find_binary windows 2>"$TEST_ROOT/win-binary.stderr")" || fail 'Windows binary discovery failed'
    assert_eq "$path" '/fixture/kanata.exe'
    grep -Fq -- "-u -a -- $native_appdata" "$cygpath_log" || fail 'native LOCALAPPDATA was not normalized through cygpath -u -a'
)

test_windows_first_install_and_unsafe_parent_preflight() (
    new_sandbox
    local native_appdata='C:\Users\mockuser\AppData\Local' normalized="$HOME/LocalAppData"
    LOCALAPPDATA="$native_appdata"
    mkdir -p "$normalized"
    export LOCALAPPDATA
    cygpath() {
        if [[ "$1" == -u && "$2" == -a && "$3" == -- && "$4" == "$native_appdata" ]]; then printf '%s\n' "$normalized"
        else fail "unexpected cygpath arguments: $*"; fi
    }
    normalized_from_native="$(kanata_windows_localappdata)" || fail 'native LOCALAPPDATA normalization failed'
    assert_eq "$normalized_from_native" "$normalized"
    kanata_windows_task_dir_preflight "$normalized/kanata" "$normalized" || fail 'missing first-install child directory was rejected'
    mkdir -p "$TEST_ROOT/elsewhere"
    ln -s "$TEST_ROOT/elsewhere" "$HOME/unsafe-parent"
    if kanata_windows_task_dir_preflight "$HOME/unsafe-parent/kanata" "$HOME/unsafe-parent"; then fail 'symlinked normalized LOCALAPPDATA parent was accepted'; fi

    LOCALAPPDATA='relative/localappdata'
    cygpath() { printf 'relative/localappdata\n'; }
    if kanata_windows_localappdata >/dev/null 2>&1; then fail 'relative LOCALAPPDATA was accepted as a native absolute path'; fi
)

test_service_queries_distinguish_absent_from_access_errors_and_fail_closed() (
    new_sandbox
    local output
    output="$(kanata_linux_status 2>&1)" || fail 'absent Linux units should report not installed'
    [[ "$output" == *'not installed'* ]] || fail 'absent units were not reported distinctly'
    MOCK_QUERY_FAIL=1 MOCK_QUERY_ERROR='Access denied'
    if kanata_linux_status >/dev/null 2>&1; then fail 'access-denied query was treated as not installed'; fi
    if kanata_linux_action stop >/dev/null 2>&1; then fail 'stop continued after a service query error'; fi
    if kanata_linux_action start >/dev/null 2>&1; then fail 'start continued after a service query error'; fi
    if kanata_linux_action restart >/dev/null 2>&1; then fail 'restart continued after a service query error'; fi
    ! grep -Eq ' (start|stop|restart) ' "$MOCK_LOG" || fail 'service mutation occurred after query failure'

    new_sandbox
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=unrecognized
    if kanata_linux_status >/dev/null 2>&1; then fail 'unknown service state was reported as valid'; fi
)

test_linux_group_query_and_fixed_target_failures_leave_targets_and_services_unchanged() (
    kanata_is_arch_linux() { return 1; }
    local candidate controller selection_log build_log target config
    setup_preflight_fixture() {
        new_sandbox
        kanata_is_arch_linux() { return 1; }
        seed_linux_fixed_targets
        candidate="$TEST_ROOT/preflight-kanata"; controller="$TEST_ROOT/preflight-controller"
        selection_log="$TEST_ROOT/preflight-selection"; build_log="$TEST_ROOT/preflight-build"
        : >"$selection_log"; : >"$build_log"
        printf '%s\n' '#!/usr/bin/env bash' \
            '[[ "$1" == --version ]] && { echo "kanata 1.12.0"; exit 0; }' \
            '[[ "$1" == --check ]] && exit 0' >"$candidate"
        printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$controller"
        chmod 0700 "$candidate" "$controller"
        target="$MOCK_ROOT/var/usrlocal/bin/kanata"
        config="$MOCK_ROOT/etc/kanata/kanata.kbd"
        kanata_linux_prepare_packages() { return 0; }
        kanata_linux_select_binary() {
            printf 'selected\n' >>"$selection_log"
            kanata_check_binary "$candidate" "$2" v1.12.0 || return 1
            printf '%s\n' "$candidate"
        }
        kanata_linux_build_controller() { printf 'built\n' >>"$build_log"; printf '%s\n' "$controller"; }
    }

    # Even after acquisition and validation, a missing required group prevents
    # fixed-target writes and service changes.
    setup_preflight_fixture
    MOCK_MISSING_GROUP=uinput MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    if kanata_linux_install >/dev/null 2>&1; then fail 'installer accepted a missing required input group'; fi
    [[ -s "$selection_log" && -s "$build_log" ]] || fail 'missing-group test did not reach actual acquisition/build gates'
    assert_eq "$(<"$target")" 'preexisting-kanata'
    assert_eq "$(<"$config")" 'preexisting-config'
    assert_eq "$MOCK_MUTATIONS" 0
    assert_eq "$MOCK_SERVICE_CHANGES" 0

    # A service-query error also leaves both target contents and service state
    # untouched, even after the candidate has been acquired and checked.
    setup_preflight_fixture
    MOCK_QUERY_FAIL=1 MOCK_QUERY_ERROR='Failed to connect to bus' MOCK_QUERY_FAIL_SCOPE=system MOCK_QUERY_FAIL_UNIT=kanata.service
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    if kanata_linux_install >/dev/null 2>&1; then fail 'installer accepted system manager query failure'; fi
    [[ -s "$selection_log" && -s "$build_log" ]] || fail 'query-error test did not reach actual acquisition/build gates'
    assert_eq "$(<"$target")" 'preexisting-kanata'
    assert_eq "$(<"$config")" 'preexisting-config'
    assert_eq "$MOCK_MUTATIONS" 0
    assert_eq "$MOCK_SERVICE_CHANGES" 0

    # Fixed-target preflight is likewise a no-write/no-stop gate.
    setup_preflight_fixture
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    kanata_linux_preflight_paths() { return 1; }
    if kanata_linux_install >/dev/null 2>&1; then fail 'installer accepted failed fixed-target preflight'; fi
    [[ -s "$selection_log" && -s "$build_log" ]] || fail 'target-preflight test did not reach actual acquisition/build gates'
    assert_eq "$(<"$target")" 'preexisting-kanata'
    assert_eq "$MOCK_SERVICE_CHANGES" 0
    assert_eq "$MOCK_MUTATIONS" 0
)

test_arch_package_preparation_is_minimal_and_failure_precedes_deployment() (
    new_sandbox
    uname() { printf 'Linux\n'; }
    local log="$TEST_ROOT/pacman-preparation" arch_marker="$TEST_ROOT/arch-release-fixture" definition saved_path="$PATH" empty_path="$TEST_ROOT/empty-tool-path"
    mkdir -p "$empty_path"
    : >"$arch_marker"; : >"$log"
    definition="$(declare -f kanata_is_arch_linux)"
    definition="${definition//\/etc\/arch-release/$arch_marker}"
    eval "$definition"
    MOCK_EXPECTED_PACMAN_ARGS='-S --needed --noconfirm base-devel git curl unzip binutils rust'
    pacman() {
        printf '%s\n' "$*" >>"$log"
        [[ "$*" == "$MOCK_EXPECTED_PACMAN_ARGS" ]] || fail "unexpected Arch package list: $*"
        (( MOCK_PACMAN_FAIL == 0 ))
    }
    sudo() {
        [[ "${1:-}" == pacman ]] || fail "unexpected package preparation privilege command: $*"
        shift
        pacman "$@"
    }
    for utility in mktemp chmod mkdir install rm; do
        utility_source="$(PATH="$saved_path" command -v "$utility")"
        [[ -n "$utility_source" ]] || fail "missing utility for isolated PATH fixture: $utility"
        ln -s "$utility_source" "$empty_path/$utility"
    done
    PATH="$empty_path"; export PATH
    kanata_linux_prepare_packages || fail 'Arch dependency preparation failed unexpectedly'
    assert_eq "$(<"$log")" "$MOCK_EXPECTED_PACMAN_ARGS"
    local package_output
    package_output="$(<"$log")"
    [[ "$package_output" != *libudev* && "$package_output" != *pkg-config* && "$package_output" != *kanata* ]] || fail 'Arch dependency list included a forbidden development or distro Kanata package'

    # If Rust is already provided by rustup, only missing build/download tools
    # are requested from pacman; this avoids replacing the existing toolchain.
    cargo() { return 0; }
    rustc() { return 0; }
    rustup() { return 0; }
    MOCK_EXPECTED_PACMAN_ARGS='-S --needed --noconfirm base-devel git curl unzip binutils'
    : >"$log"
    kanata_linux_prepare_packages || fail 'Arch preparation failed with existing Cargo/rustup'
    assert_eq "$(<"$log")" "$MOCK_EXPECTED_PACMAN_ARGS"
    package_output="$(<"$log")"
    [[ " $package_output " != *' rust '* ]] || fail 'Arch preparation would replace an existing rustup toolchain'
    unset -f cargo rustc rustup

    # A non-Arch fixture skips pacman entirely.
    local nonarch_marker="$TEST_ROOT/not-arch-release"
    rm -f "$arch_marker"
    definition="$(declare -f kanata_is_arch_linux)"
    definition="${definition//$arch_marker/$nonarch_marker}"
    eval "$definition"
    : >"$log"
    kanata_linux_prepare_packages || fail 'non-Arch Linux package preparation should be a no-op'
    [[ ! -s "$log" ]] || fail 'non-Arch Linux attempted pacman preparation'

    # A package-manager failure is allowed before deployment, but it must not
    # stop or otherwise change managed services or fixed Kanata targets.
    PATH="$saved_path"; export PATH
    local utility_path="$TEST_ROOT/package-failure-utils" utility utility_source
    mkdir -p "$utility_path"
    for utility in mktemp chmod mkdir install rm; do
        utility_source="$(command -v "$utility")"
        [[ -n "$utility_source" ]] || fail "missing fixture-only utility for safe package failure test: $utility"
        ln -s "$utility_source" "$utility_path/$utility"
    done
    new_sandbox
    seed_linux_fixed_targets
    arch_marker="$TEST_ROOT/arch-release-install-fixture"; : >"$arch_marker"
    definition="$(declare -f kanata_is_arch_linux)"
    definition="${definition//$nonarch_marker/$arch_marker}"
    eval "$definition"
    local package_log="$TEST_ROOT/pacman-failed-install"; : >"$package_log"
    pacman() { printf '%s\n' "$*" >>"$package_log"; return 1; }
    sudo() { [[ "${1:-}" == pacman ]] || fail "unexpected privileged command during package failure: $*"; shift; pacman "$@"; }
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active MOCK_PACMAN_FAIL=1
    PATH="$utility_path"; export PATH
    if kanata_linux_install >/dev/null 2>&1; then fail 'Linux install hid pacman failure'; fi
    PATH="$saved_path"; export PATH
    grep -Fq -- '-S --needed --noconfirm base-devel git curl unzip binutils rust' "$package_log" || fail 'failed Arch package install was not exercised'
    assert_eq "$(<"$MOCK_ROOT/var/usrlocal/bin/kanata")" 'preexisting-kanata'
    assert_eq "$MOCK_SERVICE_CHANGES" 0
    assert_eq "$MOCK_MUTATIONS" 0
)

test_arch_repo_binary_daily_preference_and_install_targets() (
    new_sandbox
    local arch_marker="$TEST_ROOT/arch-detection-fixture" architecture_definition find_definition original_arch='/etc/arch-release' original_binary='/usr/bin/kanata'
    local repository_binary="$TEST_ROOT/repository-kanata" stale_local_binary="$TEST_ROOT/stale-local-kanata" selection_log="$TEST_ROOT/arch-daily-selection"
    : >"$arch_marker"; : >"$selection_log"
    architecture_definition="$(declare -f kanata_is_arch_linux)"
    architecture_definition="${architecture_definition//$original_arch/$arch_marker}"
    eval "$architecture_definition"
    find_definition="$(declare -f kanata_find_binary)"
    find_definition="${find_definition//$original_binary/$repository_binary}"
    eval "$find_definition"
    printf '%s\n' '#!/usr/bin/env bash' \
        'printf "repository-binary\\n" >>"$KANATA_TEST_BINARY_LOG"' \
        '[[ "$1" == --version ]] && { echo "kanata 0.8.1"; exit 0; }' \
        '[[ "$1" == --check ]] && exit 0' >"$repository_binary"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "stale-local\\n" >>"$KANATA_TEST_BINARY_LOG"' 'exit 0' >"$stale_local_binary"
    chmod 0700 "$repository_binary" "$stale_local_binary"
    KANATA_SYSTEM_BINARY="$stale_local_binary"
    KANATA_TEST_BINARY_LOG="$selection_log"
    export KANATA_TEST_BINARY_LOG
    pacman() { fail 'Arch daily check invoked pacman'; }
    yay() { fail 'Arch daily check invoked yay'; }
    kanata_main check || fail 'Arch daily check rejected the runnable repository Kanata binary'
    grep -Fq repository-binary "$selection_log" || fail 'Arch daily check did not select /usr/bin/kanata'
    ! grep -Fq stale-local "$selection_log" || fail 'Arch daily check selected a stale local Kanata before repository Kanata'

    new_sandbox
    : >"$arch_marker"
    architecture_definition="$(declare -f kanata_is_arch_linux)"
    architecture_definition="${architecture_definition//$original_arch/$arch_marker}"
    eval "$architecture_definition"
    local event_log="$TEST_ROOT/arch-install-events" candidate="$TEST_ROOT/arch-selection-forbidden" arch_controller_fixture="$TEST_ROOT/arch-controller"
    : >"$event_log"; : >"$arch_controller_fixture"
    seed_linux_fixed_targets
    export KANATA_TEST_EVENT_LOG="$event_log"
    MOCK_SYSTEM_LOAD=not-found MOCK_USER_CONTROLLER_LOAD=not-found
    kanata_linux_prepare_packages() { printf 'dependency-prep\n' >>"$event_log"; return 0; }
    kanata_check_binary() {
        [[ "$1" == /usr/bin/kanata && $# == 2 ]] || fail "Arch installer did not validate repo-owned /usr/bin/kanata without a pinned version: $*"
        printf 'checked-repo-binary\n' >>"$event_log"
        return 0
    }
    kanata_linux_select_binary() { printf 'selection-forbidden\n' >>"$event_log"; return 1; }
    kanata_linux_build_source() { printf 'source-fallback-forbidden\n' >>"$event_log"; return 1; }
    kanata_linux_build_controller() { printf 'controller-build\n' >>"$event_log"; printf '%s\n' "$arch_controller_fixture"; }
    kanata_linux_preflight_paths() { return 0; }
    kanata_user_file_preflight() { return 0; }
    kanata_root_ensure_dir() {
        printf 'root-directory %s\n' "$1" >>"$event_log"
        mkdir -p "$(virtual_path "$1")"
    }
    kanata_root_install_file() {
        local host
        host="$(virtual_path "$2")"
        mkdir -p "$(dirname -- "$host")"
        printf 'root-write %s\n' "$2" >>"$event_log"
        command install -m "$3" "$1" "$host"
    }
    yay() { printf 'yay %s\n' "$*" >>"$event_log"; return 0; }
    pacman() { printf 'pacman %s\n' "$*" >>"$event_log"; return 0; }
    kanata_linux_install || fail 'Arch repository install failed'
    grep -Fq 'yay -S --needed --noconfirm kanata' "$event_log" || fail 'Arch installer did not prefer yay for repository Kanata'
    ! grep -Fq 'selection-forbidden' "$event_log" || fail 'Arch installer entered pinned binary selection'
    ! grep -Fq 'source-fallback-forbidden' "$event_log" || fail 'Arch installer attempted pinned source fallback'
    ! grep -Fq 'root-write /usr/local/bin/kanata' "$event_log" || fail 'Arch installer copied package-owned Kanata to /usr/local'
    assert_eq "$(<"$MOCK_ROOT/var/usrlocal/bin/kanata")" 'preexisting-kanata'
    grep -Fq 'ExecStart=/usr/bin/kanata ' "$MOCK_ROOT/etc/systemd/system/kanata.service" || fail 'Arch system unit did not use repository Kanata path'

    local saved_path="$PATH" no_yay="$TEST_ROOT/no-yay-path"; mkdir -p "$no_yay"
    unset -f yay
    PATH="$no_yay"; export PATH
    kanata_install_arch_packages || fail 'Arch fallback package installation failed without yay'
    PATH="$saved_path"; export PATH
    grep -Fq 'pacman --needed --noconfirm -S kanata' "$event_log" || fail 'Arch did not fall back to pacman when yay was unavailable'
)

test_linux_configuration_template_and_toolchain_gates_precede_privilege() (
    new_sandbox
    kanata_is_arch_linux() { return 1; }
    kanata_linux_prepare_packages() { return 0; }
    local saved_dotfiles="$DOTFILES_DIR" candidate="$TEST_ROOT/candidate" controller="$TEST_ROOT/controller" fakebin="$TEST_ROOT/fail-cargo-bin"
    local original_controller_builder
    original_controller_builder="$(declare -f kanata_linux_build_controller)"
    DOTFILES_DIR="$TEST_ROOT/no-configuration"
    mkdir -p "$DOTFILES_DIR/kanata/config"
    seed_linux_fixed_targets
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    if kanata_linux_install >/dev/null 2>&1; then fail 'missing config passed Linux installation gate'; fi
    assert_eq "$MOCK_MUTATIONS" 0
    assert_eq "$(<"$MOCK_ROOT/var/usrlocal/bin/kanata")" 'preexisting-kanata'
    assert_eq "$MOCK_SERVICE_CHANGES" 0
    ! grep -Eq '^sudo |^sudo-auth' "$MOCK_LOG" || fail 'missing config reached privileged commands'

    DOTFILES_DIR="$TEST_ROOT/template-fixture"
    mkdir -p "$DOTFILES_DIR/kanata/config"
    cp "$saved_dotfiles/kanata/config/kanata-linux.kbd" "$DOTFILES_DIR/kanata/config/kanata-linux.kbd"
    cp "$saved_dotfiles/kanata/config/kanata-common.kbd" "$DOTFILES_DIR/kanata/config/kanata-common.kbd"
    printf 'candidate\n' >"$candidate"; printf 'controller\n' >"$controller"
    seed_linux_fixed_targets
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    kanata_linux_preflight() { return 0; }
    kanata_linux_select_binary() { printf '%s\n' "$candidate"; }
    kanata_linux_build_controller() { printf '%s\n' "$controller"; }
    if kanata_linux_install >/dev/null 2>&1; then fail 'missing service templates passed Linux installation gate'; fi
    assert_eq "$MOCK_MUTATIONS" 0
    assert_eq "$(<"$MOCK_ROOT/var/usrlocal/bin/kanata")" 'preexisting-kanata'
    assert_eq "$MOCK_SERVICE_CHANGES" 0
    ! grep -Eq '^sudo |^sudo-auth' "$MOCK_LOG" || fail 'template validation reached privileged commands'

    DOTFILES_DIR="$saved_dotfiles"
    eval "$original_controller_builder"
    mkdir -p "$fakebin"
    printf '#!/usr/bin/env bash\nprintf "mock cargo failure\\n" >&2\nexit 1\n' >"$fakebin/cargo"
    chmod 0700 "$fakebin/cargo"
    PATH="$fakebin:$PATH"; export PATH
    rustc() { printf 'host: x86_64-unknown-linux-gnu\n'; }
    seed_linux_fixed_targets
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    if kanata_linux_install >/dev/null 2>&1; then fail 'controller toolchain failure passed Linux installation gate'; fi
    assert_eq "$MOCK_MUTATIONS" 0
    assert_eq "$(<"$MOCK_ROOT/var/usrlocal/bin/kanata")" 'preexisting-kanata'
    assert_eq "$MOCK_SERVICE_CHANGES" 0
    ! grep -Eq '^sudo |^sudo-auth' "$MOCK_LOG" || fail 'controller build failure reached privileged commands'
)

test_atomic_replace_failures_preserve_existing_user_and_root_files() (
    new_sandbox
    local source="$TEST_ROOT/new-content" user_file="$HOME/user-target" root_file="$TEST_ROOT/root-targets/bin/target"
    mkdir -p "$(dirname -- "$root_file")"
    printf 'replacement\n' >"$source"
    printf 'user-original\n' >"$user_file"
    mv() { return 1; }
    if kanata_atomic_user_file "$source" "$user_file" 0600; then fail 'user atomic replacement unexpectedly succeeded'; fi
    assert_eq "$(<"$user_file")" 'user-original'
    unset -f mv

    printf 'root-original\n' >"$root_file"
    MOCK_FAIL_ROOT_MV=1
    if kanata_root_install_file "$source" "$root_file" 0755; then fail 'root atomic replacement unexpectedly succeeded'; fi
    assert_eq "$(<"$root_file")" 'root-original'
    assert_eq "$(<"$root_file.pre-kanata.bak")" 'root-original'
)

test_fixed_root_targets_reject_direct_destination_and_backup_symlinks() (
    new_sandbox
    mkdir -p "$MOCK_ROOT/var/usrlocal/bin"
    ln -s "$TEST_ROOT/outside-file" "$MOCK_ROOT/var/usrlocal/bin/target"
    if kanata_root_files_preflight /usr/local/bin/target; then fail 'root preflight accepted a fixed-target symlink'; fi
    assert_eq "$MOCK_MUTATIONS" 0

    new_sandbox
    mkdir -p "$MOCK_ROOT/var/usrlocal/bin"
    printf 'original\n' >"$MOCK_ROOT/var/usrlocal/bin/target"
    ln -s "$TEST_ROOT/outside-backup" "$MOCK_ROOT/var/usrlocal/bin/target.pre-kanata.bak"
    if kanata_root_files_preflight /usr/local/bin/target; then fail 'root preflight accepted a backup-path symlink'; fi
    assert_eq "$(<"$MOCK_ROOT/var/usrlocal/bin/target")" 'original'
    assert_eq "$MOCK_MUTATIONS" 0
)

test_windows_task_state_normalizes_crlf_and_rejects_unknown_state() (
    new_sandbox
    powershell.exe() { printf '4\r\n'; }
    assert_eq "$(kanata_windows_task_query)" 4
    powershell.exe() { printf '0\r\n'; }
    if kanata_windows_task_query >/dev/null 2>&1; then fail 'Windows task state 0 (unknown) was accepted'; else
        local unknown_status=$?
        assert_eq "$unknown_status" 2
    fi
    powershell.exe() { printf '3\r\n'; }
    assert_eq "$(kanata_windows_task_query)" 3
    powershell.exe() { printf 'mystery\r\n'; }
    if kanata_windows_task_query >/dev/null 2>&1; then fail 'malformed Windows task state was accepted'; fi
)

test_windows_task_query_errors_are_not_absence_and_never_mutate() (
    new_sandbox
    local log="$TEST_ROOT/windows-query-errors" output fake="$TEST_ROOT/windows-query-kanata" native_appdata='C:\Users\mockuser\AppData\Local' normalized="$HOME/LocalAppData"
    : >"$log"
    WINDOWS_TASK_RESULT=NOT_FOUND
    powershell.exe() {
        case "$*" in
        *IsInRole*) printf 'True\n' ;;
        *GetTask*)
            case "$WINDOWS_TASK_RESULT" in
            NOT_FOUND) printf 'NOT_FOUND\n' ;;
            ACCESS_DENIED) printf 'Access denied\n' >&2; return 1 ;;
            RUNNING) printf '4\r\n' ;;
            esac
            ;;
        *Schedule.Service*) return 0 ;;
        *Get-Content*) printf '<Task><LogonTrigger/></Task>\n' >"$TEST_XML_OUTPUT" ;;
        *) printf 'MOCK\\mockuser\n' ;;
        esac
    }
    cygpath() {
        if [[ "$1" == -u && "$2" == -a && "$3" == -- && "$4" == "$native_appdata" ]]; then printf '%s\n' "$normalized"
        elif [[ "$1" == -u && "$2" == -- ]]; then printf '%s\n' "$fake"
        else printf 'C:\\fixture\\path\n'; fi
    }
    kanata_windows_schtasks() { printf '%s\n' "$*" >>"$log"; return 0; }
    output="$(kanata_windows_status 2>/dev/null)" || fail 'NOT_FOUND task status was treated as a query error'
    [[ "$output" == *'not installed'* ]] || fail 'actual Windows task query did not report NOT_FOUND distinctly'
    if kanata_windows_start; then fail 'Windows start succeeded with an absent task'; fi
    kanata_windows_stop || fail 'Windows stop should be a no-op for an absent task'
    [[ ! -s "$log" ]] || fail 'absent task caused a task mutation'

    WINDOWS_TASK_RESULT=ACCESS_DENIED
    printf '%s\n' '#!/usr/bin/env bash' '[[ "$1" == --version ]] && { echo "kanata 1.12.0"; exit 0; }' '[[ "$1" == --check ]] && exit 0' >"$fake"
    chmod 0700 "$fake"
    mkdir -p "$normalized/Microsoft/WinGet/Packages"
    export LOCALAPPDATA="$native_appdata" USERDOMAIN=MOCK USERNAME=mockuser
    TEST_EXPECTED_DATA_DIR="$normalized/kanata" TEST_XML_OUTPUT="$TEST_ROOT/query-error-task.xml"
    export TEST_EXPECTED_DATA_DIR TEST_XML_OUTPUT
    winget() {
        printf 'winget %s\n' "$*" >>"$log"
        [[ "$*" == *'--id jtroo.kanata_gui'* ]] || fail "unexpected WinGet package id: $*"
        (( ${MOCK_WINGET_FAIL:-0} == 0 )) || return 1
        mkdir -p "$normalized/Microsoft/WinGet/Packages/Fixture.Kanata"
        cp "$fake" "$normalized/Microsoft/WinGet/Packages/Fixture.Kanata/kanata_windows_gui_winIOv2_x64.exe"
    }
    kanata_check_binary() { printf 'binary-check\n' >>"$log"; return 0; }
    if kanata_windows_task_present; then fail 'access denied was treated as an installed task'; else
        local query_status=$?
        assert_eq "$query_status" 2
    fi
    if output="$(kanata_windows_status 2>/dev/null)"; then fail 'Windows status hid a COM permission error'; fi
    if kanata_windows_start >/dev/null 2>&1; then fail 'Windows start hid a COM permission error'; fi
    if kanata_windows_stop >/dev/null 2>&1; then fail 'Windows stop hid a COM permission error'; fi
    if kanata_windows_restart >/dev/null 2>&1; then fail 'Windows restart hid a COM permission error'; fi

    WINDOWS_TASK_RESULT=NOT_FOUND MOCK_WINGET_FAIL=1
    if kanata_windows_install >/dev/null 2>&1; then fail 'Windows install hid WinGet package failure'; fi
    [[ ! -e "$TEST_EXPECTED_DATA_DIR" ]] || fail 'WinGet failure wrote the per-user Kanata target'
    ! grep -Eq '//(Create|Run|End)' "$log" || fail 'WinGet failure mutated the managed task'

    MOCK_WINGET_FAIL=0
    WINDOWS_TASK_RESULT=ACCESS_DENIED
    if kanata_windows_install >/dev/null 2>&1; then fail 'Windows install accepted a COM permission error'; fi
    grep -Fq 'winget install' "$log" || fail 'Windows software preparation was not exercised before task query'
    [[ ! -e "$TEST_EXPECTED_DATA_DIR" ]] || fail 'Windows query failure wrote the per-user Kanata target'
    ! grep -Eq '//(Create|Run|End)' "$log" || fail 'Windows COM query error changed the managed task'
)

test_pinned_prebuilt_checksum_precedes_extraction() (
    local archive_source="$TEST_ROOT/pinned-archive" fake_binary="$TEST_ROOT/pinned-kanata" config="$TEST_ROOT/pinned.kbd" output
    printf 'synthetic archive fixture\n' >"$archive_source"
    : >"$config"
    printf '%s\n' '#!/usr/bin/env bash' '[[ "$1" == --version ]] && { echo "kanata 1.12.0"; exit 0; }' '[[ "$1" == --check ]] && { echo "config check diagnostic on stdout"; exit 0; }' >"$fake_binary"
    chmod 0700 "$fake_binary"
    TEST_UNZIP_LOG="$TEST_ROOT/unzip.log"; export TEST_UNZIP_LOG
    : >"$TEST_UNZIP_LOG"
    curl() {
        local destination=''
        while (($#)); do
            if [[ "$1" == --output ]]; then destination="$2"; shift 2; else shift; fi
        done
        cp "$archive_source" "$destination"
    }
    unzip() {
        printf '%s\n' "$*" >>"$TEST_UNZIP_LOG"
        case "$1" in
        -tqq) printf 'archive test diagnostic on stdout\n'; return 0 ;;
        -Z1) printf 'kanata_linux_x64\n' ;;
        -p) cat "$fake_binary" ;;
        *) fail "unexpected unzip operation: $1" ;;
        esac
    }
    kanata_linux_native_elf() { return 0; }
    KANATA_LINUX_ARCHIVE_SHA256="$(sha256sum "$archive_source" | awk '{print $1}')"
    mkdir -p "$TEST_ROOT/prebuilt-good" "$TEST_ROOT/prebuilt-bad"
    kanata_linux_native_elf() { return 1; }
    local prebuilt_status
    if kanata_linux_prebuilt "$TEST_ROOT/prebuilt-good" "$config" >/dev/null 2>&1; then fail 'ABI-incompatible prebuilt was accepted'; else prebuilt_status=$?; fi
    assert_eq "$prebuilt_status" 10

    kanata_linux_native_elf() { return 0; }
    output="$(kanata_linux_prebuilt "$TEST_ROOT/prebuilt-good" "$config")" || fail 'valid pinned mock archive was rejected'
    assert_file "$output"
    [[ -s "$TEST_UNZIP_LOG" ]] || fail 'verified archive was not inspected/extracted'

    : >"$TEST_UNZIP_LOG"
    KANATA_LINUX_ARCHIVE_SHA256=wrong-digest
    if kanata_linux_prebuilt "$TEST_ROOT/prebuilt-bad" "$config" >/dev/null 2>&1; then fail 'checksum mismatch was accepted'; fi
    [[ ! -s "$TEST_UNZIP_LOG" ]] || fail 'archive was inspected or extracted before its digest matched'
)

test_linux_install_orders_preparation_check_stop_deploy_enable_start_and_propagates_failures() (
    local scenario event_log target config_path
    setup_linux_fixture() {
        kanata_is_arch_linux() { return 1; }
        kanata_linux_prepare_packages() { printf 'prepare-software\n' >>"$KANATA_TEST_EVENT_LOG"; }
        new_sandbox
        MOCK_FAIL_DEPLOY_PATH=''
        event_log="$TEST_ROOT/linux-install-events-$RANDOM"
        : >"$event_log"
        export KANATA_TEST_EVENT_LOG="$event_log"
        local arch_marker="$TEST_ROOT/arch-release-lifecycle-$RANDOM" arch_definition
        : >"$arch_marker"
        arch_definition="$(declare -f kanata_is_arch_linux)"
        arch_definition="${arch_definition//\/etc\/arch-release/$arch_marker}"
        eval "$arch_definition"
        MOCK_CANDIDATE="$TEST_ROOT/candidate-kanata" MOCK_CONTROLLER="$TEST_ROOT/candidate-controller"
        export MOCK_CANDIDATE MOCK_CONTROLLER
        printf '%s\n' '#!/usr/bin/env bash' \
            'if [[ "$1" == --version ]]; then printf "check-version\\n" >>"$KANATA_TEST_EVENT_LOG"; printf "kanata 1.12.0\\n"; exit 0; fi' \
            'if [[ "$1" == --check ]]; then printf "check-config\\n" >>"$KANATA_TEST_EVENT_LOG"; exit 0; fi' >"$MOCK_CANDIDATE"
        printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$MOCK_CONTROLLER"
        chmod 0700 "$MOCK_CANDIDATE" "$MOCK_CONTROLLER"
        target="$(virtual_path /usr/local/bin/kanata)"
        config_path="$(virtual_path /etc/kanata/kanata.kbd)"
        mkdir -p "$(dirname -- "$target")" "$(dirname -- "$config_path")"
        printf 'old-kanata\n' >"$target"
        printf 'old-config\n' >"$config_path"

        pacman() {
            printf 'pacman %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
            case "$*" in
            '-S --needed --noconfirm base-devel git curl unzip binutils'|'-S --needed --noconfirm base-devel git curl unzip binutils rust') ;;
            *) fail "unexpected Arch dependency list: $*" ;;
            esac
            return 0
        }
        kanata_linux_preflight_paths() { [[ "${1:-}" == 0 ]]; }
        kanata_user_file_preflight() { return 0; }
        kanata_linux_select_binary() {
            kanata_check_binary "$MOCK_CANDIDATE" "$2" v1.12.0 || return 1
            printf '%s\n' "$MOCK_CANDIDATE"
        }
        kanata_linux_build_controller() {
            printf 'controller-build\n' >>"$KANATA_TEST_EVENT_LOG"
            printf '%s\n' "$MOCK_CONTROLLER"
        }
        kanata_root_ensure_dir() {
            mkdir -p "$(virtual_path "$1")"
            printf 'directory %s\n' "$1" >>"$KANATA_TEST_EVENT_LOG"
        }
        kanata_root_install_file() {
            local host
            MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
            host="$(virtual_path "$2")"
            mkdir -p "$(dirname -- "$host")"
            printf 'write %s\n' "$2" >>"$KANATA_TEST_EVENT_LOG"
            if [[ "${MOCK_FAIL_DEPLOY_PATH:-}" == "$2" ]]; then return 1; fi
            command install -m "$3" "$1" "$host"
        }
    }

    # Existing active system Kanata is stopped; the inactive controller is
    # not stopped. Both definitions are refreshed and then explicitly started.
    setup_linux_fixture
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    MOCK_USER_CONTROLLER_LOAD=loaded MOCK_CONTROLLER_STATUS=inactive
    kanata_linux_install || fail 'mock Linux active-component install failed'
    grep -Fq 'system stop kanata.service' "$MOCK_LOG" || fail 'active system Kanata was not stopped'
    ! grep -Fq 'user stop kanata-controller.service' "$MOCK_LOG" || fail 'inactive controller was unnecessarily stopped'
    grep -Fq 'system start kanata.service' "$MOCK_LOG" || fail 'installed system Kanata was not started'
    grep -Fq 'user start kanata-controller.service' "$MOCK_LOG" || fail 'installed controller was not started'
    grep -Fq 'ExecStart=/usr/local/bin/kanata --cfg /etc/kanata/kanata.kbd' "$MOCK_ROOT/etc/systemd/system/kanata.service" || fail 'non-Arch service unit used a temporary candidate instead of the durable runtime path'
    ! grep -Fq "$MOCK_CANDIDATE" "$MOCK_ROOT/etc/systemd/system/kanata.service" || fail 'temporary non-Arch candidate path leaked into systemd'
    assert_before 'prepare-software' 'check-version' "$event_log"
    assert_before 'check-config' 'system stop kanata.service' "$event_log"
    assert_before 'system stop kanata.service' 'write /usr/local/bin/kanata' "$event_log"
    assert_before 'write /etc/polkit-1/rules.d/50-kanata-controller.rules' 'system enable kanata.service' "$event_log"
    assert_before 'system enable kanata.service' 'system start kanata.service' "$event_log"
    assert_before 'user enable kanata-controller.service' 'user start kanata-controller.service' "$event_log"

    # A fresh installation starts both services without stopping anything.
    setup_linux_fixture
    if kanata_linux_install >/dev/null 2>&1; then :; else fail 'fresh Linux installation failed'; fi
    ! grep -Eq ' (stop) ' "$MOCK_LOG" || fail 'fresh installation stopped an absent service'
    grep -Fq 'system start kanata.service' "$MOCK_LOG" || fail 'fresh install did not start system Kanata'
    grep -Fq 'user start kanata-controller.service' "$MOCK_LOG" || fail 'fresh install did not start controller'

    # A stop error prevents all fixed-target writes and activation.
    setup_linux_fixture
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active MOCK_SYSTEM_STOP_FAIL=1
    if kanata_linux_install >/dev/null 2>&1; then fail 'Linux install hid a service-stop failure'; fi
    assert_eq "$(<"$target")" 'old-kanata'
    assert_eq "$(<"$config_path")" 'old-config'
    ! grep -Fq 'write ' "$event_log" || fail 'deployment began after a failed stop'
    ! grep -Eq ' start ' "$MOCK_LOG" || fail 'install started a service after stop failure'

    # A deployment error does not restore files or automatically restart the
    # stopped service; partial deployment is retained for manual recovery.
    setup_linux_fixture
    MOCK_SYSTEM_LOAD=loaded MOCK_SYSTEM_STATUS=active
    MOCK_FAIL_DEPLOY_PATH=/etc/kanata/kanata.kbd
    if kanata_linux_install >/dev/null 2>&1; then fail 'Linux install hid a deployment failure'; fi
    grep -Fq 'system stop kanata.service' "$MOCK_LOG" || fail 'deployment fixture did not stop the active service'
    ! grep -Eq ' start ' "$MOCK_LOG" || fail 'deployment failure triggered automatic activation/rollback'
    [[ "$(<"$target")" != old-kanata ]] || fail 'partial deployment was unexpectedly rolled back'

    # Activation failures are returned after deployment and do not claim
    # success or roll back the fixed files.
    setup_linux_fixture
    MOCK_SYSTEM_START_FAIL=1
    if kanata_linux_install >/dev/null 2>&1; then fail 'Linux install hid activation failure'; fi
    assert_file "$target"
    assert_file "$config_path"
)

test_root_atomic_replacement_keeps_first_manual_backup() (
    new_sandbox
    local source="$TEST_ROOT/new-binary" destination="$TEST_ROOT/root-files/bin/kanata" backup
    mkdir -p "$(dirname -- "$destination")"
    printf old >"$destination"
    printf new >"$source"
    kanata_root_install_file "$source" "$destination" 0755 || fail 'root replacement failed'
    backup="$destination.pre-kanata.bak"
    assert_eq "$(<"$destination")" new
    assert_eq "$(<"$backup")" old
    printf newer >"$source"
    kanata_root_install_file "$source" "$destination" 0755 || fail 'second replacement failed'
    assert_eq "$(<"$destination")" newer
    assert_eq "$(<"$backup")" old
)

test_root_comparator_error_preserves_original_without_backup_or_writes() (
    new_sandbox
    local source="$TEST_ROOT/replacement" destination="$TEST_ROOT/root-compare/bin/kanata"
    mkdir -p "$(dirname -- "$destination")"
    printf 'original\n' >"$destination"
    printf 'replacement\n' >"$source"
    MOCK_CMP_ERROR=1
    if kanata_root_install_file "$source" "$destination" 0755; then fail 'root installer accepted comparator I/O failure'; fi
    assert_eq "$(<"$destination")" 'original'
    [[ ! -e "$destination.pre-kanata.bak" ]] || fail 'comparator error created the recovery backup'
    assert_eq "$MOCK_MUTATIONS" 0
)

test_linux_service_actions_preserve_order_and_propagate_failure() (
    new_sandbox
    MOCK_SYSTEM_LOAD=loaded MOCK_USER_CONTROLLER_LOAD=loaded
    kanata_linux_action start || fail 'start action failed with mocked services'
    local root_start user_start
    root_start="$(awk '$0 == "system start kanata.service" { print NR; exit }' "$MOCK_LOG")"
    user_start="$(awk '$0 == "user start kanata-controller.service" { print NR; exit }' "$MOCK_LOG")"
    [[ -n "$root_start" && -n "$user_start" ]] && (( root_start < user_start )) || fail 'tray did not start after remapper'

    new_sandbox
    MOCK_USER_START_FAIL=1
    MOCK_SYSTEM_LOAD=loaded MOCK_USER_CONTROLLER_LOAD=loaded
    if kanata_linux_action start; then fail 'controller start failure was hidden'; fi
    grep -Fq 'system start kanata.service' "$MOCK_LOG" || fail 'main service start not attempted'
    grep -Fq 'user start kanata-controller.service' "$MOCK_LOG" || fail 'controller failure path not exercised'

    new_sandbox
    MOCK_SYSTEM_LOAD=loaded MOCK_USER_CONTROLLER_LOAD=loaded
    kanata_linux_action stop || fail 'mock Linux stop failed'
    local controller_stop system_stop
    controller_stop="$(awk '$0 == "user stop kanata-controller.service" { print NR; exit }' "$MOCK_LOG")"
    system_stop="$(awk '$0 == "system stop kanata.service" { print NR; exit }' "$MOCK_LOG")"
    [[ -n "$controller_stop" && -n "$system_stop" ]] && (( controller_stop < system_stop )) || fail 'controller was not stopped before the system remapper'

    new_sandbox
    MOCK_SYSTEM_LOAD=loaded MOCK_USER_CONTROLLER_LOAD=loaded
    kanata_linux_action restart || fail 'mock Linux restart failed'
    grep -Fq 'system restart kanata.service' "$MOCK_LOG" || fail 'Linux system unit restart was not issued'
    grep -Fq 'user restart kanata-controller.service' "$MOCK_LOG" || fail 'Linux controller restart was not issued'
    local state_output
    state_output="$(kanata_linux_status)" || fail 'mock Linux status failed'
    [[ "$state_output" == *'Kanata: inactive'* && "$state_output" == *'controller: inactive'* ]] || fail 'Linux status did not report the loaded inactive units'
)

test_nonlinux_dispatch_is_explicit_and_mocked() (
    CALL_LOG="$TEST_ROOT/platform-dispatch"
    : >"$CALL_LOG"
    KANATA_TEST_PLATFORM=macos
    kanata_platform() { printf '%s\n' "$KANATA_TEST_PLATFORM"; }
    kanata_require_host_target() { [[ "$1" == "$KANATA_TEST_PLATFORM" ]]; }
    kanata_platform_install() { printf 'install:%s\n' "$1" >>"$CALL_LOG"; }
    kanata_config_check() { printf 'check:%s\n' "$1" >>"$CALL_LOG"; }
    kanata_macos_start() { printf 'mac-start\n' >>"$CALL_LOG"; }
    kanata_main install macos || fail 'macOS install dispatch failed'
    kanata_main check || fail 'macOS check dispatch failed'
    kanata_main start || fail 'macOS start dispatch failed'
    KANATA_TEST_PLATFORM=windows
    kanata_windows_stop() { printf 'windows-stop\n' >>"$CALL_LOG"; }
    kanata_main stop || fail 'Windows stop dispatch failed'
    assert_eq "$(<"$CALL_LOG")" $'install:macos\ncheck:macos\nmac-start\nwindows-stop'
)

test_macos_lifecycle_commands_are_mocked() (
    new_sandbox
    CALL_LOG="$TEST_ROOT/macos-actions"
    : >"$CALL_LOG"
    kanata_macos_agent_loaded() { return 1; }
    kanata_macos_launchctl() { printf 'launchctl %s\n' "$*" >>"$CALL_LOG"; return 0; }
    kanata_macos_control() { printf 'control %s\n' "$*" >>"$CALL_LOG"; return 0; }
    kanata_macos_start || fail 'mock macOS start failed'
    grep -Fq 'control start' "$CALL_LOG" || fail 'macOS helper start was not called through the mock'
    grep -Fq 'launchctl bootstrap' "$CALL_LOG" || fail 'macOS controller bootstrap was not mocked'
    : >"$CALL_LOG"
    kanata_macos_agent_loaded() { return 0; }
    kanata_macos_stop || fail 'mock macOS stop failed'
    grep -Fq 'launchctl bootout' "$CALL_LOG" && grep -Fq 'control stop' "$CALL_LOG" || fail 'macOS stop was not routed through mocks'
    : >"$CALL_LOG"
    kanata_macos_restart || fail 'mock macOS restart failed'
    grep -Fq 'control restart' "$CALL_LOG" && grep -Fq 'launchctl kickstart -k' "$CALL_LOG" || fail 'macOS restart was not routed through mocks'
    ! grep -Eq 'org\.pqrs\.Karabiner-VirtualHIDDevice-Daemon|codesign|ps |kill ' "$CALL_LOG" || fail 'daily macOS controller actions managed VirtualHID'
)

test_macos_job_query_distinguishes_absence_from_errors() (
    new_sandbox
    CALL_LOG="$TEST_ROOT/macos-query"; : >"$CALL_LOG"
    kanata_macos_root_launchctl() { printf 'root %s\n' "$*" >>"$CALL_LOG"; printf 'Operation not permitted\n' >&2; return 1; }
    kanata_macos_launchctl() { printf 'user %s\n' "$*" >>"$CALL_LOG"; printf 'Could not find service\n' >&2; return 1; }
    if kanata_macos_query_job system/dev.kanata.kanata >/dev/null 2>&1; then fail 'launchd access error was treated as an absent job'; fi
    grep -Fq 'root print system/dev.kanata.kanata' "$CALL_LOG" || fail 'system launchd query was not exercised'

    : >"$CALL_LOG"
    kanata_macos_root_launchctl() { printf 'root %s\n' "$*" >>"$CALL_LOG"; printf 'Could not find service\n' >&2; return 1; }
    local state
    state="$(kanata_macos_query_job system/dev.kanata.kanata)" && assert_eq "$state" absent || fail 'missing system launchd job was not distinguished from query failure'
    state="$(kanata_macos_query_job gui/1000/dev.kanata.controller)" && assert_eq "$state" absent || fail 'missing controller launchd job was not distinguished from query failure'
)

test_macos_launchd_stopped_terminal_states_are_not_absent() (
    new_sandbox
    local launchd_state state
    for launchd_state in throttled terminated crashed; do
        kanata_macos_root_launchctl() { printf 'state = %s\n' "$launchd_state"; return 0; }
        state="$(kanata_macos_query_job system/dev.kanata.kanata)" || fail "launchd $launchd_state state query failed"
        assert_eq "$state" loaded
    done
)

test_macos_controller_build_failure_precedes_service_changes_and_target_writes() (
    new_sandbox
    local fakebin="$TEST_ROOT/macos-fail-bin" log="$TEST_ROOT/macos-fail-events" kanata_package_fixture="$TEST_ROOT/macos-fail-kanata"
    MOCK_BREW_PREFIX="$TEST_ROOT/macos-prefix"
    TEST_MAC_ICONV_PREFIX="$TEST_ROOT/macos-libiconv-prefix"
    export MOCK_BREW_PREFIX TEST_MAC_ICONV_PREFIX
    mkdir -p "$MOCK_BREW_PREFIX/bin" "$TEST_MAC_ICONV_PREFIX" "$fakebin"
    : >"$log"
    export KANATA_TEST_EVENT_LOG="$log" CARGO_TARGET_DIR="$TEST_ROOT/macos-fail-target"
    KANATA_MACOS_VHID_BINARY="$TEST_ROOT/mac-driver-fixture"
    printf 'driver fixture\n' >"$KANATA_MACOS_VHID_BINARY"; chmod 0700 "$KANATA_MACOS_VHID_BINARY"
    export KANATA_MACOS_VHID_BINARY
    printf '%s\n' '#!/usr/bin/env bash' 'if [[ "$1" == --version ]]; then echo "kanata 1.12.0"; exit 0; fi' 'if [[ "$1" == --check ]]; then exit 0; fi' >"$kanata_package_fixture"
    chmod 0700 "$kanata_package_fixture"
    printf '#!/usr/bin/env bash\nprintf "cargo-failed\\n" >>"$KANATA_TEST_EVENT_LOG"\nexit 1\n' >"$fakebin/cargo"
    chmod 0700 "$fakebin/cargo"
    PATH="$fakebin:$PATH"; export PATH
    brew() {
        printf 'brew %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        case "$1" in
        install)
            [[ "$*" == 'install kanata libiconv' ]] || return 1
            (( ${MOCK_BREW_FAIL:-0} == 0 )) || return 1
            cp "$kanata_package_fixture" "$MOCK_BREW_PREFIX/bin/kanata"
            chmod 0700 "$MOCK_BREW_PREFIX/bin/kanata"
            ;;
        --prefix)
            case "${2:-}" in
            kanata) printf '%s\n' "$MOCK_BREW_PREFIX" ;;
            libiconv) printf '%s\n' "$TEST_MAC_ICONV_PREFIX" ;;
            *) fail "unexpected Homebrew prefix query: $*" ;;
            esac
            ;;
        *) fail "unexpected brew command: $*" ;;
        esac
    }
    kanata_macos_prepare_software() { brew install kanata libiconv >&2; }
    kanata_macos_require_build_tools() { return 0; }
    rustc() { printf 'host: x86_64-apple-darwin\n'; }
    file() { printf 'Mach-O fixture\n'; }
    otool() { printf '%s: /usr/lib/libSystem.B.dylib\n' "${2:-$1}"; }
    plutil() { return 0; }
    visudo() { return 0; }
    kanata_macos_root_launchctl() { printf 'root launchctl %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"; printf 'Could not find service\n' >&2; return 1; }
    kanata_macos_launchctl() { printf 'user launchctl %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"; printf 'Could not find service\n' >&2; return 1; }
    kanata_root_ensure_dir() { printf 'root-directory %s\n' "$1" >>"$KANATA_TEST_EVENT_LOG"; return 0; }
    kanata_root_install_file() { printf 'root-write %s\n' "$2" >>"$KANATA_TEST_EVENT_LOG"; return 0; }
    kanata_macos_control() { printf 'control %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"; return 0; }
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install hid controller Cargo build failure'; fi
    grep -Fq 'brew install kanata libiconv' "$log" || fail 'macOS preparation did not attempt the approved Homebrew packages'
    grep -Fq 'cargo-failed' "$log" || fail 'macOS install did not exercise the Cargo build failure path'
    ! grep -Eq 'root-write|root-directory|control (stop|start)|launchctl (bootout|bootstrap|kickstart)|launchctl (enable)' "$log" || fail 'macOS controller build failure changed services or fixed targets'

    new_sandbox
    rm -f "$MOCK_BREW_PREFIX/bin/kanata"
    log="$TEST_ROOT/macos-brew-fail-events"; : >"$log"
    export KANATA_TEST_EVENT_LOG="$log"
    MOCK_BREW_FAIL=1
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install hid Homebrew preparation failure'; fi
    grep -Fq 'brew install kanata libiconv' "$log" || fail 'macOS package failure path did not use Homebrew'
    ! grep -Eq 'cargo|root-write|root-directory|control (stop|start)|launchctl (bootout|bootstrap|kickstart|enable)' "$log" || fail 'Homebrew failure proceeded to build, service changes, or deployment'
)

test_macos_lifecycle_query_errors_fail_before_service_mutations() (
    new_sandbox
    CALL_LOG="$TEST_ROOT/macos-lifecycle-query-error"; : >"$CALL_LOG"
    kanata_macos_launchctl() { printf 'launchctl %s\n' "$*" >>"$CALL_LOG"; printf 'Operation not permitted\n' >&2; return 1; }
    kanata_macos_control() { printf 'control %s\n' "$*" >>"$CALL_LOG"; return 0; }
    if kanata_macos_start >/dev/null 2>&1; then fail 'macOS start accepted launchd query failure'; fi
    if kanata_macos_stop >/dev/null 2>&1; then fail 'macOS stop accepted launchd query failure'; fi
    if kanata_macos_restart >/dev/null 2>&1; then fail 'macOS restart accepted launchd query failure'; fi
    ! grep -Eq 'bootstrap|bootout|kickstart|control (start|stop|restart)' "$CALL_LOG" || fail 'macOS lifecycle mutation followed a query error'
)

test_macos_status_propagates_controller_query_error() (
    new_sandbox
    local fixture_control="$TEST_ROOT/fixture-kanata-control" definition fixed_path='/usr/local/libexec/kanata-control' output
    printf '#!/usr/bin/env bash\nexit 0\n' >"$fixture_control"; chmod 0700 "$fixture_control"
    # The status helper has a fixed installed-path probe. Substitute only that
    # path in the function definition so this test never creates host files.
    definition="$(declare -f kanata_macos_status)"
    definition="${definition//$fixed_path/$fixture_control}"
    eval "$definition"
    CALL_LOG="$TEST_ROOT/macos-status-query"; : >"$CALL_LOG"
    kanata_macos_control() { printf 'control %s\n' "$*" >>"$CALL_LOG"; return 0; }
    kanata_macos_launchctl() { printf 'launchctl %s\n' "$*" >>"$CALL_LOG"; printf 'Operation not permitted\n' >&2; return 1; }
    if output="$(kanata_macos_status 2>/dev/null)"; then fail 'macOS status hid controller launchd query failure'; fi
    grep -Fq 'control status' "$CALL_LOG" || fail 'macOS status did not query the managed controller'
    ! grep -Eq 'org\.pqrs\.Karabiner-VirtualHIDDevice-Daemon|codesign|ps |kill ' "$CALL_LOG" || fail 'daily macOS status queried or managed VirtualHID'
    [[ "$output" != *'controller: not loaded'* && "$output" != *'controller: loaded'* ]] || fail 'macOS status reported a state despite query failure'
)

test_macos_install_prepares_checks_stops_deploys_enables_and_starts() (
    new_sandbox
    local fakebin="$TEST_ROOT/mac-cargo-bin" log="$TEST_ROOT/macos-install-events" kanata_package_fixture="$TEST_ROOT/kanata-homebrew-fixture"
    local vendor_binary_literal="$KANATA_MACOS_VHID_BINARY" socket_dir_fixed="$KANATA_MACOS_VHID_SOCKET_DIR"
    local mac_dotfiles="$TEST_ROOT/macos-dotfiles" daemon_template fixture_template_content
    assert_eq "$KANATA_MACOS_VHID_LABEL" 'org.pqrs.Karabiner-VirtualHIDDevice-Daemon'
    assert_eq "$KANATA_MACOS_VHID_PLIST" '/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist'
    assert_eq "$socket_dir_fixed" '/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server'
    assert_eq "$vendor_binary_literal" '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon'
    MOCK_BREW_PREFIX="$TEST_ROOT/intel/usr/local/opt/kanata"
    TEST_MAC_ICONV_PREFIX="$TEST_ROOT/intel/usr/local/opt/libiconv"
    export MOCK_BREW_PREFIX TEST_MAC_ICONV_PREFIX
    mkdir -p "$MOCK_BREW_PREFIX/bin" "$TEST_MAC_ICONV_PREFIX" "$fakebin"
    mkdir -p "$mac_dotfiles/kanata" "$mac_dotfiles/kanata/controller"
    cp -a "$ROOT/kanata/config" "$ROOT/kanata/services" "$mac_dotfiles/kanata/"
    cp "$ROOT/kanata/controller/Cargo.toml" "$ROOT/kanata/controller/Cargo.lock" "$mac_dotfiles/kanata/controller/"
    DOTFILES_DIR="$mac_dotfiles"
    daemon_template="$DOTFILES_DIR/kanata/services/macos/$KANATA_MACOS_VHID_LABEL.plist"
    grep -Fq "$vendor_binary_literal" "$daemon_template" || fail 'checked-in VirtualHID plist no longer names the expected vendor executable'
    mkdir -p "$MOCK_ROOT/var/usrlocal/bin"
    ln -s "$MOCK_BREW_PREFIX/bin/kanata" "$MOCK_ROOT/var/usrlocal/bin/kanata"
    : >"$log"
    export KANATA_TEST_EVENT_LOG="$log"
    MOCK_VHID_VENDOR_BINARY="$TEST_ROOT/vendor fixture/VirtualHID Daemon"
    mkdir -p "$(dirname -- "$MOCK_VHID_VENDOR_BINARY")"
    printf 'signed daemon fixture\n' >"$MOCK_VHID_VENDOR_BINARY"; chmod 0700 "$MOCK_VHID_VENDOR_BINARY"
    KANATA_MACOS_VHID_BINARY="$MOCK_VHID_VENDOR_BINARY"
    fixture_template_content="$(<"$daemon_template")"
    fixture_template_content="${fixture_template_content//$vendor_binary_literal/$KANATA_MACOS_VHID_BINARY}"
    printf '%s\n' "$fixture_template_content" >"$daemon_template"
    MOCK_VHID_SOCKET_FIXTURE="$TEST_ROOT/vhidd-sockets"
    KANATA_MACOS_VHID_SOCKET_DIR="$MOCK_VHID_SOCKET_FIXTURE"
    MOCK_VHID_SOCKET_DIR_FIXED="$socket_dir_fixed"
    export KANATA_MACOS_VHID_BINARY
    export MOCK_VHID_VENDOR_BINARY MOCK_VHID_SOCKET_FIXTURE KANATA_MACOS_VHID_SOCKET_DIR
    command -v python3 >/dev/null 2>&1 || fail 'python3 is required only for the isolated AF_UNIX socket fixture'
    mkdir -p "$MOCK_VHID_SOCKET_FIXTURE"
    python3 - "$MOCK_VHID_SOCKET_FIXTURE/vhidd.sock" <<'PY'
import socket, sys
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sys.argv[1])
server.close()
PY
    [[ -S "$MOCK_VHID_SOCKET_FIXTURE/vhidd.sock" ]] || fail 'isolated VirtualHID socket fixture was not created'
    printf '%s\n' '#!/usr/bin/env bash' \
        'if [[ "$1" == --version ]]; then printf "kanata-version\\n" >>"$KANATA_TEST_EVENT_LOG"; echo "kanata 1.12.0"; exit 0; fi' \
        'if [[ "$1" == --check ]]; then printf "kanata-config-check\\n" >>"$KANATA_TEST_EVENT_LOG"; exit "${MOCK_KANATA_CONFIG_FAIL:-0}"; fi' >"$kanata_package_fixture"
    chmod 0700 "$kanata_package_fixture"
    cat >"$fakebin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
expected_flags="-C"$'\x1f'"link-arg=-L${TEST_MAC_ICONV_PREFIX}/lib"
[[ "${CARGO_ENCODED_RUSTFLAGS:-}" == "$expected_flags" ]] || exit 93
target_dir="${CARGO_TARGET_DIR:-}"
target=''
while (($#)); do
    if [[ "$1" == --target ]]; then target="$2"; shift 2
    elif [[ "$1" == --target-dir ]]; then target_dir="$2"; shift 2
    else shift; fi
done
[[ "$target_dir" == "$TEST_ROOT/"* ]] || exit 91
[[ "$target" == *-apple-darwin ]] || exit 92
mkdir -p "$target_dir/$target/release"
printf 'Mach-O controller fixture\n' >"$target_dir/$target/release/kanata-controller"
chmod 0700 "$target_dir/$target/release/kanata-controller"
EOF
    chmod 0700 "$fakebin/cargo"
    PATH="$fakebin:$PATH"; export PATH

    brew() {
        printf 'brew %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        case "$1" in
        install)
            [[ "$*" == 'install kanata libiconv' ]] || fail "unexpected Homebrew install request: $*"
            printf 'brew-install\n' >>"$KANATA_TEST_EVENT_LOG"
            cp "$kanata_package_fixture" "$MOCK_BREW_PREFIX/bin/kanata"
            chmod 0700 "$MOCK_BREW_PREFIX/bin/kanata"
            ;;
        --prefix)
            case "${2:-}" in
            kanata) printf '%s\n' "$MOCK_BREW_PREFIX" ;;
            libiconv) printf '%s\n' "$TEST_MAC_ICONV_PREFIX" ;;
            *) fail "unexpected Homebrew prefix query: $*" ;;
            esac
            ;;
        *) fail "unexpected brew command: $*" ;;
        esac
    }
    kanata_macos_prepare_software() { brew install kanata libiconv >&2; }
    kanata_macos_require_build_tools() { return 0; }
    rustc() { printf 'host: x86_64-apple-darwin\n'; }
    file() { printf 'Mach-O 64-bit executable\n'; }
    otool() { printf '%s: /usr/lib/libSystem.B.dylib\n' "${2:-$1}"; }
    plutil() {
        printf 'plutil %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        local plist
        for plist in "${@:2}"; do
            [[ -f "$plist" ]] || continue
            case "$plist" in
            *org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist)
                (( MOCK_VHID_PLIST_FAIL == 0 )) || return 1
                grep -Fqx '    <string>org.pqrs.Karabiner-VirtualHIDDevice-Daemon</string>' "$plist" || return 1
                grep -Fqx "        <string>$KANATA_MACOS_VHID_BINARY</string>" "$plist" || return 1
                grep -Fq '<key>KeepAlive</key>' "$plist" && grep -Fq '<true/>' "$plist" || return 1
                printf 'vhid-plist-validated\n' >>"$KANATA_TEST_EVENT_LOG"
                ;;
            esac
        done
        return 0
    }
    codesign() {
        printf 'codesign %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        case "$*" in
        *--verify*) (( MOCK_CODESIGN_VERIFY_FAIL == 0 )) ;;
        *-dv*|*--display*)
            printf 'Identifier=%s\nTeamIdentifier=%s\n' "$MOCK_SIGNATURE_ID" "$MOCK_SIGNATURE_TEAM" >&2
            printf 'codesign-identity %s %s\n' "$MOCK_SIGNATURE_ID" "$MOCK_SIGNATURE_TEAM" >>"$KANATA_TEST_EVENT_LOG"
            ;;
        *) fail "unexpected codesign request: $*" ;;
        esac
    }
    ps() {
        printf 'ps %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        [[ "$*" == '-axo pid=,comm=' ]] || fail "unexpected ps flags: $*"
        (( MOCK_VHID_PS_FAIL == 0 )) || return 1
        if (( MOCK_VHID_ALIVE || MOCK_VHID_STUCK )); then printf '4242 %s\n' "$KANATA_MACOS_VHID_BINARY"; fi
        printf '4243 %s-nearby\n4244 /usr/bin/unrelated-daemon\n' "$KANATA_MACOS_VHID_BINARY"
    }
    kill() {
        printf 'kill %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        [[ "${1:-}" == -TERM && "${2:-}" == 4242 ]] || fail "refusing unexpected process signal: $*"
        (( MOCK_VHID_KILL_FAIL == 0 )) || return 1
        MOCK_VHID_ALIVE=0
    }
    find() {
        local found=0 arg
        local -a mapped=()
        [[ " $* " == *' -maxdepth 1 '* && " $* " == *' -type s '* && " $* " == *' -name *.sock '* ]] || fail "VHID socket search must restrict to direct UNIX *.sock entries: $*"
        for arg in "$@"; do
            if [[ "$arg" == "$MOCK_VHID_SOCKET_DIR_FIXED" || "$arg" == "$KANATA_MACOS_VHID_SOCKET_DIR" ]]; then
                mapped+=("$MOCK_VHID_SOCKET_FIXTURE"); found=1
            else
                mapped+=("$arg")
            fi
        done
        (( found )) || fail "refusing find outside the isolated VHID socket fixture: $*"
        printf 'vhid-socket-find\n' >>"$KANATA_TEST_EVENT_LOG"
        command find "${mapped[@]}"
    }
    visudo() { return 0; }
    MOCK_MAC_SYSTEM_STATE=running
    MOCK_MAC_CONTROLLER_STATE=absent
    set_mock_vhid_job_state absent
    MOCK_VHID_ALIVE=0
    MOCK_VHID_BOOTSTRAP_DISABLED=1
    kanata_macos_root_launchctl() {
        local vhid_state bootstrap_count
        printf 'root launchctl %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        vhid_state="$(<"$MOCK_VHID_JOB_STATE_FILE")"
        case "$1:$2" in
        print:system/dev.kanata.kanata)
            case "$MOCK_MAC_SYSTEM_STATE" in
            running) printf 'state = running pid = 321\n'; return 0 ;;
            loaded) printf 'state = waiting\n'; return 0 ;;
            absent) printf 'Could not find service\n' >&2; return 1 ;;
            esac
            ;;
        print:system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon)
            if (( MOCK_VHID_QUERY_FAIL )); then printf 'Operation not permitted\n' >&2; return 1; fi
            if (( MOCK_VHID_CONFIRM_QUERY_FAIL )) && [[ "$vhid_state" == absent ]]; then printf 'Operation not permitted\n' >&2; return 1; fi
            if (( MOCK_VHID_READY_QUERY_FAIL )) && [[ "$vhid_state" == running ]]; then
                printf 'Operation not permitted\n' >&2
                return 1
            fi
            case "$vhid_state" in
            absent) printf 'Could not find service\n' >&2; return 1 ;;
            loaded) printf 'state = waiting\n'; return 0 ;;
            running) printf 'state = running pid = 222\n'; return 0 ;;
            *) printf 'state = unknown\n'; return 0 ;;
            esac
            ;;
        bootout:*)
            case "$*" in
            *org.pqrs.Karabiner-VirtualHIDDevice-Daemon*)
                (( MOCK_VHID_BOOTOUT_FAIL == 0 )) || return 1
                set_mock_vhid_job_state absent
                ;;
            *dev.kanata.kanata*) MOCK_MAC_SYSTEM_STATE=absent ;;
            esac
            ;;
        enable:system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon) ;;
        bootstrap:*)
            case "$*" in
            *org.pqrs.Karabiner-VirtualHIDDevice-Daemon*)
                bootstrap_count="$(<"$MOCK_VHID_BOOTSTRAP_COUNT_FILE")"
                if (( MOCK_VHID_BOOTSTRAP_DISABLED )) && (( bootstrap_count == 0 )); then
                    printf '1\n' >"$MOCK_VHID_BOOTSTRAP_COUNT_FILE"
                    printf 'Service is disabled\n' >&2
                    return 1
                fi
                if (( MOCK_VHID_BOOTSTRAP_FAIL )); then
                    printf '%s\n' "$((bootstrap_count + 1))" >"$MOCK_VHID_BOOTSTRAP_COUNT_FILE"
                    printf 'generic launchd bootstrap error\n' >&2
                    return 1
                fi
                printf '%s\n' "$((bootstrap_count + 1))" >"$MOCK_VHID_BOOTSTRAP_COUNT_FILE"
                set_mock_vhid_job_state loaded
                ;;
            *dev.kanata.kanata*) MOCK_MAC_SYSTEM_STATE=loaded ;;
            esac
            ;;
        kickstart:system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon) set_mock_vhid_job_state running ;;
        esac
        return 0
    }
    kanata_macos_launchctl() {
        printf 'user launchctl %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        case "$1:$2" in
        print:*)
            case "$MOCK_MAC_CONTROLLER_STATE" in
            running) printf 'state = running pid = 123\n'; return 0 ;;
            loaded) printf 'state = waiting\n'; return 0 ;;
            absent) printf 'Could not find service\n' >&2; return 1 ;;
            esac
            ;;
        bootout:*) ;;
        esac
        return 0
    }
    kanata_macos_target_preflight() {
        printf 'target-preflight\n' >>"$KANATA_TEST_EVENT_LOG"
        (( MOCK_TARGET_PREFLIGHT_FAIL == 0 ))
    }
    kanata_root_ensure_dir() {
        printf 'root-directory %s\n' "$1" >>"$KANATA_TEST_EVENT_LOG"
        mkdir -p "$(virtual_path "$1")"
    }
    kanata_root_install_file() {
        local host
        [[ -f "$1" ]] || fail "missing root deployment source: $1"
        host="$(virtual_path "$2")"
        mkdir -p "$(dirname -- "$host")"
        printf 'root-write %s\n' "$2" >>"$KANATA_TEST_EVENT_LOG"
        [[ "$2" != "$MOCK_FAIL_ROOT_WRITE_PATH" ]] || return 1
        command install -m "$3" "$1" "$host"
    }
    sleep() {
        printf 'sleep %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        MOCK_SLEEP_COUNT=$((MOCK_SLEEP_COUNT + 1))
    }
    sudo() {
        printf 'sudo %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"
        case "${1:-}" in
        -v) return 0 ;;
        /bin/kill) shift; kill "$@" ;;
        /usr/bin/kill) shift; kill "$@" ;;
        kill) shift; kill "$@" ;;
        /bin/ps) shift; ps "$@" ;;
        ps) shift; ps "$@" ;;
        test)
            local flag="${2:-}" path host negate=0 status
            shift
            flag="${1:-}"
            if [[ "$flag" == '!' ]]; then negate=1; flag="${2:-}"; path="${3:-}"; else path="${2:-}"; fi
            host="$(virtual_path "$path")"
            case "$flag" in
            -d) [[ -d "$host" ]] ;;
            -e) [[ -e "$host" ]] ;;
            -f) [[ -f "$host" ]] ;;
            -L) [[ -L "$host" ]] ;;
            *) fail "unexpected mocked sudo test operation: $*" ;;
            esac
            status=$?
            if (( negate )); then (( status != 0 )); else (( status == 0 )); fi
            ;;
        find) shift; find "$@" ;;
        /bin/sh)
            local script="${3:-}"
            if [[ "$script" == *'ps -axo pid=,comm='* || "$script" == *'/bin/ps -axo pid=,comm='* ]]; then
                ps -axo pid=,comm=
            elif [[ "$script" == *'kill -TERM'* || "$script" == *'/bin/kill -TERM'* ]]; then
                kill -TERM "${5:-${4:-}}"
            else
                fail "unexpected privileged VHID shell operation: $*"
            fi
            ;;
        *) return 0 ;;
        esac
    }

    setup_macos_vhid_case() {
        new_sandbox
        log="$TEST_ROOT/macos-vhid-case-$RANDOM"
        : >"$log"
        export KANATA_TEST_EVENT_LOG="$log"
        KANATA_MACOS_VHID_BINARY="$MOCK_VHID_VENDOR_BINARY"
        printf 'signed daemon fixture\n' >"$KANATA_MACOS_VHID_BINARY"
        chmod 0700 "$KANATA_MACOS_VHID_BINARY"
        MOCK_VHID_SOCKET_FIXTURE="$TEST_ROOT/vhidd-socket-fixture-$RANDOM"
        KANATA_MACOS_VHID_SOCKET_DIR="$MOCK_VHID_SOCKET_FIXTURE"
        export KANATA_MACOS_VHID_BINARY MOCK_VHID_SOCKET_FIXTURE KANATA_MACOS_VHID_SOCKET_DIR
        mkdir -p "$MOCK_ROOT/var/usrlocal/bin" "$MOCK_VHID_SOCKET_FIXTURE"
        if [[ "${MOCK_MACOS_INTEL_SYMLINK:-1}" == 1 ]]; then
            ln -s "$MOCK_BREW_PREFIX/bin/kanata" "$MOCK_ROOT/var/usrlocal/bin/kanata"
        fi
        MOCK_BREW_FAIL=0
        MOCK_MAC_SYSTEM_STATE=running
        MOCK_MAC_CONTROLLER_STATE=running
        set_mock_vhid_job_state absent
        MOCK_VHID_ALIVE=1
    }
    create_vhid_socket_fixture() {
        local socket_path="$MOCK_VHID_SOCKET_FIXTURE/vhidd.sock"
        mkdir -p "$MOCK_VHID_SOCKET_FIXTURE"
        python3 - "$socket_path" <<'PY'
import socket, sys
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sys.argv[1])
server.close()
PY
        [[ -S "$socket_path" ]] || fail 'isolated VirtualHID socket fixture is not a UNIX socket'
    }

    kanata_macos_install || fail 'mock macOS package/build/deployment lifecycle failed'
    grep -Fq 'brew install kanata libiconv' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not prepare Kanata and libiconv with Homebrew'
    grep -Fq 'cargo build' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not build the controller with Cargo'
    grep -Fq 'codesign --verify' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not verify the vendor daemon signature'
    grep -Fq 'codesign-identity org.pqrs.Karabiner-VirtualHIDDevice-Daemon G43BCU2T37' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not confirm the vendor identifier and Team ID'
    grep -Fq 'vhid-plist-validated' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not validate the fixed VHID plist label and executable'
    grep -Fq 'root launchctl bootout system' "$KANATA_TEST_EVENT_LOG" || fail 'active managed Kanata job was not stopped before deployment'
    grep -Fq 'root launchctl enable system/dev.kanata.kanata' "$KANATA_TEST_EVENT_LOG" || fail 'system LaunchDaemon was not enabled'
    grep -Fq 'user launchctl enable gui/1000/dev.kanata.controller' "$KANATA_TEST_EVENT_LOG" || fail 'controller LaunchAgent was not enabled'
    grep -Fq 'root launchctl bootstrap system' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not start Kanata after deployment'
    grep -Eq 'user launchctl (bootstrap|kickstart)' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not activate the controller after deployment'
    grep -Fq 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not refresh the fixed VHID daemon plist'
    ! grep -Fq 'kill -TERM' "$KANATA_TEST_EVENT_LOG" || fail 'fresh VHID install signaled a nonexistent daemon process'
    ! grep -Fq 'root launchctl bootout system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$KANATA_TEST_EVENT_LOG" || fail 'fresh absent VHID job was unnecessarily unloaded'
    grep -Fq 'vhid-socket-find' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install did not inspect the actual AF_UNIX socket fixture'
    [[ "$(grep -Fc 'root launchctl bootstrap system /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$KANATA_TEST_EVENT_LOG")" == 2 ]] || fail 'disabled VHID bootstrap did not receive exactly one narrow retry'
    [[ "$(grep -Fc 'root launchctl enable system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$KANATA_TEST_EVENT_LOG")" == 2 ]] || fail 'disabled VHID bootstrap retry did not re-enable the fixed service once'
    assert_before 'brew install kanata libiconv' 'cargo build' "$KANATA_TEST_EVENT_LOG"
    assert_before 'codesign --verify' 'root launchctl bootout system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$KANATA_TEST_EVENT_LOG"
    assert_before 'kanata-config-check' 'root launchctl bootout system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$KANATA_TEST_EVENT_LOG"
    assert_before 'vhid-plist-validated' 'root launchctl bootout system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$KANATA_TEST_EVENT_LOG"
    assert_before 'root launchctl bootout system /Library/LaunchDaemons/dev.kanata.kanata.plist' 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$KANATA_TEST_EVENT_LOG"
    assert_before 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' 'root launchctl enable system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$KANATA_TEST_EVENT_LOG"
    assert_before 'root launchctl kickstart system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' 'vhid-socket-find' "$KANATA_TEST_EVENT_LOG"
    assert_before 'vhid-socket-find' 'root-write /Library/LaunchDaemons/dev.kanata.kanata.plist' "$KANATA_TEST_EVENT_LOG"
    assert_before 'root-write /Library/LaunchDaemons/dev.kanata.kanata.plist' 'root launchctl enable system/dev.kanata.kanata' "$KANATA_TEST_EVENT_LOG"
    assert_before 'root launchctl enable system/dev.kanata.kanata' 'root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$KANATA_TEST_EVENT_LOG"
    [[ -L "$MOCK_ROOT/usr/local/bin/kanata" ]] || fail 'macOS deployment replaced the Homebrew-owned /usr/local/bin/kanata symlink'
    assert_eq "$(readlink "$MOCK_ROOT/usr/local/bin/kanata")" "$MOCK_BREW_PREFIX/bin/kanata"
    ! grep -Fq 'root-write /usr/local/bin/kanata' "$KANATA_TEST_EVENT_LOG" || fail 'macOS deployment overwrote the Homebrew binary path'
    ! grep -Fxq 'root-write /usr/local/libexec/kanata' "$KANATA_TEST_EVENT_LOG" || fail 'macOS install copied Kanata outside its Homebrew prefix'
    grep -Fq '<string>'"$MOCK_BREW_PREFIX/bin/kanata"'</string>' "$MOCK_ROOT/Library/LaunchDaemons/dev.kanata.kanata.plist" || fail 'launchd ProgramArguments did not use the Homebrew Kanata executable'
    [[ ! -e "$(virtual_path /usr/local/libexec/kanata)" ]] || fail 'macOS install created an independent /usr/local/libexec/kanata binary'

    # A manual exact-path daemon is terminated with TERM even when its launchd
    # job is absent; nearby and unrelated process commands remain untouched.
    setup_macos_vhid_case
    set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=1
    create_vhid_socket_fixture
    kanata_macos_install || fail 'macOS install failed while stopping a manually running exact VHID daemon'
    grep -Fq 'kill -TERM 4242' "$log" || fail 'manual exact-path VHID daemon was not sent TERM'
    [[ "$(grep -Fxc 'kill -TERM 4242' "$log")" == 1 ]] || fail 'VHID refresh signaled more than one exact daemon PID'
    ! grep -Eq 'kill .*4243|kill .*4244|kill .*KILL' "$log" || fail 'VHID refresh signaled a nearby/other process or escalated to KILL'
    ! grep -Fq 'root launchctl bootout system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log" || fail 'absent VHID job was unnecessarily unloaded'
    assert_before 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' 'kill -TERM 4242' "$log"
    assert_before 'kill -TERM 4242' 'root launchctl bootstrap system /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$log"

    # Loaded but idle launchd jobs are unloaded before any fixed target write.
    setup_macos_vhid_case
    MOCK_MAC_SYSTEM_STATE=loaded MOCK_MAC_CONTROLLER_STATE=loaded
    set_mock_vhid_job_state loaded; MOCK_VHID_ALIVE=0
    create_vhid_socket_fixture
    MOCK_MAC_SYSTEM_STATE=loaded MOCK_MAC_CONTROLLER_STATE=loaded
    kanata_macos_install || fail 'macOS install failed for loaded-but-idle jobs'
    assert_before 'root launchctl bootout system /Library/LaunchDaemons/dev.kanata.kanata.plist' 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$log"
    assert_before 'user launchctl bootout gui/1000' 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$log"
    local vhid_unload_line vhid_confirm_line vhid_plist_line
    vhid_unload_line="$(log_line "$log" 'root launchctl bootout system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon')"
    vhid_confirm_line="$(log_line_after "$log" "$vhid_unload_line" 'root launchctl print system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon')"
    vhid_plist_line="$(log_line "$log" 'root-write /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist')"
    [[ -n "$vhid_unload_line" && -n "$vhid_confirm_line" ]] || fail 'loaded-idle VHID job was not booted out and confirmed absent'
    (( vhid_confirm_line < vhid_plist_line )) || fail 'VHID plist was written before launchd confirmed the loaded job absent'
    ! grep -Fq 'kill -TERM' "$log" || fail 'loaded-idle VHID daemon without a matching process was signaled'

    # Apple Silicon Homebrew uses its /opt/homebrew prefix directly too; no
    # independent Kanata executable is copied into a script-owned location.
    MOCK_MACOS_INTEL_SYMLINK=0
    MOCK_BREW_PREFIX="$TEST_ROOT/apple/opt/homebrew/opt/kanata"; TEST_MAC_ICONV_PREFIX="$TEST_ROOT/apple/opt/homebrew/opt/libiconv"
    export MOCK_BREW_PREFIX TEST_MAC_ICONV_PREFIX
    mkdir -p "$MOCK_BREW_PREFIX/bin" "$TEST_MAC_ICONV_PREFIX"
    setup_macos_vhid_case
    set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=0
    create_vhid_socket_fixture
    kanata_macos_install || fail 'macOS install failed with Apple Silicon Homebrew prefix'
    grep -Fq '<string>'"$MOCK_BREW_PREFIX/bin/kanata"'</string>' "$MOCK_ROOT/Library/LaunchDaemons/dev.kanata.kanata.plist" || fail 'Apple Silicon launchd plist did not directly use /opt/homebrew Kanata'
    ! grep -Fxq 'root-write /usr/local/libexec/kanata' "$log" || fail 'Apple Silicon install copied Kanata out of its Homebrew prefix'
    [[ ! -e "$(virtual_path /usr/local/libexec/kanata)" ]] || fail 'Apple Silicon install created an independent Kanata binary'

    # A non-directory controller log target is rejected before stopping active
    # launchd jobs or writing any fixed target.
    setup_macos_vhid_case
    MOCK_MAC_SYSTEM_STATE=running MOCK_MAC_CONTROLLER_STATE=running
    mkdir -p "$HOME/.local/state"
    printf 'not a log directory\n' >"$HOME/.local/state/kanata-controller"
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install accepted a file at the controller log directory'; fi
    ! grep -Eq 'bootout|root-write|user-write' "$log" || fail 'unsafe controller log target changed services or deployed files'

    setup_macos_vhid_case
    MOCK_MAC_SYSTEM_STATE=running MOCK_MAC_CONTROLLER_STATE=running
    mkdir -p "$HOME/.local/state"; mkdir -p "$TEST_ROOT/external-log-target"
    ln -s "$TEST_ROOT/external-log-target" "$HOME/.local/state/kanata-controller"
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install accepted a symlink at the controller log directory'; fi
    ! grep -Eq 'bootout|root-write|user-write' "$log" || fail 'symlinked controller log target changed services or deployed files'

    run_macos_predeployment_failure() {
        local failure_kind="$1"
        setup_macos_vhid_case
        MOCK_MAC_SYSTEM_STATE=running MOCK_MAC_CONTROLLER_STATE=running
        set_mock_vhid_job_state running; MOCK_VHID_ALIVE=1
        case "$failure_kind" in
        vendor-binary) rm -f "$KANATA_MACOS_VHID_BINARY" ;;
        signature) MOCK_CODESIGN_VERIFY_FAIL=1 ;;
        identifier) MOCK_SIGNATURE_ID='org.pqrs.Karabiner-VirtualHIDDevice-Daemon-untrusted' ;;
        team) MOCK_SIGNATURE_TEAM='G43BCU2T37-extra' ;;
        plist) MOCK_VHID_PLIST_FAIL=1 ;;
        config) MOCK_KANATA_CONFIG_FAIL=1 ;;
        target) MOCK_TARGET_PREFLIGHT_FAIL=1 ;;
        query) MOCK_VHID_QUERY_FAIL=1 ;;
        ps) MOCK_VHID_PS_FAIL=1 ;;
        *) fail "unknown macOS preflight failure case: $failure_kind" ;;
        esac
        if kanata_macos_install >/dev/null 2>&1; then fail "macOS install accepted predeployment $failure_kind failure"; fi
        ! grep -Eq 'launchctl (bootout|bootstrap|kickstart)|kill (-TERM|-KILL)|root-write|user-write' "$log" || \
            fail "macOS $failure_kind failure stopped services, signaled processes, or wrote targets"
    }
    run_macos_predeployment_failure vendor-binary
    run_macos_predeployment_failure signature
    run_macos_predeployment_failure identifier
    run_macos_predeployment_failure team
    run_macos_predeployment_failure plist
    run_macos_predeployment_failure config
    run_macos_predeployment_failure target
    run_macos_predeployment_failure query
    run_macos_predeployment_failure ps

    # A loaded VHID bootout failure permits earlier Kanata/controller stops,
    # but does not write the daemon plist, signal processes, or start anything.
    setup_macos_vhid_case
    set_mock_vhid_job_state loaded; MOCK_VHID_ALIVE=0 MOCK_VHID_BOOTOUT_FAIL=1
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install hid VHID bootout failure'; fi
    grep -Fq 'root launchctl bootout system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log" || fail 'loaded VHID job bootout was not exercised'
    ! grep -Eq 'root-write|kill |root launchctl (bootstrap|kickstart).*org.pqrs|root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$log" || \
        fail 'VHID bootout failure wrote targets, signaled a process, or started a daemon'

    setup_macos_vhid_case
    set_mock_vhid_job_state loaded; MOCK_VHID_ALIVE=0 MOCK_VHID_CONFIRM_QUERY_FAIL=1
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install ignored failed VHID absence confirmation after bootout'; fi
    grep -Fq 'root launchctl bootout system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log" || fail 'VHID bootout confirmation failure did not follow unload'
    ! grep -Eq 'root-write|kill |root launchctl (bootstrap|kickstart).*org.pqrs|root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$log" || fail 'VHID absence query failure wrote files or continued startup'

    # Only the known disabled bootstrap response is retried; unrelated
    # launchd bootstrap failures are propagated without retry or Kanata start.
    setup_macos_vhid_case
    set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=0 MOCK_VHID_BOOTSTRAP_FAIL=1
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install hid generic VHID bootstrap failure'; fi
    [[ "$(grep -Fc 'root launchctl bootstrap system /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist' "$log")" == 1 ]] || fail 'generic VHID bootstrap error was retried'
    [[ "$(grep -Fc 'root launchctl enable system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log")" == 1 ]] || fail 'generic VHID bootstrap error triggered the disabled-job retry'
    ! grep -Eq 'root launchctl kickstart.*org.pqrs|root-write /usr/local/libexec/kanata|root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$log" || fail 'generic VHID bootstrap error proceeded to Kanata activation'

    # A TERM error or failure to exit within ten bounded checks never escalates
    # to KILL and never starts VHID/Kanata/controller afterward.
    setup_macos_vhid_case
    set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=1; MOCK_VHID_KILL_FAIL=1
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install hid exact-PID TERM failure'; fi
    grep -Fq 'kill -TERM 4242' "$log" || fail 'manual exact-path process did not receive TERM'
    ! grep -Eq 'kill .*KILL|root launchctl (bootstrap|kickstart).*org.pqrs|root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist|root-write /usr/local/libexec/kanata' "$log" || \
        fail 'TERM failure proceeded to daemon/Kanata activation or escalated to KILL'

    setup_macos_vhid_case
    set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=1; MOCK_VHID_STUCK=1
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install accepted a vendor process that survived TERM'; fi
    local wait_count
    wait_count="$(grep -Fxc 'sleep 1' "$log" || true)"
    (( wait_count > 0 && wait_count <= 10 )) || fail 'VHID termination wait was not bounded to ten seconds'
    ! grep -Eq 'kill .*KILL|root launchctl (bootstrap|kickstart).*org.pqrs|root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist|root-write /usr/local/libexec/kanata' "$log" || \
        fail 'VHID TERM timeout escalated or started dependent Kanata services'

    # Running launchd state without a real direct-child UNIX *.sock is not
    # readiness, whether the similarly named object is absent, a file, or a directory.
    run_vhid_socket_failure() {
        local kind="$1"
        setup_macos_vhid_case
        set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=0
        case "$kind" in
        absent) ;;
        regular) printf 'not a socket\n' >"$MOCK_VHID_SOCKET_FIXTURE/fake.sock" ;;
        directory) mkdir -p "$MOCK_VHID_SOCKET_FIXTURE/fake.sock" ;;
        query) MOCK_VHID_READY_QUERY_FAIL=1 ;;
        *) fail "unknown VHID readiness fixture: $kind" ;;
        esac
        if kanata_macos_install >/dev/null 2>&1; then fail "macOS install accepted VHID readiness failure: $kind"; fi
        grep -Fq 'root launchctl kickstart system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log" || fail "$kind readiness test did not start the mock VHID job"
        ! grep -Eq 'root-write /usr/local/libexec/kanata|root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist|root launchctl kickstart system/dev.kanata.kanata|user launchctl bootstrap' "$log" || \
            fail "$kind readiness failure continued to Kanata/controller deployment or startup"
        if [[ "$kind" != query ]]; then
            wait_count="$(grep -Fxc 'sleep 1' "$log" || true)"
            (( wait_count > 0 && wait_count <= 10 )) || fail "$kind VHID readiness wait was not bounded"
        fi
    }
    run_vhid_socket_failure absent
    run_vhid_socket_failure regular
    run_vhid_socket_failure directory
    run_vhid_socket_failure query

    # A later Kanata deployment failure retains the already-ready daemon and
    # does not roll VHID back or start the partially deployed Kanata service.
    setup_macos_vhid_case
    set_mock_vhid_job_state absent; MOCK_VHID_ALIVE=0
    create_vhid_socket_fixture
    MOCK_FAIL_ROOT_WRITE_PATH=/etc/kanata/kanata.kbd
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install hid Kanata deployment failure after VHID readiness'; fi
    grep -Fq 'root launchctl kickstart system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log" || fail 'VHID was not started before later Kanata failure'
    grep -Fq 'vhid-socket-find' "$log" || fail 'VHID readiness was not verified before Kanata deployment'
    [[ -f "$(virtual_path /Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist)" ]] || fail 'VHID plist was rolled back after later Kanata failure'
    ! grep -Fq 'root launchctl bootout system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon' "$log" || fail 'later Kanata failure unloaded the refreshed VHID service'
    ! grep -Fq 'root launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist' "$log" || fail 'later deployment failure started partially deployed Kanata'
)

test_macos_helper_source_is_preflighted_before_privileged_writes() (
    new_sandbox
    local saved_dotfiles="$DOTFILES_DIR" fixture="$TEST_ROOT/macos-missing-helper" binary="$TEST_ROOT/prepared-mac-kanata" controller="$TEST_ROOT/prepared-mac-controller"
    DOTFILES_DIR="$fixture"
    mkdir -p "$fixture/kanata/config" "$fixture/kanata/services/macos"
    cp "$saved_dotfiles/kanata/config/kanata-macos.kbd" "$fixture/kanata/config/kanata-macos.kbd"
    cp "$saved_dotfiles/kanata/config/kanata-common.kbd" "$fixture/kanata/config/kanata-common.kbd"
    cp "$saved_dotfiles/kanata/services/macos/dev.kanata.kanata.plist" "$fixture/kanata/services/macos/"
    cp "$saved_dotfiles/kanata/services/macos/dev.kanata.controller.plist" "$fixture/kanata/services/macos/"
    cp "$saved_dotfiles/kanata/services/macos/kanata-controller.sudoers.template" "$fixture/kanata/services/macos/"
    cp "$saved_dotfiles/kanata/services/macos/$KANATA_MACOS_VHID_LABEL.plist" "$fixture/kanata/services/macos/"
    printf 'prepared\n' >"$binary"; printf 'prepared controller\n' >"$controller"
    chmod 0700 "$binary" "$controller"
    KANATA_MACOS_VHID_BINARY="$TEST_ROOT/fake-vhid"
    printf 'driver fixture\n' >"$KANATA_MACOS_VHID_BINARY"; chmod 0700 "$KANATA_MACOS_VHID_BINARY"
    export KANATA_MACOS_VHID_BINARY
    KANATA_TEST_EVENT_LOG="$TEST_ROOT/macos-helper-preflight-events"; : >"$KANATA_TEST_EVENT_LOG"
    export KANATA_TEST_EVENT_LOG
    brew() { printf 'brew %s\n' "$*" >>"$KANATA_TEST_EVENT_LOG"; return 0; }
    kanata_macos_prepare_software() { brew install kanata libiconv >&2; }
    kanata_macos_require_build_tools() { return 0; }
    file() { printf 'Mach-O fixture\n'; }
    otool() { printf '%s: /usr/lib/libSystem.B.dylib\n' "$2"; }
    plutil() { return 0; }
    visudo() { return 0; }
    kanata_macos_binary() { printf '%s\n' "$binary"; }
    kanata_macos_build_controller() { printf 'controller-build\n' >>"$KANATA_TEST_EVENT_LOG"; printf '%s\n' "$controller"; }
    kanata_root_ensure_dir() { MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1)); return 0; }
    kanata_root_install_file() {
        MOCK_MUTATIONS=$((MOCK_MUTATIONS + 1))
        [[ -f "$1" ]]
    }
    kanata_check_binary() { return 0; }
    if kanata_macos_install >/dev/null 2>&1; then fail 'macOS install accepted missing helper source'; fi
    grep -Fq 'brew install kanata libiconv' "$KANATA_TEST_EVENT_LOG" || fail 'macOS software preparation was not mocked before source validation'
    grep -Fq 'controller-build' "$KANATA_TEST_EVENT_LOG" || fail 'controller fixture was not prepared before source validation'
    assert_eq "$MOCK_MUTATIONS" 0
    ! grep -Fq 'sudo-auth' "$MOCK_LOG" || fail 'missing helper source reached privilege authorization'
)

test_windows_install_prepares_or_reuses_winget_and_runs_current_user_task() (
    new_sandbox
    local fake="$TEST_ROOT/kanata.exe" native_appdata='C:\Users\mockuser\AppData\Local' normalized_appdata="$HOME/LocalAppData"
    printf '%s\n' '#!/usr/bin/env bash' \
        '[[ "$1" == --version ]] && { echo "kanata 1.12.0"; exit 0; }' \
        '[[ "$1" == --check ]] && exit 0' >"$fake"
    chmod 0700 "$fake"
    mkdir -p "$TEST_ROOT/winbin"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 99' >"$TEST_ROOT/winbin/schtasks.exe"
    chmod 0700 "$TEST_ROOT/winbin/schtasks.exe"
    PATH="$TEST_ROOT/winbin:$PATH"
    export PATH
    export LOCALAPPDATA="$native_appdata" USERDOMAIN=MOCK USERNAME=mockuser
    mkdir -p "$normalized_appdata"
    TEST_EXPECTED_DATA_DIR="$normalized_appdata/kanata" TEST_XML_OUTPUT="$TEST_ROOT/task.xml"
    export TEST_EXPECTED_DATA_DIR TEST_XML_OUTPUT
    POWERSHELL_LOG="$TEST_ROOT/powershell.log"; TASK_LOG="$TEST_ROOT/tasks.log"; CYGPATH_LOG="$TEST_ROOT/windows-install-cygpath.log"
    WINDOWS_TASK_RESULT=NOT_FOUND
    : >"$POWERSHELL_LOG"; : >"$TASK_LOG"; : >"$CYGPATH_LOG"
    powershell.exe() {
        printf '%s\n' "$*" >>"$POWERSHELL_LOG"
        if [[ "$*" == *IsInRole* ]]; then
            printf 'True\n'
        elif [[ "$*" == *GetTask* ]]; then
            [[ -z "${TASK_LOG:-}" ]] || printf 'task-query\n' >>"$TASK_LOG"
            case "$WINDOWS_TASK_RESULT" in
            ACCESS_DENIED) printf 'Access denied\n' >&2; return 1 ;;
            *) printf '%s\n' "$WINDOWS_TASK_RESULT" ;;
            esac
        elif [[ "$*" == *CreateFolder* ]]; then
            return 0
        elif [[ "$*" == *Get-Content* ]]; then
            if [[ "${TEST_ALLOW_EXISTING_DATA:-0}" == 0 ]]; then
                [[ ! -e "$TEST_EXPECTED_DATA_DIR" ]] || fail 'first-install fixture data directory should still be absent during task rendering'
            fi
            [[ "$*" == *'Split-Path -Parent $workingDirectory'* ]] || fail 'task renderer did not validate the working-directory parent'
            [[ "$*" == *'if ((Test-Path -LiteralPath $workingDirectory)'* ]] || fail 'task renderer did not permit a missing first-install directory'
            printf '<Task><LogonTrigger/></Task>\n' >"$TEST_XML_OUTPUT"
        else
            printf 'MOCK\\mockuser\n'
        fi
    }
    cygpath() {
        printf '%s\n' "$*" >>"$CYGPATH_LOG"
        if [[ "$1" == -u && "$2" == -a && "$3" == -- && "$4" == "$native_appdata" ]]; then
            printf '%s\n' "$normalized_appdata"
        elif [[ "$1" == -u && "$2" == -- ]]; then
            printf '%s\n' "$3"
        elif [[ "$1" == -w && "$2" == -a ]]; then
            printf 'C:\\fixture\\path\n'
        elif [[ "$1" == -w ]]; then
            printf 'C:\\fixture\\path\n'
        else
            fail "unexpected cygpath arguments: $*"
        fi
    }
    winget() {
        printf 'winget %s\n' "$*" >>"$TASK_LOG"
        if [[ "$1" == list ]]; then
            [[ ! -f "$normalized_appdata/Microsoft/WinGet/Packages/Fixture.Kanata/kanata_windows_gui_winIOv2_x64.exe" ]] || printf 'jtroo.kanata_gui\n'
            return 0
        fi
        [[ "$1" == install && "$*" == *'--id jtroo.kanata_gui'* ]] || fail "unexpected winget command: $*"
        mkdir -p "$normalized_appdata/Microsoft/WinGet/Packages/Fixture.Kanata"
        cp "$fake" "$normalized_appdata/Microsoft/WinGet/Packages/Fixture.Kanata/kanata_windows_gui_winIOv2_x64.exe"
    }
    install() {
        if [[ "${4:-}" == "$normalized_appdata/kanata/"* ]]; then printf 'file-write %s\n' "$4" >>"$TASK_LOG"; fi
        command install "$@"
    }
    sleep() { printf 'sleep %s\n' "$*" >>"$TASK_LOG"; }
    kanata_windows_schtasks() {
        printf '%s\n' "$*" >>"$TASK_LOG"
        case "$1" in
        //End) WINDOWS_TASK_RESULT="${WINDOWS_AFTER_END_STATE:-1}" ;;
        //Create) WINDOWS_TASK_RESULT=1 ;;
        //Run) WINDOWS_TASK_RESULT=4 ;;
        esac
        return 0
    }
    kanata_windows_install || fail 'mock Windows install failed'
    assert_file "$normalized_appdata/kanata/kanata.kbd"
    assert_file "$normalized_appdata/kanata/kanata-common.kbd"
    grep -Fq -- "-u -a -- $native_appdata" "$CYGPATH_LOG" || fail 'Windows install did not normalize native LOCALAPPDATA'
    grep -Fq 'winget install' "$TASK_LOG" && grep -Fq -- '--id jtroo.kanata_gui' "$TASK_LOG" || fail 'missing Windows GUI package was not installed through WinGet'
    grep -Fq '//Create' "$TASK_LOG" || fail 'scheduled task was not registered'
    grep -Fq '//Run' "$TASK_LOG" || fail 'Windows install did not run the current-user task after registration'
    assert_before 'winget install' '//Create' "$TASK_LOG"
    assert_before 'file-write ' '//Create' "$TASK_LOG"
    assert_before '//Create' '//Run' "$TASK_LOG"

    # Reinstallation finds the GUI package and stops the active managed task,
    # but it does not request the same software from WinGet again.
    local winget_installs
    printf 'stale managed configuration\n' >"$normalized_appdata/kanata/kanata.kbd"
    printf 'stale common configuration\n' >"$normalized_appdata/kanata/kanata-common.kbd"
    winget_installs="$(grep -Fc 'winget install' "$TASK_LOG")"
    TEST_ALLOW_EXISTING_DATA=1
    export TEST_ALLOW_EXISTING_DATA
    WINDOWS_TASK_RESULT=4
    kanata_windows_install || fail 'Windows reinstall with an installed GUI package failed'
    assert_eq "$(grep -Fc 'winget install' "$TASK_LOG")" "$winget_installs"
    [[ "$(grep -Fc '//End' "$TASK_LOG")" == 1 ]] || fail 'active managed Windows task was not ended before redeployment'
    [[ "$(grep -Fc '//Run' "$TASK_LOG")" == 2 ]] || fail 'Windows reinstall did not run the task after redeployment'
    local reinstall_end_line reinstall_write_line
    reinstall_end_line="$(log_line "$TASK_LOG" '//End')"
    reinstall_write_line="$(log_line_after "$TASK_LOG" "$reinstall_end_line" 'file-write ')"
    [[ -n "$reinstall_write_line" ]] || fail 'active task was not ended before Windows configuration replacement'

    # An installed but non-runnable package must trigger WinGet repair and a
    # fresh executable discovery rather than being accepted by package name.
    local installed_gui="$normalized_appdata/Microsoft/WinGet/Packages/Fixture.Kanata/kanata_windows_gui_winIOv2_x64.exe" installs_before paths_before paths_after
    printf '%s\n' '#!/usr/bin/env bash' '[[ "$1" == --version ]] && exit 7' 'exit 7' >"$installed_gui"
    chmod 0700 "$installed_gui"
    installs_before="$(grep -Fc 'winget install' "$TASK_LOG")"
    paths_before="$(grep -Fc -- "-u -- $installed_gui" "$CYGPATH_LOG" || true)"
    WINDOWS_TASK_RESULT=3
    kanata_windows_install || fail 'WinGet did not repair a present but unusable Kanata executable'
    [[ "$(grep -Fc 'winget install' "$TASK_LOG")" == "$(( installs_before + 1 ))" ]] || fail 'bad installed binary did not trigger WinGet repair'
    paths_after="$(grep -Fc -- "-u -- $installed_gui" "$CYGPATH_LOG" || true)"
    (( paths_after >= paths_before + 2 )) || fail 'installer did not rediscover the repaired executable after WinGet'
    grep -Fq '//Run' "$TASK_LOG" || fail 'repaired Windows task was not started'
    [[ "$(grep -Fc '//End' "$TASK_LOG")" == 2 ]] || fail 'queued state 3 was not ended before reinstall'
    local queued_end_line queued_confirm_line
    queued_end_line="$(log_line "$TASK_LOG" '//End')"
    queued_confirm_line="$(log_line_after "$TASK_LOG" "$queued_end_line" 'task-query')"
    [[ -n "$queued_confirm_line" ]] || fail 'installer did not query task state after ending queued task 3'

    # If End does not quiesce the queued task, installation polls finitely,
    # returns a failure, and leaves target config files untouched.
    local config_before config_after query_count queries_before end_line confirmation_queries
    config_before="$(<"$TEST_EXPECTED_DATA_DIR/kanata.kbd")"
    WINDOWS_TASK_RESULT=3 WINDOWS_AFTER_END_STATE=3
    queries_before="$(grep -Fc 'task-query' "$TASK_LOG")"
    if kanata_windows_install >/dev/null 2>&1; then fail 'Windows install accepted a task that stayed queued after End'; fi
    query_count="$(grep -Fc 'task-query' "$TASK_LOG")"
    end_line="$(awk '/\/\/End/ { line = NR } END { print line + 0 }' "$TASK_LOG")"
    confirmation_queries="$(awk -v after="$end_line" 'NR > after && index($0, "task-query") { count++ } END { print count + 0 }' "$TASK_LOG")"
    (( query_count > queries_before && confirmation_queries > 0 && confirmation_queries <= 8 )) || fail 'Windows stop confirmation did not use a bounded post-End query loop'
    config_after="$(<"$TEST_EXPECTED_DATA_DIR/kanata.kbd")"
    assert_eq "$config_after" "$config_before"

    # A query failure during post-End confirmation is not treated as stopped.
    WINDOWS_TASK_RESULT=3 WINDOWS_AFTER_END_STATE=ACCESS_DENIED
    if kanata_windows_install >/dev/null 2>&1; then fail 'Windows install ignored post-End task query error'; fi
    config_after="$(<"$TEST_EXPECTED_DATA_DIR/kanata.kbd")"
    assert_eq "$config_after" "$config_before"
)

test_windows_start_stop_restart_use_only_task_mocks() (
    new_sandbox
    TASK_LOG="$TEST_ROOT/windows-actions"; : >"$TASK_LOG"
    WINDOWS_TASK_RESULT=4
    kanata_windows_task_present() { return 0; }
    kanata_windows_task_query() { printf '%s\n' "$WINDOWS_TASK_RESULT"; }
    kanata_windows_schtasks() {
        printf '%s\n' "$*" >>"$TASK_LOG"
        case "$1" in
        //End) WINDOWS_TASK_RESULT=1 ;;
        //Run) WINDOWS_TASK_RESULT=4 ;;
        esac
        return 0
    }
    kanata_windows_start || fail 'mock Windows start failed'
    kanata_windows_stop || fail 'mock Windows stop failed'
    kanata_windows_restart || fail 'mock Windows restart failed'
    [[ "$(grep -Fc '//Run' "$TASK_LOG")" == 2 ]] || fail 'expected explicit start and restart task runs'
    [[ "$(grep -Fc '//End' "$TASK_LOG")" == 1 ]] || fail 'stop of the current running task was not confirmed exactly once'
)

TESTS=0
run_test() {
    local label="$1" fn="$2"
    if "$fn"; then printf 'ok - %s\n' "$label"; TESTS=$((TESTS + 1)); else printf 'not ok - %s\n' "$label" >&2; FAILURES=$((FAILURES + 1)); fi
}

run_test 'CLI dispatch and unknown-action no-op' test_cli_dispatch_and_unknown_actions_are_side_effect_free
run_test 'daily install wrapper delegates to dedicated installer script' test_daily_install_wrapper_executes_dedicated_installer
run_test 'daily check/start/stop/restart/status never prepare software' test_daily_non_install_actions_never_prepare_software
run_test 'daily and installer source guards are side-effect free' test_source_guards_do_not_run_either_cli_main
run_test 'template renderer fails closed on missing source/output and grep errors' test_template_renderer_fails_on_io_and_inspection_errors
run_test 'installer main dispatch uses mocked platform handlers' test_installer_main_dispatch_is_mocked_and_unknown_actions_are_noop
run_test 'binary check is parse-only and fail-fast' test_binary_check_is_parse_only_and_stops_on_version_failure
run_test 'prebuilt runtime failure falls back; integrity failure stops' test_source_fallback_only_after_prebuilt_runtime_failure
run_test 'Linux reuses only the pinned compatible existing binary' test_linux_existing_binary_is_reused_only_at_pinned_version
run_test 'candidate stdout contains only executable path' test_linux_candidate_output_is_only_a_path
run_test 'source fallback does not require pkg-config/libudev metadata' test_linux_source_fallback_does_not_require_pkg_config
run_test 'macOS /etc alias is limited to a trusted private target' test_macos_standard_etc_symlink_is_only_accepted_when_target_is_trusted
run_test 'binary discovery keeps stdout to one path and rejects unsafe macOS linkage' test_binary_discovery_stdout_is_path_only_and_macos_rejects_bad_linkage
run_test 'Windows binary discovery keeps stdout to one path' test_windows_binary_discovery_stdout_is_path_only
run_test 'Windows first-install directory is allowed but unsafe parent is rejected' test_windows_first_install_and_unsafe_parent_preflight
run_test 'service query errors fail closed and absent units remain distinct' test_service_queries_distinguish_absent_from_access_errors_and_fail_closed
run_test 'Linux group/query/target gates preserve fixed targets and service state' test_linux_group_query_and_fixed_target_failures_leave_targets_and_services_unchanged
run_test 'Arch package preparation is minimal, non-Arch is a no-op, and failure leaves targets/services unchanged' test_arch_package_preparation_is_minimal_and_failure_precedes_deployment
run_test 'Arch install/check use repository Kanata and yay/pacman selection' test_arch_repo_binary_daily_preference_and_install_targets
run_test 'Linux config/template/toolchain gates fail before privileged commands' test_linux_configuration_template_and_toolchain_gates_precede_privilege
run_test 'failed atomic replacements preserve original user and root files' test_atomic_replace_failures_preserve_existing_user_and_root_files
run_test 'fixed root destinations reject direct destination/backup symlinks' test_fixed_root_targets_reject_direct_destination_and_backup_symlinks
run_test 'Windows task query normalizes CRLF and rejects unknown/invalid states' test_windows_task_state_normalizes_crlf_and_rejects_unknown_state
run_test 'Windows task query errors are not absence and cause no mutations' test_windows_task_query_errors_are_not_absence_and_never_mutate
run_test 'pinned prebuilt checksum is validated before extraction' test_pinned_prebuilt_checksum_precedes_extraction
run_test 'Linux install prepares, checks, stops active units, deploys, enables, and starts' test_linux_install_orders_preparation_check_stop_deploy_enable_start_and_propagates_failures
run_test 'atomic root replacement preserves finite manual backup' test_root_atomic_replacement_keeps_first_manual_backup
run_test 'root comparator I/O errors preserve the original without writes' test_root_comparator_error_preserves_original_without_backup_or_writes
run_test 'Linux action ordering and error propagation' test_linux_service_actions_preserve_order_and_propagate_failure
run_test 'macOS/Windows routing uses mocked handlers' test_nonlinux_dispatch_is_explicit_and_mocked
run_test 'macOS lifecycle operations use mocks' test_macos_lifecycle_commands_are_mocked
run_test 'macOS launchd query distinguishes absence from permission/query errors' test_macos_job_query_distinguishes_absence_from_errors
run_test 'macOS throttled/terminated/crashed launchd states remain loaded states' test_macos_launchd_stopped_terminal_states_are_not_absent
run_test 'macOS controller build failure leaves services and fixed targets untouched' test_macos_controller_build_failure_precedes_service_changes_and_target_writes
run_test 'macOS lifecycle query errors fail before service mutations' test_macos_lifecycle_query_errors_fail_before_service_mutations
run_test 'macOS status propagates controller query errors' test_macos_status_propagates_controller_query_error
run_test 'macOS install prepares software, builds controller, and starts managed services' test_macos_install_prepares_checks_stops_deploys_enables_and_starts
run_test 'macOS helper source is preflighted before privileged writes' test_macos_helper_source_is_preflighted_before_privileged_writes
run_test 'Windows install prepares/reuses the GUI and runs the current-user task' test_windows_install_prepares_or_reuses_winget_and_runs_current_user_task
run_test 'Windows start/stop/restart use the task mock' test_windows_start_stop_restart_use_only_task_mocks

(( FAILURES == 0 )) || exit 1
printf 'All Kanata maintenance mock tests passed (%d tests).\n' "$TESTS"
