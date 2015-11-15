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

IMG_SIZE=`stat -c %s "$IMG_FILE"`
echo "$1:	Image Size:	$IMG_SIZE BYTES"

DEV_SIZE=`blockdev --getsize64 "/dev/$1"`
if [ $? -ne 0 ]; then
	echo "$1:	Unable to get blocksize."
	exit 1
fi
echo "$1:	Device Size:	$DEV_SIZE BYTES"

if [ $IMG_SIZE -gt $DEV_SIZE ]; then
	echo "$1:	Image size is larger than device size."
	exit 1
fi

BS=1048576
IMG_CNT=$((IMG_SIZE / BS + (IMG_SIZE % BS > 0)))
BLOCKS_FIXED=0
BLOCKS_FIXED_AGAIN=0
echo "$1:	Reading:	$IMG_CNT MBYTES"
echo "0" > /sys/block/$1/queue/read_ahead_kb
#set -x
cmp -s -n $((BS*100)) $IMG_FILE /dev/$1
if [ $? -ne 0 ]; then
	echo "$1:	First 100MB does not match!"
	dd if=$IMG_FILE of=/dev/$1 bs=1M oflag=direct 2> /dev/null
fi
for i in `seq 0 $IMG_CNT`; do
	if [ $i -eq $IMG_CNT ]; then
		cmp -s $IMG_FILE <(dd if=/dev/$1 bs=1M count=$IMG_CNT iflag=direct 2> /dev/null)
		if [ $? -ne 0 ]; then
			echo "$1:	CRITICAL!!! File does not match after check and rewrite! $BLOCKS_FIXED"
			exit 1
		fi
		echo "$1:	File matches! $BLOCKS_FIXED"
		exit 0
	fi
	cmp -s <(dd if=$IMG_FILE bs=1M skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=1M skip=$i count=1 iflag=direct 2> /dev/null)
	if [ $? -ne 0 ]; then
		echo -e -n "\r$1:	Mismatch at $i MB."
		dd if=$IMG_FILE of=/dev/$1 bs=1M skip=$i seek=$i count=1 oflag=direct 2> /dev/null && cmp -s <(dd if=$IMG_FILE bs=1M skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=1M skip=$i count=1 iflag=direct 2> /dev/null)
		if [ $? -ne 0 ]; then
			echo "$1:	Unable to fix block $i!"
			dd if=$IMG_FILE of=/dev/$1 bs=1M skip=$i seek=$i count=1 oflag=direct 2> /dev/null && cmp -s <(dd if=$IMG_FILE bs=1M skip=$i count=1 2> /dev/null) <(dd if=/dev/$1 bs=1M skip=$i count=1 iflag=direct 2> /dev/null)
			if [ $? -ne 0 ]; then
				echo "$1:	Unable to fix block $i again!"
				exit 1
			fi
			((BLOCKS_FIXED_AGAIN++))
		fi
		((BLOCKS_FIXED++))
	fi
done
