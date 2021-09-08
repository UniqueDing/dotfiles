#! /bin/bash
# sed 's/breeze\b/bloom/' -i /home/uniqueding/.config/gtk-3.0/settings.ini
# sed 's/breeze\b/bloom/' -i /home/uniqueding/.gtkrc-2.0
killall start-status.sh
~/.config/dwm/start-status.sh &
variety &
nm-applet &
blueman-applet &
xfsettingsd &
dunst &
picom &
fcitx &
redshiftgui &
syncthing &
#slstatus &
xautolock -time 15 -locker slock &

java
export _JAVA_AWT_WM_NONREPARENTING=1
export AWT_TOOLKIT=MToolkit
wmname LG3D &

xrandr --output HDMI-1 --right-of DP-1 --rotate right --auto
