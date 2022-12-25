#!/usr/bin/env bash

start() {
    fcitx5-remote -g "squeekboard"
    squeekboard & sleep 0.3
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true

}

stop() {
    fcitx5-remote -g "colemak"
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
    kill `pidof squeekboard`
}

start_nochange() {
    squeekboard & sleep 0.3
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
}

stop_nochange() {
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
    kill `pidof squeekboard`
}

case $1 in
    "toggle")
        STATUS=$(ps -ef | grep squeekboard | grep -vE 'grep|nvim|vim' | wc -l)
        if [[ $STATUS == 0 ]];then
            start
        else
            stop
        fi
        ;;
    "start")
            start
        ;;
    "stop")
            stop
        ;;
    "start_nochange")
            start_nochange
        ;;
    "stop_nochange")
            stop_nochange
        ;;
esac
