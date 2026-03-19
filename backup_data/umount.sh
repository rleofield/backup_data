#!/bin/bash


# file: umount.sh
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
# exit 1, if umount or cryptsetup fails
# umount only from /mnt, not from /media

if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for mount backup disk"
        exit
fi


. ./cfg.working_folder
. ./src_log.sh


function umount_normal {
	local _label=$1
	local _mountdir=/mnt/$_label
	umount $_mountdir 2> /dev/null
	local _RET=$?
	if test $_RET -ne 0
	then
		dlog "'umount /mnt/$_label' fails"
		return 1
	fi
	mountpoint -q $_mountdir 
	_RET=$?
	if [[  $_RET -eq 0 ]]
	then
		dlog "disk '$_label' '$_mountdir' is already present'"
		test_normal_file $_mountdir/marker 
		# ret > 0, if ok
		if [ $? -gt 0  ]
		then
			dlog "${_mountdir}/marker exists"
			return 1
		fi
	fi
	dlog "umount  successful: '$_mountdir'"
	return 0
}


function umount_luks {
	local _label=$1
	umount_normal $_label
	local _RET=$?
	if [[  $_RET -eq 0 ]]
	then
		mapperlink="/dev/mapper/$_label"
		if [ -L "$mapperlink" ]
		then
			dlog "LUKS: 'cryptsetup luksClose $_label'"
			cryptsetup luksClose $_label
			_RET=$?
			if test $_RET -ne 0
			then
				dlog "LUKS: 'cryptsetup luksClose $_label' fails"
				return 1
			fi
		fi
		dlog "LUKS done"
		return 0
	fi
	dlog "LUKS umount fails"
	return 1
}


readonly label=$1
readonly lv_cc_logname="$label:umount"
mountdir=/mnt/$label
mountpoint -q $mountdir 
_RET=$?
if [[  ! $_RET -eq 0 ]]
then
	dlog "disk '$label' '$mountdir' is not mounted'"
	exit 0
fi


dlog "$mountdir"

# check, if no 'umount' line is present
_dev=$(blkid | grep crypt | grep "$label" | awk -F ':' '{print $1}')

if [[ -n $_dev ]]
then
	# maybe, this is LUKS?
	# check
	_RET=$(cryptsetup isLuks $_dev ) 
	if [[ $_RET -eq 0  ]]
	then
		mountdir=/mnt/$label
		dlog "is LUKS device"
		umount_luks $label
		_RET=$?
		if [[  $_RET -eq 0 ]]
		then
			exit 0
		fi
	fi
else
	_dev=$(blkid | grep "$label" | awk -F ':' '{print $1}')
	if [[ -n $_dev ]]
	then
		mountdir=/mnt/$label
		dlog "no LUKS device: 'umount  $mountdir'"
		umount_normal $label
		_RET=$?
		if [[  $_RET -eq 0 ]]
		then
			exit 0
		fi
	fi
fi
exit 1

# EOF

