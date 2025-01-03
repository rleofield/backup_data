#!/bin/bash

# file: bk_rsnapshot.sh

# bk_version 25.01.1


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


# call chain:
# ./bk_main.sh, runs forever 
#	./bk_disks.sh,   all disks  
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with n folder trees,   
#				./bk_rsnapshot.sh,  do rsnapshot   <- this file
#				./bk_archive.sh,    no history, rsync only


# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_


. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_folders.sh
. ./src_log.sh



set -u


# exit values
# exit $BK_NORSNAPSHOTROOT - no backupfolder set at backup disk
# exit $BK_NOINTERVALSET    - no correct interval set in call
# exit $rs_exitcode  - 0, all is ok
# exit $BK_RSYNCFAILS - set in exit_code




# par1 = currentretain
readonly lv_retain=$1 

# par2 = label of backup-disk
readonly lv_disklabel=$2

# par3 = name of the project 
readonly lv_project=$3

# parameter
# $1 = currentretain
# $2 = lv_disklabel 
# $3 = lv_project
readonly lv_tracelogname="rsnapshot"
readonly lv_cc_logname="${lv_disklabel}:rsnapshot:${lv_project}"
readonly lv_lpkey=${lv_disklabel}_${lv_project}


# rsnapshot exit values
# 0 All operations completed successfully
# 1 A fatal error occurred
# 2 Some warnings occurred, but the backup still finished

tlog "start: $lv_lpkey"

lv_logdate=$( currentdate_for_log )

dlog "== start bk_rsnapshot.sh, '$lv_retain' =="
#dlog "-- retain value: '$lv_retain' --"


readonly lv_rsnapshot_config=./${bv_conffolder}/${lv_lpkey}.conf
readonly lv_ro_rsnapshot_root=$(cat ${lv_rsnapshot_config} | grep snapshot_root | grep -v '#' | awk '{print $2}')


if test ! -d $lv_ro_rsnapshot_root 
then
       	dlog "snapshot root folder '$lv_ro_rsnapshot_root' doesn't exist" 
        dlog "give up, also don't do remaining rsnapshots"
	exit $BK_NORSNAPSHOTROOT
fi


#function write_rsynclog {
#	dlog "$1"
#}



# check, if  only one retain line with current retaininterval exists 
readonly lv_count_current_retain=$(cat ${lv_rsnapshot_config} | grep ^retain | grep $lv_retain | wc -l)

# set to 0

if test $lv_count_current_retain -ne  1
then
	dlog "==> can't execute -->: '${lv_lpkey}', interval '$lv_retain' is not in '${lv_rsnapshot_config}' "
	dlog "== end bk_rsnapshot.sh, interval not found in cfg, return '$BK_NOINTERVALSET' =="
	tlog "end, exit code: $BK_NOINTERVALSET"
	exit $BK_NOINTERVALSET
fi

dlog "--- execute -->: '/usr/bin/rsnapshot -c ${lv_rsnapshot_config} ${lv_retain}'"

# get first interval line, 
#  second entry in line is name of interval, eins, zwei or first, second ...
readonly lv_first_retain=$(cat ${lv_rsnapshot_config} | grep ^retain | awk 'NR==1'| awk '{print $2}')


#dlog "${lv_cc_logname}: -----------  first is: ${lv_first_retain}, interval: ${lv_retain}"

# lookup sync_first entry
readonly lv_count_sync_first_lines=$(cat ${lv_rsnapshot_config} | grep ^sync_first |  wc -l)

# do rsync first
lv_rsnapshot_return=0
rs_exitcode=$BK_SUCCESS
rs_exitcode_txt="success"

# if 'sync first' is in cnfig and interval is also first interval, do sync
# sync data to folder .sync in target, only if retain is first in list
if [ $lv_count_sync_first_lines -eq 1  ] 
then 
	# check, if first retain key is is used
	# if, then do sync 
	if [  "${lv_first_retain}" =  "${lv_retain}" ]
	then
		# do sync 
		#dlog "is first retain value: ${lv_first_retain}, do sync" 
		dlog "-- sync data: '/usr/bin/rsnapshot -c ${lv_rsnapshot_config} sync'"
		tlog "rsync"
		readonly lv_rsync_start_logdate=$( currentdate_for_log )
		dlog "-- start sync --" 
		readonly sec=$SECONDS
		##########################################################################################
		########### rsnapshot call, sync ######################
		/usr/bin/rsnapshot -c ${lv_rsnapshot_config} sync 
		##########################################################################################
		lv_rsnapshot_return=$?
		#	0 All operations completed successfully
		#	1 A fatal error occurred
		#	2 Some warnings occurred, but the backup still finished

		readonly sec2=$(( SECONDS - sec ))
		lv_logdate=$( currentdate_for_log )
		
		dlog "return from rsnapshot: $lv_rsnapshot_return, used seconds: $sec2"
		if test $lv_rsnapshot_return -ne 0
		then
			if test $lv_rsnapshot_return -eq 1
			then
				dlog "rsync fails: $lv_rsnapshot_return, A fatal error occurred "
			fi
			if test $lv_rsnapshot_return -eq 2
			then
				dlog "rsync fails: $lv_rsnapshot_return, Some warnings occurred, but the backup still finished (rotate is not done) "
			fi
			# set own exitcode = 'BK_RSYNCFAILS=8'	
			# check for rsync warning: some files vanished before they could be transferred (code 24) at main.c(1865) 
			dlog "rsync fails: retsync: $lv_rsnapshot_return, exit with '$BK_RSYNCFAILS' "
			rs_exitcode=$BK_RSYNCFAILS
			rs_exitcode_txt="rsync fails"
		else
			dlog "sync data of backup to disk, wait"
			sync
			dlog "sync was ok"
			# write marker file with date to backup folder .sync in rsnapshot root"
			runningnumber=$( get_runningnumber )
			TODAY_LOG2=$( currentdateT )

			readonly lv_created_at_filename="$lv_ro_rsnapshot_root.sync/${bv_createdatfileprefix}${TODAY_LOG2}_number_$runningnumber.txt"
			dlog "'created at' info file: '$lv_created_at_filename'"
			readonly lv_created_at_line="created at: ${TODAY_LOG2}, loop: $runningnumber"
			dlog "write line to info file: '$lv_created_at_line'"
			# write control message to .sync folder
			# is moved to first retain folder later
			echo "$lv_created_at_line" > $lv_created_at_filename
			sync
		fi
		readonly lv_rsync_end_logdate=$( currentdate_for_log )
		dlog "-- end  sync --"
	fi
fi


# sync is done or we have a simple rotate
# do rsnapshot rotate, in all cases, also, if no sync was executed, then it is a simple rotate  

# lv_rsnapshot_return > 0  is error
# = 0 all is ok
lv_rotate_return=0
if test $lv_rsnapshot_return -eq 0 
then
	dlog "-- run rotate: '/usr/bin/rsnapshot -c ${lv_rsnapshot_config} ${lv_retain}'"
	lv_rotate_start_logdate=$( currentdate_for_log )
	#write_rsynclog "rotate start ${lv_retain} -- $lv_rotate_start_logdate"
	tlog "rotate: ${lv_retain}"
	##########################################################################################
	########### rsnapshot call, rotate ######################
	/usr/bin/rsnapshot -c ${lv_rsnapshot_config} ${lv_retain} # >> ${RSYNCLOGFILE}
	##########################################################################################
	lv_rotate_return=$?
	lv_rotate_end_logdate=$( currentdate_for_log )
	dlog "rotate end   ${lv_retain} -- $lv_rotate_end_logdate"

	###################### test #######################
	#lv_rotate_return=1


	if test $lv_rotate_return -ne 0 
	then
		if test $lv_rotate_return -eq 1
		then
			dlog "rsync rotate fails: '$lv_rotate_return', A fatal error occurred "
		fi
		if test $lv_rotate_return -eq 2
		then
			dlog "rsync rotate fails: '$lv_rotate_return', Some warnings occurred, but the backup still finished (rotate is not done) "
		fi
		if test $lv_rotate_return -gt 2
		then
			dlog "rsync rotate fails: '$lv_rotatate_return'"
		fi
		# set own exitcode = 'BK_RSYNCFAILS=8'	
		rs_exitcode=$BK_ROTATE_FAILS
		rs_exitcode_txt="rotate fails"
	else
		zero_interval_folder=$( echo "${lv_ro_rsnapshot_root}${lv_retain}.0" )
		dlog "interval.0 folder: ${zero_interval_folder} check, after rotate"
		if test -d ${zero_interval_folder} 
		then
			dlog "interval.0 folder: ${zero_interval_folder} exists"
			runningnumber=$( printf "%05d"  $( get_loopcounter ) )
			TODAY_LOG1=$( currentdateT )
			lv_created_in_filename=${zero_interval_folder}/created_in_${lv_retain}_at_${TODAY_LOG1}_number_${runningnumber}.txt
			echo "created in ${lv_retain}, at ${TODAY_LOG1}. loop: $runningnumber" > ${lv_created_in_filename}
		fi
	fi
else
	dlog "==> return in sync first wasn't ok, check logfile or config in  '${lv_rsnapshot_config}' "
fi

#dlog "sync to disk"
sync

dlog "== end bk_rsnapshot.sh: $rs_exitcode_txt ($rs_exitcode) =="
tlog "end, code: $rs_exitcode"

exit $rs_exitcode


# rsnapshot errors, only 3 values
#	0 All operations completed successfully
#	1 A fatal error occurred
#	2 Some warnings occurred, but the backup still finished

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


