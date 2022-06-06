#!/bin/bash

if [ $1 == 'up' ];then
	xbacklight +10
	notify-send -t 500 "light +10"
elif [ $1 == 'down' ];then
	xbacklight -10
	notify-send -t 500 "light -10"
fi
backlightSize=$(xbacklight | awk -F '.' '{print $1}')


