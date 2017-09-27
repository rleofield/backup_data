#!/bin/bash

# file: rs.sh

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


# parameter
# $1 = currentretain
# $" = DISK 
# $3 = PROJECT


readonly INTERVAL=$1 
readonly DISK=$2 
readonly PROJECT=$3 

FILENAME=$(basename "$0" .sh)
FILENAME="rs"
FILENAME=${FILENAME}:${DISK}:$PROJECT

 
# rsnapshot exit values
# 0 All operations completed successfully
# 1 A fatal error occurred
# 2 Some warnings occurred, but the backup still finished

. ./cfg.exit_codes
. ./lib.logger



readonly TODAY_LOG=`date +%Y-%m-%dT%H:%M:%S`
RSYNCLOG=""



function rsynclog {
  echo "$1" >> $RSYNCLOG
}


datelog "${FILENAME}: == start rs.sh =="
datelog "${FILENAME}: $TODAY_LOG -- $INTERVAL --"


if [ "$INTERVAL" = "all" ]
then
	exit 1
fi

readonly CONFFOLDER="./conf"

rs_exitcode=0

RSNAPSHOT_CFG=${DISK}_${PROJECT}
RSNAPSHOT_CONFIG=${RSNAPSHOT_CFG}.conf
RSNAPSHOT_ROOT=$(cat $CONFFOLDER/${RSNAPSHOT_CONFIG} | grep snapshot_root | grep -v '#' | awk '{print $2}')

RSYNCLOG="rsynclog/${RSNAPSHOT_CFG}.log"

#datelog "${FILENAME}: root folder: $RSNAPSHOT_ROOT"


if test ! -d $RSNAPSHOT_ROOT 
then
       	datelog "${FILENAME}: snapshot root folder '$RSNAPSHOT_ROOT' doesn't exist" 
        datelog "${FILENAME}: give up, also don't do remaining rsnapshots"
	exit $NORSNAPSHOTROOT
fi

#datelog "${FILENAME}: interval: ${INTERVAL}"
#echo "cat $CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^retain | grep $INTERVAL"
WC=$(cat $CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^retain | grep $INTERVAL | wc -l)

# only one retain line with interval can exist 
if test $WC -eq  1 
then

	datelog "${FILENAME}: ==> execute -->: /usr/bin/rsnapshot -c $CONFFOLDER/${RSNAPSHOT_CONFIG} ${INTERVAL}"
	FIRST_INTERVAL=$(cat $CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^retain | awk 'NR==1'| awk '{print $2}')
	datelog "${FILENAME}: first retain value: ${FIRST_INTERVAL}" 
	
	rsynclog "${FILENAME}: -----------  first: ${FIRST_INTERVAL}, interval: ${INTERVAL}"

	# lookup sync_first entry
	WC=$(cat $CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^sync_first |  wc -l)

	# do rsync first
	RETSYNC=0
	# if sync first & interval = first interval, do sync
	# sync data to folder .sync in target, only if retain is first in list
	if test  $WC -eq 1  
	then	
		if test  "${FIRST_INTERVAL}" =  "${INTERVAL}" 
		then
			# do sync 
			datelog "${FILENAME}: ==> first interval with run sync   : /usr/bin/rsnapshot -c $CONFFOLDER/${RSNAPSHOT_CONFIG} sync"
			TODAY_RSYNC_START=`date +%Y%m%d-%H%M`
			rsynclog "${FILENAME}: start sync -- $TODAY_RSYNC_START" 
			/usr/bin/rsnapshot -c $CONFFOLDER/${RSNAPSHOT_CONFIG} sync >> ${RSYNCLOG}
			
			RETSYNC=$?
			TODAY_RSYNC_END=`date +%Y%m%d-%H%M`
			if test $RETSYNC -ne 0
			then
				rs_exitcode=$RSYNCFAILS
			else		
				# write marker file with date to backup folder .sync in rsnapshot root"
				datelog "${FILENAME}: write: 'created at: ${TODAY_LOG}'"
				# write control message to .sync
				echo "created at: ${TODAY_LOG}" > $RSNAPSHOT_ROOT.sync/created_at_${TODAY_LOG}.txt
			fi	
			rsynclog "${FILENAME}: end   sync -- $TODAY_RSYNC_END"
		fi
	fi

        # do rsnapshot rotate, in all cases, also if no sync was executed, then it is a simple rotate  
        if test $RETSYNC -eq 0 
        then
               	datelog "${FILENAME}: ==> run rotate: /usr/bin/rsnapshot -c $CONFFOLDER/${RSNAPSHOT_CONFIG} ${INTERVAL}"
                TODAY_RSYNC2_START=`date +%Y%m%d-%H%M`
                #rsynclog "rotate starts at ${INTERVAL} -- $TODAY_RSYNC_START"
                rsynclog "${FILENAME}: start ${INTERVAL} -- $TODAY_RSYNC2_START"
		RETROTATE=1
   		/usr/bin/rsnapshot -c $CONFFOLDER/${RSNAPSHOT_CONFIG} ${INTERVAL} >> ${RSYNCLOG}
	        RETROTATE=$?
                #datelog "${FILENAME}: rotate return: $RETROTATE"
                TODAY_RSYNC2_END=`date +%Y%m%d-%H%M`
                rsynclog "${FILENAME}: end   ${INTERVAL} -- $TODAY_RSYNC2_END"
                if test $RETROTATE -ne 0 
                then
       			datelog "${FILENAME}: ==> error in rsnapshop, in '$CONFFOLDER/${RSNAPSHOT_CONFIG}' "
                fi
       	else
               	datelog "${FILENAME}: ==> return in sync first was not ok, in '$CONFFOLDER/${RSNAPSHOT_CONFIG}' "
        fi
		
else
	datelog "${FILENAME}: ==> can't execute -->: '${RSNAPSHOT_CFG}', interval '$INTERVAL' is not in '$CONFFOLDER/${RSNAPSHOT_CONFIG}' "
fi

sync

datelog "${FILENAME}: == end rs.sh =="

exit $rs_exitcode




