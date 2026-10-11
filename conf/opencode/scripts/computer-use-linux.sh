#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"

fail() {
  printf 'computer-use-linux: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == Linux ]] || fail '仅支持 Linux。'

uid="$(id -u)"
runtime="${XDG_RUNTIME_DIR:-}"
if [[ -z "$runtime" || ! -d "$runtime" || ! -O "$runtime" ]]; then
  runtime="/run/user/$uid"
fi

if [[ -d "$runtime" && -O "$runtime" ]]; then
  export XDG_RUNTIME_DIR="$runtime"
  bus="$runtime/bus"
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "$bus" && -O "$bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
  fi
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  fail '未找到当前用户有效的 D-Bus 会话总线；请从已登录的桌面会话启动。'
fi

if [[ "$DBUS_SESSION_BUS_ADDRESS" != unix:path=* ]]; then
  fail '当前 D-Bus 地址不是可验证的 Unix 路径套接字；拒绝猜测或替换会话授权。'
fi
bus_path="${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
bus_path="${bus_path%%,*}"
[[ -S "$bus_path" && -O "$bus_path" ]] || fail '当前 D-Bus 地址不是当前用户拥有的有效套接字。'

package_dir="${HOME:?}/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux"
native="$package_dir/npm/bin/computer-use-linux-linux-x64"
[[ -x "$native" ]] || fail "找不到已安装的 Linux 原生程序：$native。请先运行 npm install --prefix \"\$HOME/.local/share/computer-use-linux\" @agent-sh/computer-use-linux@0.7.12。"
[[ -r "$package_dir/package.json" ]] || fail "找不到软件包元数据：$package_dir/package.json。"
command -v node >/dev/null 2>&1 || fail '找不到 node，无法验证已安装软件包版本。'
version="$(node -e 'process.stdout.write(require(process.argv[1]).version || "")' "$package_dir/package.json")"
[[ "$version" == 0.7.12 ]] || fail "软件包版本不匹配（需要 0.7.12，实际为 ${version:-未知}）。"

command -v nix >/dev/null 2>&1 || fail '找不到 Nix；无法提供原生程序所需的兼容运行时。'
cache_root="${XDG_CACHE_HOME:-${HOME:?}/.cache}/opencode"
if [[ -e "$cache_root" && ( ! -d "$cache_root" || ! -O "$cache_root" ) ]]; then
  fail "缓存目录不是当前用户拥有的目录：$cache_root。"
fi
mkdir -p -m 700 -- "$cache_root"
runtime_link="$cache_root/computer-use-runtime"
runtime_wrapper="$runtime_link/bin/computer-use-runtime"
if [[ ! -x "$runtime_wrapper" ]]; then
  if ! nix build --offline --impure --file "$script_dir/computer-use-runtime.nix" --out-link "$runtime_link" >&2; then
    fail '无法构建 Nix 兼容运行时（仅使用本地锁定 flake 与已有 store，不会下载或更新依赖）。'
  fi
fi
[[ -x "$runtime_wrapper" ]] || fail 'Nix 兼容运行时 wrapper 构建结果无效。'

# The package's shell-capable tool is intentionally never exposed.
unset COMPUTER_USE_LINUX_ENABLE_SHELL
export COMPUTER_USE_LINUX_ENABLE_SHELL=0

args=("$@")
if [[ ${#args[@]} -eq 0 ]]; then
  args=(mcp)
fi
exec "$runtime_wrapper" "$native" "${args[@]}"
