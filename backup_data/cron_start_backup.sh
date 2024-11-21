#!/bin/bash

# file: cron_start_backup.sh

# bk_version 24.08.2

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


# call chain:
# ./bk_main.sh 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot



# -- start backup from cronjob with @reboot
# logfile: /var/log/cron/cron_start_backup.crontab"
# waits 5 minutes 

# removes main_lock, if exist
# do not start manually

# create log folder in /var/lo  for cron logfiles
if [ ! -d /var/log/cron ]
then
	mkdir /var/log/cron
fi


readonly bv_version="24.08.1"


readonly callfilename=$(basename "$0")

LLFILE="/var/log/cron/${callfilename}.crontab"


# param = message
function cron_dlog {
	# YYYYmmdd-HHMM
	local _TODAY=`date +%Y%m%d-%H%M`
	local _msg="$_TODAY -- $1"
	echo -e "$_msg" >> ${LLFILE}
}


cron_dlog ""
cron_dlog ""
cron_dlog "======================="
cron_dlog "start of: $callfilename"
cron_dlog "version: '$bv_version'"
cron_dlog "======================="

cron_dlog ""



if [[ $(id -u) != 0 ]]
then
        cron_dlog "we are not root, use root for backup"
        exit 1
fi


# STARTFOLDER is set from: /etc/rlf_backup_data.rc, 
#   if exists ok, otherwise exits

readonly rlf_backup_data_rc="rlf_backup_data.rc"

if [ ! -f /etc/$rlf_backup_data_rc ]
then
	cron_dlog "'/etc/$rlf_backup_data_rc' not found, exit "	
	cron_dlog "create file '/etc/$rlf_backup_data_rc' with used working folder"
	cron_dlog "Example line: WORKINGFOLDER=\"/home/rleo/bin/backup_data\"" 
	cron_dlog "" 
	cron_dlog "COMMAND:" 
	cron_dlog "echo \"WORKINGFOLDER=/home/rleo/bin/backup_data\" > /etc/$rlf_backup_data_rc"
	exit 1
fi

# ok, source rlf_backup_data.rc

. /etc/$rlf_backup_data_rc

STARTFOLDER=$WORKINGFOLDER
_size=${#STARTFOLDER}
if [ $_size -eq 0 ]
then
	cron_dlog "'WORKINGFOLDER'  Variable not found in '/etc/rlf_backup_data.rc'"	
	cron_dlog ""	
	cron_dlog "content of file '/etc/rlf_backup_data.rc':"	
	cron_dlog ""	
	cron_dlog "cat '/etc/$rlf_backup_data_rc'"
	cat /etc/$rlf_backup_data_rc >> ${LLFILE}
	cron_dlog "== end == "
	exit 1
fi

if [ ! -d $STARTFOLDER ]
then
	cron_dlog "'WORKINGFOLDER' entry in '/etc/rlf_backup_data.rc' not found '$STARTFOLDER', exit 1"	
	exit 1
fi

cron_dlog "'$STARTFOLDER' exists, change, and write new file .cfg" 
#echo "all backupfolders have chmod 700 and owned by root, this prevents vom deleting, with user rights"


cd "$STARTFOLDER" || exit 1
cron_dlog "write WORKINGFOLDER from '/etc/rlf_backup_data_rc' to file 'cfg.working_folder'" 

# create file 'cfg.working_folder'
echo "# BK_WORKINGFOLDER from /etc/rlf_backup_data_rc" > cfg.working_folder
echo "# bk version $bv_version" >> cfg.working_folder
echo "bv_workingfolder=\"$STARTFOLDER\"" >> cfg.working_folder
echo "# EOF" >> cfg.working_folder
chmod 755 cfg.working_folder
#echo "export bv_workingfolder " >> cfg.working_folder


#  start 'bk_main.sh' in background and returns
#   if 'bk_main.sh' is running, display a message and exit


# check, if already running, look for process 'bk_main.sh'
cron_dlog "check, if already running, lookup for process 'bk_main.sh'"
cron_dlog "ps aux | grep bk_main.sh | grep -v grep | wc -l "
wc=$( ps aux | grep bk_main.sh | grep -v grep | wc -l )


if [ $wc -gt 0  ]
then
	cron_dlog "count of 'bk_main.sh' in 'ps aux' is > 0 : $wc"	
	cron_dlog "Backup is running, exit"
	cron_dlog "==  end == "
	exit 1
fi
cron_dlog "process 'bk_main.sh' is not running, start"

cron_dlog ""
cron_dlog "working folder is: '$(pwd)'"
cron_dlog ""

cron_dlog "in cron_start_backup.sh"
cron_dlog "Backup is not running, start in '$STARTFOLDER'"

cron_dlog ""
cron_dlog "sleep 2.5m"
count=0
while test "$count" -lt "15" 
do

        echo "count: $count" >> out_bk_main
         ((count++))
        sleep 10
done

cron_dlog "start main with: nohup ./bk_main.sh 'cron' > out_bk_main"

# start in crontab at boot, no check, if is running
nohup ./bk_main.sh "cron" > out_bk_main &


# wait a little bit
sync
sleep 0.5


exit 0


# EOF


