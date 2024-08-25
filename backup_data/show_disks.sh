#!/bin/bash


# file: show_disks.sh

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
. ./src_folders.sh

SHOW_DISKS_LOGFILE="list_disks_log.log"
lv_cc_logname="show_disks"

#bv_disklist is from cfg.projects
readonly bv_disklist=$DISKLIST



# copy from src_log.sh
function targetdisk {
	local _disk_label=$1
	local _targetdrive=${a_targetdisk[${_disk_label}]}
	# test for a variable that does contain a value  
	if [[ $_targetdrive ]]
	then
		echo "$_targetdrive"
	else
		echo "$_disk_label"
	fi
}



function log {
   local msg=$1
   #echo -e "$msg" >> $SHOW_DISKS_LOGFILE
   echo -e "$msg"    
}


function dlog {
        local _TODAY=`date +%Y%m%d-%H%M`
        log "${_TODAY} -> ${lv_cc_logname}: $1"
}

function sddatelog {
        local _TODAY=`date +%Y%m%d-%H%M`
        log "${_TODAY} -> ${lv_cc_logname}: $1"
}


cd $bv_workingfolder
if [ ! -d $bv_workingfolder ] && [ ! $( pwd ) = $bv_workingfolder ]
then
	echo "WD '$bv_workingfolder'"
	echo "WD is wrong"
	exit 1
fi



function check_disk_label {
        local _LABEL=$1
        # 0 = success
        # 1 = error
	local _targetdisk=$( targetdisk $_LABEL )

        local uuid=$( cat "uuid.txt" | grep -w $_targetdisk | awk '{print $2}' )
#	local uuid=$( gawk -v pattern="$_LABEL" '$1 ~ pattern  {print $NF}' uuid.txt )
        local disklink="/dev/disk/by-uuid/$uuid"
        # test, if symbolic link
        if test -L ${disklink} 
        then
             return 0
        fi
        return 1
}



sddatelog ""
sddatelog "== Liste der verbundenen Disks == "
sddatelog "= Disks: '$bv_disklist' = "
for _disk in $bv_disklist
do
        LABEL=$_disk
        check_disk_label $_disk
        goodlink=$?
	_targetdisk=$( targetdisk $LABEL )

        RET="disk: '$_targetdisk' "
        if [ $goodlink -ne 0 ]
        then
		
                RET="${RET} ist nicht verbunden"
		aw="awk '{ print $1 }'"
		F=$( find $bv_oldlogsfolder -name "cc_log*" | grep -v save | xargs grep $_disk | grep 'is mounted' | sort | awk '{ print $1 }'| cut -d '/' -f 2 | tail -f -n1 )
        	sddatelog "$RET, letztes Backup war: $F "
        else
                RET="${RET} ist verbunden"
        	sddatelog "$RET"
		
        fi
done

#tail  list_disks_log.log -n 12


exit 0


# EOF







