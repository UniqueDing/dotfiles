#!/bin/bash

WAYBAR="$HOME/.config/waybar/config-dock"

if [[ $1 == "status" ]];then
    while true
    do
    STATUS=$(ps -ef | grep "$WAYBAR" | grep -v grep | wc -l)
    if [[ $STATUS == 0 ]];then
        echo "{\"alt\":\"deactivated\"}"
    else
        echo "{\"alt\":\"activated\"}"
    fi
    sleep 0.5
    done
elif [[ $1 == "toggle" ]];then
    STATUS=$(ps -ef | grep "$WAYBAR" | grep -v grep | wc -l)
    if [[ $STATUS == 0 ]];then
        $HOME/.config/sway/script/lightdark.sh waybar-dock
    else
        PID=$(ps -ef | grep "$WAYBAR" | grep -v grep | awk '{print $2}' )
        echo $PID
        kill $PID
    fi
fi
