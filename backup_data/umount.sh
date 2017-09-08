#!/bin/bash


# file: mount.sh

# Copyright (C) 2017 Richard Albrecht
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


. ./log.sh


FILENAME=$(basename "$0" .sh)

label=$1
FILENAME="umount:$label"


if [[ "$label" == *luks ]]
then
	#datelog "${FILENAME}:  is luks"
	#datelog "${FILENAME}:   LUKS: 'umount /mnt/$label'"
	umount /mnt/$label
	RET=$?
	if test $RET -eq 0
	then
		datelog "${FILENAME}:   LUKS: 'cryptsetup luksClose $label'"
		cryptsetup luksClose $label
		RET=$?
		if test $RET -ne 0
		then
			datelog "${FILENAME}:   LUKS: 'cryptsetup luksClose $label' fails"
			exit 1
		fi
	else
		datelog "${FILENAME}:   LUKS: 'umount /mnt/$label' fails"
		exit 1
	fi


	#datelog "${FILENAME}:   LUKS: ok, dismounted"
	exit 0
else
	#datelog "${FILENAME}:  is not luks, umount normal"
	#datelog "${FILENAME}:    'umount /mnt/$label'"
	umount /mnt/$label
	RET=$?
	if test $RET -ne 0
	then
		datelog "${FILENAME}: 'umount /mnt/$label' fails"
		exit 1
	fi
fi


exit 0
