#!/usr/bin/env bash
set -x

case $HOSTNAME in
    "uniqueding-pad")
        exec nm-applet &
        exec blueman-applet &
        exec wlsunset -l 39.9 -L 116.3 &
        exec syncthing &
        ;;
esac
