#!/bin/bash


# file: mount.sh
# bk_version 24.08.1

# Copyright (C) 2017-2024 Richard Albrecht
# www.rleofield.de

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#------------------------------------------------------------------------------


if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for mount backup disk"
        exit
fi

. ./cfg.working_folder
. ./src_log.sh


# call: ./mount.sh $LABEL

readonly targetdisk=$1

label=$1
#lv_cc_logname="mount:$label"
readonly lv_cc_logname="$label:mount"
mountdir=/mnt/$label
merr=""

if [[ "$label" == *luks ]]
then
	dlog "mount luks device"
	LUKSKEYFILE=/root/luks/${label}_keyfile
	if test ! -f $LUKSKEYFILE
	then
		LUKSKEYFILE=/root/luks/keyfile_${label}
		if test ! -f $LUKSKEYFILE
		then
			LUKSKEYFILE=/root/keyfile_${label}
			if test ! -f $LUKSKEYFILE
			then
				dlog "LUKS =="
				dlog "LUKS keyfile not found: '$LUKSKEYFILE'"
				dlog "LUKS =="
				exit 1
			fi
		fi
	fi
	UUID=`grep -v '#' uuid.txt | grep -w ${label} | awk '{print $2}'`
	DEVICE="/dev/disk/by-uuid/${UUID}"
	dlog "LUKS device: $DEVICE"
	# test, if LUKS Device is open
	# test against block device
	if test ! -b /dev/mapper/$label
	then
		dlog "LUKS:  cryptsetup luksOpen --key-file $LUKSKEYFILE $DEVICE $label"
		cryptsetup luksOpen --key-file $LUKSKEYFILE $DEVICE $label
	#       RETURN CODES
	#              Cryptsetup returns 0 on success and a non-zero value on error.
	#              Error codes are: 
	#                1 wrong parameters, 
	#                2 no permission (bad passphrase), 
	#                3 out of memory, 
	#                4 wrong device specified, 
	#                5 device already exists or device is busy.

		RET=$?
		if test $RET -ne 0
		then
			dlog "LUKS Device couldn't be opened"
			exit 1
		fi
	else
		dlog "LUKS Device /dev/mapper/$label is already open"
	fi

	mount /dev/mapper/$label $mountdir
	RET=$?
	if test $RET -ne 0
	then
		dlog "LUKS Device couldn't be mounted"
		exit 1
	fi
else
	dlog "mount normal, no luks device"
	dlog "'mount -L $label $mountdir'"
	mount -L $label $mountdir
	RET=$?
	if test $RET -ne 0
	then
		dlog "Device couldn't be mounted"
		exit 1
	fi
fi


exit 0

# EOF

