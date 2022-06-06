#!/bin/bash

if [ $HOSTNAME == "uniqueding-pad" ];then
    swaymsg "output eDP-1 scale 1.75"
    $HOME/.config/sway/script/gesture.sh 0
fi
