#!/bin/bash

CURRENT=$(swaymsg -t get_workspaces | jq '.[] | select(.focused).num')
if [[ $1 == "next" ]];then
    NEXT=$(( ($CURRENT % 10 ) + 1))
    swaymsg move container to workspace $NEXT
    swaymsg workspace $NEXT
elif [[ $1 == "prev" ]];then
    PREV=$(( ($CURRENT - 1 + 9 ) % 10 + 1))
    swaymsg move container to workspace $PREV
    swaymsg workspace $PREV
fi
