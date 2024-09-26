#!/usr/bin/env bash

FILE=/tmp/EWW_LOCK

_auth() {
    echo $1 | su `whoami`

    if [[ $? == 0 ]];then
        _unlock
        echo success > $FILE
    else
        echo fail > $FILE
    fi
}

_lock() {
    eww close-all
    eww open lock
    echo wait > $FILE
    ~/.config/eww/scripts/keyboard.sh start_nochange
}

_unlock() {
    ~/.config/eww/scripts/keyboard.sh stop_nochange
    eww close lock
    eww open bar
}

_status() {
    STATUS=`cat $FILE`
    if [[ $STATUS == "success" ]];then
        echo ""
    elif [[ $STATUS == "fail" ]];then
        echo ""
    else
        echo ""
    fi
}

case $1 in
    "auth")
        _auth $2
        ;;
    "lock")
        _lock
        ;;
    "status")
        _status
        ;;
esac
