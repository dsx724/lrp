#!/bin/bash

if [ -z "$1" ]; then
	echo "Please enter a device name."
	exit 1
fi

if [ "$1" = "sda" ]; then
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	exit 1
fi
if [ "$1" = "sdb" ]; then
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	exit 1
fi

if [ ! -b "/dev/$1" ]; then
	echo "$1: Not a block device."
	exit 1
fi

if [ "$USER" != "root" ]; then
	echo "$1: No permission."
	exit 1
fi

IMG_FILE="2015-09-24-raspbian-jessie.img"

IMG_SIZE_B=`stat -c %s "$IMG_FILE"`
echo "$1:	Image Size:	$IMG_SIZE_B BYTES"

DEV_SIZE_B=`blockdev --getsize64 "/dev/$1"`
if [ $? -ne 0 ]; then
	echo "$1:	Unable to get blocksize."
	exit 1
fi
echo "$1:	Device Size:	$DEV_SIZE_B BYTES"

if [ $IMG_SIZE_B -gt $DEV_SIZE_B ]; then
	echo "$1:	Image size is larger than device size."
	exit 1
fi

function checkUSBPath {
	local USB_PATH_NEW
	USB_PATH_NEW=`readlink -f /sys/block/$1`
	USB_PATH_NEW="${USB_PATH_NEW%%/host*}"
	USB_PATH_NEW="${USB_PATH_NEW##*/}"
	if [ -z "$USB_PATH" ]; then
		USB_PATH="$USB_PATH_NEW"
	elif [ "$USB_PATH_NEW" != "$USB_PATH" ]; then
		echo "=====USB DEVICE CHANGED FROM $USB_PATH TO $USB_PATH_NEW====="
		exit 1
	fi
}

B_PER_MB=1048576
BLK_MB=3
BLK_B=$((BLK_MB * B_PER_MB))
IMG_BLK_CNT=$((IMG_SIZE_B / BLK_B + (IMG_SIZE_B % BLK_B > 0)))
BLOCKS_FIXED=0
BLOCKS_FIXED_AGAIN=0
BLOCKS_FIXED_CONT=0
BLOCKS_FIXED_CONT_LIMIT=3
BLOCKS_FIXED_CONT_LIMIT_REACHED=0
echo "$1:	Reading:	$IMG_BLK_CNT BLOCKS OF $BLK_MB MBYTES"
echo "0" > /sys/block/$1/queue/read_ahead_kb
echo "2048" > /sys/block/$1/device/max_sectors

if [ "$DEBUG" = "1" ]; then
	set -x
fi

cmp -s -n $BLK_B $IMG_FILE /dev/$1

if [ $? -ne 0 ]; then
	checkUSBPath
	echo "$1:	First block does not match!"
	dd if=$IMG_FILE of=/dev/$1 bs=$BLK_B oflag=direct 2> /dev/null
fi
for i in `seq 0 $IMG_BLK_CNT`; do
	if [ $i -eq $IMG_BLK_CNT ]; then
		cmp -s $IMG_FILE <(dd if=/dev/$1 bs=$BLK_B count=$IMG_BLK_CNT iflag=direct 2> /dev/null)
		if [ $? -ne 0 ]; then
			checkUSBPath
			echo "$1:	CRITICAL!!! File does not match after check and rewrite! $BLOCKS_FIXED"
			exit 1
		fi
		echo "$1:	File matches! $BLOCKS_FIXED"
		exit 0
	fi
	cmp -s <(dd if=$IMG_FILE bs=$BLK_B skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=$BLK_B skip=$i count=1 iflag=direct 2> /dev/null)
	if [ $? -ne 0 ]; then
		checkUSBPath
		((BLOCKS_FIXED_CONT++))
		if [ "$BLOCKS_FIXED_CONT" -gt "$BLOCKS_FIXED_CONT_LIMIT" ]; then
			((BLOCKS_FIXED_CONT_LIMIT_REACHED++))
			echo "$1:	Reached continuous fixed block limit at $i. Flashing from $i to $IMG_BLK_CNT!"
			dd if=$IMG_FILE of=/dev/$1 bs=$BLK_B skip=$i seek=$i count=$((IMG_BLK_CNT - i)) oflag=direct 2> /dev/null
			if [ $? -ne 0 ]; then
				checkUSBPath
				echo "$1:	Flashing from $i to $IMG_BLK_CNT failed!"
			fi
			cmp -s <(dd if=$IMG_FILE bs=$BLK_B skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=$BLK_B skip=$i count=1 iflag=direct 2> /dev/null)
		else
			echo "$1:	Mismatch at block $i, $((i * BLK_MB)) MB."
			dd if=$IMG_FILE of=/dev/$1 bs=$BLK_B skip=$i seek=$i count=1 oflag=direct 2> /dev/null && cmp -s <(dd if=$IMG_FILE bs=$BLK_B skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=$BLK_B skip=$i count=1 iflag=direct 2> /dev/null)
		fi
		if [ $? -ne 0 ]; then
			checkUSBPath
			echo "$1:	Unable to fix block $i!"
			dd if=$IMG_FILE of=/dev/$1 bs=$BLK_B skip=$i seek=$i count=1 oflag=direct 2> /dev/null && cmp -s <(dd if=$IMG_FILE bs=$BLK_B skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=$BLK_B skip=$i count=1 iflag=direct 2> /dev/null)
			if [ $? -ne 0 ]; then
				checkUSBPath
				echo "$1:	Unable to fix block $i again!"
				exit 1
			fi
		fi
		((BLOCKS_FIXED++))
	else
		BLOCKS_FIXED_CONT=0
	fi
done
