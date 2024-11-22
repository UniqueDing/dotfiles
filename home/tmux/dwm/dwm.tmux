setenv -g tmuxdwm_version 0.1.0
setenv -g killlast 1 # Toggle killing last pane
setenv -g mfact 50   # Main pane area factor
setenv -g dwm_path "$HOME/.config/tmux/dwm/dwm.sh"

set -g command-alias[100] newpane='run-shell "$dwm_path newpane"'
set -g command-alias[101] newpanecurdir='run-shell "$dwm_path newpanecurdir"'
set -g command-alias[102] killpane='run-shell "$dwm_path killpane"'
set -g command-alias[103] nextpane='run-shell "$dwm_path nextpane"'
set -g command-alias[104] prevpane='run-shell "$dwm_path prevpane"'
set -g command-alias[105] rotateccw='run-shell "$dwm_path rotateccw"'
set -g command-alias[106] rotatecw='run-shell "$dwm_path rotatecw"'
set -g command-alias[107] zoom='run-shell "$dwm_path zoom"'
set -g command-alias[108] layouttile='run-shell "$dwm_path layouttile"'
set -g command-alias[109] float='run-shell "$dwm_path float"'
set -g command-alias[110] incmfact='run-shell "$dwm_path incmfact"'
set -g command-alias[111] decmfact='run-shell "$dwm_path decmfact"'
set -g command-alias[112] joinpane1='run-shell "$dwm_path join 1"'
set -g command-alias[113] joinpane2='run-shell "$dwm_path join 2"'
set -g command-alias[114] joinpane3='run-shell "$dwm_path join 3"'
set -g command-alias[115] joinpane4='run-shell "$dwm_path join 4"'
set -g command-alias[116] joinpane5='run-shell "$dwm_path join 5"'
set -g command-alias[117] joinpane6='run-shell "$dwm_path join 6"'
set -g command-alias[118] joinpane7='run-shell "$dwm_path join 7"'
set -g command-alias[119] joinpane8='run-shell "$dwm_path join 8"'
set -g command-alias[120] joinpane9='run-shell "$dwm_path join 9"'
set-hook -g pane-exited 'run-shell "$dwm_path layouttile"'

# bind n newpane
bind w newpanecurdir
bind q killpane
bind n nextpane
bind e prevpane
bind , rotateccw
bind . rotatecw
bind Enter zoom
bind m layouttile
# bind Space float
bind l decmfact
bind u incmfact
bind !   joinpane1
bind @   joinpane2
bind "#" joinpane3
bind $   joinpane4
bind %   joinpane5
bind ^   joinpane6
bind &   joinpane7
bind *   joinpane8
bind (   joinpane9

