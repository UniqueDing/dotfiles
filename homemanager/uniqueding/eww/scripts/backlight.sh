#!/usr/bin/env bash

WOBSOCK=$XDG_RUNTIME_DIR/wob.sock

case $1 in
"up")
    brightnessctl set +5% | sed -En 's/.*\(([0-9]+)%\).*/\1/p' > $WOBSOCK
    ;;
"down")
    brightnessctl set 5%- | sed -En 's/.*\(([0-9]+)%\).*/\1/p' > $WOBSOCK
    ;;
"status")
    brightnessctl -m | awk -F, '{print $4}' | tr -d "%"
    ;;
"set")
    brightnessctl set $2%
    ;;
esac
