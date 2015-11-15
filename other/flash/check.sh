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
	echo "Not a block device."
	exit 1
fi

if [ "$USER" != "root" ]; then
	echo "No permission."
	exit 1
fi

IMG_SIZE=`stat -c %s 2015-05-05-raspbian-wheezy.img`
echo "Image Size:	$IMG_SIZE BYTES"

DEV_SIZE=`blockdev --getsize64 "/dev/$1"`
echo "Device Size:	$DEV_SIZE BYTES"

if [ $IMG_SIZE -gt $DEV_SIZE ]; then
	echo "Image size is larger than device size."
	exit 1
fi

BS=1048576
IMG_CNT=$((IMG_SIZE / BS + (IMG_SIZE % BS > 0)))
echo "Reading:	$IMG_CNT MBYTES"

diff -q 2015-05-05-raspbian-wheezy.img <(dd if=/dev/$1 bs=1M count=$IMG_CNT iflag=direct 2> /dev/null)

CODE=$?
if [ $CODE -eq 0 ]; then
	echo "Successful match of $1!"
	udisksctl power-off -b /dev/$1
	if [ $? -eq 0 ]; then
		echo "Ejected $1!"
		exit 0
	else
		echo "Unable to Eject $1!"
		exit 1
	fi
else
	echo "Error match $1! Error code $CODE!"
	exit 1
fi
