#!/bin/bash

# file: start_backup.sh
# version 19.04.1


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


# starts:
# ./bk_main.sh 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot



# shellcheck source=/etc/rlf_backup_data.rc

if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for backup"
        echo "we are not root, 'mount' needs root"
        exit
fi



# STARTFOLDER is set from: /etc/rlf_backup_data.rc, 
#   if exists ok, otherwise exits

readonly rlf_backup_data_rc="rlf_backup_data.rc"

if [ -f /etc/$rlf_backup_data_rc ]
then
	. /etc/$rlf_backup_data_rc
	STARTFOLDER=$WORKINGFOLDER
	_size=${#STARTFOLDER}
	if [ $_size -eq 0 ]
	then
		echo "'WORKINGFOLDER'  Variable not found in '/etc/rlf_backup_data.rc'"	
		echo ""	
		echo "content of file '/etc/rlf_backup_data.rc':"	
		echo ""	
		echo "cat '/etc/$rlf_backup_data_rc'"
		cat /etc/$rlf_backup_data_rc
		echo "== end == "
		exit 1
	fi
	if [ -d $STARTFOLDER ]
	then
		cd $STARTFOLDER 
		echo "set the WORKINGFOLDER from '/etc/rlf_backup_data_rc' to file 'cfg.working_folder'" 
		# create file 'cfg.working_folder'
		echo "# WORKINGFOLDER from /etc/rlf_backup_data_rc" > cfg.working_folder
		echo "# version 19.04.1" >> cfg.working_folder
		echo "WORKINGFOLDER=$WORKINGFOLDER" >> cfg.working_folder
	else
		echo "'WORKINGFOLDER'  not found '$STARTFOLDER', exit 1"	
		exit 1
	fi
else
	echo "'/etc/$rlf_backup_data_rc' not found, exit "	
	echo "create file '/etc/$rlf_backup_data_rc' with used working folder"
	echo "Example line: WORKINGFOLDER=\"/home/rleo/bin/backup_data\"" 
	echo "" 
	echo "COMMAND:" 
	echo "echo \"WORKINGFOLDER=/home/rleo/bin/backup_data\" > /etc/$rlf_backup_data_rc"
	exit 1
fi



#  starts 'bk_main.sh' in background and returns
#   if 'bk_main.sh' is runnung, it displays a message and exits


# check, if already running, look for process 'bk_main.sh'
# shellcheck disable=SC2009,SC2126 
wc=$( ps aux | grep bk_main.sh | grep -v grep | wc -l )

# shellcheck disable=SC2086 
if [ $wc -gt 0  ]
then
       	echo "wc count is > 0 : $wc"	
       	echo "Backup is running, exit"	
	echo "==  end == "
	exit 1
fi

echo ""
echo "working folder is: '$(pwd)'"
echo ""

echo "Backup is not running, start in '$STARTFOLDER'"	

echo ""

echo "nohup ./bk_main.sh  nohupexecute.out " 
nohup ./bk_main.sh > nohupexecute.out &


# wait a little bit
sync
sleep 0.5


exit 0

