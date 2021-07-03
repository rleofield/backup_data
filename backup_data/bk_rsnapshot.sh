#!/bin/bash

# file: bk_rsnapshot.sh

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


# call chain:
# ./bk_main.sh, runs forever 
#	./bk_disks.sh,   all disks  
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with n folder trees,   
#				./bk_rsnapshot.sh,  do rsnapshot   <- this file
#				./bk_archive.sh,    no history, rsync only


. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_global_strings.sh
#. ./src_folders.sh
. ./src_log.sh

# parameter
# $1 = currentretain
# $2 = DISK 
# $3 = PROJECT

readonly INTERVAL=$1 
readonly DISK=$2 
readonly PROJECT=$3 


readonly OPERATION="rsnapshot"
#readonly FILENAME="${OPERATION}:${DISK}:$PROJECT"
readonly FILENAME="${DISK}:$PROJECT:${OPERATION}"
readonly projectkey=${DISK}_${PROJECT}

 
# rsnapshot exit values
# 0 All operations completed successfully
# 1 A fatal error occurred
# 2 Some warnings occurred, but the backup still finished

tlog "start: $projectkey"


TODAY_LOG=`date +%Y-%m-%dT%H:%M`


dlog "== start bk_rsnapshot.sh =="
dlog "$TODAY_LOG -- $INTERVAL --"


if [ "$INTERVAL" = "all" ]
then
	exit 1
fi

# now in src_folders.sh:22
#readonly CONFFOLDER="./conf"

rs_exitcode=0



readonly RSNAPSHOT_CFG=${projectkey}
readonly cfg_file=./${CONFFOLDER}/${RSNAPSHOT_CFG}.conf
readonly RSNAPSHOT_ROOT=$(cat ${cfg_file} | grep snapshot_root | grep -v '#' | awk '{print $2}')
readonly RSYNCLOGFILE="$rsynclogfolder/${RSNAPSHOT_CFG}.log"

if test ! -d $rsynclogfolder
then
       	dlog "folder '$rsynclogfolder' doesn't exist" 
	exit $NOFOLDERRSNAPSHOT
fi

if test ! -d $RSNAPSHOT_ROOT 
then
       	dlog "snapshot root folder '$RSNAPSHOT_ROOT' doesn't exist" 
        dlog "give up, also don't do remaining rsnapshots"
	exit $NORSNAPSHOTROOT
fi


function write_rsynclog {
	if [ -d $rsynclogfolder ]
	then
		echo "$1" >> $RSYNCLOGFILE
	else
		dlog "'rsynclog' doesn't exist, can't write: '$1' to '$RSYNCLOGFILE'"
	fi
}



WC=$(cat ${cfg_file} | grep ^retain | grep $INTERVAL | wc -l)

# only one retain line with current interval can exist 
if test $WC -eq  1 
then

	dlog "==> execute -->: /usr/bin/rsnapshot -c ${cfg_file} ${INTERVAL}"
	# get first interval line, second entry is name of interval, eins, zwei or first second ...
	FIRST_INTERVAL=$(cat ${cfg_file} | grep ^retain | awk 'NR==1'| awk '{print $2}')
	
	write_rsynclog "${FILENAME}: -----------  first is: ${FIRST_INTERVAL}, interval: ${INTERVAL}"

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
			tlog "rsync"
			TODAY_RSYNC_START=`date +%Y%m%d-%H%M`
			write_rsynclog "${FILENAME}: start sync -- $TODAY_RSYNC_START" 
			########### rsnapshot call, sync ######################
			/usr/bin/rsnapshot -c ${cfg_file} sync >> ${RSYNCLOGFILE}
			RETSYNC=$?
			#	0 All operations completed successfully
			#	1 A fatal error occurred
			#	2 Some warnings occurred, but the backup still finished
			
			TODAY_LOG=`date +%Y-%m-%dT%H:%M`
			dlog "return from rsnapshot: '$RETSYNC'"
			TODAY_RSYNC_END=`date +%Y%m%d-%H%M`
			if test $RETSYNC -ne 0
			then
				# set own exitcode = 'RSYNCFAILS=8'	
				dlog "rsync fails: retsync: $RETSYNC "
				rs_exitcode=$RSYNCFAILS
			else		
				# write marker file with date to backup folder .sync in rsnapshot root"
				runningnumber=$( printf "%05d"  $( get_loopcounter ) )
				dlog "created at file is: '$RSNAPSHOT_ROOT.sync/created_at_${TODAY_LOG}_number_$runningnumber.txt'"
				dlog "write to file: 'created at: ${TODAY_LOG} , loop: $runningnumber'"
				# write control message to .sync
				echo "created at: ${TODAY_LOG}, loop: $runningnumber" > $RSNAPSHOT_ROOT.sync/created_at_${TODAY_LOG}_number_$runningnumber.txt
				#     'created at: '
			fi	
			write_rsynclog "${FILENAME}: end   sync -- $TODAY_RSYNC_END"
		fi
	fi
	# sync is done or we have a simple rotate
        # do rsnapshot rotate, in all cases, also, if no sync was executed, then it is a simple rotate  
	
	#rs_exitcode=$RSYNCFAILS

        # RETSYNC > 0  is error 
        if test $RETSYNC -eq 0 
        then
               	datelog "${FILENAME}: ==> run rotate: /usr/bin/rsnapshot -c ${cfg_file} ${INTERVAL}"
                TODAY_RSYNC2_START=`date +%Y%m%d-%H%M`
                #write_rsynclog "rotate starts at ${INTERVAL} -- $TODAY_RSYNC_START"
                write_rsynclog "${FILENAME}: start ${INTERVAL} -- $TODAY_RSYNC2_START"
		tlog "rotate: ${INTERVAL}"
		RETROTATE=1
		########### rsnapshot call, rotate ######################
   		/usr/bin/rsnapshot -c ${cfg_file} ${INTERVAL} >> ${RSYNCLOGFILE}
	        RETROTATE=$?
                #datelog "${FILENAME}: rotate return: $RETROTATE"
                TODAY_RSYNC2_END=`date +%Y%m%d-%H%M`
                write_rsynclog "${FILENAME}: end   ${INTERVAL} -- $TODAY_RSYNC2_END"
                if test $RETROTATE -ne 0 
                then
			datelog "${FILENAME}: ==> error in rsnapshop, in '${cfg_file}' "
		else
			zero_interval_folder=$( echo "${RSNAPSHOT_ROOT}${INTERVAL}.0" )
			dlog "interval.0 folder: ${zero_interval_folder} check"
			if test -d ${zero_interval_folder} 
			then
				dlog "interval.0 folder: ${zero_interval_folder} exists"
				TODAY_LOG1=`date +%Y-%m-%dT%H:%M`
				echo "created in ${INTERVAL}, at ${TODAY_LOG1}. loop: $runningnumber" > ${zero_interval_folder}/created_in_${INTERVAL}_at_${TODAY_LOG1}_number_$runningnumber.txt
			fi
                fi
       	else
               	datelog "${FILENAME}: ==> return in sync first wasn't ok, check disk or config in  '${cfg_file}' "
        fi
		
else
	datelog "${FILENAME}: ==> can't execute -->: '${RSNAPSHOT_CFG}', interval '$INTERVAL' is not in '${cfg_file}' "
fi

sync

dlog "== end bk_rsnapshot.sh: $rs_exitcode =="
tlog "end, code: $rs_exitcode"

exit $rs_exitcode

# rsync errors
#       0      Success
#       1      Syntax or usage error
#       2      Protocol incompatibility
#       3      Errors selecting input/output files, dirs
#       4      Requested  action not supported: an attempt was made to manipulate 64-bit files on a platform 
#              that cannot support them; or an option was specified that is supported by the client and not by the server.
#       5      Error starting client-server protocol
#       6      Daemon unable to append to log-file
#       10     Error in socket I/O
#       11     Error in file I/O
#       12     Error in rsync protocol data stream
#       13     Errors with program diagnostics
#       14     Error in IPC code
#       20     Received SIGUSR1 or SIGINT
#       21     Some error returned by waitpid()
#       22     Error allocating core memory buffers
#       23     Partial transfer due to error
#       24     Partial transfer due to vanished source files
#       25     The --max-delete limit stopped deletions
#       30     Timeout in data send/receive
#       35     Timeout waiting for daemon connection

# EOF



