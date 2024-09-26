#!/usr/bin/env bash
# set -x

WOBSOCK=$XDG_RUNTIME_DIR/wob.sock

_get_sink_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ | head -n 1 | awk '{print substr($5, 1, length($5)-1)}'
}

_get_source_volume() {
    pactl get-source-volume @DEFAULT_SOURCE@ | head -n 1 | awk '{print substr($5, 1, length($5)-1)}'
}

_get_sink_mute() {
    STATUS=`pactl get-sink-mute @DEFAULT_SINK@ | head -n 1 | awk '{print $2}'`
    echo $STATUS
}

_get_source_mute() {
    STATUS=`pactl get-source-mute @DEFAULT_SOURCE@ | head -n 1 | awk '{print $2}'`
    echo $STATUS
}

_ewwstatus() {
    if [[ "`_get_sink_mute`" == "yes" ]];then
        echo ""
    else
        echo ""
    fi
}

case $1 in
    "sinkvalue")
        _get_sink_volume
        ;;
    "sinkset")
        pactl set-sink-volume @DEFAULT_SINK@ $2%
        ;;
    "sinkup")
        pactl set-sink-volume @DEFAULT_SINK@ +5% && _get_sink_volume > $WOBSOCK
        ;;
    "sinkdown")
        pactl set-sink-volume @DEFAULT_SINK@ -5% && _get_sink_volume > $WOBSOCK
        ;;
    "sinkmute")
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        ;;
    "sinkstatus")
        _get_sink_mute
        ;;


    "sourcevalue")
        _get_source_volume
        ;;
    "sourceset")
        pactl set-source-volume @DEFAULT_SOURCE@ $2%
        ;;
    "sourceup")
        pactl set-source-volume @DEFAULT_SOURCE@ +5% && _get_source_volume > $WOBSOCK
        ;;
    "sourcedown")
        pactl set-source-volume @DEFAULT_SOURCE@ -5% && _get_source_volume > $WOBSOCK
        ;;
    "sourcemute")
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        ;;
    "sourcestatus")
        _get_source_mute
        ;;

    "ewwstatus")
        _ewwstatus

esac
