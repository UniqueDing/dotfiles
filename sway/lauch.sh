#!/bin/bash

IDENTIFY=$(cat ~/.config/identify)
if [ $IDENTIFY == "jing" ];then
    echo "jing"
    # swaymsg "output HDMI-A-1 transform 90"
    # swaymsg "workspace 1 output DP-1"
    # swaymsg "workspace 10 output HDMI-A-1"
    swaymsg "exec /opt/bytedance/feishu/bytedance-feishu"
elif [ $IDENTIFY == "pad" ];then
    echo "pad"
    # swaymsg "output HDMI-A-1 transform 90"
    # swaymsg "workspace 1 output DP-1"
    # swaymsg "workspace 10 output HDMI-A-1"
    swaymsg "output eDP-1 scale 1.8"
fi
