#!/bin/bash

WOBSOCK=$XDG_RUNTIME_DIR/wob.sock

if [[ $1 == "up" ]];then
    pactl set-sink-volume @DEFAULT_SINK@ +5% && pactl get-sink-volume @DEFAULT_SINK@ | head -n 1| awk '{print substr($5, 1, length($5)-1)}' > $WOBSOCK
elif [[ $1 == "down" ]];then
    pactl set-sink-volume @DEFAULT_SINK@ -5% && pactl get-sink-volume @DEFAULT_SINK@ | head -n 1 | awk '{print substr($5, 1, length($5)-1)}' > $WOBSOCK
elif [[ $1 == "mute" ]];then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
fi
