#!/bin/bash

# file: bk_disk.sh
# bk_version 22.01.1

# Copyright (C) 2021 Richard Albrecht
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
#	./bk_disks.sh,   all disks,  <- this file
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_


. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./cfg.filenames

. ./src_folders.sh
. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_ssh.sh

# exit values
# exit $BK_EXECONCESTOPPED - test 'exec once' stopped
# exit $BK_NORMALDISKLOOPEND  - 99, normal end
# exit $BK_STOPPED -   normal stop, file 'stop' detected




readonly lv_iscron=$1

readonly lv_tracelogname="disks"

# logname, not readonly, changed to diskname later
lv_cc_logname="disks"

readonly lv_stopfile="stop"

# set internal counter in bash to 0
SECONDS=0

#  is set in cfg.projects
readonly bv_disklist=$DISKLIST


readonly lv_successloglinestxt="successloglines.txt"

# backup waits after end of loop
# 
# min=01, max=23
# identical values means no interval is set
#  lv_waittimestart="09"
#  lv_waittimeend="09"
function get_waittimeinterval() {
	local _waittimeinterval=$waittimeinterval
	local _oldifs=$IFS
	lv_waittimestart="09"
	lv_waittimeend="09"
	IFS='-'
	
	# convert to array
	local dononearray=($_waittimeinterval)
	IFS=$_oldifs
	# read configured values from cfg.loop_time_duration
	if [ ${#dononearray[@]} = 2 ]
	then
		lv_waittimestart=${dononearray[0]}
		lv_waittimeend=${dononearray[1]}
	fi
}



function rsyncerrorlog {
	local _TODAY=$( currentdate_for_log )
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $bv_internalerrors
}


# programmmed stop, if something has happened
# executed after 'is_number $_minutes'
# $1 = short text, reason for stop
# used only in tests for valid waittimes, all numbers, no alpha-chars
# see 'is_number'
function stop_exit(){
	local _name=$1
	dlog "$text_marker ${text_stop_exit}: by '$_name'"
	exit $BK_STOPPED
}



# file 'stop' is tested, set manually with 'stop.sh'
# $1 = Name des Ortes, in dem stop getestet wird
function check_stop(){
	local _name=$1
	if test -f $lv_stopfile
	then
		local msg=$( printf "%05d"  $( get_loopcounter  ) )
		dlog "$text_backup_stopped in '$_name', counter: $msg  "
		rm $lv_stopfile
		exit $BK_STOPPED
	fi
	return 0
}

# return
#  0, if number
#  1, if contains chars
#  1, if string doesn't exist
function is_number(){
	local _input=$1	
	if [[ -z $_input ]]
	then
		# not a number, length = 0
		return 1
	fi
	# remove all numbers from _input
	#	${_input//[0-9]/} 
	#
	# if length is zero, the it was a number
	# -n = nicht length 0 
	if [[ ! -n ${_input//[0-9]/} ]]
	then
		# is number
		return 0
	fi
	# not a numbersuccessloglinestxt
}
  

function loop_minutes (){
	local _minutes=$1
	is_number $_minutes
	local _RET=$?
	if [ $_RET -eq 1 ]
	then
		stop_exit "minute '$_minutes' is not a string with numbers"
	fi
	local _seconds=$(( _minutes * 60 ))
	local _sleeptime="10"
	if [ $bv_test_short_minute_loop_seconds_10 -eq 1 ]
	then
		_seconds=$(( _minutes * 10 ))
	fi
	local _minute=$(date +%M)
	local _count=0
	if [ $bv_test_short_minute_loop -eq 0 ]
	then
		while [  $_count -lt $_seconds ] 
		do
			# sleep 
			sleep  $_sleeptime
			_count=$(( _count + _sleeptime ))
			dlog "in loop minutes: $_count seconds"
			check_stop "in 'loop_minutes', value of seconds: $_seconds"
		done
	fi
	check_stop "loop minutes, end"
	return 0
}

# par1 = target minute 00 < par1 < 59
# used in 'loop_to_full_next_hour()'
function loop_until_minute  {
	local _endminute=$1
	is_number $_endminute 
	RET=$?
	if [ $RET -eq 1 ]
	then
		stop_exit "minute '$_endminute' is not a string with numbers"
	fi
	local _sleeptime="2"
	local _minute=$(date +%M)
	while [  $_minute -ne $_endminute ] 
	do
		# sleep 2 sec
		sleep  $_sleeptime
		# every 2 sec check stop
		check_stop "in loop_until_minute: $_minute "
		_minute=$(date +%M)
	done
	return 0
}


# wait, until minute is 00 in next hour
# exits, if stop is found
function loop_to_full_next_hour {
	local _minute=$(date +%M)

	# if minute is '00', then count to 1 minute and ten to '00', until next full hour  
	#  if [ $_minute == "00"  ] | $_minute == "15" | $_minute == "30" | $_minute == "45"  
	if [ $_minute == "00" ]
	then
		# if full hour, then wait 1 minute
		loop_until_minute "01"
	fi
	# wait until next full hour
	loop_until_minute "00"
	return 0

}


# parameter
# 1 = list successlist[@] 
# 2 = list unsuccesslist[@] 
function successlog {
	
	# defined in cfg.target_disk_list
	# list of headers 
	declare -a successline=( $SUCCESSLINE )
#set +u
	declare -a slist=("${!1}")
	declare -a unslist=("${!2}")
#set -u
	local line="" 
	for _s in "${successline[@]}"
	do
#		dlog "successlog: item '$_s'"
		value="-"
		for item in "${slist[@]}" 
		do
			#dlog "item in slist:  $item, s: $_s" 
			if test "$_s" = "$item" 
			then
				value="ok"
			fi
		done
		for item in "${unslist[@]}" 
		do
        		#dlog "item in unslist:  $item, s: $_s" 
			if test "$_s" = "$item" 
			then
				value="nok"
			fi
		done
		txt=$( printf "%${SUCCESSLINEWIDTH}s" $value )
		line=$line$txt
	done


	local ff=$lv_successloglinestxt
	local _TODAY=$( currentdate_for_log )
#	dlog " $_TODAY: $line" 

	# add line to lv_successloglinestxt
	echo "$_TODAY: $line" >> $ff

	# copy lv_successloglinestxt to local folder, in any case, also if sshlogin is empty
	dlog "cp $lv_successloglinestxt  ${bv_backup_messages_testfolder}/${file_successloglines}"
	cp $lv_successloglinestxt  ${bv_backup_messages_testfolder}/${file_successloglines}


	#if [ ! -z $sshlogin ] # in successlog
	# if sshlogin is not empty, send lv_successloglinestxt to remote Desktop
	# aus cfg: sshlogin=
	if [  -n  "${sshlogin}" ] 
	then
		ssh_port=$( func_sshport )
#		dlog "successlog : login: '${sshlogin}', host: '${sshhost}', target: '${sshtargetfolder}', port: '${ssh_port}'"
		if [ "${sshhost}" == "localhost" ] || [ "${sshhost}" == "127.0.0.1" ]
		then
			COMMAND="cp ${ff} ${sshtargetfolder}${file_successloglines}"
			dlog "copy logs to local Desktop: $COMMAND"
			COMMAND="rsync -av --delete ${bv_backup_messages_testfolder}/ ${sshtargetfolder}"
			dlog "rsync command; $COMMAND"
			dlog "chown -R ${sshlogin}:${sshlogin} ${sshtargetfolder}"
			chown -R ${sshlogin}:${sshlogin} ${sshtargetfolder}
		else
			# is in cfg.ssh_login
			# in 'successlog' do_ping_host 
			# check, if host is available
			dlog "do_ping_host ${sshlogin}@${sshhost}:${sshtargetfolder}"
			do_ping_host ${sshlogin} ${sshhost} ${sshtargetfolder}
			RET=$?
			# dlog "ping, RET: $RET"
			if [ $RET -eq  0 ]
			then
				# copy to remote target folder
				dlog "rsync -av --delete -e 'ssh -4 -p 4194' ${bv_backup_messages_testfolder}/ ${sshlogin}@${sshhost}:${sshtargetfolder} -P"
				#rsync -a --delete -e 'ssh -4 -p 4194' ${bv_backup_messages_testfolder}/ ${sshlogin}@${sshhost}:${sshtargetfolder} -P >> $bv_rsynclogfile
				rsync -a --delete -e 'ssh -4 -p 4194' ${bv_backup_messages_testfolder}/ ${sshlogin}@${sshhost}:${sshtargetfolder} -P 
				RET=$?
				if [ $RET -gt 0 ]
				then
					dlog "rsync failed, target for log messages is not available  "
					dlog "COMMAND:  rsync -av --delete -e ssh -4 -p 4194 ${bv_backup_messages_testfolder}/ ${sshlogin}@{$sshhost}:${sshtargetfolder}"
					dlog ""
				else
					dlog "rsync was ok"
				fi
			else
				dlog "host $sshlogin@$sshhost is not up, is not copied"
			fi
		fi
	else
		dlog "'sshlogin' is empty"
	fi
}


function write_header(){

	declare -a successline=( $SUCCESSLINE )

	# use first entry in header array for grep 
	local firstheader=${successline[0]}

	# get count of lines without header
	local count=$( cat $lv_successloglinestxt | grep -v $firstheader | wc -l )
	local divisor=20
	local n=$(( count % divisor ))

	# if count is divideable by 20, write header
	if test $n -eq 0 
	then
		# write headers formatted to one line
		line1=""
		for _s in ${successline[@]}
        	do

			# write line in field, width = 15
			txt=$( printf "%${SUCCESSLINEWIDTH}s" $_s )

			# append formatted header to line
			line1=${line1}${txt}
        	done
		ff=$lv_successloglinestxt
        local _TODAY=$( currentdate_for_log )
		# append formatted header line
		echo "$_TODAY: $line1" >> $ff
	fi
}

function list_connected_disks_by_uuid(){
	local _oldifs=$IFS
	IFS=$'\n'

	#ls -1 /dev/disk/by-uuid/
	for _uuid in $(ls -1 /dev/disk/by-uuid/)
	do
		_line=$(grep  ${_uuid}  uuid.txt)
		# Following syntax deletes the longest match of $substring from front of $string
		# ${string##substring}
		if ! [ -z "${_line##*swap*}" ] && ! [ -z "${_line##*boot*}" ]
		then
			dlog " all  connected disk:  $_line"
		fi
	done
	IFS=$_oldifs
}


dlog "=== disks start ==="
tlog "start"
check_stop  "at start of loop through disklist (bk_disks.sh)"

#IFS=' '
declare -a successlist
declare -a unsuccesslist

dlog "check all projects in disks: '$bv_disklist'"
dlog ""

dlog "show connected disks:"

list_connected_disks_by_uuid

dlog ""

# loop disk list

# disklist is set in cfg.projects
dlog "execute list: $bv_disklist"
tlog "execute list: $bv_disklist"
for _disk in $bv_disklist
do
	dlog ""
	dlog "==== next disk: '$_disk' ===="


	_FNOLD=$lv_cc_logname
	lv_cc_logname="$_disk"
	dlog ""
	oldifs2=$IFS
	IFS=','
	RET=""
	############################################################################
	# call loop.sh to loop one disk ############################################
	./bk_loop.sh "$_disk"
	############################################################################
        RET=$?
	#dlog "RET nach loop: $RET"


	# possible exit values from 'bk_loop.sh'
	# exit BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
	# exit $BK_ARRAYSNOK         	- property arrays have errors
	# exit $BK_DISKLABELNOTFOUND	- disk with uuid nit found in /dev/disk/by-uuid, disk ist not in system 
	# exit $BK_NOINTERVALSET	- no backup time inteval configured in 'cfg.projects'
	# exit $BK_TIMELIMITNOTREACHED	- for none project at this disk time limit is not reached
	# exit $BK_DISKNOTUNMOUNTED	- ddisk couldn't be unmounted
	# exit $BK_MOUNTDIRTNOTEXIST	- mount folder for backup disk is not present in '/mnt'
	# exit $BK_DISKNOTMOUNTED	- disk couldn't be mounted 
	# exit $BK_DISKNOTMOUNTED	- rsync error, see logs
	# exit $BK_SUCCESS		- all was ok



	IFS=$oldifs2
	dlog " end of 'bk_loop.sh'"
	msg=""
	PROJECTERROR="false"
	lv_cc_logname=$_FNOLD

	if [[ $RET = "$BK_NOINTERVALSET" ]]
	then
		msg="for one project of disk '$_disk' time interval is not set"
	fi
	if [[ $RET = "$BK_DISKLABELNOTFOUND" ]]
	then
		# no error, normal use of disks
		dlog "HD with label: '$_disk' not found ..." 
	fi
	if [[ $RET = "$BK_MOUNTDIRTNOTEXIST" ]]
	then
		msg="mountpoint for HD with label: '$_disk' not found: '/mnt/$_disk' "
	fi

	if [[ $RET = "$BK_DISKNOTMOUNTED" ]]
	then
		msg="HD with label: '$_disk' couldn't be mounted" 
	fi
	if [[ ${RET} == "$BK_DISKNOTUNMOUNTED" ]]
	then
		msg="HD with label: '$_disk' couldn't be unmounted" 
	fi
	if [[ ${RET} == "$BK_RSYNCFAILS" ]]
	then
		msg="rsync error in disk: '$_disk'"
		PROJECTERROR="true"
		RET=$BK_SUCCESS
	fi
	# test msg: msg="test abc"
	#msg="test abc"
	if [ "$msg" ]
	then
		rsyncerrorlog "$msg"
		#dlog "$msg" 
	fi

	if [[ ${RET} == "$BK_SUCCESS" ]]
	then
		if [[ $PROJECTERROR == "true" ]]
		then
			dlog "'$_disk' done, min. one project has rsync errors, see log"
		else
			dlog "'$_disk' successfully done"
		fi
#		dlog   "cat bv_successarray: $( cat $bv_successarray )"
		# defined in  filenames.sh
		# successarray and unsuccessarray contain 
		# shortened names, like in header in var SUCCESSLINE="c:dserver ...."
		if test -f "$bv_successarray"
		then
			oldifs3=$IFS
			IFS=' '
			successlist=( ${successlist[@]} $(cat $bv_successarray) )
			IFS=$oldifs3
			rm $bv_successarray
		fi
		if test -f "$bv_unsuccessarray"
		then
			oldifs3=$IFS
			IFS=' '
			unsuccesslist=( ${unsuccesslist[@]} $(cat $bv_unsuccessarray) )
			IFS=$oldifs3
			rm $bv_unsuccessarray
		fi
	else
		if [[ "${RET}" == "$BK_TIMELIMITNOTREACHED" ]]
		then
                	dlog "'$_disk' no project has timelimit reached, wait for next loop"
                else
                	if [[ "${RET}" == "$BK_DISKLABELNOTFOUND" ]]
			then
				dlog "'$_disk' is not connected with the server"
			else
				# none of exit values are checked
				dlog  "'$_disk' returns with error: '$RET', see log"
			fi
		fi
	fi
	sync
done
# end loop disk list
dlog ""
dlog "-- end disk list --"
dlog ""
tlog "end list"


#dlog "write success disk: $_disk"
# x replaces successlist, if not empty,  and testet
if [ -z ${successlist+x} ]
then
	_length_successlist=0
else
	_length_successlist=${#successlist[@]}
fi
if [ -z ${unsuccesslist+x} ]
then
	_length_unsuccesslist=0
else
	_length_unsuccesslist=${#unsuccesslist[@]}
fi

if test "$_length_successlist" -eq "0" -a "$_length_unsuccesslist" -eq "0"  
then
	dlog "successarrays are empty, don't write an entry to: $lv_successloglinestxt"
else
	dlog "successarrays are not empty, write success/error entry to: $lv_successloglinestxt"
	write_header
	successlog  successlist[@] unsuccesslist[@] 
fi


# SECONDS in bash hat die Zeit in Sekunden
dlog "-- used time: $SECONDS seconds"

# log used time in loop.log
TODAY2=$( currentdate_for_log )
counter1=$( get_loopcounter )
projects=""
if [ -f $bv_executedprojectsfile ]
then
	projects=$( cat $bv_executedprojectsfile ) 
	rm $bv_executedprojectsfile
fi
#dlog "projects: $projects"
_seconds=$( printf  "%3d" $SECONDS )
_counter=$( printf  "%5d" $counter1 )

loopmsg=$(  echo "$TODAY2, seconds: $_seconds,  loop: $_counter, $projects" )

dlog "loopmsg: $loopmsg "
#echo "$loopmsg" >> loop.log


#IFS=$_oldifs

# end full backup loop
# lookup for waittimeinterval


dlog ""

get_waittimeinterval

dlog "waittime interval:  $lv_waittimestart - $lv_waittimeend "


hour=$(date +%H)


# check for stop with 'bv_test_execute_once'
if [ $bv_test_execute_once -eq 1 ]
then
	# bv_test_do_once_count=0
	dlog "'execute once' set, stop loop, max count: '$bv_test_do_once_count'"
	exit $BK_EXECONCESTOPPED
fi



# check for stop in wait interval

dlog "if  $hour >= $lv_waittimestart  && $hour  < $lv_waittimeend "
if [ "$hour" -ge "$lv_waittimestart" ] && [ "$hour" -lt "$lv_waittimeend"  ] && [ $bv_test_use_minute_loop -eq 0 ] 
then
	# in waittime interval or minute loop used
	dlog "$text_marker $text_wait_interval_reached, current: $hour, begin wait interval: $lv_waittimestart, end wait interval: $lv_waittimeend"
	count=0
	while [  $hour -lt $lv_waittimeend ] 
        do

		#dlog "time $(date +%H:%M:%S), wait until $lv_waittimeend"
		hour=$(date +%H)
		# every 30 min display a status message
		# 30 min = 1800 sec 
		# 180 counts = 30 min
		if [ $count -eq 180 ]
		then
			count=0
			mminute=$(date +%M)

			#dlog "value of minute, in loop: $mminute"
			dlog "$text_marker ${text_wait_interval_reached}, time $(date +%H:%M:%S), wait until $lv_waittimeend"
		fi
		count=$(( count+1 ))

		# every 10 sec check stop file
		sleep "10s"

		#dlog "before stop: "
		check_stop "wait interval loop"
	done
	_minute2=$(date +%M)
	#dlog " value of minute, after stop interval: $_minute2"
	dlog "$text_marker ${text_waittime_end}, next check at $(date +%H):00"
	#dlog "$text_marker ${text_waittime_end}, next check at $(date -d '+1 hour' '+%H'):00"
	#tlog "wait 1 hour"
#	if [ $bv_test_execute_once -eq 1 ]
#	then
#		dlog "'test_execute_once': stop in 'loop_to_full_next_hour'"
#	fi
# wait one hour ?
#	loop_to_full_next_hour

else
	# not in waittime interval
	hour=$(date +%H:%M)
	dlog "time '$hour' not in waittime interval: '$lv_waittimestart - $lv_waittimeend'"

	loopcounter=$( printf "%05d"  $( get_loopcounter ) )

	# "--- marker ---"	
	# "waiting, backup ready"

	# first show errors
	if [ -s $bv_internalerrors ]
	then
		dlog ""
		dlog "show errors:"
		dlog "$( cat $bv_internalerrors )"
		dlog ""
		dlog "${text_marker_error_in_waiting}, next check at $(date +%H --date='-1 hours ago' ):00, loop: $loopcounter,  stop backup with './stop.sh'"
	else
		dlog "${text_marker_waiting}, next check at $(date +%H --date='-1 hours ago' ):00, loop: $loopcounter,  stop backup with './stop.sh'"
	fi
	# display message and wait
	# lastlogline, this is last line of log, if in wait state
	if [ $bv_test_use_minute_loop -eq 1 ]
	then
		# 'test_use_minute'_loop is set
		tlog "wait minutes: $bv_test_minute_loop_duration"
		dlog "wait minutes: $bv_test_minute_loop_duration"
		# default=2
		mlooptime=$bv_test_minute_loop_duration

		if [ -z $mlooptime  ]
		then
			mlooptime=2
		fi
		dlog "'test_use_minute_loop' is set, wait '$mlooptime' minutes"
		if [ $bv_test_short_minute_loop -eq 1 ]
		then
			dlog "'test_short_minute_loop' set, skip immediately, not waiting '$mlooptime' minutes"
		fi
		 
		if [ $bv_test_short_minute_loop_seconds_10 -eq 1 ]
		then
			_seconds=$((  mlooptime * 10 ))
			dlog "'test_short_minute_loop_seconds_10' is set, one minute ist shortened to 10 seconds, '$_seconds' seconds "
		fi

		loop_minutes $mlooptime 
	else
	        # wait until next full hour
		# skipped if 'test_check_looptimes'=0
		# stop is checked here
		tlog "wait 1 hour"
		#dlog "wait 1 hour", # don't enable this, 'is_stopped.sh' uses last line, and didn't work correct
		if [ $bv_test_check_looptimes -eq 1 ]
		then
			loop_to_full_next_hour
		fi
	fi

fi
dlog "=== disks end  ==="
tlog "end"


# exit BK_NORMALDISKLOOPEND for successful loop
# test_execute_once is 0

exit $BK_NORMALDISKLOOPEND


# EOF



