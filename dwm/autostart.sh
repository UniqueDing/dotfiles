#! /bin/bash
# sed 's/breeze\b/bloom/' -i /home/uniqueding/.config/gtk-3.0/settings.ini
# sed 's/breeze\b/bloom/' -i /home/uniqueding/.gtkrc-2.0
killall status.sh
~/.config/dwm/status.sh &
variety &
nm-applet &
blueman-applet &
xfsettingsd &
dunst &
picom &
fcitx5 &
redshift-gtk &
syncthing &
#slstatus &
xautolock -time 15 -locker slock &
sleep 2
fcitx5-remote -c

# java
export _JAVA_AWT_WM_NONREPARENTING=1
export AWT_TOOLKIT=MToolkit
wmname LG3D &

