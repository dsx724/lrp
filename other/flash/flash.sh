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

IMG_FILE="2015-05-05-raspbian-wheezy.img"

IMG_SIZE=`stat -c %s "$IMG_FILE"`
echo "$1: Image Size:	$IMG_SIZE BYTES"

DEV_SIZE=`blockdev --getsize64 "/dev/$1"`
echo "$1: Device Size:	$DEV_SIZE BYTES"

if [ $IMG_SIZE -gt $DEV_SIZE ]; then
	echo "$1: Image size is larger than device size."
	exit 1
fi

BS=1048576
IMG_CNT=$((IMG_SIZE / BS + (IMG_SIZE % BS > 0)))
echo "$1: Reading:  $IMG_CNT MBYTES"

diff -q 2015-05-05-raspbian-wheezy.img <(dd if=/dev/$1 bs=1M count=$IMG_CNT iflag=direct 2> /dev/null)

if [ $? -ne 0 ]; then
	dd if=2015-05-05-raspbian-wheezy.img of=/dev/$1 bs=1M
	CODE=$?
	if [ $CODE -ne 0 ]; then
		echo "$1: Error flashing! Error code $CODE!"
		exit 1
	fi
	diff -q 2015-05-05-raspbian-wheezy.img <(dd if=/dev/$1 bs=1M count=$IMG_CNT iflag=direct 2> /dev/null)

	CODE=$?
	if [ $CODE -eq 0 ]; then
		echo "$1: Successful flash!"
		#udisksctl power-off -b /dev/$1
		#if [ $? -eq 0 ]; then
		#	echo "$1: Successful eject!"
		#	exit 0
		#else
		#	echo "$1: Unable to eject!"
		#	exit 1
		#fi
	else
		echo "$1: Error on verification pass! Error code $CODE!"
		exit 1
	fi
else
	echo "$1: Device matches: No flash necessary!"
	#udisksctl power-off -b /dev/$1
	#if [ $? -eq 0 ]; then
	#	echo "$1: Successful eject!"
	#	exit 0
	#else
	#	echo "$1: Unable to eject!"
	#	exit 1
	#fi
	#exit 0
fi
