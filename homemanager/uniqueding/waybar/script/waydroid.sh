#!/usr/bin/env bash

if [[ $1 == "status" ]];then
    while true
    do
    if [ -f /tmp/waybar_waydroid ];then
        echo "{\"alt\":\"activated\"}"
    else
        echo "{\"alt\":\"deactivated\"}"
    fi
    sleep 0.1
    done
elif [[ $1 == "toggle" ]];then
    if [ -f /tmp/waybar_waydroid ];then
        systemctl stop waydroid-container.service
        exec ~/.config/sway/lauch.sh
        swaymsg workspace 1
        rm -f /tmp/waybar_waydroid
    else
        touch /tmp/waybar_waydroid
        systemctl start waydroid-container.service
        swaymsg reload
        swaymsg workspace 0
        waydroid show-full-ui &

        kill `pidof lisgd`

        lisgd \
            -g "3,UD,*,*,R, swaymsg fullscreen" \
            -d /dev/input/event30 &
    fi
fi
