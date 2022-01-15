#!/bin/bash


# file: umount.sh
# bk_version 22.01.1

# Copyright (C) 2021 Richard Albrecht
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

# exit 0, if ok
# exit 1, if umount or cryptsetup fails


. ./src_log.sh


disklabel=$1
lv_cc_logname="$disklabel:umount"

# check, if is luks device, has 'luks' at end of label
if [[ "$disklabel" == *luks ]]
then
	dlog "is luks"
	dlog "LUKS: 'umount /mnt/$disklabel'"
	umount /mnt/$disklabel
	RET=$?
	if test $RET -eq 0
	then
		dlog "LUKS: 'cryptsetup luksClose $disklabel'"
		cryptsetup luksClose $disklabel
		RET=$?
		if test $RET -ne 0
		then
			dlog "LUKS: 'cryptsetup luksClose $disklabel' fails"
			exit 1
		fi
	else
		dlog "LUKS: 'umount /mnt/$disklabel' fails"
		exit 1
	fi
else
	# not a luks device
	dlog "is not luks, umount normal"
	dlog "'umount /mnt/$disklabel'"
	umount /mnt/$disklabel
	RET=$?
	if test $RET -ne 0
	then
		dlog "'umount /mnt/$disklabel' fails"
		exit 1
	fi
fi


exit 0

# EOF

