#!/bin/bash

if [[ $1 == "full" ]];then
    NAME=$(date +'%s_grim.png')
    mkdir -p $HOME/Pictures/screenshot
    grim $HOME/Pictures/screenshot/$NAME
    notify-send "screenshot $NAME"
elif [[ $1 == "rect" ]];then
    NAME=$(date +'%s_grim.png')
    mkdir -p $HOME/Pictures/screenshot
    grim -g `slurp` $HOME/Pictures/screenshot/$NAME
    notify-send "screenshot $NAME"
fi
