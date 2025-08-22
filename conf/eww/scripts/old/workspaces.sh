#!/bin/bash
#set -x

workspaces() {
    ./scripts/old/workspaces.lua
}

workspaces

tail -f /tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log | grep --line-buffered "Changed to workspace" | while read -r; do 
    workspaces
done


