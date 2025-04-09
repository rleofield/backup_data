#!/bin/bash

# file: show_times.sh

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


. ./cfg.working_folder
. ./cfg.projects


. ./src_exitcodes.sh
. ./src_filenames.sh



readonly bv_errorlog="cc_show_times_error.log"

use_retains=$1
if [ -z $use_retains ]
then
	use_retains=0
fi

readonly bv_disklist=$DISKLIST



function log {
   local _msg=$1
   echo "$_msg" 
#   echo -e "$msg" >> $SHOWTIMES_LOGFILE
}


lv_cc_logname=""

function stdatelog {
	if [  -z ${lv_cc_logname} ]
	then
		local _msg="$1"
		local _TODAY=`date +%Y%m%d-%H%M`
		log "$_TODAY ==>  $_msg"
	else
		local _msg="${lv_cc_logname}: $1"
		local _TODAY=`date +%Y%m%d-%H%M`
	log "$_TODAY ==>  $_msg"
	fi
}

function errorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $bv_errorlog
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
	stdatelog ""
	./disk_show_times.sh "$_disk" "$use_retains"
        RET=$?
	if [[ $RET = "$BK_DISKLABELNOTFOUND" ]]
	then
		stdatelog "${lv_cc_logname}: HD with label: '$_disk' not found"
	fi
done


exit 0

# EOF



