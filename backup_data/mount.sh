#!/bin/bash


# file: mount.sh
# bk_version  26.05.1

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



# prefixes of variables in backup:
# bv_*  - global vars, all files
# lv_*  - local vars, global in file
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_


# which will exit your script if you try to use an uninitialised variable.
set -u

# exit 0, if ok
# exit 1, if mount or cryptsetup fails

# called in
# bk_loop.sh:784:		./mount.sh "$lv_targetdisk" 



if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for mount backup disk"
        exit
fi

. ./cfg.working_folder
. ./src_filenames.sh
. ./src_log.sh


# call: ./mount.sh $LABEL
# normal file test
# -e     True if exists.
#        0 if exists

function tst_folder_exists {
	local name=$1
	# exists···
	[ -e "$name" ]
	local ret=$?
	return $ret

}


function mount_normal {
	local _label=$disklabel
	local _mountdir=/mnt/$_label
	dlog "'mount -L $_label $_mountdir'"
	mount -L $_label $_mountdir
	local _mount_RET=$?
	if test $_mount_RET -ne 0
	then
		dlog "device '$_label' could not be mounted"
		exit 1
	fi
	mountpoint -q $_mountdir 
	local _mountpoint_RET=$?
	if [[  $_mountpoint_RET -eq 0 ]]
	then
		tst_folder_exists $_mountdir/marker 
		_tst_ret=$?
		# ret = 0, if ok
		if [ $_tst_ret -eq 0  ]
		then
			dlog "disk '$_label' is mounted at '$_mountdir'"
			exit 0
		fi
		dlog "disk '$_label' isn't correctly mounted, '${_mountdir}/marker' doesn't exist"
		exit 1
	fi
	exit 1
}


function mount_luks { 
	local _label=$disklabel
	local _mountdir=/mnt/$_label
	# look for file '/root/luks/label_keyfile'
	local _lukskeyfile=/root/luks/${_label}_keyfile
	if test ! -f $_lukskeyfile
	then
		dlog "LUKS keyfile not found: '$_lukskeyfile'"
		# look for file 'folder /root/luks/keyfile_label'
		_lukskeyfile=/root/luks/keyfile_${_label}
		if test ! -f $_lukskeyfile
		then
#			dlog "LUKS keyfile not found: '$_lukskeyfile'"
			dlog "1: LUKS keyfile for '$_label' not found"
			# look for file '/root/keyfile_label'
			_lukskeyfile=/root/keyfile_${_label}
			if test ! -f $_lukskeyfile
			then
				dlog "2: LUKS keyfile for '$_label' not found"
				exit 1
			fi
		fi
	fi
	# KEYFILE found
	local _uuid=`grep -v '#' uuid.txt | grep -w ${_label} | gawk '{print $2}'`
	local _device="/dev/disk/by-uuid/${_uuid}"
	dlog "LUKS device: $_device"

	# test, if LUKS Device is open
	# test against block device in /dev/mapper
	# test -b
	if test ! -b /dev/mapper/$_label
	then
#		dlog "LUKS:  cryptsetup luksOpen --key-file $_lukskeyfile $_device $_label"
		dlog "LUKS:  cryptsetup luksOpen '$_label'"
		cryptsetup luksOpen --key-file $_lukskeyfile $_device $_label
		local _crypt_RET=$?
	#       RETURN CODES
	#              Cryptsetup returns 0 on success and a non-zero value on error.
	#              Error codes are: 
	#                1 wrong parameters, 
	#                2 no permission (bad passphrase), 
	#                3 out of memory, 
	#                4 wrong device specified, 
	#                5 device already exists or device is busy.
		if test $_crypt_RET -ne 0
		then
			dlog "LUKS device couldn't be opened, label '$_label', ret: $_crypt_RET"
			exit 1
		fi
	else
		dlog "LUKS Device '$_label' is already open"
	fi
	mount_normal

}


readonly disklabel=$1
readonly lv_cc_logname="$disklabel:mount"
readonly mountdir=/mnt/$disklabel
mountpoint -q $mountdir 
readonly mountpoint_RET=$?
if [[  $mountpoint_RET -eq 0 ]]
then
	dlog "disk '$disklabel' is mounted at '$mountdir'"
	exit 0
fi

readonly _device_crypt=$(blkid | grep crypt | grep "$disklabel" | gawk -F ':' '{print $1}')
# -n    string is not null
if [[ -n $_device_crypt ]]
then
	# maybe, this is LUKS?
	# check
	cryptsetup isLuks $_device_crypt  
	_luks_check_RET=$?
	if [[ $_luks_check_RET -eq 0  ]]
	then
		mount_luks 
		exit 0
	fi
	dlog "label: '$disklabel'  not found"
	exit 1
fi

readonly _device=$(blkid | grep "$disklabel" | gawk -F ':' '{print $1}')
if [[ -n $_device ]]
# -n    string is not null
then
	mount_normal 
	exit 0
fi

dlog "label: '$disklabel'  not found"
exit 1


# EOF

