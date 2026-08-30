#!/usr/bin/env bash
set -x

window_panes=
killlast=
mfact=

newpane() {
    tmux \
        split-window -t :.0\; \
        swap-pane -s :.0 -t :.1\; \
        select-layout main-vertical-mirrored\; \
        resize-pane -t :.0 -x ${mfact}%
}

newpanecurdir() {
    tmux \
        split-window -t :.0 -c "#{pane_current_path}"\; \
        swap-pane -s :.0 -t :.1\; \
        select-layout main-vertical-mirrored\; \
        resize-pane -t :.0 -x ${mfact}%
}

killpane() {
    if [ $window_panes -gt 1 ]; then
        tmux kill-pane -t :.\; \
            select-layout main-vertical-mirrored\; \
            resize-pane -t :.0 -x ${mfact}%
    else
        if [ $killlast -ne 0 ]; then
            tmux kill-window
        fi
    fi
}

nextpane() {
    tmux select-pane -t :.+
}

prevpane() {
    tmux select-pane -t :.-
}

rotateccw() {
    tmux rotate-window -U\; select-pane -t 0
}

rotatecw() {
    tmux rotate-window -D\; select-pane -t 0
}

zoom() {
    tmux swap-pane -s :. -t :.0\; select-pane -t :.0
}

layouttile() {
    tmux select-layout main-vertical\; resize-pane -t :.0 -x ${mfact}%
}

float() {
    tmux resize-pane -Z
}

repair() {
    target=
    for candidate in "$@"; do
        [ -n "$candidate" ] || continue
        if tmux display -p -t "$candidate" '#{window_id}' >/dev/null 2>&1; then
            target=$candidate
            break
        fi
    done
    [ -n "$target" ] || return 0
    # Pane-exited and after-kill-pane can run after the final pane has already
    # destroyed its window. Do not try to repair a target that no longer exists.
    target_mfact=$(tmux display -p -t "$target" '#{mfact}') || return 0
    tmux select-layout -t "$target" main-vertical-mirrored >/dev/null 2>&1 || return 0
    tmux resize-pane -t "$target.0" -x "${target_mfact}%" >/dev/null 2>&1 || true
}

incmfact() {
    fact=$((mfact + 5))
    if [ $fact -le 95 ]; then
        tmux \
            setenv mfact $fact\; \
            resize-pane -t :.0 -x ${fact}%
    fi
}

decmfact() {
    fact=$((mfact - 5))
    if [ $fact -ge 5 ]; then
        tmux \
            setenv mfact $fact\; \
            resize-pane -t :.0 -x ${fact}%
    fi
}

window() {
    window=$1
    tmux selectw -t $window
}

join() {
    window=$1
    source_window=$(tmux display -p '#{window_id}')
    tmux rotate-window -U\; select-pane -l
    if destination_window=$(tmux list-windows \
        -f "#{==:#{window_index},$window}" \
        -F '#{window_id}' 2>/dev/null) && [ -n "$destination_window" ]; then
        tmux join-pane -t :$window\; \
            swap-pane -s :.0 -t :.1\; \
            select-layout main-vertical-mirrored\; \
            resize-pane -t :.0 -x ${mfact}%
        repair "$source_window"
        repair "$destination_window"
    else
        tmux break-pane -t :$window
        destination_window=$(tmux display -p '#{window_id}')
        repair "$source_window"
        repair "$destination_window"
    fi
}

if [ $# -lt 1 ]; then
    echo "dwm.tmux.sh [command]"
    exit
fi

command=$1
shift
args=$*
read -r window_panes killlast mfact < <(tmux display -p "#{window_panes} #{killlast} #{mfact}")

case $command in
newpane) newpane ;;
newpanecurdir) newpanecurdir ;;
killpane) killpane ;;
nextpane) nextpane ;;
prevpane) prevpane ;;
rotateccw) rotateccw ;;
rotatecw) rotatecw ;;
zoom) zoom ;;
layouttile) layouttile ;;
float) float ;;
incmfact) incmfact ;;
decmfact) decmfact ;;
window) window $args ;;
join) join $args ;;
repair) repair "$@" ;;
*)
    echo "unknown command"
    exit 1
    ;;
esac
