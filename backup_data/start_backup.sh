#!/bin/bash

# file: start_backup.sh
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


# call chain:
# ./bk_main.sh 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot


#echo "name: $0"
callfilename=$(basename "$0")
echo "name: $callfilename"


echo ""


if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for backup"
        exit
fi

if [ ! -f  /usr/bin/gawk ]
then
	echo "gawk not found"
	exit 1
fi

# STARTFOLDER is set from: /etc/rlf_backup_data.rc, 
#   if exists ok, otherwise exits

readonly rlf_backup_data_rc="rlf_backup_data.rc"

if [ ! -f /etc/$rlf_backup_data_rc ]
then
	echo "'/etc/$rlf_backup_data_rc' not found, exit "	
	echo "create file '/etc/$rlf_backup_data_rc' with used working folder"
	echo "Example line: WORKINGFOLDER=\"/home/rleo/bin/backup_data\"" 
	echo "" 
	echo "COMMAND:" 
	echo "echo \"WORKINGFOLDER=/home/rleo/bin/backup_data\" > /etc/$rlf_backup_data_rc"
	exit 1
fi

# ok, source rlf_backup_data.rc

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

if [ ! -d $STARTFOLDER ]
then
	echo "'WORKINGFOLDER' set in '/etc/rlf_backup_data.rc' not found: '$STARTFOLDER', exit 1"	
	exit 1
fi

echo "'$STARTFOLDER' exists, change" 
#echo "all backupfolders have chmod 700 and owned by root, this prevents from deleting, with user rights"

cd $STARTFOLDER 

#  start 'bk_main.sh' in background and returns
#   if 'bk_main.sh' is running, display a message and exit
# check, if already running, look for process 'bk_main.sh'
echo "ps aux | grep bk_main.sh | grep -v grep | grep -v vim | wc -l "
wc=$( ps aux | grep bk_main.sh | grep -v grep | grep -v vim | wc -l )
echo "wc=$wc"
if [ $wc -gt 0  ]
then
	echo "count of 'bk_main.sh' in 'ps aux' is > 0 : $wc"	
	echo "Backup is running, exit"
	echo "==  end == "
	exit 1
fi

echo "Backup is not running, start in '$STARTFOLDER'"
echo "write WORKINGFOLDER, set in '/etc/rlf_backup_data_rc', to file 'cfg.working_folder'" 

# create file 'cfg.working_folder'
echo "write new file 'cfg.working_folder'"
echo "# WORKINGFOLDER from /etc/rlf_backup_data_rc" > cfg.working_folder
echo "# bk_version 21.09.1" >> cfg.working_folder
echo "WORKINGFOLDER=$WORKINGFOLDER" >> cfg.working_folder
echo "export WORKINGFOLDER" >> cfg.working_folder
echo ""
echo "working folder is: '$(pwd)'"
echo "start command: nohup ./bk_main.sh 'manual' > out_bk_main"
nohup ./bk_main.sh "manual" > out_bk_main &


# wait for sync
sync
sleep 0.1
echo "started"


exit 0


# EOF

