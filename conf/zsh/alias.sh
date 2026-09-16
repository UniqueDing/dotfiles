# alias

alias ra='yazi'
# alias ls='lsd --hyperlink=auto'
alias ls='eza --icons=auto --hyperlink -g'
alias l=ls
alias ll='ls -l --git -g'
alias lla='ll -a'
alias lst='ls --tree'
alias ..='cd ..'
alias ...='cd ../..'
# alias cdl='~/.config/dwm/dark-light.sh'
alias icat="kitty +kitten icat"
function showkey() {
	case "$(uname -s)" in
		Linux)
			if (( ! $+commands[wshowkeys] )); then
				print -u2 'showkey: wshowkeys is not installed'
				return 1
			fi
			wshowkeys -a bottom -b 00000033 -m100 -F 'Hack 44'
			;;
		Darwin)
			if ! open -Ra Karabiner-EventViewer >/dev/null 2>&1; then
				print -u2 'showkey: Karabiner-Elements is required on macOS'
				return 1
			fi
			open -a Karabiner-EventViewer
			;;
		*)
			print -u2 "showkey: unsupported operating system: $(uname -s)"
			return 1
			;;
	esac
}

alias tssh="TERM=xterm ssh"
alias scpr="rsync -aHAXP --rsh=ssh"
alias lg="lazygit"
# Connect the TUI to the systemd-managed OpenCode server.
# Keep the caller's current directory as the OpenCode project directory.
alias oc='OPENCODE_ENABLE_EXA=1 opencode attach http://127.0.0.1:4096 --dir "$PWD"'
function mkcd(){
	mkdir $1
	cd $1
}
function _ssh_add() {
	if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
		eval "$(ssh-agent -s)" || return
	fi
	ssh-add
}

function ssha() {
	_ssh_add
}

# Unlock an SSH key, share its agent with the user service manager, then restart OpenCode.
function ocs() {
	_ssh_add || return

	case "$(uname -s)" in
		Linux)
			systemctl --user import-environment SSH_AUTH_SOCK || return
			systemctl --user restart opencode-serve
			;;
		Darwin)
			launchctl setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK" || return
			launchctl kickstart -k "gui/$(id -u)/opencode-serve"
			;;
		*)
			print -u2 "ocs: unsupported operating system: $(uname -s)"
			return 1
			;;
	esac
}

alias proxychains="proxychains4"
alias pc="proxychains -q"

alias f=$(pay-respects zsh)

alias fzda="d-attach" # fzf docker attach
alias fzdirm="d-image-rm" # fzf docker image rm
alias fzdrm="d-rm" # fzf docker rm
alias fzds="d-stop-container" # fzf docker stop
alias fz="fif"
alias fze="fzf-find-edit" # fzf edit with $EDITOR
alias fzg="fzf-grep-edit" # fzf edit with $EDITOR
alias fzk="fzf-kill" # fzf kill processes

alias pS='sudo pacman -S'
alias pSs='pacman -Ss'
alias pSyu='sudo pacman -Syu'
alias pSyyu='sudo pacman -Syyu'
alias pR='sudo pacman -R'
alias pRs='sudo pacman -Rs'
alias pSi='pacman -Si'
alias pQs='pacman -Qs'
alias pQi='pacman -Qi'
alias yS='paru -S'
alias ySs='paru -Ss'
alias yR='paru -R'
alias ySyu='paru -Syu'
alias ySyyu='paru -Syyu'

alias bI='brew install'
alias bR='brew remove'
alias bS='brew search'
alias bL='brew list'
alias bF='brew info'
alias bU='brew update && brew upgrade && brew upgrade --cask'

alias aI='sudo apt install'
alias aS='apt search'
alias aR='sudo apt remove'
alias aP='sudo apt purge'
alias aL='apt list'
alias aH='apt show'
alias aU='sudo apt update && sudo apt upgrade'

alias gu='git status'
alias gm='git commit'
alias gmm='git commit -m'
alias gpa='git push origin ; git push github; git push gitee'

# alias pipU='pip3 freeze --local | grep -v '^-e' | cut -d = -f 1  | xargs -n1 pip install -U'

# fzf
alias nvimf='nvim `fzf --preview "cat {}"`'

function _sys() {
	local action=$1
	local scope=$2
	local label=$3
	local target plist

	if [[ -z "$label" ]]; then
		print -u2 "usage: ${scope}sys${action} <label>"
		return 1
	fi

	case "$(uname -s)" in
		Linux)
			if [[ "$scope" == system ]]; then
				case "$action" in
					E) sudo systemctl enable "$label" ;;
					D) sudo systemctl disable "$label" ;;
					S) sudo systemctl start "$label" ;;
					P) sudo systemctl stop "$label" ;;
					U) systemctl status "$label" ;;
					R) sudo systemctl restart "$label" ;;
				esac
			else
				case "$action" in
					E) systemctl --user enable "$label" ;;
					D) systemctl --user disable "$label" ;;
					S) systemctl --user start "$label" ;;
					P) systemctl --user stop "$label" ;;
					U) systemctl --user status "$label" ;;
					R) systemctl --user restart "$label" ;;
				esac
			fi
			;;
		Darwin)
			if [[ "$scope" == system ]]; then
				target="system/$label"
				plist="/Library/LaunchDaemons/$label.plist"
				case "$action" in
					E) sudo launchctl bootstrap system "$plist" ;;
					D) sudo launchctl bootout "$target" ;;
					S) sudo launchctl kickstart "$target" ;;
					P) sudo launchctl kill SIGTERM "$target" ;;
					U) sudo launchctl print "$target" ;;
					R) sudo launchctl kickstart -k "$target" ;;
				esac
			else
				target="gui/$(id -u)/$label"
				plist="$HOME/Library/LaunchAgents/$label.plist"
				case "$action" in
					E) launchctl bootstrap "gui/$(id -u)" "$plist" ;;
					D) launchctl bootout "$target" ;;
					S) launchctl kickstart "$target" ;;
					P) launchctl kill SIGTERM "$target" ;;
					U) launchctl print "$target" ;;
					R) launchctl kickstart -k "$target" ;;
				esac
			fi
			;;
		*)
			print -u2 "sys${action}: unsupported operating system: $(uname -s)"
			return 1
			;;
	esac
}

function sysE() { _sys E system "$1"; }
function sysD() { _sys D system "$1"; }
function sysS() { _sys S system "$1"; }
function sysP() { _sys P system "$1"; }
function sysU() { _sys U system "$1"; }
function sysR() { _sys R system "$1"; }
function sysuE() { _sys E user "$1"; }
function sysuD() { _sys D user "$1"; }
function sysuS() { _sys S user "$1"; }
function sysuP() { _sys P user "$1"; }
function sysuU() { _sys U user "$1"; }
function sysuR() { _sys R user "$1"; }

function penv() {
	local path_entry
	local -a filtered_path

	if (( $# == 0 )); then
		print -u2 'usage: penv <command> [arguments...]'
		return 1
	fi

	for path_entry in ${(s/:/)PATH}; do
		if [[ "$path_entry" == "$HOME"/.nix-profile* || \
			"$path_entry" == /nix/var/nix/profiles/* || \
			"$path_entry" == /run/current-system/sw* || \
			"$path_entry" == /nix/store/* ]]; then
			continue
		fi
		filtered_path+=("$path_entry")
	done

	(
		unset LD_LIBRARY_PATH LD_PRELOAD NIX_PATH NIX_PROFILES NIX_SSL_CERT_FILE NIX_REMOTE IN_NIX_SHELL
		PATH="${(j/:/)filtered_path}"
		exec "$@"
	)
}
