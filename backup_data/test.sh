#!/bin/bash

# file: test.sh
# version 20.08.1


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
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects

errlog="test_errors.log"
  

cd $WORKINGFOLDER 2> "$errlog"  || exit
if [ ! -d $WORKINGFOLDER ] && [ ! "$( pwd )" = $WORKINGFOLDER ]
then
	echo "WD '$WORKINGFOLDER'"
	echo "WD is wrong"
	exit 1
fi



function datelog {
	local _TODAY
	_TODAY=$(date +%Y%m%d-%H%M)
        local _msg="$_TODAY --» $1"
        echo -e "count $#,    $_msg" 
}




# loop disk list
echo "loop disk list: \"$DISKLIST\""
echo ""
for _disk in $DISKLIST
do
	
	echo " ====  check disk: $_disk  ===="
	
	PROJEKTLABELS=${a_projects[$_disk]}
	echo "  ===  projects: '$PROJEKTLABELS' ==="
	for p in $PROJEKTLABELS
	do
		echo "       check project '$p' in disk: '$_disk'  "
        	lpkey=${_disk}_${p}
		RSNAPSHOT_CONFIG=${lpkey}.conf
		echo "try with .conf:  $RSNAPSHOT_CONFIG"
		if test -f "./conf/$RSNAPSHOT_CONFIG" 
		then
			echo "       try rsnapshot -c conf/$lpkey.conf configtest"
			DO_RSYNC=$(cat ./conf/${RSNAPSHOT_CONFIG} | grep ^snapshot_root | grep -v '#' | wc -l)
			if [ $DO_RSYNC -eq 1 ]
			then
				RS=$( rsnapshot -c ./conf/${lpkey}.conf configtest )
				echo "       $RS"
			fi
			if [ $DO_RSYNC -eq 0 ]
			then
				rsnapshot -c conf/${lpkey}.conf configtest
			fi
			echo "--------"
		fi
		
		RSNAPSHOT_CONFIG=${lpkey}.arch
		echo "try with .arch:  $RSNAPSHOT_CONFIG"

		if test -f "./conf/$RSNAPSHOT_CONFIG"
		then
			echo "        is arch: ${RSNAPSHOT_CONFIG}"
		fi


		echo ""
		echo "pre/$lpkey.pre.sh" 
		pre/${lpkey}.pre.sh
		RET=$?
		if [ $RET -eq 0 ]
		then 
			echo "ok"
		else 
			echo "not reached" 
		fi
	done
done

echo "==================="
echo ""



