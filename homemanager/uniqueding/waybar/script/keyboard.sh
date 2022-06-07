#!/usr/bin/env bash

if [[ $1 == "status" ]];then
    while true
    do
    STATUS=$(ps -ef | grep squeekboard | grep -vE 'grep|nvim|vim' | wc -l)
    if [[ $STATUS == 0 ]];then
        echo "{\"alt\":\"deactivated\"}"
    else
        echo "{\"alt\":\"activated\"}"
    fi
    sleep 0.5
    done
elif [[ $1 == "toggle" ]];then
    STATUS=$(ps -ef | grep squeekboard | grep -vE 'grep|nvim|vim' | wc -l)
    if [[ $STATUS == 0 ]];then
        fcitx5-remote -g "squeekboard"
        squeekboard & sleep 0.3
        busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
    else
        fcitx5-remote -g "colemak"
        busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
        killall squeekboard
    fi
fi
