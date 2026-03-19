#!/bin/bash

# file: bk_main.sh
# bk_version  26.01.1

# Copyright (C) 2017-2025 Richard Albrecht
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
# https://www.gnu.org/licenses/gpl-3.0
#------------------------------------------------------------------------------

# call chain:
# ./bk_main.sh, runs forever, <- this file 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only



# prefixes of variables in backup:
# bv_*  - global vars, all files
# lv_*  - local vars, global in file
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_


# set -u, which will exit your script if you try to use an uninitialised variable.
# = set -o unset 
set -u
#set -e

. ./cfg.working_folder
. ./cfg.projects
. ./cfg.ssh_login

. ./src_test_vars.sh
. ./src_filenames.sh
. ./src_exitcodes.sh
. ./src_log.sh
. ./src_folders.sh
if ! typeset -f  execute_main_begin > /dev/null 
then 
	. ./src_begin_end.sh
fi



# values: "cron"   = backup was started via cronjob
#         "manual" = backup was started via commandline
readonly lv_call_source=$1

readonly lv_lockfilename="main_lock"

# output goes to 'out_bk_main'
# print pwd and current time
echo "start main, working folder: $PWD"
echo "start main, time is:        $( currentdate_for_log )"
# 

readonly lv_tracelogname="main"
readonly lv_cc_logname="main"

tlog "start"


# gawk is used instead of awk
function check_if_gawk_exists {
	which gawk > /dev/null
	local RET=$?
	if [ $RET -ne 0  ]
	then
		dlog "'gawk' not found"
		exit 1
	fi
}


# rsnapshot is used in final backup
function check_if_rsnapshot_exists {
	which rsnapshot > /dev/null
	local RET=$?
	if [ $RET -ne 0  ]
	then
		dlog "'rsnapshot' not found"
		exit 1
	fi
}


function check_working_folder {
	if [ -d "$bv_workingfolder" ] && [ "$PWD" = "$bv_workingfolder" ]
	then
		dlog ""
	else
		dlog "workingfolder '$bv_workingfolder' is wrong, stop, exit 1 "
		exit 1
	fi
}


function start_message {
	local _call_source=$lv_call_source
	dlog ""
	dlog "========================"
	dlog "========================"
	dlog "========================"
	dlog "===  start of backup ==="
	dlog "===  version $bv_version ==="
	dlog "========================"
	local _runningnumber=$( get_runningnumber )

	if [ "$_call_source" = "cron" ]
	then
		dlog "------  is cron start    ------"
	else
		dlog "------  is manual start  ------"
	fi
	dlog ""
	dlog "--> workingfolder: $bv_workingfolder"
}


function check_main_lock {
	local _call_source=$lv_call_source
	# remove main_lock, if is startet via 'cron_start_backup.sh'
	#dlog " =="
	dlog " == check '$lv_lockfilename'"
	# values: "cron"   = backup was started via cronjob
	#         "manual" = backup was started via commandline
	if [ $_call_source = "cron" ]
	then
		# call_source = "cron"
		# if main_lock exists, remove 'main_lock' and starts
		dlog "   check '$lv_lockfilename' for 'cron_start_backup'"
		if [ -f "$lv_lockfilename" ]
		then
			dlog "  '$lv_lockfilename' exists, remove and continue"
			dlog "  rm '$lv_lockfilename'"
			rm $lv_lockfilename
			dlog "  '$lv_lockfilename' removed"
		fi
		dlog "   check 'stop' for 'cron_start_backup'"
		if [ -f "stop" ]
		then
			dlog "  'stop' exists, remove and continue"
			dlog "  rm stop"
			rm stop
			dlog "  'stop' removed"
		fi
	else
		# call_source = "manual"
		# dont't start, if main_lock exists 
		#dlog "check '$lv_lockfilename' for 'start_backup'"
		if [ -f $lv_lockfilename ]
		then
			echo "   backup is running, '$lv_lockfilename' exists"
			dlog "   backup is running, '$lv_lockfilename' exists, exit 1"
			echo "   exit 1"
			dlog "   exit 1"
			exit 1
		fi
	fi
#	dlog " == ok"
}


function check_and_remove_rsnapshot_pid_lock {
	if [ -f  rsnapshot.pid ]
	then
		dlog "old rsnapshot.pid found, has backup_data crashed before?"
		rm rsnapshot.pid
	fi
}


# empty '$bv_internalerrors' = internalerrors.txt
# do not clear in main loop
# errors must be present until solved
function clear_internalerrors_list {
	#dlog " == "
	dlog " == clear error list '$bv_internalerrors'"
	truncate -s 0 $bv_internalerrors
	dlog ""
}


function shatestfile(){
	local _file1=$1
	local _lsum1=$2
	local sum=$( sha256sum $_file1 )
	local a=$( echo $sum | cut -f1 -d " " )
	if [ $_lsum1 != $a ]
	then
		dlog "'$_file' was changed. sha256sum  $a, "
		dlog "         sha256sum  must be $_lsum1 "
		return 1
	fi
	return 0
}


function shatestfiles(){
	local _testfile=$1
	local exitval=0
	local oldifs=$IFS
	IFS=' '
	# read 2 positions in line
	while read -r _lsum _file 
	do
		if [ -f $_file ]
		then
			shatestfile  $_file $_lsum 
			#echo "$_file, $_lsum"
			local RET=$?
			if [ $RET -eq 0 ]
			then
				dlog "  '$_file' is ok"
			else
				exitval=1
			fi
		fi
	#done < <(cat $_testfile )
	done <  $_testfile 

	IFS=$oldifs
	return $exitval
}


function shatest(){
	if [ -f "sha256sum.txt" ]
	then
		dlog " ==  test sha256sums"
		shatestfiles sha256sum.txt
		RETSHA256=$?
		if [ ${RETSHA256} -gt 0  ]
		then
			dlog "sha256sum check fails"
			dlog "create new 'sha256sum.txt' by call of './get_sha256.sh'"
			dlog "start again with './start_backup.sh'"
			exit 0
		else
			dlog "  sha256sum check ok"
		fi
	else
		dlog "sha256sum check fails, file 'sha256sum.txt' is missing"
		dlog "create new file 'sha256sum.txt' by call of './get_sha256.sh'"
		dlog "start again with './start_backup.sh'"
	fi
}


function list_test_flags(){
	dlog " ==  list test flags and variables"
	dlog "   maxlast date:                             $max_last_date"
	dlog "   maxfillbackupdiskpercent (70):            $bv_maxfillbackupdiskpercent"
	dlog "   no_check_disk_done (0):                   $bv_test_no_check_disk_done"
	dlog "   check_looptimes (1):                      $bv_test_check_looptimes"
	dlog "   execute_once (0):                         $bv_test_execute_once"
	dlog "   do_once_count (0):                        $bv_test_do_once_count"
	dlog "   test_use_minute_loop (0):                 $bv_test_use_minute_loop"
	dlog "   test_short_minute_loop (0):               $bv_test_short_minute_loop"
	dlog "   test_short_minute_loop_seconds_10 (0):    $bv_test_short_minute_loop_seconds_10"
	dlog "   test_minute_loop_duration (2):            $bv_test_minute_loop_duration"
	dlog "   daily_rotate (1):                         $bv_daily_rotate"
}


# check existence of folders for rsnapshot configuration files
#  set in file src_folders.sh
#  8 folder
# 	bv_conffolder="conf"
# 	bv_intervaldonefolder="interval_done"
# 	bv_retainscountfolder="retains_count"
# 	bv_backup_messages_testfolder="backup_messages_test"
# 	bv_donefolder="done"
# 	bv_excludefolder="exclude"
# 	bv_oldlogsfolder="oldlogs"
# 	bv_preconditionsfolder="pre"
function check_configuration_folders(){
	dlog " ==  check existence of folders for backup scripts"
	local _folderlist="$bv_folderlist"

	for _folder in $_folderlist
	do
		dlog "   check folder: '$_folder'"
		if  [ ! -d $_folder   ]
		then
			dlog "folder: '$_folder' doesn't exist, exit 1"
			dlog "===================="
			exit 1
		fi
	done
}


# associative arrays for projects
# "a_properties"  - properties for disks
# "a_projects"    - projects per disk
# "a_interval"    - time interval per project
# "a_targetdisk"  - used, if label is changed 
# "a_waittime"    - waittime per project
# return $BK_ARRAYSOK or $BK_ARRAYSNOK
function check_arrays {
	dlog " ==  check arrays in 'cfg.projects'"

	local arrays_ok=$BK_ARRAYSOK

	# find arrays in cfg.projects
	arrays="$( cat cfg.projects |  grep '()' | grep -v '#' | gawk -F= '{print $1}' )"
	for _arr in ${arrays[@]}
	do
		is_associative_array $_arr
		local arrayRET=$?
		if [ $arrayRET -ne 0 ]
		then
			if [ $arrayRET -eq $BK_ASSOCIATIVE_ARRAY_NOT_EXISTS ]
			then
				dlog "   array '$_arr' doesn't exist"
				dlog "   -- add array entry with"
				dlog "      'declare -A $_arr'"
				dlog "      '$_arr=()'"
				dlog "      ------"
				arrays_ok=$BK_ARRAYSNOK
			fi
			if [ $arrayRET -eq $BK_ASSOCIATIVE_ARRAY_IS_EMPTY ]
			then
				dlog "   array '$_arr' is empty"
			fi
			if [ $arrayRET -eq $BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY ]
			then
				dlog "   array '$_arr' is not empty"
			fi
		fi
	done

	if test $arrays_ok -ne $BK_ARRAYSOK 
	then
		dlog "!! arrays in 'cfg.projects' are defined incorrectly !!"
		exit $arrays_ok
	fi
	return $arrays_ok
}


# set in cfg.ssh_login
function check_ssh_config(){
	if ! check_ssh_configuration
	then
		return 1
	fi
	if ! check_ssh_configuration2
	then
		return 1
	fi
}


function rotate_logs(){
	# date in year month day
	local _date=$(date +%Y-%m-%d)
	local _oldlogdir=$bv_oldlogsfolder/$_date

	# if _oldlogdir with date doesn't exist
	if [ ! -d "$_oldlogdir" ]
	then

		if [ $bv_daily_rotate -eq 1 ]
		then
			dlog "rotate log to '$_oldlogdir'"
			mkdir $_oldlogdir
			mv aa_* $_oldlogdir
			mv rr_* $_oldlogdir
			mv $bv_logfile $_oldlogdir
#			mv $bv_errorlog $_oldlogdir
			mv $bv_tracefile $_oldlogdir
			if [ -f label_not_found.log ]
			then
				mv label_not_found.log "$_oldlogdir"
			fi
			# create new, empty files
			touch $bv_logfile
#			touch $bv_errorlog
			touch $bv_tracefile
			dlog "log rotated to '$_oldlogdir'"

			# date: year month 01
			local _date01=$(date +%Y-%m-01)
			dlog "rotate monthly, if date '$_date01'"
			# if _date = first of month, save logs 
			if [[ ${_date01} == ${_date} ]]
			then
				dlog "rotate monthly at '$_date'"
				dlog "rotate successloglines.txt '$_date'"
				mv successloglines.txt $_oldlogdir
				touch successloglines.txt 
			fi
		fi
	fi
}


function set_lock(){
	local _runningnumber=$( printf "%05d"  $( get_loopcounter ) )
	local _lock_date=`date +%Y%m%d-%H%M%S`
	dlog "${_lock_date}: create file '$lv_lockfilename'"
	touch $lv_lockfilename
	echo "$_runningnumber" > $lv_lockfilename
}


function release_lock(){
	if [ -f $lv_lockfilename ]
	then
		local _release_date=`date +%Y%m%d-%H%M%S`
		echo "$_release_date: remove file '$lv_lockfilename'"
		dlog "$_release_date: remove file '$lv_lockfilename'"
		rm $lv_lockfilename
	fi
}


check_if_gawk_exists 
check_if_rsnapshot_exists

check_working_folder
start_message
check_main_lock
check_and_remove_rsnapshot_pid_lock
clear_internalerrors_list 

# if fails, create sha file manually, if needed
# sha256sum.sh generates sha256sum.txt
shatest
dlog ""
list_test_flags

# check folder for rsnapshot configuration files
check_configuration_folders

# check_existence_of_arrays_in_cfg
#  is in scr_log.sh
check_arrays
RET=$?
if test $RET -ne $BK_ARRAYSOK 
then
	dlog "!! arrays in 'cfg.projects' are defined incorrectly !!"
	exit $BK_ARRAYSNOK
fi
dlog ""


# check ssh values in cfg.ssh_login
dlog " ==  check ssh configuration to send success messages"
if ! check_ssh_config
then	
	exit 1
fi

# loop, until 'bk_disks.sh' returns  not '$BK_NORMALDISKLOOPEND'
do_once_counter=0

# start of main loop
# runs, until stop.sh ist executed
while true
do
	dlog "" 
	_runningnumber=$( get_runningnumber )
	# _runningnumber is incremented ai loop end in 'increment_loop_counter'

	tlog "counter $_runningnumber"
	dlog " ===== start main loop ($_runningnumber) =====" 
	dlog " ===   version: $bv_version   ==="
	_hostname="$(hostname)"
	dlog " ===   hostname: $_hostname   ==="

	# rotate log
	rotate_logs

	dlog ""

	#  e.g. conf/sdisk_start,sh
	# in conf folder
	# shell script, executed at start of disk
	# execute_main_end is in bk_disks.sh line 1036
	
	execute_main_begin
	eRET=$?
	if [ $eRET -gt 0 ]
	then
		dlog "execute_main_begin: RET: $eRET"
		exit 1
	fi

	# set lock
	set_lock
	# sync after set_lock
	sync

	dlog ""
	# call 'bk_disks.sh' to loop over all backup disks 
	##########################################################################################
	./bk_disks.sh 
	dRET=$?
	# RdET can't be 'readonly'
	##########################################################################################

	# exit values from 'bk_disks.sh'
	# exit $BK_EXECONCESTOPPED - test 'exec once' stopped
	# exit $BK_NORMALDISKLOOPEND  - 99, normal end
	# exit $BK_STOPPED -   normal stop, file 'stop' detected
	

	# release lock
	release_lock


	# increment counter 
	increment_loop_counter
	_runningnumber=$( get_runningnumber )


#       RET = EXECONCESTOPPED,    if stop ist executed by 'test_execute_once' = 1
#       RET = NORMALDISKLOOPEND,  if all is ok and normal loop
#       RET = STOPPED,            if stop ist executed by hand and 'test_execute_once' = 0

	endmsg=""
	if [ $dRET -eq $BK_DISK_TEST_RETURN ]
	then
		endmsg="--- test return from bk_disks.sh"
	fi
	if [ $dRET -eq $BK_NORMALDISKLOOPEND ]
	then
		endmsg="all is ok, is 'normal wait in loop'"
	fi
	if [ $dRET -eq $BK_STOPPED ]
	then
		endmsg="stop is 'manually stopped'"
	fi
	if [ $dRET -eq $BK_EXECONCESTOPPED ]
	then
		endmsg="stop, is 'run once only'"
	fi
	if test $dRET -eq $BK_MAIN_END_FAILED 
	then
		endmsg="main end error"
	fi

	dlog "---  last return says: $endmsg "
#	dlog "---    values are: 'normal stop in loop', 'manually stopped', 'run once only'"
	# sync at main loop end
	sync
	sleep 0.5


	if [ $dRET -eq $BK_DLOG_CC_LOGNAME_NOT_SET ]
	then
		echo "dlog cc_logname not set"
		exit 1
	fi

	#  all was ok, check for next loop
	if [ $dRET -eq $BK_NORMALDISKLOOPEND ] 
	then
		if [ -s $bv_internalerrors ]
		then
			dlog "" 
			dlog "errors in backup loop: "
			dlog "" 
			dlog "errors:" 
			dlog "$( cat $bv_internalerrors )"
			dlog "" 
			dlog "$text_marker_error, last loop counter: '$_runningnumber'"
			dlog "" 
		fi
	fi	


	# $BK_DISK_TEST_RETURN, exit
	# early return for tests only
	if [ $dRET -eq $BK_DISK_TEST_RETURN ]
	then
		dlog "--- test return from bk_disks.sh"
		exit 0
	fi

	# BK_STOPPED, exit
	if [ $dRET -eq $BK_STOPPED ]
	then
		if [ -s $bv_internalerrors ]
		then
			dlog "" 
			dlog "--- stop was set, errors in backup: "
			dlog "" 
			dlog "errors:" 
			dlog "$( cat $bv_internalerrors )" 
			dlog "" 
			dlog "$text_marker_error_in_stop, last loop counter: '$_runningnumber', RET=$dRET "
		else
			dlog "$text_marker_stop, end reached, start backup again with './start_backup.sh'"
		fi
		# normal stop via stop.sh
		# no 'test_do_once_count' is set in 'src_test_vars.sh'
		#dlog "stopped with 'stop' file"
		tlog "end, return from bk_disks: $dRET"
		exit 1
	fi

	if [ $dRET -eq $BK_EXECONCESTOPPED ]
	then
		if [ -s $bv_internalerrors ]
		then
			dlog "" 
			dlog "'test_execute_once' was set, errors in backup: "
			dlog "" 
			dlog "errors:" 
			dlog "$( cat $bv_internalerrors )" 
			dlog "" 
			dlog "$text_marker_error, last loop counter: '$_runningnumber', RET=$dRET "
		fi


		# check, if _'test_do_once_count' is set
		if [ $bv_test_do_once_count -gt 0 ]
		then
			# increment 'do_once_counter' and check nr of counts
			((do_once_counter=do_once_counter+1))
			dlog "do_once_counter = $do_once_counter"
			if [ $do_once_counter -lt $bv_test_do_once_count ]
			then
				# 'test_do_once_count' is not reached, start new loop
				dlog "$text_marker_test_counter, 'test_do_once_count' loops not reached, '$do_once_counter -lt $bv_test_do_once_count' "
				sleep 5
				# goto end of loop
			else
				# 'test_do_once_count' is reached, exit
				dlog "$text_marker_stop, end, 'test_do_once_count' loops reached, '$do_once_counter -eq $bv_test_do_once_count' "
				# sync vor exit 1, 'test_do_once_count'
				sync
				exit 1
			fi
		else
			# 'test_execute_once' is set, exit
			dlog "$text_marker_stop, end reached, 'test_execute_once', RET: '$dRET', exit 1 "
			tlog "end, 'test_execute_once', return from bk_disks.sh: $dRET"
			# sync vor exit 1, 'test_execute_once'
			sync
			exit 1
		fi
	fi
	if test $dRET -eq $BK_MAIN_END_FAILED 
	then
		dlog "error return: RET: '$dRET', txt :'$text_main_end_failed'"
		if test -f $bv_stopfile
		then
			dlog "remove stop file"
			rm $bv_stopfile
		fi
		exit 1
	fi

	# some cleanup can be done here
	# after all is ok, after stop evaluation

	# no stop was set
	dlog " ----> goto next loop  <----"
	tlog " ----> goto next loop  <----"
	sleep 1

done

# end

dlog "execute loop: shouldn't be reached"
exit 0

# EOF



