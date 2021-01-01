#!/bin/bash

if [ $1 == 'full' ];then
	scrot -e 'mv $f ~/Pictures/screenscrot'
	notify-send "scrot full"
elif [ $1 == 'select' ];then
	sleep 1s
	scrot -se 'mv $f ~/Pictures/screenscrot'
	notify-send "scrot select"
fi

