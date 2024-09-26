#!/usr/bin/env bash

# 0 * * * * ~/.config/sway/bg.sh
set -e

BASE_URL="https://bing.biturl.top/?resolution=3840&format=json&index=0&mkt=zh-CN"
PIC_DIR="$HOME/Pictures/Bing"

mkdir -p $PIC_DIR
CONTEXT=`curl -s $BASE_URL`

PIC_URL=`echo $CONTEXT | jq ".url" --raw-output`
PIC_NAME=${PIC_URL#*=}
echo $PIC_NAME
PIC_COPYRIGHT=`echo $CONTEXT | jq ".copyright" --raw-output`

curl -o ${PIC_DIR}/${PIC_NAME} $PIC_URL

C_PIC_NAME=${PIC_NAME%.*}_.${PIC_NAME##*.}
# convert ${PIC_DIR}/${PIC_NAME} -gravity southeast -fill white -pointsize 48 -font /usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc -draw "text 100,30 '$PIC_COPYRIGHT'" ${PIC_DIR}/${C_PIC_NAME}

# cp -f ${PIC_DIR}/${C_PIC_NAME} ${PIC_DIR}/now
cp -f ${PIC_DIR}/${PIC_NAME} ${PIC_DIR}/now

swaymsg "output * bg ${PIC_DIR}/now fill"
