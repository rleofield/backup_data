#!/bin/bash

# file: bk_rsnapshot.sh
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

. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_global_strings.sh
. ./src_folders.sh
. ./src_log.sh

# parameter
# $1 = currentretain
# $2 = DISK 
# $3 = PROJECT

readonly INTERVAL=$1 
readonly DISK=$2 
readonly PROJECT=$3 


readonly FILENAME="rsnapshot:${DISK}:$PROJECT"

 
# rsnapshot exit values
# 0 All operations completed successfully
# 1 A fatal error occurred
# 2 Some warnings occurred, but the backup still finished


function dlog2 {
        datelog "${FILENAME}: $1"
}


#readonly TODAY_LOG=`date +%Y-%m-%dT%H:%M:%S`
TODAY_LOG=`date +%Y-%m-%dT%H:%M`
RSYNCLOG=""




function rsynclog {
  echo "$1" >> $RSYNCLOG
}


dlog "== start bk_rsnapshot.sh =="
dlog "$TODAY_LOG -- $INTERVAL --"


if [ "$INTERVAL" = "all" ]
then
	exit 1
fi

# now in src_folders.sh:22
#readonly CONFFOLDER="./conf"

rs_exitcode=0

readonly projectkey=${DISK}_${PROJECT}


readonly RSNAPSHOT_CFG=${projectkey}
readonly RSNAPSHOT_CONFIG=${RSNAPSHOT_CFG}.conf
readonly cfg_file=./${CONFFOLDER}/${RSNAPSHOT_CFG}.conf
readonly RSNAPSHOT_ROOT=$(cat ${cfg_file} | grep snapshot_root | grep -v '#' | awk '{print $2}')

readonly RSYNCLOG="rsynclog/${RSNAPSHOT_CFG}.log"



if test ! -d $RSNAPSHOT_ROOT 
then
       	dlog "snapshot root folder '$RSNAPSHOT_ROOT' doesn't exist" 
        dlog "give up, also don't do remaining rsnapshots"
	exit $NORSNAPSHOTROOT
fi

#datelog "${FILENAME}: interval: ${INTERVAL}"
#echo "cat ./$CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^retain | grep $INTERVAL"
WC=$(cat ./$CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^retain | grep $INTERVAL | wc -l)

# only one retain line with current interval can exist 
if test $WC -eq  1 
then

	dlog "==> execute -->: /usr/bin/rsnapshot -c ${cfg_file} ${INTERVAL}"
	# get first interval line, second entry is name of interval, eins, zwei or first second ...
	FIRST_INTERVAL=$(cat ${cfg_file} | grep ^retain | awk 'NR==1'| awk '{print $2}')
	
	rsynclog "${FILENAME}: -----------  first is: ${FIRST_INTERVAL}, interval: ${INTERVAL}"

	# lookup sync_first entry
	WC=$(cat ${cfg_file} | grep ^sync_first |  wc -l)

	# do rsync first
	RETSYNC=0
	# if sync first & interval = first interval, do sync
	# sync data to folder .sync in target, only if retain is first in list
	if test  $WC -eq 1  
	then	
		if test  "${FIRST_INTERVAL}" =  "${INTERVAL}" 
		then
			# do sync 
			dlog "first retain value: ${FIRST_INTERVAL}, use sync" 
			dlog "==> first interval with run sync   : /usr/bin/rsnapshot -c ${cfg_file} sync"
			TODAY_RSYNC_START=`date +%Y%m%d-%H%M`
			rsynclog "${FILENAME}: start sync -- $TODAY_RSYNC_START" 
			########### rsnapshot call, sync ######################
			/usr/bin/rsnapshot -c ${cfg_file} sync >> ${RSYNCLOG}
			RETSYNC=$?
			
			TODAY_LOG=`date +%Y-%m-%dT%H:%M`
			dlog "return from rsnapshot: '$RETSYNC'"
			TODAY_RSYNC_END=`date +%Y%m%d-%H%M`
			if test $RETSYNC -ne 0
			then
				rs_exitcode=$RSYNCFAILS
			else		
				# write marker file with date to backup folder .sync in rsnapshot root"
				runningnumber=$( printf "%05d"  $( get_loopcounter ) )
				dlog "created at file is: '$RSNAPSHOT_ROOT.sync/created_at_${TODAY_LOG}_number_$runningnumber.txt'"
				dlog "write to file: 'created at: ${TODAY_LOG} , loop: $runningnumber'"
				# write control message to .sync
				echo "${prefix_created_at}${TODAY_LOG}, loop: $runningnumber" > $RSNAPSHOT_ROOT.sync/created_at_${TODAY_LOG}_number_$runningnumber.txt
			fi	
			rsynclog "${FILENAME}: end   sync -- $TODAY_RSYNC_END"
		fi
	fi
	# sync is done or we have a simple rotate
        # do rsnapshot rotate, in all cases, also, if no sync was executed, then it is a simple rotate  
        if test $RETSYNC -eq 0 
        then
               	datelog "${FILENAME}: ==> run rotate: /usr/bin/rsnapshot -c ${cfg_file} ${INTERVAL}"
                TODAY_RSYNC2_START=`date +%Y%m%d-%H%M`
                #rsynclog "rotate starts at ${INTERVAL} -- $TODAY_RSYNC_START"
                rsynclog "${FILENAME}: start ${INTERVAL} -- $TODAY_RSYNC2_START"
		RETROTATE=1
		########### rsnapshot call, rotate ######################
   		/usr/bin/rsnapshot -c ${cfg_file} ${INTERVAL} >> ${RSYNCLOG}
	        RETROTATE=$?
                #datelog "${FILENAME}: rotate return: $RETROTATE"
                TODAY_RSYNC2_END=`date +%Y%m%d-%H%M`
                rsynclog "${FILENAME}: end   ${INTERVAL} -- $TODAY_RSYNC2_END"
                if test $RETROTATE -ne 0 
                then
       			datelog "${FILENAME}: ==> error in rsnapshop, in '${cfg_file}' "
                fi
       	else
               	datelog "${FILENAME}: ==> return in sync first was not ok, in '${cfg_file}' "
        fi
		
else
	datelog "${FILENAME}: ==> can't execute -->: '${RSNAPSHOT_CFG}', interval '$INTERVAL' is not in '${cfg_file}' "
fi

sync

dlog "== end bk_rsnapshot.sh =="

exit $rs_exitcode




