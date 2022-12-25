#!/usr/bin/env bash

eth=`nmcli device | grep -E 'wifi|ethernet' | grep connected | awk 'NR==1{print $1}'`
RXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
TXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
sleep 1
RXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
TXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
#clear
RX=$[(${RXnext}-${RXpre})]
TX=$[(${TXnext}-${TXpre})]

if [[ $RX -lt 900 ]];then
    RX=$(printf "%3.0fB" ${RX})
elif [[ $RX -gt 900000 ]];then
    RX=$(printf "%3.2fM" $(echo $RX | awk '{print $1/1048576}'))
else
    RX=$(printf "%3.2fK" $(echo $RX | awk '{print $1/1024}'))
fi

if [[ $TX -lt 900 ]];then
    TX=$(printf "%3.0fB" ${TX})
elif [[ $TX -gt 900000 ]];then
    TX=$(printf "%3.2fM" $(echo $TX | awk '{print $1/1048576}'))
else
    TX=$(printf "%3.2fK" $(echo $TX | awk '{print $1/1024}'))
fi

# echo $eth
# echo ${RX}/${TX}
echo ${RX}
