#!/bin/bash

if [[ $1 == "status" ]];then
    while true
    do
    MODE=$(grep '\"mode"\:' $HOME/.config/waybar/config | cut -d ":" -f 2 | cut -d "\"" -f 2 | head -1)
    if [[ $MODE == "dock" ]];then
        echo "{\"alt\":\"activated\"}"
    else
        echo "{\"alt\":\"deactivated\"}"
    fi
    sleep 0.1
    done
elif [[ $1 == "toggle" ]];then
    MODE=$(grep '\"mode"\:' $HOME/.config/waybar/config | cut -d ":" -f 2 | cut -d "\"" -f 2 | head -1)
    if [[ $MODE == "dock" ]];then
        sed "s/dock/invisible/g" -i $HOME/.config/waybar/config
        swaymsg "reload"
    else
        sed "s/invisible/dock/g" -i $HOME/.config/waybar/config
        swaymsg "reload"
    fi
fi
