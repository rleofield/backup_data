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



. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.projects

. ./src_exitcodes.sh
. ./src_filenames.sh

LOGFILE="list_disks_log.log"
FILENAME="show_disks"


#DISKLIST is from cfg.target_disk_list

function log {
   local msg=$1
   #echo "$msg" | tee -a $LOGFILE
   echo -e "$msg" >> $LOGFILE
}



function datelog {
        local _TODAY=`date +%Y%m%d-%H%M`
        log "${_TODAY} -> ${FILENAME}: $1"
}

function errorlog {
        local _TODAY=`date +%Y%m%d-%H%M`
	msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$msg" >> $ERRORLOG
}



cd $WORKINGFOLDER
if [ ! -d $WORKINGFOLDER ] && [ ! $( pwd ) = $WORKINGFOLDER ]
then
	echo "WD '$WORKINGFOLDER'"
	echo "WD is wrong"
	exit 1
fi



function check_disk_label {
        local _LABEL=$1

        # 0 = success
        # 1 = error
        local goodlink=1

        local uuid=$( cat "uuid.txt" | grep -w $_LABEL | awk '{print $2}' )
#	local uuid=$( gawk -v pattern="$_LABEL" '$1 ~ pattern  {print $NF}' uuid.txt )
	#datelog "/dev/disk/by-uuid/$uuid"
        local disklink="/dev/disk/by-uuid/$uuid"
        # test, if symbolic link
        if test -L ${disklink} 
        then
             return 0
        fi
        return 1
}



datelog ""
datelog "== Liste der verbundenen Disks == "
datelog "= Disks: '$DISKLIST' = "
for _disk in $DISKLIST
do
        LABEL=$_disk
        check_disk_label $_disk
        goodlink=$?
        RET="disk: '$LABEL' "
        if [ $goodlink -ne 0 ]
        then
                RET="${RET} ist nicht verbunden"
		aw="awk '{ print $1 }'"
#		echo "find oldlogs -name "cc_log*" | grep -v save | xargs grep $_disk | grep 'is mounted' | sort | $aw | cut -d '/' -f 2 | tail -f -n1"
		F=$( find oldlogs -name "cc_log*" | grep -v save | xargs grep $_disk | grep 'is mounted' | sort | awk '{ print $1 }'| cut -d '/' -f 2 | tail -f -n1 )
        	datelog "$RET, letztes Backup war: $F "
        else
                RET="${RET} ist verbunden"
        	datelog "$RET"
        fi
done

tail  list_disks_log.log -n 12


exit 0


# EOF







