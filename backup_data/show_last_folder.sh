#!/bin/bash


# file: show_disks.sh

# bk_version 21.05.1

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

IFS="$(printf '\n\t')"

. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.projects

. ./src_exitcodes.sh
. ./src_filenames.sh


cd $WORKINGFOLDER
if [ ! -d $WORKINGFOLDER ] && [ ! $( pwd ) = $WORKINGFOLDER ]
then
	echo "WD '$WORKINGFOLDER'"
	echo "WD is wrong"
	exit 1
fi

# set disk label
DISKLABEL="label"

# set projekt
PROJECT="project"

PROJECT_LABEL=$( echo "${DISKLABEL}_${PROJECT}" )

#array=($(ls -d */))
retains=($(grep retain conf/${PROJECT_LABEL}.conf | awk '{ print $2 }'))
numbers=($(grep retain conf/${PROJECT_LABEL}.conf | awk '{ print $3 }'))

#echo "${#retains[@]}"
#echo "${#numbers[@]}"
#echo "${!numbers[@]}"
#echo "dd"


echo "${retains[*]}"
echo "${numbers[*]}"
count=${#retains[@]}
((count--))

#echo "nr retains : $count"

first=""
while [ $count -ge 0 ]
do
#	echo "retain: $count"
	retainvalue=${retains[count]}
#	echo "loop retain: $retainvalue"
#	echo "number: ${numbers[count]}"
	i=${numbers[count]}
	((i--))
	ok=0
	while [ $i -ge  0 ]
	do
#		echo "i: $i "
	
		p=$( echo "/mnt/${DISKLABEL}/rs/${PROJECT}/${retainvalue}.$i")
		if [ -d "$p" ]
		then
		
			d0=$( ls -1F $p | grep '/' | cut -d '/' -f 1 )
	#		echo "abc: $p/$d0"
			d1=$( echo "$p/${d0}" )
			first=$p
	#		echo "def: $d1"
			if [ -d "$d1" ]
			then
				echo "d1 exists:           $d1"
	#			i=0
	#			ok=1
			else	
				echo "d1 doesn't exist:     $d1"
			fi
		else
			echo "p doesn't exist:     $p"

		fi

		((i--))
	done
	if [ $ok -eq 1 ]
	then
		count=0
	fi
	((count--))
done

#echo "found: $first"


# EOF

# ./conf/wdg_tux2.conf
# find . -name "*.conf"| xargs grep backup| grep -v pid | grep -v delete | grep -v log | grep -v exclude | awk '{ print $2 " " $3}




