#!/bin/bash

# file: connected_disks.sh

# bk_version 23.12.1


# Copyright (C) 2017-2023 Richard Albrecht
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


temp=$(mktemp)

#if test -f $temp 
#then
#        rm $temp
#fi

for _d in $(ls -1 /dev/disk/by-uuid/)
do
	val=$( cat uuid.txt | awk  '{ print $2 }' )	
	#echo "val : $val "
	g=$(grep  "$_d"  uuid.txt) 
	if ! [ -z "${g##*swap*}" ] && ! [ -z "${g##*boot*}" ]
	then
	        echo "disk:  $g " >> $temp
	fi
done
cat $temp | sort -k2

echo "$temp"

if test -f $temp 
then
        rm $temp
fi


# EOF

