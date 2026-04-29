#!/bin/bash

# file: show_times.sh
# bk_version  26.04.1


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



# set -u, which will exit your script if you try to use an uninitialised variable
set -u


. ./cfg.working_folder
. ./cfg.projects


. ./src_exitcodes.sh
. ./src_filenames.sh

# gawk is used instead of awk
function check_if_gawk_exists {
	which gawk > /dev/null
	local _check_if_gawk_exists_RET=$?
	if [ $_check_if_gawk_exists_RET -ne 0  ]
	then
		echo "'gawk' not found"
		exit 1
	fi
}


check_if_gawk_exists 


use_retains=0

#set +u
#use_retains=0
#set -u

if [  $# -gt 0 ]
then
	use_retains=$1
fi

# from cfg.projects
readonly bv_disklist=$DISKLIST

truncate -s 0  "sst.log"

function log {
	local _msg=$1
	echo -e "$_msg" >> "sst.log"
}



function stdatelog {
	local _msg="$1"
	local _TODAY=`date +%Y%m%d-%H%M`
	log "$_TODAY ==>  $_msg"
}




cd $bv_workingfolder
if [ ! -d $bv_workingfolder ] && [ ! $( pwd ) = $bv_workingfolder ]
then
	echo "working folder is '$bv_workingfolder'"
	echo "working folder is wrong"
	exit 1
fi




stdatelog "show times for all disks and all projects"

for _disk in $bv_disklist
do
	stdatelog "disk: $_disk"

	./disk_show_times.sh "$_disk" "$use_retains"
        times_RET=$?
	stdatelog "disk_show_times_ret: $times_RET"
	if [[ $times_RET -eq "$BK_DISKLABELNOTFOUND" ]]
	then
		stdatelog "HD with label: '$_disk' not found"
		exit 1
	fi
	if [[ $times_RET -eq "$BK_ARRAYSNOK" ]]
	then
		stdatelog "arrays in cfg.projects are not ok"
		echo "arrays in cfg.projects are not ok"
		exit 1
	fi
	if [ $times_RET -gt 0  ]
	then
		stdatelog "other err"
		exit 1
	fi

done


exit 0

# EOF



