#! /bin/bash
dunst &
picom &
fcitx &
nm-applet &
variety &
blueman-applet &
source ~/.xinitrc
xautolock -time 15 -locker slock &

# while true ; do
# 		    xsetroot -name "$( acpi -b | awk '{ print $3, $4 }' | tr -d ',' )"
# 			    sleep 1s
# 		done &
