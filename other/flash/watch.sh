#!/bin/bash
watch -n 1 "lsblk -d | grep ^sd | grep -v ^sda | grep -v ^sdb | grep -n ^sd"
