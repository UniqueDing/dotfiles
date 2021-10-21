#!/bin/bash

if [ $(cat ~/.config/identify) == "jing" ];then
    echo "jing"
    swaymsg "output HDMI-A-1 transform 90"
    swaymsg "workspace 1 output DP-1"
    swaymsg "workspace 10 output HDMI-A-1"
    swaymsg "exec sleep 1 && fcitx"
fi
