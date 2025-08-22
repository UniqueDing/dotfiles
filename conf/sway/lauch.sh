#!/usr/bin/env bash

if [ $HOSTNAME == "uniqueding-pad" ];then
    swaymsg "output eDP-1 scale 1.75"
    $HOME/.config/sway/script/gesture.sh 0
    # set $lock gdmflexiserver
    exec swayidle -w \
             timeout 600 $lock \
             timeout 900 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' \
             before-sleep $lock

fi
