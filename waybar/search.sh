#!/bin/bash

STATUS=$(ps -ef | grep wofi | grep -v grep | wc -l)
if [[ $STATUS == 0 ]];then
    wofi --show drun,run &
else
    killall wofi
fi
