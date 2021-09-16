#!/bin/bash

# file: show_times.sh

# bk_version 21.09.1


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

. /etc/rlf_backup_data.rc
cd $WORKINGFOLDER

. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.projects


. ./src_exitcodes.sh
. ./src_filenames.sh

#SHOWTIMES_LOGFILE="_show_times.log"
#export SHOWTIMES_LOGFILE 

echo "show times for all disks and all projects"
#echo "result is in '$SHOWTIMES_LOGFILE'"

function log {
   local _msg=$1
   echo "$_msg" 
#   echo -e "$msg" >> $SHOWTIMES_LOGFILE
}


FILENAME="show_times"

function stdatelog {
	if [  -z ${FILENAME} ]
	then
		echo "${FILENAME} is empty"
		exit
	fi
	local _msg="${FILENAME}: $1"
	local _TODAY=`date +%Y%m%d-%H%M`
	log "$_TODAY ==>  $_msg"
}

function errorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $ERRORLOG
}




cd $WORKINGFOLDER
if [ ! -d $WORKINGFOLDER ] && [ ! $( pwd ) = $WORKINGFOLDER ]
then
	echo "WD '$WORKINGFOLDER'"
	echo "WD is wrong"
	exit 1
fi





for _disk in $DISKLIST
do
	# clean up ssh messages
	stdatelog ""
	stdatelog "${FILENAME}: ==== next disk: '$_disk' ===="
	oldifs2=$IFS
	IFS=','
	RET=""
	./disk_show_times.sh "$_disk"
        RET=$?
	IFS=$oldifs2

	if [[ $RET = "$DISKLABELNOTFOUND" ]]
	then
		stdatelog "${FILENAME}: HD with label: '$_disk' not found"
        fi

done


exit 0

# EOF



