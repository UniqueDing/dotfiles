#!/usr/bin/env bash

NAME=$(date +'%s_grim.png')
if [[ ! -d $HOME/Pictures/screenshot ]]; then
    mkdir -p $HOME/Pictures/screenshot
fi

case $1 in
    "full")
        grim $HOME/Pictures/screenshot/$NAME
        notify-send "screenshot $NAME"
        ;;
    "rect")
        sleep 0.3         # for eww cannot slurp
        grim -g "`slurp`" $HOME/Pictures/screenshot/$NAME
        notify-send "screenshot $NAME"
        ;;
esac
