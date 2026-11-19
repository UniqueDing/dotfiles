#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/ghostty-config-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

export DOTFILES_DIR="$repo_root"
export CONF_DIR="$DOTFILES_DIR/conf"
source "$repo_root/scripts/conf.sh"

count_exact() {
    local expected="$1" file="$2"
    grep -Fxc -- "$expected" "$file" || true
}

check_includes() {
    local file="$1" platform="$2" common_line platform_line old_line
    common_line="config-file = \"$CONF_DIR/ghostty/config\""
    platform_line="config-file = \"$CONF_DIR/ghostty/$platform.conf\""
    old_line="config-file = \"$CONF_DIR/ghostty/macos-keybinds.conf\""
    [[ "$(count_exact "$common_line" "$file")" -eq 1 ]]
    [[ "$(count_exact "$platform_line" "$file")" -eq 1 ]]
    [[ "$(count_exact "$old_line" "$file")" -eq 0 ]]
    [[ "$(grep -nF -- "$common_line" "$file" | cut -d: -f1)" -lt \
        "$(grep -nF -- "$platform_line" "$file" | cut -d: -f1)" ]]
}

# macOS: legacy filename, old managed include migration, preservation, idempotency.
export HOME="$fixture/macos"
mac_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$mac_dir"
printf 'background = #123456\nconfig-file = "%s/ghostty/macos-keybinds.conf"\nuser-setting = keep\n' \
    "$CONF_DIR" > "$mac_dir/config"
link_ghostty_configs macos
check_includes "$mac_dir/config" macos
grep -Fqx 'background = #123456' "$mac_dir/config"
grep -Fqx 'user-setting = keep' "$mac_dir/config"
[[ ! -e "$mac_dir/config.ghostty" ]]
first="$(shasum -a 256 "$mac_dir/config" | cut -d' ' -f1)"
link_ghostty_configs macos
[[ "$(shasum -a 256 "$mac_dir/config" | cut -d' ' -f1)" == "$first" ]]

# macOS: new native config prefers config.ghostty and leaves the legacy file alone.
export HOME="$fixture/macos-new"
mac_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$mac_dir"
printf 'legacy = untouched\n' > "$mac_dir/config"
printf 'native = preferred\n' > "$mac_dir/config.ghostty"
link_ghostty_configs macos
[[ -f "$mac_dir/config.ghostty" ]]
grep -Fqx 'legacy = untouched' "$mac_dir/config"
grep -Fqx 'native = preferred' "$mac_dir/config.ghostty"
check_includes "$mac_dir/config.ghostty" macos

# Linux: remove only the old repo-directory symlink, never write through it.
export HOME="$fixture/linux"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"
common_hash="$(shasum -a 256 "$CONF_DIR/ghostty/config" | cut -d' ' -f1)"
ln -s "$CONF_DIR/ghostty/" "$XDG_CONFIG_HOME/ghostty"
link_ghostty_configs linux
[[ ! -L "$XDG_CONFIG_HOME/ghostty" ]]
[[ -d "$XDG_CONFIG_HOME/ghostty" ]]
[[ "$(shasum -a 256 "$CONF_DIR/ghostty/config" | cut -d' ' -f1)" == "$common_hash" ]]
check_includes "$XDG_CONFIG_HOME/ghostty/config.ghostty" linux
! grep -Fq 'macos.conf' "$XDG_CONFIG_HOME/ghostty/config.ghostty"
! grep -Fq 'linux.conf' "$mac_dir/config.ghostty"

# Existing Linux legacy config content is retained when no native config exists.
export HOME="$fixture/linux-existing"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME/ghostty"
printf 'user-linux-setting = keep\n' > "$XDG_CONFIG_HOME/ghostty/config"
link_ghostty_configs linux
grep -Fqx 'user-linux-setting = keep' "$XDG_CONFIG_HOME/ghostty/config"
check_includes "$XDG_CONFIG_HOME/ghostty/config" linux

# Do not write through a config symlink into versioned repo config.
export HOME="$fixture/repo-link"
mac_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$mac_dir"
ln -s "$CONF_DIR/ghostty/config" "$mac_dir/config.ghostty"
if link_ghostty_configs macos 2>/dev/null; then
    printf '%s\n' 'Expected repo-owned config symlink to be rejected.' >&2
    exit 1
fi

# Reject a self-referential config symlink immediately rather than traversing it.
export HOME="$fixture/self-link"
mac_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$mac_dir"
ln -s config.ghostty "$mac_dir/config.ghostty"
if link_ghostty_configs macos 2>/dev/null; then
    printf '%s\n' 'Expected self-referential config symlink to be rejected.' >&2
    exit 1
fi

# Refuse an unrelated Linux directory symlink without changing its target.
export HOME="$fixture/linux-unrelated-link"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME" "$fixture/unrelated-ghostty"
printf 'unrelated = untouched\n' > "$fixture/unrelated-ghostty/config"
ln -s "$fixture/unrelated-ghostty" "$XDG_CONFIG_HOME/ghostty"
if link_ghostty_configs linux 2>/dev/null; then
    printf '%s\n' 'Expected unrelated Ghostty directory symlink to be rejected.' >&2
    exit 1
fi
[[ -L "$XDG_CONFIG_HOME/ghostty" ]]
grep -Fqx 'unrelated = untouched' "$fixture/unrelated-ghostty/config"

# Exercise the GNU stat -c mode path, which is available on Linux.
export HOME="$fixture/portable-stat"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME/ghostty" "$fixture/fake-bin"
printf 'mode-preserved = true\n' > "$XDG_CONFIG_HOME/ghostty/config"
chmod 640 "$XDG_CONFIG_HOME/ghostty/config"
cat > "$fixture/fake-bin/stat" <<'STAT'
#!/usr/bin/env bash
if [[ "$1" == '-c' && "$2" == '%a' ]]; then
    printf '640\n'
    exit 0
fi
exit 1
STAT
chmod +x "$fixture/fake-bin/stat"
PATH="$fixture/fake-bin:$PATH" link_ghostty_configs linux
[[ "$(/usr/bin/stat -f '%Lp' "$XDG_CONFIG_HOME/ghostty/config")" == 640 ]]
grep -Fqx 'mode-preserved = true' "$XDG_CONFIG_HOME/ghostty/config"

printf '%s\n' 'Ghostty config deployment tests passed.'
