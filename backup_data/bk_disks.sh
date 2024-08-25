#!/bin/bash

# shellcheck disable=SC2155
# disable: Declare and assign separately to avoid masking return


# file: bk_disk.sh
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
. ./cfg.successloglineheader
. ./cfg.projects
. ./cfg.ssh_login

. ./src_folders.sh
. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh



# set -u, which will exit your script if you try to use an uninitialised variable.
set -u

# exit values
# exit $BK_EXECONCESTOPPED - test 'exec once' stopped
# exit $BK_NORMALDISKLOOPEND  - 99, normal end
# exit $BK_STOPPED -   normal stop, file 'stop' detected


# in start_backup.sh:nohup ./bk_main.sh "manual"
# in cron_start_backup.sh:nohup ./bk_main.sh "cron"
readonly lv_iscron=$1

# in function tlog() in src_log.sh
readonly lv_tracelogname="disks"

#  in cfg.projects
readonly bv_disklist=$DISKLIST


# logname, not readonly, changed to diskname later
# must be set, if empty 
# used in function dlog un src_log.sh
# $lv_cc_logname must be set at start of each bk_ file
# changed to diskname var in line 541 and 543
lv_cc_logname="disks"

readonly lv_stopfile="stop"

# set internal counter in bash to 0
SECONDS=0

readonly lv_successloglinestxt="successloglines.txt"



# backup waits after end of loop
# 
# min=01, max=23
# identical values means no interval is set
#lv_waittimestart="09"
#lv_waittimeend="09"
#function get_globalwaittimeinterval() {
#	local _w=$1
#	# 'waittimeinterval' ist set in cfg.waittimeinterval 
#	local _waittimeinterval=$_w
#	local _oldifs=$IFS
#	IFS='-'
#	# split to array with ()
#	local dononearray=($_waittimeinterval)
#	IFS=$_oldifs
#	# read configured values from cfg.waittimeinterval
#	# must be 2 values
#	if [ ${#dononearray[@]} = 2 ]
#	then
#		# copy to local vars, global in file
#		lv_waittimestart=${dononearray[0]}
#		lv_waittimeend=${dononearray[1]}
#	fi
#}



function rsyncerrorlog {
	local _TODAY=$( currentdate_for_log )
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $bv_internalerrors
        # defined in scr_filenames.sh
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
		local msg=$( printf "%05d"  "$( get_loopcounter  )" )
		dlog "$text_backup_stopped in '$_name', counter: $msg  "
		dlog "remove stop file"
		rm $lv_stopfile
		dlog "exit bk_stopped"
		exit $BK_STOPPED
	fi
	#dlog "don't stop"
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
        #       ${_input//[0-9]/}
        #
        # if length is zero, the it was a number
        # -n = nicht length 0
        local _var=${_input//[0-9]/}
        if [[ ! -n ${_var} ]]
        then
                # is number
                return 0
        fi
        # not a numbersuccessloglinestxt
        return 1
}


# used in $bv_test_use_minute_loop
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
	local _count=0
	local _minute=$(date +%M)
	while [  $_minute -ne $_endminute ] 
	do
		# sleep 2 sec
		sleep  $_sleeptime
		# every 2 sec check stop
		check_stop "in loop_until_minute: $_minute "
		_minute=$(date +%M)
		_count=$(( _count + _sleeptime ))
		# count until 900 sec done = 15 minutes
		if [ $_count -gt 900 ]
		then
			dlog "minute: $_minute"
			_count=0
		fi
	done
	return 0
}


# wait, until minute is 00 in next hour
# exits, if stop is found
function loop_to_full_next_hour {
	local _minute=$(date +%M)

	# if minute is '00', then count to 1 minute and ten to '00', until next full hour  
	#  if [ $_minute = "00"  ] | $_minute = "15" | $_minute = "30" | $_minute = "45"  
	if [ $_minute = "00" ]
	then
		# if full hour, then wait 1 minute
		loop_until_minute "01"
	fi
	# wait until next full hour
	loop_until_minute "00"
	return 0

}
function do_ping_host {

        local _USER=$1
        local _HOST=$2
        local _FOLDER=$3
        local _PORT=$4

        #dlog "in ping, host: $_HOST"
        ping -c1 $_HOST &> /dev/null
	RET=$?
        if test $RET -eq 0
        then
#                 dlog "ping ok  ping -c1 $_HOST "
                ssh_test_str="x=99; y=88; if test  -d $_FOLDER; then  exit 99; else exit 88; fi" 
                ssh_test_login="ssh -p $_PORT $_USER@$_HOST '${ssh_test_str}'"
                eval ${ssh_test_login}  &> /dev/null
                local _RET=$?
                if test  $_RET -eq 99; then
                        # host exists
                        return 0
                fi
        fi
        return 1
}


declare -a lv_disks_successlist
lv_disks_successlist=()
declare -a lv_disks_unsuccesslist
lv_disks_unsuccesslist=()

# global parameter
# lv_disks_successlist[@] 
# lv_disks_unsuccesslist[@] 
function successlog {
	
	# list of headers 
	# defined in cfg.successloglineheader
	declare -a successline=( $SUCCESSLINE )
	local line="" 
	for _s in "${successline[@]}"
	do
		value="-"
		for item in "${lv_disks_successlist[@]}" 
		do
			if test "$_s" = "$item" 
			then
				value="ok"
			fi
		done
		for item in "${lv_disks_unsuccesslist[@]}" 
		do
			if test "$_s" = "$item" 
			then
				value="nok"
			fi
		done
		local txt=$( printf "%${SUCCESSLINEWIDTH}s" $value )
		line=$line$txt
	done

	local _TODAY=$( currentdate_for_log )

	# add line to lv_successloglinestxt
	echo "$_TODAY: $line" >> $lv_successloglinestxt

	# copy lv_successloglinestxt to local folder, in any case, also if sshlogin is empty
	# sshtargetfolder
	dlog "cp $lv_successloglinestxt  ${bv_backup_messages_testfolder}/${file_successloglines}"
	cp $lv_successloglinestxt  ${bv_backup_messages_testfolder}/${file_successloglines}

}

# parameter
# $1 login: '${sshlogin}', $2 target: '${sshtargetfolder}', $3 host: '${sshhost}', $4 port: '${sshport}' "
# successlog_notifymessages_login ${sshlogin} ${sshtargetfolder} ${sshhost} ${sshport}

function successlog_notifymessages_login {

	local _sshlogin=$1
	local _sshtargetfolder=$2
	local _sshhost=$3
	local _sshport=$4

	dlog "check target folder: '${_sshtargetfolder}'"
#	dlog "login: '${_sshlogin}', target: '${_sshtargetfolder}'"
	# if targetfolder string exists
	if [  -n  "${_sshtargetfolder}" ] 
	then
		if [ "${_sshhost}" = "localhost" ] || [ "${_sshhost}" = "127.0.0.1" ]
		then
			# remove all files in targetifolder*
			# add *, sshtargetfolder has slash at end, in cfg.ssh_login
			local_ssh_targetfolder_wildcard="rm ${_sshtargetfolder}*"
			dlog "targetfolder is at 'localhost', local remove: '$local_ssh_targetfolder_wildcard'"
			eval "$local_ssh_targetfolder_wildcard"
			COMMAND="rsync -a ${bv_backup_messages_testfolder}/* ${_sshtargetfolder}"
			dlog "rsync command: '$COMMAND'"
			eval "$COMMAND"
			RET=$?
			if [ $RET -gt 0 ]
				then
					dlog "local rsync failed"
					dlog ""
				else
					dlog "rsync was ok"
				fi
			targetuser="${sshlogin}"
			dlog "set ownership: 'chown -R ${targetuser}:${targetuser} ${_sshtargetfolder}'"
			chown -R $targetuser:$targetuser  "${_sshtargetfolder}"
		else
			# check, if host is available
			dlog "target folder is remote, check host and folder: '${_sshlogin}@${_sshhost}:${_sshtargetfolder}'"
			do_ping_host "${_sshlogin}" "${_sshhost}" "${_sshtargetfolder}" "${_sshport}"
			RET=$?
			# dlog "ping, RET: $RET"
			if [ $RET -eq  0 ]
			then
				# add *, sshtargetfolder has slash at end, in cfg.ssh_login
				remote_ssh_targetfolder_wildcard="rm ${_sshtargetfolder}*"
				sshlogin_for_remove="ssh -p $_sshport $_sshlogin@$_sshhost '${remote_ssh_targetfolder_wildcard}'"
				dlog "remote remove: '$sshlogin_for_remove'"
				eval "$sshlogin_for_remove"
				# copy to remote target folder, no --delete
				rsync_remote_shell="ssh -4 -p $_sshport"
				COMMAND="rsync -a  -e '$rsync_remote_shell' ${bv_backup_messages_testfolder}/* ${_sshlogin}@${_sshhost}:${_sshtargetfolder} "
				dlog "remote rsync command:  '$COMMAND'"
				eval "$COMMAND"
				RET=$?
				if [ $RET -gt 0 ]
				then
					dlog "remote rsync failed"
					dlog ""
				else
					dlog "remote rsync was ok"
				fi
			else
				dlog "host '$_sshhost' is not up, notify message not copied"
			fi
		fi
	else
		dlog "'sshtargetfolder' is empty"
	fi

}

function successlog_notifymessages {
	dlog ""
	dlog "copy messages to target folder"
	#dlog "login: '${sshlogin}', target: '${sshtargetfolder}', host: '${sshhost}', port: '${sshport}' "
	dlog "check loginname: '${sshlogin}' "
#	dlog "login: '${sshlogin}'"
	# if login exists
	if [  -n  "${sshlogin}" ] 
	then
		successlog_notifymessages_login ${sshlogin} ${sshtargetfolder} ${sshhost} ${sshport}
	else
		dlog "'sshlogin' is empty"
	fi

	# login2
	dlog "check loginname 2: '${sshlogin2}' "
	if [  -n  "${sshlogin2}" ] 
	then
		dlog "login2: '${sshlogin2}', target2: '${sshtargetfolder2}', host2: '${sshhost2}', port2: '${sshport2}' "
		successlog_notifymessages_login ${sshlogin2} ${sshtargetfolder2} ${sshhost2} ${sshport2}
	else
		dlog "'sshlogin2' is empty"
	fi

}

# write a header every 20 lines in successlog
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
		local line1=""
		for _s in ${successline[@]}
		do
			# write line in field
			local txt=$( printf "%${SUCCESSLINEWIDTH}s" $_s )
			# append formatted header to line
			line1=${line1}${txt}
		done
		local _TODAY=$( currentdate_for_log )
		# append formatted header line to file
		echo "$_TODAY: $line1" >> $lv_successloglinestxt
	fi
}

function list_connected_disks_by_uuid(){
	local _oldifs=$IFS
	IFS=$'\n'

#	echo "  connected disks start"
	# ls -1 /dev/disk/by-uuid/
	for _uuid in $(ls -1 /dev/disk/by-uuid/)
	do
		_line=$(grep  ${_uuid}  uuid.txt | grep -v '#' ) || true
		#   Following syntax deletes the longest match of $substring from front of $string
		#   ${string##substring}
		# don't show name swap and boot
		if ! [ -z "${_line##*swap*}" ] && ! [ -z "${_line##*boot*}" ] 
		then
			if echo $_line | grep -v '#'
			then
				dlog "  connected disk:  $_line"
			fi
		fi
	done
#	echo "  connected disks end"
	IFS=$_oldifs
}


dlog "=== disks start ==="


tlog "start"
check_stop  "at start of loop through disklist (bk_disks.sh)"

#IFS=' '

_hostname="$(hostname)"

dlog ""
dlog "show all disks connected at '$_hostname' "
list_connected_disks_by_uuid

dlog ""

dlist=""
for _d in $bv_disklist
do
	td=$( targetdisk "$_d" )
	if [ "$_d" != "$td" ]
	then
		td="${_d}(${td})"
	fi
	dlist="${dlist} $td"
done
dlist="${dlist#"${dlist%%[![:space:]]*}"}"
dlog "check all projects in disks: '$dlist'"
dlog ""

# loop disk list


# disklist is set in cfg.projects
#dlog "execute list: $bv_disklist"
tlog "execute list: $bv_disklist"
for _disk in $bv_disklist
do
	dlog ""
	dlog "==== next disk: '$_disk' ===="

	_old_cc_logname=$lv_cc_logname
	lv_cc_logname="$_disk"
	dlog ""
	oldifs2=$IFS
	IFS=','
	RET=""
	############################################################################
	# call loop.sh to loop over all projects for disk ############################################
	./bk_loop.sh "$_disk"
	############################################################################
        RET=$?
	#dlog "RET nach loop: $RET"

	#    exit values from 'bk_loop.sh'
	# exit BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
	# exit BK_ARRAYSNOK         	- property arrays have errors
	# exit BK_DISKLABELNOTFOUND	- disk with uuid not found in /dev/disk/by-uuid
	# exit BK_NOINTERVALSET		- no backup time inteval configured in 'cfg.projects'
	# exit BK_TIMELIMITNOTREACHED	- for none project at this disk time limit is not reached
	# exit BK_DISKNOTUNMOUNTED	- ddisk couldn't be unmounted
	# exit BK_MOUNTDIRTNOTEXIST	- mount folder for backup disk is not present in '/mnt'
	# exit BK_DISKNOTMOUNTED	- disk couldn't be mounted 
	# exit BK_DISKNOTMOUNTED	- disk couldn't be unmounted
	# exit BK_RSYNCFAILS		- rsync error
	# exit BK_ROTATE_FAILS		- rotate error
	# exit BK_SUCCESS		- all was ok



	IFS=$oldifs2
	dlog " end of 'bk_loop.sh'"
	msg=""
	PROJECTERROR="false"
	lv_cc_logname=$_old_cc_logname
	_targetdisk=$( targetdisk $_disk )

	if test  $RET -eq $BK_NOINTERVALSET 
	then
		msg="for one project in '$_disk' time interval is not set"
	fi
	if test $RET -eq $BK_DISKLABELNOTFOUND 
	then
		# no error, normal use of disks, disk is not present, maybe present at next main loop
		dlog "HD with label: '$_targetdisk' not found ..." 
	fi
	if test $RET -eq $BK_MOUNTDIRTNOTEXIST
	then
		msg="mountpoint for HD with label: '$_targetdisk' not found: '/mnt/$_targetdisk' "
	fi

	if test $RET -eq $BK_DISKNOTMOUNTED 
	then
		msg="HD with label: '$_targetdisk' couldn't be mounted" 
	fi
	if test ${RET} -eq $BK_DISKNOTUNMOUNTED 
	then
		msg="HD with label: '$_targetdisk' couldn't be unmounted" 
	fi
	if test  ${RET} -eq $BK_RSYNCFAILS 
	then
		msg="rsync error in disk: '$_targetdisk'"
		PROJECTERROR="true"
		RET=$BK_SUCCESS
	fi
	if test  ${RET} -eq $BK_ROTATE_FAILS 
	then
		msg="file rotate error in history, check backup disk for errors: '$_targetdisk'"
		PROJECTERROR="true"
		RET=$BK_SUCCESS
	fi
	# test msg: msg="test abc"
	#msg="test abc"
	if test -n "$msg" 
	then
		dlog "rsnapshot error: $msg"
  		rsyncerrorlog "$msg"
	fi

	if test ${RET} -eq $BK_SUCCESS
	then
		if test  "$PROJECTERROR" = "true" 
		then
			dlog "'$_disk' done, min. one project has rsync errors, see log"
		else
			dlog "'$_disk' successfully done"
		fi
		# defined in  scr_filenames.sh
		# successarray and unsuccessarray contain 
		# shortened names, like in header in var SUCCESSLINE="c:dserver ...."
		# read successarray written by bk_loop
		if test -f "$bv_successarray_tempfile"
		then
			oldifs3=$IFS
			IFS=' '
			lv_disks_successlist=( ${lv_disks_successlist[@]} $(cat $bv_successarray_tempfile) )
#			dlog "nachher: $( echo ${lv_disks_successlist[@]} )"
			IFS=$oldifs3
			rm $bv_successarray_tempfile
		fi
		# read unsuccessarray written by bk_loop
		if test -f "$bv_unsuccessarray_tempfile"
		then
			oldifs3=$IFS
			IFS=' '
			lv_disks_unsuccesslist=( ${lv_disks_unsuccesslist[@]} $(cat $bv_unsuccessarray_tempfile) )
			IFS=$oldifs3
			rm $bv_unsuccessarray_tempfile
		fi
	else
		if test ${RET} -eq $BK_TIMELIMITNOTREACHED
		then
			dlog "'$_disk' no project has timelimit reached, wait for next loop"
		else
			if test ${RET} -eq $BK_DISKLABELNOTFOUND 
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

function is_in_global_waitinterval {
	local _waittime=$bv_globalwaittimeinterval
	local wstart=$( get_waittimestart $_waittime )
	local wend=$( get_waittimeend $_waittime )

        local hour=$(date +%H)
        if [ $bv_test_use_minute_loop -eq 0 ]
	then
		if [ "$hour" -ge "$wstart" ] && [ "$hour" -lt "$wend"  ]
		then
			return 0
		fi
	fi
	return 1
}


# arrays exists and can have a length of 0, but are not null
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash/13864829#13864829

_length_successlist=${#lv_disks_successlist[@]}
_length_unsuccesslist=${#lv_disks_unsuccesslist[@]}

if test "$_length_successlist" -eq "0" -a "$_length_unsuccesslist" -eq "0"  
then
	dlog "successarrays are empty, don't write an entry to: $lv_successloglinestxt"
else
	dlog "successarrays are not empty, write success/error entry to: $lv_successloglinestxt"
	write_header
	successlog  
	successlog_notifymessages
fi


# SECONDS, bash has time after start of module in seconds
dlog "--- "
dlog "--- used time: $SECONDS seconds"
dlog "--- "

# log used time in loop.log
TODAY2=$( currentdate_for_log )
lv_executedprojects=""
if [ -f $bv_executedprojectsfile ]
then
	lv_executedprojects=$( cat $bv_executedprojectsfile ) 
	rm $bv_executedprojectsfile
fi
#dlog "lv_projects: $lv_projects"
loopcountertemp=$( get_loopcounter )
#_seconds=$( printf  "%3d" $SECONDS )
loopcounter=$( printf  "%5d" $loopcountertemp )
loopmsg=$(  echo "$TODAY2, loop: $loopcounter, disk and projects: $lv_executedprojects" )

dlog "loopmsg: $loopmsg "


#IFS=$_oldifs

# end full backup loop
# lookup for waittimeinterval


dlog ""

waittimestart=$(  get_waittimestart $bv_globalwaittimeinterval )
waittimeend=$(  get_waittimeend $bv_globalwaittimeinterval )

#get_globalwaittimeinterval $bv_globalwaittimeinterval

#is_waittimeinterval_empty
if test $waittimeend == $waittimestart
then
	# 'bv_globalwaittimeinterval' ist not set in cfg.projects 
	dlog "global waittime interval is not set or '0', set in 'cfg.projects', var 'bv_globalwaittimeinterval'"
fi


# check for stop with 'bv_test_execute_once'
if [ $bv_test_execute_once -eq 1 ]
then
	# bv_test_do_once_count=0
	dlog "'execute once' set, stop loop, max count: '$bv_test_do_once_count'"
	exit $BK_EXECONCESTOPPED
fi



# check for stop in wait interval
is_in_global_waitinterval
RET=$?
if [ "$RET" -eq 0 ] 
then
	# in waittime interval or minute loop used
	wstart=$( get_waittimestart $bv_globalwaittimeinterval )
	wend=$( get_waittimeend $bv_globalwaittimeinterval )
        hour=$(date +%H)
	dlog "$text_marker $text_wait_interval_reached, current: $hour, begin wait interval: $wstart, end wait interval: $wend"
	count=0
	waittimeend=$(  get_waittimeend $bv_globalwaittimeinterval )
	while [  $hour -lt $waittimeend ] 
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
			dlog "$text_marker ${text_wait_interval_reached}, time $(date +%H:%M:%S), wait until $waittimeend"
		fi
		count=$(( count+1 ))

		# every 10 sec check stop file
		sleep "10s"

		#dlog "before stop: "
		check_stop "wait interval loop"
	done
	_minute2=$(date +%M)
	#dlog " value of minute, after stop interval: $_minute2"
	# text_waittime_end="waittime end"
	dlog "$text_marker ${text_waittime_end}, next check at $(date +%H):00"

else
	# check for stop in wait interval
	# not in waittime interval
	# waittime interval = stop from - to
	hour=$(date +%H:%M)
	waittimestart=$(  get_waittimestart $bv_globalwaittimeinterval )
	waittimeend=$(  get_waittimeend $bv_globalwaittimeinterval )
	dlog "time '$hour' not in waittime interval: '$waittimestart - $waittimeend'"

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
		# skipped if 'test_check_looptimes' -eq 0
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



