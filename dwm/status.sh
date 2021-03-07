#!/bin/bash
show(){
	while :
	do
		str=$(printf " %s C%2s M%2s T%2s F%2s V%2s L%2s B%3s $(date '+%m/%d %H:%M')" $(netspeed wlp2s0) $(cpu) $(memory) $(temperature) $(disk /home) $(volume) $(backlight) $(battery))
		xsetroot -name "$str"
		# sleep 0.1
	done
}

volume(){
	volumeStatus=$(amixer get Master | awk NR==6'{print $6}' | tr -d [%])
	if [ "${volumeStatus}" == "on" ]
	then
		volumeSize=$(amixer get Master | awk 'NR==6{printf "%s",$5}' | tr -d [%])
	else
		volumeSize=$(amixer get Master | awk 'NR==6{printf "-%s",$5}' | tr -d [%])
	fi
	check $volumeSize
}

backlight(){
	backlightSize=$(xbacklight | awk -F '.' '{print $1}')
	check $backlightSize
}

cpu(){
	cpuRate=$(top -b -n1 | fgrep "Cpu(s)" | tail -1 | awk -F'id,' '{split($1, vs, ","); v=vs[length(vs)]; sub(/\s+/, "", v);sub(/\s+/, "", v); printf "%d", 100-v;}')
	check $cpuRate
}

memory(){
	memoryRate=$(free -m | awk -F '[ :]+' 'NR==2{printf "%d", ($2-$7)/$2*100}')
	check $memoryRate
}

disk(){
	diskRate=$(df | grep $1 | awk 'NR==1{printf $5}' | tr -d [%])
	check $diskRate
}

temperature(){
	temperatureSize=$(expr $(cat /sys/class/thermal/thermal_zone0/temp) / 1000)
	check $temperatureSize
}

iostatus(){
	iostatRate=$(iostat -d -x 1 1 | grep nvme0n1 | awk 'NR==1{printf "%d", $23}' )
	check $iostatRate
}

battery(){
	batteryRate=$(acpi -b | awk -F'[: ,]+' 'NR==1{print $4}'|tr -d [%])
	batteryStatus=$(acpi -b | awk -F'[: ,]+' 'NR==1{print $3}')
	if [ "$batteryStatus" == "Discharging" ]
	then 
		batteryStatus="-"
        if [ $batteryRate -lt 5 ]
        then
            notify-send "low power"
        fi
	elif [ "$batteryStatus" == "Charging" ]
	then
		batteryStatus="+"
	else
		batteryStatus="="
	fi
	check $batteryRate$batteryStatus
}

netspeed(){
	eth=$1
	RXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
	TXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
	sleep 1
	RXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
	TXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
	#clear
	RX=$[(${RXnext}-${RXpre})]
	TX=$[(${TXnext}-${TXpre})]

	if [[ $RX -lt 1024 ]];then
		RX=$(printf "%3.2fB" ${RX})
	elif [[ $RX -gt 1048576 ]];then
		RX=$(printf "%3.2fM" $(echo $RX | awk '{print $1/1048576}'))
	else
		RX=$(printf "%3.2fK" $(echo $RX | awk '{print $1/1024}'))
	fi

	if [[ $TX -lt 1024 ]];then
		TX=$(printf "%3.2fB" ${TX})
	elif [[ $TX -gt 1048576 ]];then
		TX=$(printf "%3.2fM" $(echo $TX | awk '{print $1/1048576}'))
	else
		TX=$(printf "%3.2fK" $(echo $TX | awk '{print $1/1024}'))
	fi

	check ${RX}/${TX}
}

check(){
	if [ "$1" == "" ]
	then
		echo NA
	else
		echo $1
	fi
}
	
show
