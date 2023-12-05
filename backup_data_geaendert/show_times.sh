#!/bin/bash

# file: show_times.sh

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

. /etc/rlf_backup_data.rc
cd $WORKINGFOLDER

. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.projects


. ./src_exitcodes.sh
. ./src_filenames.sh

#SHOWTIMES_LOGFILE="_show_times.log"
#export SHOWTIMES_LOGFILE 

readonly bv_disklist=$DISKLIST


echo "show times for all disks and all projects"
#echo "result is in '$SHOWTIMES_LOGFILE'"

function log {
   local _msg=$1
   echo "$_msg" 
#   echo -e "$msg" >> $SHOWTIMES_LOGFILE
}


lv_cc_logname="show_times"

function stdatelog {
	if [  -z ${lv_cc_logname} ]
	then
		echo "${lv_cc_logname} is empty"
		exit
	fi
	local _msg="${lv_cc_logname}: $1"
	local _TODAY=`date +%Y%m%d-%H%M`
	log "$_TODAY ==>  $_msg"
}

function errorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $bv_errorlog
}




cd $bv_workingfolder
if [ ! -d $bv_workingfolder ] && [ ! $( pwd ) = $bv_workingfolder ]
then
	echo "WD '$bv_workingfolder'"
	echo "WD is wrong"
	exit 1
fi





for _disk in $bv_disklist
do
	# clean up ssh messages
	stdatelog ""
	stdatelog "${lv_cc_logname}: ==== next disk: '$_disk' ===="
	oldifs2=$IFS
	IFS=','
	RET=""
	./disk_show_times.sh "$_disk"
        RET=$?
	IFS=$oldifs2

	if [[ $RET = "$BK_DISKLABELNOTFOUND" ]]
	then
		stdatelog "${lv_cc_logname}: HD with label: '$_disk' not found"
        fi

done


exit 0

# EOF



