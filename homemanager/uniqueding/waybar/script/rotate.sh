#!/bin/bash

if [[ $1 == "status" ]];then
    while true
    do
    STATUS=$(ps -ef | grep autorotate.sh | grep -vE 'grep|nvim|vim' | wc -l)
    if [[ $STATUS == 0 ]];then
        echo "{\"alt\":\"deactivated\"}"
    else
        echo "{\"alt\":\"activated\"}"
    fi
    sleep 0.1
    done
elif [[ $1 == "toggle" ]];then
    STATUS=$(ps -ef | grep autorotate.sh | grep -vE 'grep|nvim|vim' | wc -l)
    if [[ $STATUS == 0 ]];then
        $HOME/.config/sway/script/autorotate.sh &
    else
        killall autorotate.sh
    fi
fi
