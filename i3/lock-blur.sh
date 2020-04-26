tmpimg=/tmp/lock.png

scrot $tmpimg
convert $tmpimg -blur 10x5 $tmpimg
i3lock -i $tmpimg
rm $tmpimg
