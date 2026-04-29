#!/bin/bash


# file: umount.sh
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
# exit 1, if umount or cryptsetup fails
# umount only from /mnt, not from /media
# called in
# bk_loop.sh:1665:		./umount.sh  $lv_targetdisk


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

function tst_folder_exists {

	local name=$1
#	   exists   
	[ -e "$name" ] 
	local ret=$?
	return $ret
}


function umount_normal {
	local _label=$1
	local _mountdir=/mnt/$_label
	umount $_mountdir 2> /dev/null
	local _umount_RET=$?
	if test $_umount_RET -ne 0
	then
		dlog "'umount /mnt/$_label' fails"
		return 1
	fi
	mountpoint -q $_mountdir 
	local _mountpoint_RET=$?
	if [[  $_mountpoint_RET -eq 0 ]]
	then
		dlog "disk '$_label' '$_mountdir' is already present'"
		tst_folder_exists "$_mountdir/marker" 
		local _tst_ret=$? 
		# ret = 0, if ok
		if [ $_tst_ret -eq 0  ]
		then
			dlog "'${_mountdir}/marker' exists, disk not unmounted"
			return 1
		fi
	fi
	dlog "umount  successful: '$_mountdir'"
	return 0
}


function umount_luks {
	local _label=$1
	umount_normal $_label
	local _umount_RET=$?
	if [[  $_umount_RET -eq 0 ]]
	then
		local _mapperlink="/dev/mapper/$_label"
		if [ -L "$_mapperlink" ]
		then
			dlog "LUKS: 'cryptsetup luksClose $_label'"
			cryptsetup luksClose $_label
			local _crypt_RET=$?
			if test $_crypt_RET -ne 0
			then
				dlog "LUKS: 'cryptsetup luksClose $_label' fails"
				return 1
			fi
		fi
		dlog "LUKS close done"
		return 0
	fi
	dlog "LUKS umount fails"
	return 1
}


readonly label=$1
readonly lv_cc_logname="$label:umount"
mountdir=/mnt/$label
mountpoint -q $mountdir 
readonly mountpoint_RET=$?
if [[  ! $mountpoint_RET -eq 0 ]]
then
	dlog "disk '$label' '$mountdir' is not mounted'"
	exit 0
fi


dlog "$mountdir"

# check, if no 'umount' line is present
readonly crypt_device=$(blkid | grep crypt | grep "$label" | gawk -F ':' '{print $1}')

if [[ -n $crypt_device ]]
then
	# maybe, this is LUKS?
	# check
	cryptsetup isLuks $crypt_device  
	readonly luks_check_RET=$?
	if [[ $luks_check_RET -eq 0  ]]
	then
		mountdir=/mnt/$label
		dlog "is LUKS device"
		umount_luks $label
		_RET=$?
		if [[  $_RET -eq 0 ]]
		then
			exit 0
		fi
	exit 1
	fi
fi

readonly device=$(blkid | grep "$label" | gawk -F ':' '{print $1}')
if [[ -n $device ]]
then
	mountdir=/mnt/$label
	dlog "no LUKS device: 'umount  $mountdir'"
	umount_normal $label
	readonly umount_RET=$?
	if [[  $umount_RET -eq 0 ]]
	then
		exit 0
	fi
fi

exit 1

# EOF

