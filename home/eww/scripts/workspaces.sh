#!/usr/bin/env bash

#set -x

workspace_list=(0 0 0 0 0 0 0 0 0 0 0)
last_workspace=0
now_workspace=0

function setLast {
    if [[ $now_workspace == $1 ]];then
        return
    fi

    last_workspace=$now_workspace
    echo $last_workspace > /tmp/lastworkspace
    now_workspace=$1
}

function show {
    json_str="["
    for i in ${!workspace_list[@]}
    do
        if [[ $i == 0 ]];then
            continue
        fi

        json_str+="{\"active\":"
        if [[ ${workspace_list[i]} == 0 ]];then
            json_str+="\"disable\","
        elif [[ $1 == $i ]];then
            json_str+="\"active\","
        else
            json_str+="\"inactive\","
        fi
        json_str+="\"id\":"$i"},"
    done
    json_str=${json_str%,*}"]"
    echo $json_str
}

function handle {
    num=${1##*>}
    case ${1%%>*} in
    "workspace")
        setLast $num
        show $num
        ;;
    "createworkspace")
        setLast $num
        workspace_list[$num]=1
        show $num
        ;;
    "destroyworkspace")
        workspace_list[$num]=0
        show $now_workspace
        ;;
    esac
  
}

function init {
    list=`hyprctl workspaces | grep ID | sed 's/()/(1)/g' | awk 'NR>1{print $1}' RS='(' FS=')'`
    for i in ${list[*]}
    do
        workspace_list[$i]=1
    done
    num=`hyprctl monitors | grep active | sed 's/()/(1)/g' | awk 'NR>1{print $1}' RS='(' FS=')'`
    show $num

    # echo ${workspace_list[*]}
}

function status {
    socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock -| while read line; do 
    # echo $line
    handle $line; 
    done
}

function last {
    hyprctl dispatch workspace `cat /tmp/lastworkspace`
}

case $1 in
"status")
    init
    status
    ;;
"last")
    last
    ;;
esac

