#!/bin/bash


# file: show_last_folder.sh

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

IFS="$(printf '\n\t')"

. ./cfg.working_folder
. ./cfg.projects

. ./src_exitcodes.sh
. ./src_filenames.sh


cd $bv_workingfolder || exit
if [ ! -d $bv_workingfolder ] && [ ! "$( pwd )" = $bv_workingfolder ]
then
	echo "WD '$bv_workingfolder'"
	echo "WD is wrong"
	exit 1
fi

# set disk label
DISKLABEL=$1

if [ ! "$DISKLABEL" ]
then
	echo "no disklabel given"
	echo "usage: show_last_folder.sh label project"
	exit 1
fi

# set projekt
PROJECT=$2
if [ ! "$PROJECT" ]
then
	echo "no project for disklabel '$DISKLABEL'  given"
	echo "usage: show_last_folder.sh label project"
	exit 1
fi



# shellcheck disable=SC2116
PROJECT_LABEL=$( echo "${DISKLABEL}_${PROJECT}" )

if [ -f conf/"${PROJECT_LABEL}".conf ]
then
	echo "conf/${PROJECT_LABEL}.conf exists"
else
	echo "conf/${PROJECT_LABEL}.conf not found, please correct DISKLABEL and PROJECT "
	exit 1
	
fi

#array=($(ls -d */))
# retain   eins 6
#          2    3
retains=($(grep retain conf/"${PROJECT_LABEL}".conf | awk '{ print $2 }'))
numbers=($(grep retain conf/"${PROJECT_LABEL}".conf | awk '{ print $3 }'))


sroot=$( grep snapshot_root  conf/"${PROJECT_LABEL}".conf | awk '{print $2}' )
echo "disk base folder: $sroot"
disk=$( echo "$sroot" | cut -d'/' -f3 )
echo "disk $disk"

count=${#retains[@]}
((count--))

first=""
while [ $count -ge 0 ]
do
	retainvalue=${retains[count]}

	i=${numbers[count]}
	((i--))
	ok=0
	while [ $i -ge  0 ]
	do
		p="${sroot}${retainvalue}.$i"
		if [ -d "$p" ]
		then
			echo "exists:         $p"
		else
			echo "doesn't exist:  $p"
		fi
		((i--))
	done
	if [ $ok -eq 1 ]
	then
		count=0
	fi
	((count--))
done


# EOF



