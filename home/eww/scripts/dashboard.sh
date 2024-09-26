#!/usr/bin/env bash
set -x

_toggle() {
    eww open dashboard --toggle
    STATUS=$(ps -ef | grep waybar | grep -v grep | wc -l)
    if [[ $STATUS == 0 ]];then
        waybar -c ~/.config/eww/scripts/tmp/waybar_tray &
    else
        kill `pidof waybar`
    fi
}

case $1 in
    "toggle")
        _toggle
        ;;
esac
