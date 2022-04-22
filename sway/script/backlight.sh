#!/bin/bash

WOBSOCK=$XDG_RUNTIME_DIR/wob.sock

if [[ $1 == "up" ]];then
    brightnessctl set +5% | sed -En 's/.*\(([0-9]+)%\).*/\1/p' > $WOBSOCK
elif [[ $1 == "down" ]];then
    brightnessctl set 5%- | sed -En 's/.*\(([0-9]+)%\).*/\1/p' > $WOBSOCK
fi
