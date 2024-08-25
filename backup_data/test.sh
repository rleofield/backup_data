#!/bin/bash

# file: test.sh
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
. ./src_folders.sh

readonly errlog="test_errors.log"
  
# copy from src_log.sh

function targetdisk {

	local _disk_label=$1
	#${a_targetdisk[${_disk_label}]}
	# test for a variable that does contain a value 

	local _targetdrive="empty"
	if [[ $_disk_label ]]
	then
		_targetdrive=${a_targetdisk[${_disk_label}]}
		if [[ $_targetdrive ]]
		then
			echo "$_targetdrive"
		else
			echo "$_disk_label"
		fi
	else
		echo "empty"
	fi
	
}



dlognomarker(){
        echo "$1"
}

dlog(){
        echo "$RSNAPSHOT -->  $1"
}

readonly bv_disklist=$DISKLIST


# loop disk list
echo "loop disk list: \"$bv_disklist\""
echo ""
for _disk in $bv_disklist
do
	
	echo " ====  check disk: $_disk  ===="
	
	PROJEKTLABELS=${a_projects[$_disk]}
	echo "  ===  projects: '$PROJEKTLABELS' ==="
	for p in $PROJEKTLABELS
	do
        	lpkey=${_disk}_${p}
		RSNAPSHOT=$lpkey
		dlog "       check project '$p' in disk: '$_disk'  "
		RSNAPSHOT_CONFIG=${lpkey}.conf
		dlog "try with .conf:  $RSNAPSHOT_CONFIG"
		if test -f "./conf/$RSNAPSHOT_CONFIG" 
		then
			dlog "       try rsnapshot -c conf/$lpkey.conf configtest"
			DO_RSYNC=$(cat ./conf/${RSNAPSHOT_CONFIG} | grep ^snapshot_root | grep -v '#' | wc -l)
			if [ $DO_RSYNC -eq 1 ]
			then
				RS=$( rsnapshot -c ./conf/${lpkey}.conf configtest )
				dlog "       $RS"
			fi
			if [ $DO_RSYNC -eq 0 ]
			then
				rsnapshot -c conf/${lpkey}.conf configtest
			fi
			dlog "--------"
		else
			dlog "--- 'conf/$RSNAPSHOT_CONFIG' --- doesn't exist"
		fi
		
		#RSNAPSHOT_CONFIG=${lpkey}.arch
		#dlog "try with .arch:  $RSNAPSHOT_CONFIG"

		#if test -f "./conf/$RSNAPSHOT_CONFIG"
		#then
		#		dlog "        is arch configuration: ${RSNAPSHOT_CONFIG}"
		#	else
		#		dlog "        no arch configured: ${RSNAPSHOT_CONFIG}"
		#fi


		dlog "check reachability"
		dlog "  $bv_preconditionsfolder/$lpkey.$bv_preconditionsfolder.sh" 
		if  [ ! -f "$bv_preconditionsfolder/$lpkey.$bv_preconditionsfolder.sh" ]
		then
			dlog "  '$bv_preconditionsfolder/$lpkey.$bv_preconditionsfolder.sh'  doesn't exist " 
		else
			pre/${lpkey}.pre.sh
			RET=$?
			if [ $RET -eq 0 ]
			then 
				dlog "  remote host reached"
			else 
				dlog "  remote host not reached" 
			fi
		fi
		echo " ================"
		echo ""

	done
	echo " ====  disk: $_disk done ===="
	echo ""
done

dlognomarker "==================="





if test -f $errlog
then
	filelength=$( cat $errlog | wc -c )
	if test $filelength -eq 0 
	then
		rm $errlog
	fi
fi
echo "ok"


# EOF

