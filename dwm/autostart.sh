#! /bin/bash
dunst &
picom &
fcitx &
nm-applet &
variety &
blueman-applet &
slstatus &
xautolock -time 15 -locker slock &

# idea
export _JAVA_AWT_WM_NONREPARENTING=1
export AWT_TOOLKIT=MToolkit
wmname LG3D &


# while true ; do
# 		    xsetroot -name "$( acpi -b | awk '{ print $3, $4 }' | tr -d ',' )"
# 			    sleep 1s
# 		done &
