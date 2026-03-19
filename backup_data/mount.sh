#!/bin/bash


# file: mount.sh
# bk_version  26.01.1

# Copyright (C) 2017-2026 Richard Albrecht
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


# which will exit your script if you try to use an uninitialised variable.
set -u

# exit 0, if ok
# exit 1, if mount or cryptsetup fails


if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for mount backup disk"
        exit
fi

. ./cfg.working_folder
. ./src_log.sh


# call: ./mount.sh $LABEL

function mount_luks { 
	local _label=$1
	local _mountdir=/mnt/$_label
	# look in folder /root/luks/label_keyfile
	LUKSKEYFILE=/root/luks/${_label}_keyfile
	if test ! -f $LUKSKEYFILE
	then
		dlog "LUKS keyfile not found: '$LUKSKEYFILE'"
		# look in folder /root/luks/keyfile_label
		LUKSKEYFILE=/root/luks/keyfile_${_label}
		if test ! -f $LUKSKEYFILE
		then
			dlog "LUKS keyfile not found: '$LUKSKEYFILE'"
			# look in folder /root/keyfile_label
			LUKSKEYFILE=/root/keyfile_${_label}
			if test ! -f $LUKSKEYFILE
			then
				dlog "LUKS keyfile not found: '$LUKSKEYFILE'"
				dlog "LUKS =="
				exit 1
			fi
		fi
	fi
	# KEYFILE found
	UUID=`grep -v '#' uuid.txt | grep -w ${_label} | awk '{print $2}'`
	DEVICE="/dev/disk/by-uuid/${UUID}"
	dlog "LUKS device: $DEVICE"

	# test, if LUKS Device is open
	# test against block device in /dev/mapper
	if test ! -b /dev/mapper/$_label
	then
		dlog "LUKS:  cryptsetup luksOpen --key-file $LUKSKEYFILE $DEVICE $_label"
		cryptsetup luksOpen --key-file $LUKSKEYFILE $DEVICE $_label
		local _RET=$?
	#       RETURN CODES
	#              Cryptsetup returns 0 on success and a non-zero value on error.
	#              Error codes are: 
	#                1 wrong parameters, 
	#                2 no permission (bad passphrase), 
	#                3 out of memory, 
	#                4 wrong device specified, 
	#                5 device already exists or device is busy.
		if test $_RET -ne 0
		then
			dlog "LUKS device could not be opened, label '$_label'"
			exit 1
		fi
	else
		dlog "LUKS Device '/dev/mapper/$_label' is already open"
	fi

	mount /dev/mapper/$_label $_mountdir
	local mountRET=$?
	if test $mountRET -ne 0
	then
		dlog "LUKS device '/dev/mapper/$_label' could not be mounted"
		exit 1
	fi
	mountpoint -q $_mountdir 
	local _RET=$?
	if [[  $_RET -eq 0 ]]
	then
		dlog "disk '$_label' is mounted at '$_mountdir'"
		test_normal_file $_mountdir/marker 
		# ret > 0, if ok
		if [ $? -gt 0  ]
		then
			dlog "${_mountdir}/marker exists"
			exit 0
		fi
		dlog "${_mountdir}/marker doesn't exist"
		exit 1
	fi
	exit 1
}


function mount_normal {
	local _label=$1
	local _mountdir=/mnt/$_label
	dlog "mount normal, is not a LUKS device"
	dlog "'mount -L $_label $_mountdir'"
	mount -L $_label $_mountdir
	RET=$?
	if test $RET -ne 0
	then
		dlog "device '$_label' could not be mounted"
		exit 1
	fi
	mountpoint -q $_mountdir 
	local _RET=$?
	if [[  $_RET -eq 0 ]]
	then
		dlog "disk '$_label' '$_mountdir' is mounted'"
		test_normal_file $_mountdir/marker 
		# ret > 0, if ok
		if [ $? -gt 0  ]
		then
			dlog "${_mountdir}/marker exists"
			exit 0
		fi
		dlog "${_mountdir}/marker doesn't exist"
		exit 1
	fi
	exit 1
}


label=$1
#lv_cc_logname="mount:$label"
readonly lv_cc_logname="$label:mount"
readonly mountdir=/mnt/$label
mountpoint -q $mountdir 
_RET=$?
if [[  $_RET -eq 0 ]]
then
	dlog "disk '$label' '$mountdir' is mounted'"
	exit 0
fi

#dlog "$mountdir"
_dev=$(blkid | grep crypt | grep "$label" | awk -F ':' '{print $1}')
# -n    string is not null
if [[ -n $_dev ]]
then
	# maybe, this is LUKS?
	# check
	_RET=$(cryptsetup isLuks $_dev ) 
	if [[ $_RET -eq 0  ]]
	then
		mount_luks $label
		exit 0
	fi
else
	_dev=$(blkid | grep "$label" | awk -F ':' '{print $1}')
	if [[ -n $_dev ]]
	then
		mount_normal $label
		exit 0
	fi
fi
dlog "label: '$label'  not found"
exit 1


# EOF

