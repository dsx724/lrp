#!/bin/bash
function getUSBPath {
	local USB_PATH_NEW
	USB_PATH_NEW=`readlink -f /sys/block/sd$1`
	USB_PATH_NEW="${USB_PATH_NEW%%/host*}"
	USB_PATH_NEW="${USB_PATH_NEW##*/}"
	USB_PATH_NEW="${USB_PATH_NEW%%:*}"
	echo -n "${USB_PATH_NEW##*-}"
}

function flash {
	for i in $@; do
		JOBS=`jobs -p | wc`
		while [ "`jobs -p | wc -l`" -gt 4 ]; do
			sleep 1;
		done
		sudo ./flash3.sh sd$i &
		sleep $((RANDOM % 3 + 1))
	done
}

declare -a a_a
i_a=0
declare -a a_b
i_b=0

for i in "$@"; do
	USB_PATH="`getUSBPath $i`"
	USB_PATH="${USB_PATH%%\.*}"
	if [ "$USB_PATH" = "1" ]; then
		a_a[i_a]=$i
		((i_a++))
	else
		a_b[i_b]=$i
		((i_b++))
	fi
done
flash ${a_a[*]} &
flash ${a_b[*]} &

exit
declare -a 
