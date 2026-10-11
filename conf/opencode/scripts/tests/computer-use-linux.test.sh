#!/usr/bin/env bash
set -euo pipefail

script="$(cd -- "$(dirname -- "$0")/.." && pwd)/computer-use-linux.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/runtime-fallback" "$tmp/runtime-empty" \
  "$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/npm/bin" \
  "$tmp/mock-runtime/bin"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "$tmp/runtime/bus"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "$tmp/runtime-fallback/bus"
printf '{"version":"0.7.12"}\n' >"$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/package.json"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/npm/bin/computer-use-linux-linux-x64"
chmod +x "$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/npm/bin/computer-use-linux-linux-x64"
printf '%s\n' '#!/usr/bin/env bash' 'printf "native=%s\n" "$1"' 'shift' 'printf "args:"' 'printf " <%s>" "$@"' \
  'printf "\nshell=%s\nbus=%s\n" "${COMPUTER_USE_LINUX_ENABLE_SHELL-unset}" "$DBUS_SESSION_BUS_ADDRESS"' \
  >"$tmp/mock-runtime/bin/computer-use-runtime"
chmod +x "$tmp/mock-runtime/bin/computer-use-runtime"

printf '%s\n' '#!/usr/bin/env bash' 'shift 2' 'python3 -c '\''import json,sys; print(json.load(open(sys.argv[1]))["version"], end="")'\'' "$1"' >"$tmp/bin/node"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'out=""' \
  'while (($#)); do if [[ "$1" == --out-link ]]; then out="$2"; shift 2; else shift; fi; done' \
  'ln -sfn "$MOCK_RUNTIME" "$out"' >"$tmp/bin/nix"
chmod +x "$tmp/bin/node" "$tmp/bin/nix"

output="$(PATH="$tmp/bin:/usr/bin:/bin" MOCK_RUNTIME="$tmp/mock-runtime" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/runtime/bus,guid=test" COMPUTER_USE_LINUX_ENABLE_SHELL=1 bash "$script")"
[[ "$output" == *"native=$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/npm/bin/computer-use-linux-linux-x64"* ]]
[[ "$output" == *' <mcp>'* ]]
[[ "$output" == *'shell=0'* ]]
[[ "$output" == *"bus=unix:path=$tmp/runtime/bus,guid=test"* ]]

output="$(PATH="$tmp/bin:/usr/bin:/bin" MOCK_RUNTIME="$tmp/mock-runtime" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/runtime/bus" bash "$script" --help)"
[[ "$output" == *' <--help>'* ]]

if PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime-empty" \
  env -u DBUS_SESSION_BUS_ADDRESS bash "$script" >"$tmp/stdout" 2>"$tmp/stderr"; then
  printf 'Expected failure when no session bus is available.\n' >&2
  exit 1
fi
[[ ! -s "$tmp/stdout" ]]
[[ "$(<"$tmp/stderr")" == *'未找到当前用户有效的 D-Bus 会话总线'* ]]

output="$(PATH="$tmp/bin:/usr/bin:/bin" MOCK_RUNTIME="$tmp/mock-runtime" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime-fallback" \
  env -u DBUS_SESSION_BUS_ADDRESS bash "$script")"
[[ "$output" == *"bus=unix:path=$tmp/runtime-fallback/bus"* ]]

if PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime" \
  DBUS_SESSION_BUS_ADDRESS='unix:path=/tmp/not-a-session-bus' bash "$script" >"$tmp/stdout" 2>"$tmp/stderr"; then
  printf 'Expected rejection of an invalid existing session bus.\n' >&2
  exit 1
fi
[[ ! -s "$tmp/stdout" ]]
[[ "$(<"$tmp/stderr")" == *'不是当前用户拥有的有效套接字'* ]]

printf '{"version":"1.0.0"}\n' >"$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/package.json"
if PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/runtime/bus" bash "$script" >"$tmp/stdout" 2>"$tmp/stderr"; then
  printf 'Expected rejection of an unexpected package version.\n' >&2
  exit 1
fi
[[ ! -s "$tmp/stdout" ]]
[[ "$(<"$tmp/stderr")" == *'软件包版本不匹配'* ]]
printf '{"version":"0.7.12"}\n' >"$tmp/home/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/package.json"

printf '%s\n' '#!/bin/bash' 'printf "Darwin\\n"' >"$tmp/bin/uname"
chmod +x "$tmp/bin/uname"
if PATH="$tmp/bin:/usr/bin:/bin" bash "$script" >"$tmp/stdout" 2>"$tmp/stderr"; then
  printf 'Expected failure on unsupported platforms.\n' >&2
  exit 1
fi
[[ ! -s "$tmp/stdout" ]]
[[ "$(<"$tmp/stderr")" == *'仅支持 Linux'* ]]

printf 'computer-use-linux launcher mock tests passed\n'
