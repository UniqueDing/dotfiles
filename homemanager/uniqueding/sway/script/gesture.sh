#!/usr/bin/env bash

kill `pidof lisgd`

ROTATE=$(( $1 / 90 ))

lisgd \
    -g "1,LR,L,S,R, wtype -M alt -P left -p left -m alt &" \
    -g "1,RL,R,S,R, wtype -M alt -P left -p left -m alt &" \
    -g "1,DU,B,S,R, $HOME/.config/waybar/script/keyboard.sh toggle &" \
    -g "1,UD,T,S,R, nwggrid &" \
    -g "2,LR,*,*,R, swaymsg workspace prev" \
    -g "2,RL,*,*,R, swaymsg workspace next" \
    -g "3,LR,*,*,R, $HOME/.config/waybar/script/workspace.sh prev &" \
    -g "3,RL,*,*,R, $HOME/.config/waybar/script/workspace.sh next &" \
    -g "3,UD,*,*,R, $HOME/.config/waybar/script/screenshot.sh full &" \
    -g "3,DU,*,*,R, $HOME/.config/waybar/script/screenshot.sh rect &" \
    -m 1200 \
    -o $ROTATE \
    -d /dev/input/event30 &
