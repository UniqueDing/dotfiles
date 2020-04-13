#!/bin/bash

if [ $1 == 'up' ];then
	amixer set Master 3277+
elif [ $1 == 'down' ];then
	amixer set Master 3277-
elif [ $1 == 'toggle' ];then
	amixer set Master toggle
fi

volumeSize=$(amixer get Master | awk NR==6'{print $5}' | tr -d [%])
volumeStatus=$(amixer get Master | awk NR==6'{print $6}' | tr -d [%])

notify-send -t 800  "volume $volumeStatus $volumeSize"

