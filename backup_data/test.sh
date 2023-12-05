#!/bin/bash

# file: test.sh
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


. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./src_folders.sh

readonly errlog="test_errors.log"
  


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
		fi
		
		RSNAPSHOT_CONFIG=${lpkey}.arch
		dlog "try with .arch:  $RSNAPSHOT_CONFIG"

		if test -f "./conf/$RSNAPSHOT_CONFIG"
		then
				dlog "        is arch: ${RSNAPSHOT_CONFIG}"
			else
				dlog "        no arch: ${RSNAPSHOT_CONFIG}"

		fi


		dlog "check reachability"
		dlog "  $bv_preconditionsfolder/$lpkey.$bv_preconditionsfolder.sh" 
		pre/${lpkey}.pre.sh
		RET=$?
		if [ $RET -eq 0 ]
		then 
			dlog "  ok"
		else 
			dlog "  not reached" 
		fi
		echo " ================"
		echo ""

	done
	echo " ================"
	echo ""
done

dlog "==================="





if test -f $errlog
then
	filelength=$( cat $errlog | wc -c )
	if test $filelength -eq 0 
	then
		rm $errlog
	fi
fi
echo "ok"



