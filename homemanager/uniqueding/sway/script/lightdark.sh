#!/bin/bash

LIGHT_GTK=Qogir-Light
LIGHT_ICON=Qogir
DARK_GTK=Qogir-Dark
DARK_ICON=Qogir-dark

FONT='WenQuanYi Zen Hei 11'
CURSOR=Adwaita

gnome_schema=org.gnome.desktop.interface

CURRENT_THEME=`gsettings get $gnome_schema gtk-theme | tr -d "'"`

_mako()
{
    killall mako
    if [[ $1 == "light" ]];then
        nohup mako -c $HOME/.config/mako/config-light > /dev/null 2>&1 &
    elif [[ $1 == "dark" ]];then
        nohup mako -c $HOME/.config/mako/config-dark > /dev/null 2>&1 &
    fi
}

_wob()
{
    WOBSOCK=$XDG_RUNTIME_DIR/wob.sock
    WOBLIGHT="--bar-color #EEEEEEF5 --background-color #333333F5 --overflow-bar-color #BF616AF5 --overflow-background-color #EEEEEEF5"
    WOBDARK="--bar-color #808080F5 --background-color #333333F5 --overflow-bar-color #BF616AF5 --overflow-background-color #808080F5"
    killall wob
    if [[ $1 == "light" ]];then
        rm -f $WOBSOCK && mkfifo $WOBSOCK
        tail -f $WOBSOCK | nohup wob -a top -a right -b 0 -M 10 -p 0 $WOBLIGHT > /dev/null 2>&1 &
    elif [[ $1 == "dark" ]];then
        rm -f $WOBSOCK && mkfifo $WOBSOCK
        tail -f $WOBSOCK | nohup wob -a top -a right -b 0 -M 10 -p 0 $WOBDARK > /dev/null 2>&1 &
    fi
}

_waybar_dock()
{
    DOCK="$HOME/.config/waybar/config-dock"
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        nohup waybar -c $DOCK -s $HOME/.config/waybar/style-light.css > /dev/null 2>&1 &
    elif [[ $CURRENT_THEME == $DARK_GTK ]];then
        nohup waybar -c $DOCK -s $HOME/.config/waybar/style-dark.css > /dev/null 2>&1 &
    fi
}

_waybar()
{
    DOCK="$HOME/.config/waybar/config-dock"
    STATUS=$(ps -ef | grep "$DOCK" | grep -v grep | wc -l)
    killall waybar
    if [[ $STATUS == 0 ]];then
        if [[ $1 == "light" ]];then
            nohup waybar -s $HOME/.config/waybar/style-light.css > /dev/null 2>&1 &
        elif [[ $1 == "dark" ]];then
            nohup waybar -s $HOME/.config/waybar/style-dark.css > /dev/null 2>&1 &
        fi
    else
        if [[ $1 == "light" ]];then
            nohup waybar -c $DOCK -s $HOME/.config/waybar/style-light.css > /dev/null 2>&1 &
            nohup waybar -s $HOME/.config/waybar/style-light.css > /dev/null 2>&1 &
        elif [[ $1 == "dark" ]];then
            nohup waybar -c $DOCK -s $HOME/.config/waybar/style-dark.css > /dev/null 2>&1 &
            nohup waybar -s $HOME/.config/waybar/style-dark.css > /dev/null 2>&1 &
        fi
    fi
}

if [[ $1 == "status" ]];then
    while true
    do
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        echo "{\"alt\":\"light\"}"
    else
        echo "{\"alt\":\"dark\"}"
    fi
    sleep 0.5
    done

elif [[ $1 == "toggle" ]];then
    gsettings set $gnome_schema cursor-theme $CURSOR
    gsettings set $gnome_schema font-name "$FONT"
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        gsettings set $gnome_schema gtk-theme $DARK_GTK
        gsettings set $gnome_schema icon-theme $DARK_ICON

        $(_waybar dark)
        $(_mako dark)
        $(_wob dark)

    else
        gsettings set $gnome_schema gtk-theme $LIGHT_GTK
        gsettings set $gnome_schema icon-theme $LIGHT_ICON

        $(_waybar light)
        $(_mako light)
        $(_wob light)

    fi

elif [[ $1 == "waybar" ]];then
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        $(_waybar light)
    else
        $(_waybar dark)
    fi

elif [[ $1 == "waybar-dock" ]];then
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        $(_waybar_dock light)
    else
        $(_waybar_dock dark)
    fi

elif [[ $1 == "mako" ]];then
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        $(_mako light)
    else
        $(_mako dark)
    fi

elif [[ $1 == "wob" ]];then
    if [[ $CURRENT_THEME == $LIGHT_GTK ]];then
        $(_wob light)
    else
        $(_wob dark)
    fi
fi

