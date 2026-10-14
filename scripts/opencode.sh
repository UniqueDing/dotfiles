#!/usr/bin/env bash

install_opencode_environment() (
    export NODE_USE_ENV_PROXY="${NODE_USE_ENV_PROXY:-1}"
    (($# <= 1)) || { printf 'Usage: bash build.sh opencode [install|help|update]\n' >&2; return 2; }
    case "${1:-install}" in
        help|-h|--help)
            cat <<'HELP'
Usage: bash build.sh opencode [install|help|update]; install is the default.
Node uses existing environment proxies by default; set NODE_USE_ENV_PROXY=0 to opt out (requires a supported Node version).
First use: prepare Nix/Home Manager, run bash build.sh dotfiles light, then bash build.sh opencode.
Firefox: save work, fully quit daily Firefox, then start the original profile (use your machine's actual path):
/opt/apps/org.mozilla.firefox-nal/files/firefox-bin --marionette --remote-debugging-port=9222
Use loopback ports 2828/9222 only; if occupied, stop. Manually enable firefox.disabled=false and use /mcps in the current OpenCode session.
After use, disconnect and restart Firefox normally to turn off Marionette. Account writes require approval; foreground behavior is not guaranteed.
update refreshes recorded external GitHub skills, then downloads latest npm MCPs and updates their pins, without restarting services.
Codegraph uses nix flake update nixpkgs then bash build.sh dotfiles light (affects other Nix packages); update Hindsight at its deployment. Configure private settings separately; never commit profiles/Cookies.
HELP
            return
            ;;
        install) ;;
        update)
            local selected
            selected="$(jq -r '.skills | to_entries | map(select(.value.sourceType == "github") | .key) | join(" ")' "$DOTFILES_DIR/conf/skills/.skill-lock.json")" || return $?
            if [[ -n "$selected" ]]; then
                local -a names
                read -r -a names <<<"$selected"
                skills update --global "${names[@]}" || return $?
            else
                printf 'No recorded GitHub skills to update.\n'
            fi
            _opencode_update_mcp
            return $?
            ;;
        *) return 2 ;;
    esac
    uv tool install code-review-graph || return $?
    install_opencode_skills || return $?
    npx -y @mozilla/firefox-devtools-mcp@0.10.5 --version || return $?
    if [[ $(uname -sm) == 'Linux x86_64' ]]; then
        local cache="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
        npm install --prefix "$HOME/.local/share/computer-use-linux" @agent-sh/computer-use-linux@0.7.16 || return $?
        mkdir -p -m 700 "$cache" || return $?
        nix build --impure --file "$DOTFILES_DIR/conf/opencode/scripts/computer-use-runtime.nix" --out-link "$cache/computer-use-runtime" || return $?
    fi
)

_opencode_update_mcp() {
    local firefox computer='' platform native
    command -v python3 >/dev/null || return 1
    firefox="$(npm view @mozilla/firefox-devtools-mcp version --silent)" || return $?
    [[ "$firefox" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?(\+[A-Za-z0-9.-]+)?$ ]] || return 1
    platform="$(uname -sm)" || return $?
    if [[ "$platform" == 'Linux x86_64' ]]; then
        computer="$(npm view @agent-sh/computer-use-linux version --silent)" || return $?
        [[ "$computer" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?(\+[A-Za-z0-9.-]+)?$ ]] || return 1
    fi
    npx -y "@mozilla/firefox-devtools-mcp@$firefox" --version || return $?
    if [[ -n "$computer" ]]; then
        npm install --prefix "$HOME/.local/share/computer-use-linux" "@agent-sh/computer-use-linux@$computer" || return $?
        native="$HOME/.local/share/computer-use-linux/node_modules/@agent-sh/computer-use-linux/npm/bin/computer-use-linux-linux-x64"
        [[ -x "$native" ]] || { printf 'Computeruse native binary missing; pins unchanged.\n' >&2; return 1; }
    fi
    python3 - "$DOTFILES_DIR" "$firefox" "$computer" <<'PY'
import os, pathlib, re, sys, tempfile
root = pathlib.Path(sys.argv[1])
firefox, computer = sys.argv[2:]
script = (root / "scripts/opencode.sh").resolve()
config = (root / "conf/opencode/opencode.jsonc").resolve()
files = {script: script.read_text(), config: config.read_text()}
original_script = files[script]
version = r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"
pins = [(script, "@mozilla/firefox-devtools-mcp", firefox), (config, "@mozilla/firefox-devtools-mcp", firefox)]
if computer:
    pins.append((script, "@agent-sh/computer-use-linux", computer))
for path, package, new in pins:
    files[path], count = re.subn(r"(" + re.escape(package) + r"@)" + version, lambda m: m.group(1) + new, files[path])
    if count != 1:
        raise SystemExit("Expected exactly one matching version pin")
if computer:
    old = re.search(r"@agent-sh/computer-use-linux@(" + version + r")", original_script)
    if not old:
        raise SystemExit("Computeruse source pin not found")
    launcher = (root / "conf/opencode/scripts/computer-use-linux.sh").resolve()
    files[launcher], count = re.subn(r"(?<![\w.])" + re.escape(old.group(1)) + r"(?![\w.])", computer, launcher.read_text())
    if count != 3:
        raise SystemExit("Expected three launcher version references")
staged = []
for path, text in files.items():
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as f:
        f.write(text)
        staged.append((path, pathlib.Path(f.name), path.stat().st_mode & 0o777))
for path, temp, mode in staged:
    os.chmod(temp, mode)
    os.replace(temp, path)
PY
}

install_opencode_skills() (
    set -euo pipefail
    [[ $# -eq 0 ]] || { echo "Usage: install_opencode_skills" >&2; return 2; }
    local lock="$DOTFILES_DIR/conf/skills/.skill-lock.json"
    jq -r '.skills | to_entries[] | [.key, .value.source] | @tsv' "$lock" |
        while IFS=$'\t' read -r name source; do
            [[ -f "${HOME:?}/.agents/skills/$name/SKILL.md" ]] && continue
            skills add "$source" --global --agent opencode --skill "$name" || return $?
        done
)
