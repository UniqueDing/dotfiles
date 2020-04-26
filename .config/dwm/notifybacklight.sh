#!/bin/bash

if [ $1 == 'up' ];then
	xbacklight +10
elif [ $1 == 'down' ];then
	xbacklight -10
fi
backlightSize=$(xbacklight | awk -F '.' '{print $1}')

#notify-send -t 800 "light $backlightSize"

