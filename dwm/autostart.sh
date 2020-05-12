#! /bin/bash
sed 's/breeze\b/bloom/' -i /home/uniqueding/.config/gtk-3.0/settings.ini
sed 's/breeze\b/bloom/' -i /home/uniqueding/.gtkrc-2.0
dunst &
picom &
fcitx &
nm-applet &
variety &
blueman-applet &
redshift-gtk &
#slstatus &
xautolock -time 15 -locker slock &
~/.config/dwm/status.sh &

# java
export _JAVA_AWT_WM_NONREPARENTING=1
export AWT_TOOLKIT=MToolkit
wmname LG3D &

