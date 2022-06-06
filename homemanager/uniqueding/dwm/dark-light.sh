ligth_theme_name=Materia-light-compact
dark_theme_name=Materia-dark-compact
ligth_icon_name=Tela
dark_icon_name=Tela-dark
ligth_cursor_name=Bibata-Modern-Classic
dark_cursor_name=Bibata-Modern-Ice
# dunst
front_num=$(grep -n "urgency_normal" ~/.config/dunst/dunstrc | cut -d ":" -f 1)
back_num=$(grep -n "urgency_critical" ~/.config/dunst/dunstrc | cut -d ":" -f 1)
light_bg=eeeeee
light_font=111111
dark_bg=333333
dark_font=bbbbbb

current=$(xfconf-query -c xsettings -p /Net/ThemeName)
if [ $current == $dark_theme_name ];then
	xfconf-query -c xsettings -p /Net/ThemeName -s $ligth_theme_name
	xfconf-query -c xsettings -p /Net/IconThemeName -s $ligth_icon_name
	xfconf-query -c xsettings -p /Gtk/CursorThemeName -s $ligth_cursor_name
	sed "${front_num},${back_num}s/${dark_bg}/${light_bg}/g" -i ~/.config/dunst/dunstrc
	sed "${front_num},${back_num}s/${dark_font}/${light_font}/g" -i ~/.config/dunst/dunstrc
	killall dunst && dunst & > /dev/null
else
	xfconf-query -c xsettings -p /Net/ThemeName -s $dark_theme_name
	xfconf-query -c xsettings -p /Net/IconThemeName -s $dark_icon_name
	xfconf-query -c xsettings -p /Gtk/CursorThemeName -s $dark_cursor_name
	sed "${front_num},${back_num}s/${light_bg}/${dark_bg}/g" -i ~/.config/dunst/dunstrc
	sed "${front_num},${back_num}s/${light_font}/${dark_font}/g" -i ~/.config/dunst/dunstrc
	killall dunst && dunst & > /dev/null
fi

