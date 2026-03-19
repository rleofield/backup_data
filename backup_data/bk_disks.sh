#!/bin/bash

# file: bk_disk.sh
# bk_version  26.02.1

# Copyright (C) 2017-2026 Richard Albrecht
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
# bv_*   - global vars, alle files
# lv_*   - local vars, global in file
# lc_*  - local constants, global in file
# _*     - local in functions or loops
# BK_*   - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_


# set -u, which will exit your script if you try to use an uninitialised variable.
set -u


. ./cfg.working_folder
. ./cfg.successloglineheader
. ./cfg.projects
. ./cfg.ssh_login

. ./src_folders.sh
. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
if ! typeset -f  execute_main_begin > /dev/null 
then 
	# used in
	# execute_main_end
	. ./src_begin_end.sh
fi




# exit values
# exit $BK_EXECONCESTOPPED - test 'exec once' stopped
# exit $BK_NORMALDISKLOOPEND  - 99, normal end
# exit $BK_STOPPED -   normal stop, file 'stop' detected


declare -a cfg_successlineheader
declare -a lv_disks_successlist
declare -a lv_disks_unsuccesslist

lv_cc_logname="disks"
readonly lv_tracelogname="disks"

function init_cfg_variables {

	# from cfg.ssh_login
	local _temp=""
	if variable_is_set sshlogin
	then
		_temp=${sshlogin}
	fi
	readonly cfg_sshlogin="$_temp"

	_temp=""
	if variable_is_set sshhost
	then
		_temp=${sshhost}
	fi
	readonly cfg_sshhost="$_temp"

	_temp=""
	if variable_is_set sshport
	then
		_temp="${sshport}"
	fi
	readonly cfg_sshport="$_temp"

	_temp=""
	if variable_is_set sshtargetfolder
	then
		_temp=${sshtargetfolder}
	fi
	readonly cfg_sshtargetfolder="$_temp"
	
	 _temp=""
	if variable_is_set sshlogin2
	then
		_temp=${sshlogin2}
	fi
	readonly cfg_sshlogin2="$_temp"

	_temp=""
	if variable_is_set sshhost2
	then
		_temp=${sshhost2}
	fi
	readonly cfg_sshhost2="$_temp"

	_temp=""
	if variable_is_set sshport2
	then
		_temp="${sshport2}"
	fi
	readonly cfg_sshport2="$_temp"

	_temp=""
	if variable_is_set sshtargetfolder2
	then
		_temp=${sshtargetfolder}2
	fi
	readonly cfg_sshtargetfolder2="$_temp"

	# backup waits after end of loop
	readonly cfg_waittimestart10=$(  get_decimal_waittimestart $bv_globalwaittimeinterval )
	readonly cfg_waittimeend10=$(  get_decimal_waittimeend $bv_globalwaittimeinterval )

	#  get from cfg.projects, var $DISKLIST
	readonly cfg_disklist=$DISKLIST

	# is_waittimeinterval_empty
	if test $cfg_waittimeend10 -eq $cfg_waittimestart10
	then
		dlog "global waittime interval is not set or empty, set in 'cfg.projects', var 'bv_globalwaittimeinterval'"
	fi

	# array of headers 
	# SUCCESSLINE is defined in 'cfg.successloglineheader'
	cfg_successlineheader=( $SUCCESSLINE )
}



function init_local_variables {

	# used in function tlog() in src_log.sh

	# logname, not readonly, changed to diskname later
	# must be set, if empty 
	# used in function dlog in src_log.sh
	# $lv_cc_logname must be set at start of each bk_ file
	# changed to diskname var in line 541 and 543

	readonly lv_successloglinestxt="successloglines.txt"
	readonly lv_stopfile="$bv_stopfile"
	readonly lv_hostname="$(hostname)"

	# set internal counter in bash to 0
	SECONDS=0
	
	# arrays
	lv_disks_successlist=()
	lv_disks_unsuccesslist=()

	# list of all excuted projects at end
	# list is filled in bk_loop.sh
	lv_executedprojects=""
	lv_disklist=""


}



# error in rsync
function rsyncerrorlog {
	local _TODAY=$( currentdate_for_log )
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $bv_internalerrors
        # defined in scr_filenames.sh
	#  readonly bv_internalerrors="errors.txt"
}


# programmmed stop, if something has happened
function stop_exit {
	local _name=$1
	dlog "$text_marker ${text_stop_exit}: by '$_name'"
	exit $BK_STOPPED
}



# file 'stop' is tested, set manually with 'stop.sh'
# $1 = Name des Ortes, in dem stop getestet wird
function check_stop {
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
	return 0
}

# return
#  0, if number
#  1, if contains chars
#  1, if string doesn't exist
function is_number {
        local _input=$1
        if [[ -z $_input ]]
        then
                # not a number, length = 0
                return 1
        fi
        # remove all numbers from _input
        #       ${_input//[0-9]/}
        #
        # if length is zero, then it was a number
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
function loop_minutes {
	local _minutes=$1
	is_number $_minutes
	local isnumber__RET=$?
	if [ $isnumber_RET -eq 1 ]
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
	local isnumber_RET=$?
	if [ $isnumber_RET -eq 1 ]
	then
		stop_exit "minute '$_endminute' is not a string with number"
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
		if [ $_count -ge 900 ]
		then
			dlog "minute: $_minute"
			_count=0
		fi
	done
	return 0
}



function do_ping_host {

        local _USER=$1
        local _HOST=$2
        local _FOLDER=$3
        local _PORT=$4

        #dlog "in ping, host: $_HOST"
        ping -c1 $_HOST &> /dev/null
	local ping_RET=$?
        if test $ping_RET -eq 0
        then
#                 dlog "ping ok  ping -c1 $_HOST "
                ssh_test_str="x=99; y=88; if test  -d $_FOLDER; then  exit 99; else exit 88; fi" 
                ssh_test_login="ssh -p $_PORT $_USER@$_HOST '${ssh_test_str}'"
                eval "${ssh_test_login}"  &> /dev/null
                local ping1_RET=$?
                if test  $ping1_RET -eq 99; then
                        # host exists
                        return 0
                fi
        fi
        return 1
}




# global parameter
# lv_disks_successlist[@] 
# lv_disks_unsuccesslist[@] 
function successlog {
	
	local line="" 
	for _s in "${cfg_successlineheader[@]}"
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
# $1 login: '${cfg_sshlogin}', $2 target: '${cfg_sshtargetfolder}', $3 host: '${cfg_sshhost}', $4 port: '${cfg_sshport}' "
# successlog_notifymessages_send ${cfg_sshlogin} ${cfg_sshtargetfolder} ${cfg_sshhost} ${cfg_sshport}
function successlog_notifymessages_send_host {
	
	local _sshlogin=$1
	local _sshtargetfolder=$2
	local _sshhost=$3
	local _sshport=$4

	# check, if host is available
	dlog "   target folder is remote, check host and folder: '${_sshlogin}@${_sshhost}:${_sshtargetfolder}'"
	do_ping_host "${_sshlogin}" "${_sshhost}" "${_sshtargetfolder}" "${_sshport}"
	ping_RET=$?
	# dlog "ping, RET: $ping_RET"
	if [ $ping_RET -eq  0 ]
	then


		# add *, sshtargetfolder has slash at end, in cfg.ssh_login
		local remote_ssh_targetfolder_wildcard="rm ${_sshtargetfolder}*"
		local sshlogin_for_remove="ssh -p $_sshport $_sshlogin@$_sshhost '${remote_ssh_targetfolder_wildcard}'"
		dlog "   remote remove: '$sshlogin_for_remove'"
		eval "$sshlogin_for_remove"
		# copy to remote target folder, no --delete
		rsync_remote_shell="ssh -4 -p $_sshport"
		COMMAND="rsync -a  -e '$rsync_remote_shell' ${bv_backup_messages_testfolder}/* ${_sshlogin}@${_sshhost}:${_sshtargetfolder} "
		dlog "   remote rsync command:  '$COMMAND'"
		eval "$COMMAND"
		local eval_RET=$?
		if [ $eval_RET -gt 0 ]
		then
			dlog "   remote rsync failed"
			dlog ""
		else
			dlog "   remote rsync was ok"
		fi
	else
		dlog "   host '$_sshhost' is not up, notify message not copied"
	fi
}


function successlog_notifymessages_send_localhost {
	
	local _sshlogin=$1
	local _sshtargetfolder=$2
	#local _sshhost=$3
	#local _sshport=$4

	# remove all files in targetfolder*
	# add *, sshtargetfolder has slash at end, in cfg.ssh_login
	local local_ssh_targetfolder_wildcard="rm ${_sshtargetfolder}*"
	dlog "   targetfolder is at 'localhost', local remove: '$local_ssh_targetfolder_wildcard'"
	eval "$local_ssh_targetfolder_wildcard"
	COMMAND="rsync -a ${bv_backup_messages_testfolder}/* ${_sshtargetfolder}"
	dlog "   rsync command: '$COMMAND'"
	eval "$COMMAND"
	local eval_RET=$?
	if [ $eval_RET -gt 0 ]
	then
		dlog "local rsync failed"
		dlog ""
	else
		dlog "rsync was ok"
	fi
	targetuser="${_sshlogin}"
	dlog "   set ownership: 'chown -R ${targetuser}:${targetuser} ${_sshtargetfolder}'"
}

# parameter
# $1 login: '${cfg_sshlogin}', $2 target: '${cfg_sshtargetfolder}', $3 host: '${cfg_sshhost}', $4 port: '${cfg_sshport}' "
# successlog_notifymessages_send ${cfg_sshlogin} ${cfg_sshtargetfolder} ${cfg_sshhost} ${cfg_sshport}
function successlog_notifymessages_send {

	local _sshlogin=$1
	local _sshtargetfolder=$2
	local _sshhost=$3
	local _sshport=$4

	dlog "   check target folder: '${_sshtargetfolder}'"
#	dlog "login: '${_sshlogin}', target: '${_sshtargetfolder}'"
	# if targetfolder string exists
	if [  -n  "${_sshtargetfolder}" ] 
	then
		if [ "${_sshhost}" = "localhost" ] || [ "${_sshhost}" = "127.0.0.1" ]
		then
			successlog_notifymessages_send_localhost $_sshlogin $_sshtargetfolder 
		else
			successlog_notifymessages_send_host $_sshlogin $_sshtargetfolder $_sshhost $_sshport
		fi
	else
		dlog "'sshtargetfolder' is empty"
	fi

}

function check_loginname {
	local  _loginname=$1
	# if login exists
	if [[   -n  "${_loginname}" ]] 
	then	
		return 0
	fi
	return 1
} 

function successlog_notifymessages {
	dlog ""
	dlog "copy messages to target folder"
	check_loginname "${sshlogin}"
	local _ret=$?
	if [[ $_ret -eq 0 ]]
	then
		dlog "login:  ${cfg_sshlogin},  target:  ${cfg_sshtargetfolder},  host: ${cfg_sshhost},   port: ${cfg_sshport}"
		successlog_notifymessages_send ${cfg_sshlogin} ${cfg_sshtargetfolder} ${cfg_sshhost} ${cfg_sshport}
	else
		dlog "'sshlogin' is empty"
	fi

	# login2
	check_loginname "${sshlogin2}"
	_ret=$?
	if [[ $_ret -eq 0 ]]
	then
		dlog "login2: ${cfg_sshlogin2}, target2: ${cfg_sshtargetfolder2}, host2: ${cfg_sshhost2}, port2: ${cfg_sshport2} "
		successlog_notifymessages_send ${cfg_sshlogin2} ${cfg_sshtargetfolder2} ${cfg_sshhost2} ${cfg_sshport2}
	else
		dlog "'sshlogin2' is empty"
	fi

}

# write a header every 20 lines in successlog
function write_header {

	# use first entry in header array for grep 
	local _firstheader=${cfg_successlineheader[0]}

	# get count of lines without header
	local _line_count=$( cat $lv_successloglinestxt | grep -v $_firstheader | wc -l )

	local _divisor=20
	# modul of _line_count by _divisor
	local _remainder=$(( _line_count % _divisor ))

	# if remainder is zero, write header
	if [[ $_remainder -eq 0 ]]
	then
		# write  formatted headers to one line
		local _formatted_header_line=""
		for _s in ${cfg_successlineheader[@]}
		do
			# write line in field
			local  _formatted_header=$( printf "%${SUCCESSLINEWIDTH}s" $_s )
			# append formatted header to line
			_formatted_header_line=${_formatted_header_line}${_formatted_header}
		done
		local _TODAY=$( currentdate_for_log )
		# append formatted header line to file
		echo "$_TODAY: $_formatted_header_line" >> $lv_successloglinestxt
	fi
}

# success arrays exists and can have a length of 0, but are not null
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash/13864829#13864829
function successlog_send {

	local _length_successlist=${#lv_disks_successlist[@]}
	local _length_unsuccesslist=${#lv_disks_unsuccesslist[@]}

	if test "$_length_successlist" -eq "0" -a "$_length_unsuccesslist" -eq "0"  
	then
		dlog "successarrays are empty, don't write an entry to: $lv_successloglinestxt"
	else
		dlog "successarrays are not empty, write success/error entry to: $lv_successloglinestxt"
		write_header
		successlog  
		successlog_notifymessages
	fi
}


function show_used_seconds {
	dlog "--- "
	dlog "--- used time: $SECONDS seconds"
	dlog "--- "
}

function copy_executedprojects_from_loop_to_disks {
	if [ -f $bv_executedprojectsfile ]
	then
		lv_executedprojects=$( cat $bv_executedprojectsfile ) 
		rm $bv_executedprojectsfile
	fi
}



function list_connected_disks_by_uuid {
	local _oldifs=$IFS
	IFS=$'\n'

	# ls -1 /dev/disk/by-uuid/
	for _uuid in $(ls -1 /dev/disk/by-uuid/)
	do
		if [ $(grep  ${_uuid}  uuid.txt | wc -l) -gt 0 ]
		then
		
			local _line_=$(grep  ${_uuid}  uuid.txt | grep -v '#' ) 
			for _l in $_line_
			do
				

			#   delete the longest match of $substring from front of $string
			#   ${string##substring}
			#   if not swap or boot, show diskname 

				if ! [ -z "${_l##*swap*}" ] && ! [ -z "${_l##*boot*}" ] 
				then
					#  check, if # is not in _line
					if [[ ! "$_l" =~ "#" ]]
					then
						dlog "  connected disk:  $_l"
					fi
				fi
			done
		fi
	done
	#dlog "  connected disks end"
	IFS=$_oldifs
}

function trim_disknames {

	# see
	# http://linux-wiki/dokuwiki/doku.php?id=shell:bash#string_suche

	# ${file%%20*} liefert erstes Vorkommen von Pattern vom Ende und alles davor
	# ${file%%pattern*}
	# %% erstes vom Ende, bis dahin und davor, Wildcard für 'davor' kommt nach dem Pattern

	# suche vom Ende
	# a="abcxxde";echo ${a%%'x'*}
	# liefert "abc",  erstes Vorkommen von x und davor
	# a="abcxxde";echo ${a%'x'*}
	# liefert "abcx", letztes Vorkommen von x und davor


	# erstes Vorkommen von 'kein space=!" "', alles davor 
	# liefert string mit Leerzeichen am Anfang von lv_disklist
	spaces_before=${lv_disklist%%[!" "]*}

	# ${file#*pattern} liefert alles ab erstem Vorkommen von pattern
	# erstes, ab da bis ende, wildcard vorher, wenn nötig 

	# suche vom Anfang
	# a="abcxxde";echo ${a##*'x'} 
	# liefert "de",  letztes Vorkommen von x und dahinter
	# a="abcxxde";echo ${a#*'x'}  
	# liefert "xde", erstes Vorkommen von x und dahinter
	# liefert _dlist ohne leerzeichen am Anfang

	# liefert alles nach 'spaces_before'
	lv_disklist=${lv_disklist#${spaces_before}}
}


function replace_disknames_with_targetdisks {

	lv_disklist=""
	for _disk in $cfg_disklist
	do
		local _targetdisk=$( targetdisk "$_disk" )
		if [ "$_disk" != "$_targetdisk" ]
		then
			_targetdisk="${_disk}(${_targetdisk})"
		fi
		lv_disklist="${lv_disklist} $_targetdisk"
	done
	trim_disknames
}


function call_bk_loop {
	local _disk=$1
	local lv_label_displayname="$_disk"
	local lv_targetdisk=$( targetdisk "$_disk" )
	if [ "$_disk" != "$lv_targetdisk" ]
	then
		lv_label_displayname="$_disk ($lv_targetdisk)"
	fi
	local lv_targetdisk=$lv_label_displayname
	dlog "= next disk: '$lv_targetdisk' ="
	local _old_cc_logname=$lv_cc_logname
	lv_cc_logname="$_disk"
	local _oldifs=$IFS
	IFS=','

	############################################################################
	# call loop.sh to loop over all projects for disk ############################################
	./bk_loop.sh "$_disk"
	############################################################################
        local loop_RET=$?
	
	# exit values from 'bk_loop.sh'
	# exit BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
	# exit BK_ARRAYSNOK		- property arrays have errors
	# exit BK_NOINTERVALSET	    	- no backup time inteval configured in 'cfg.projects'
	# exit BK_DISKNOTUNMOUNTED    	- ddisk could not be unmounted
	# exit BK_MOUNTDIRTNOTEXIST   	- mount folder for backup disk is not present in '/mnt'
	# exit BK_DISKNOTMOUNTED	- disk could not be mounted 
	# exit BK_RSYNCFAILS		- rsync error
	# exit BK_ROTATE_FAILS		- rotate error
	# exit BK_SUCCESS		- all was ok

	lv_cc_logname=$_old_cc_logname
	# check
	# exit BK_TIMELIMITNOTREACHED 	- for none project at this disk time limit is reached
	# exit BK_DISKLABELNOTFOUND 	- disk with uuid not found in /dev/disk/by-uuid
	# exit BK_DISKNOTUNMOUNTED	- disk could not be unmounted
	# exit BK_DISK_IS_NOT_SET_IN_CONF	disk is not set in conf

	dlog ""
	if test $loop_RET -eq $BK_TIMELIMITNOTREACHED
	then
		dlog "'$lv_targetdisk' no project has timelimit reached, wait for next loop"
		#dlog "ready, time limit of a project is not reached"
	else
		if test $loop_RET -eq $BK_DISKLABELNOTFOUND
		then
			# no error, normal use of disks, disk is not present, maybe present at next main loop
			dlog "HD with label: '$lv_targetdisk' not found ..." 
		else
			if test $loop_RET -eq $BK_DISKNOTMOUNTED
			then
				dlog "warning: disk '$_disk' not mounted"
			else
				if test $loop_RET -eq $BK_DISK_IS_NOT_SET_IN_CONF
				then
					dlog "disk '$_disk' not set in snapshot root"
				else
					
					if test $loop_RET -ne 0 
					then
						dlog "unknown error: RET nach loop: $loop_RET"
					fi
				fi
			fi
		fi
	fi	


	IFS=$_oldifs

	local _msg=""
	local _PROJECTERROR="false"
	lv_cc_logname=$_old_cc_logname

	# write a message to error.log
	# RET is unchanged
	# exit BK_NOINTERVALSET	    	- no backup time inteval configured in 'cfg.projects'
	# exit BK_MOUNTDIRTNOTEXIST   	- mount folder for backup disk is not present in '/mnt'
	# exit BK_DISKNOTUNMOUNTED    	- ddisk could not be unmounted
	if test  $loop_RET -eq $BK_NOINTERVALSET 
	then
		_msg="for one project in '$lv_targetdisk' time interval is not set"
	fi
	if test $loop_RET -eq $BK_MOUNTDIRTNOTEXIST
	then
		local mount_targetdisk=$( targetdisk $_disk )
		_msg="mountpoint for HD with label: '$lv_targetdisk' not found: '/mnt/$mount_targetdisk' "
	fi
	if test ${loop_RET} -eq $BK_DISKNOTUNMOUNTED 
	then
		_msg="HD with label: '$lv_targetdisk' could not be unmounted" 
	fi


	# set PROJECTERROR to 'true', write message to error.log
	# set RET to BK_SUCCESS
	# exit BK_RSYNCFAILS		- rsync error
	# exit BK_DISK_IS_NOT_SET_IN_CONF	disk is not set in conf
	# exit BK_ROTATE_FAILS		- rotate error
	if test  ${loop_RET} -eq $BK_RSYNCFAILS 
	then
		_msg="rsync error in disk: '$lv_targetdisk'"
		_PROJECTERROR="true"
		loop_RET=$BK_SUCCESS
	fi
	if test  ${loop_RET} -eq $BK_DISK_IS_NOT_SET_IN_CONF  
	then
		_msg="disk '$lv_targetdisk' is not set in snapshot root"
		dlog "msg: $_msg"
		_PROJECTERROR="true"
		loop_RET=$BK_SUCCESS
	fi
	if test  ${loop_RET} -eq $BK_ROTATE_FAILS 
	then
		_msg="file rotate error in history, check backup disk for errors: '$lv_targetdisk'"
		_PROJECTERROR="true"
		loop_RET=$BK_SUCCESS
	fi

	# test msg: msg="test abc"
	#msg="test abc"
	if test -n "$_msg" 
	then
		#dlog "rsnapshot error: $msg"
  		rsyncerrorlog "$_msg"
	fi

	if test ${loop_RET} -eq $BK_SUCCESS
	then
		if test  "$_PROJECTERROR" = "true" 
		then
			dlog "'$lv_targetdisk' done, min. one project has rsync errors, see log"
		else
			dlog "'$lv_targetdisk' successfully done"
		fi

		# defined in  scr_filenames.sh
		# successarray and unsuccessarray contain 
		# shortened names, like in header in var SUCCESSLINE="c:dserver ...."
		# read successarray written by bk_loop
		if test -f "$bv_successarray_tempfile"
		then
			_oldifs=$IFS
			IFS=' '
			lv_disks_successlist=( ${lv_disks_successlist[@]} $(cat $bv_successarray_tempfile) )
#			dlog "nachher: $( echo ${lv_disks_successlist[@]} )"
			IFS=$_oldifs
			rm $bv_successarray_tempfile
		fi
		# read unsuccessarray written by bk_loop
		if test -f "$bv_unsuccessarray_tempfile"
		then
			_oldifs=$IFS
			IFS=' '
			lv_disks_unsuccesslist=( ${lv_disks_unsuccesslist[@]} $(cat $bv_unsuccessarray_tempfile) )
			IFS=$_oldifs
			rm $bv_unsuccessarray_tempfile
		fi
	else
		if test ${loop_RET} -ne $BK_TIMELIMITNOTREACHED
		then
			if test ${loop_RET} -eq $BK_DISKLABELNOTFOUND 
			then
				dlog "'$lv_targetdisk' is not connected with the server"
			else
				if test ${loop_RET} -eq $BK_FATAL
				then 
					dlog  "'$lv_targetdisk' returns with fatal error: '$loop_RET', see log"
				else
					# none of exit values are checked
					dlog  "'$lv_targetdisk' returns with error: '$loop_RET', see log"
				fi
			fi
		fi
	fi

	dlog "= disk: '$lv_targetdisk' done ="
}


# loop disk list
# use list without targetdisks: 'cfg_disklist'
function call_bk_loops {
	for _disk in $cfg_disklist
	do
		call_bk_loop $_disk
	done
}


# wait, until minute is 00 in next hour
# exits, if stop is found
function loop_to_full_next_hour {
	local _minute=$(date +%M)

	# if minute is '00', then count to 1 minute and then to next full hour  

	# 00
	if [ $_minute = "00" ]
	then
		# if full hour, then wait 1 minute
		loop_until_minute "01"
	fi
	# wait until next full hour
	loop_until_minute "00"

	return 0
}


function wait_until_full_hour {
	# check for stop in wait interval
	# not in waittime interval
	# waittime interval = stop from - to
	# local vars set at start of 'bk_disks.sh'
	# in line 86
	#local _wstart=$cfg_waittimestart10
	#local _wend=$cfg_waittimeend10
	#local _hour=$(date +%H:%M)
	#dlog "time '$_hour' not in waittime interval: '$_wstart - $_wend'"

	loopcounter=$( printf "%05d"  $( get_loopcounter ) )

	# "--- marker ---"	
	# "waiting, backup ready"
	local nextcheck="$(date +%H --date='-1 hours ago' ):00"

	# first show errors
	if [ -s $bv_internalerrors ]
	then
		dlog ""
		dlog "show errors:"
		dlog "$( cat $bv_internalerrors )"
		dlog ""
		dlog "${text_marker_error_in_waiting}, next check at ${nextcheck}, loop: $loopcounter,  stop backup with './stop.sh'"
	else
		dlog "${text_marker_waiting}, next check at ${nextcheck}, loop: $loopcounter,  stop backup with './stop.sh'"
	fi
	# display message and wait
	# lastlogline, this is last line of log, if in wait state
	# is not in global waittime interval, check minute loop used
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
		# skipped, if 'test_check_looptimes' -eq 0

		# stop is checked here
		tlog "wait 1 hour"
		#dlog "wait 1 hour", # don't uncomment this line, 'is_stopped.sh' uses last line, and fails
		if [ $bv_test_check_looptimes -eq 1 ]
		then
			loop_to_full_next_hour
		fi
	fi
}


function is_in_global_waitinterval {
	local _wstart=$cfg_waittimestart10
	local _wend=$cfg_waittimeend10
	is_in_waittime $_wstart $_wend
	local waittime_RET=$?
	# 0, if is in wait time
	# 1, if is not
	#dlog "is_in_global_waitinterval  ZZZZZ  '$_RET', start: '$_wstart', end '$_wend'"
	return $waittime_RET
}

function wait_until_end_of_global_waittime {

	local _wstart=$cfg_waittimestart10
	local _wend=$cfg_waittimeend10
	local _hour=$(date +%H)
	local hour10=$(( 10#"${_hour}" ))
	# readonly text_wait_interval_reached="wait interval reached"  
	dlog "$text_marker $text_wait_interval_reached, currenti time: $hour10, begin: $_wstart, end: $_wend"

	local _count=0

	is_in_global_waitinterval 
	local _globalRET=$?
	# 0, if is in wait time
	# 1, if is not
	while [[  $_globalRET -eq 0  ]] 
	do
		#dlog "time $(date +%H:%M:%S), wait until $cfg_waittimeend"
		_hour=$(date +%H)
		hour10=$(( 10#"${_hour}" ))
	#		dlog "XXXX $text_marker ${text_wait_interval_reached}, time $(date +%H:%M:%S), wait until $_wend"
		# every 30 min display a status message
		# 30 min = 1800 sec 
		# 180 counts = 30 min

		if [ $_count -eq 90 ]
		then
			_count=0
			dlog "$text_marker ${text_wait_interval_reached}, time $(date +%H:%M:%S), wait until $_wend"
			#dlog "$text_marker ${text_wait_interval_reached}, time $(date +%H:%M:%S), wait until $_wend"
		fi
		_count=$(( _count+1 ))

		# every 10 sec check stop file
		sleep "10s"
		# check for stop in wait interval
		check_stop "wait interval loop"
		#	dlog "STOP danach , until $_wend"
		is_in_global_waitinterval 
		_globalRET=$?
	done
	# text_waittime_end="waittime end"
	dlog "$text_marker ${text_waittime_end}, next check at $(date +%H):00"
}



# uses $bv_globalwaittimeinterval
# uses is_in_waittime $_wstart $_wend
function wait_until_end {
	is_in_global_waitinterval 
	local RET=$?
	# 0, if is in wait time
	# 1, if is not
	#dlog "GLGLGL  RET: '$RET'"
	if [ "$RET" -eq 0 ] 
	then
	#	dlog "in global wait GLGLGL  RET: '$RET'"
		wait_until_end_of_global_waittime 
	else
	#	dlog "in hour wait HWHWHW RET: '$RET'"
		wait_until_full_hour 
	fi
}



###########################################################################################


dlog "=== disks start ==="
tlog "start"

init_cfg_variables
init_local_variables

check_stop  "at start of loop through disklist (bk_disks.sh)"
#TEST: exit $BK_DISK_TEST_RETURN


dlog ""
dlog "show all disks, connected at backup host '$lv_hostname' "
list_connected_disks_by_uuid

replace_disknames_with_targetdisks

dlog "check all projects in disks: '$lv_disklist'"
dlog ""

# loop disk list
# use list without targetdisks
tlog "execute list: $cfg_disklist"

call_bk_loops

# end loop disk list
dlog ""
dlog "-- end disk list --"
dlog ""
tlog "end disk list"


successlog_send

# SECONDS, bash has time after start of module in seconds
show_used_seconds

copy_executedprojects_from_loop_to_disks

loopcountertemp=$( get_loopcounter )
loopcounter=$( printf  "%5d" $loopcountertemp )
loopmsg="loop: $loopcounter, disk and projects: $lv_executedprojects" 
dlog "$loopmsg "


# end full backup loop

dlog ""


# check for stop with 'bv_test_execute_once'
if [ $bv_test_execute_once -eq 1 ]
then
	# bv_test_do_once_count=0
	dlog "'execute once' set, stop loop, max count: '$bv_test_do_once_count'"
	exit $BK_EXECONCESTOPPED
fi
# shell script, executed at start of disk

execute_main_end
exec_end_RET=$?
if [ $exec_end_RET -gt 0 ]
then
	dlog "execute_main_end: RET: $exec_end_RET"
	exit $BK_MAIN_END_FAILED
fi

wait_until_end

dlog "=== disks end  ==="
tlog "end"


# exit BK_NORMALDISKLOOPEND for successful loop
# test_execute_once is 0

exit $BK_NORMALDISKLOOPEND

# not reached
# test messages after call of loop
	./bk_loop.sh "$_disk"

		msg="for one project in '$lv_targetdisk' time interval is not set"
echo "$msg"
		msg="HD with label: '$lv_targetdisk' not found ..." 
echo "$msg"
		msg="HD with label: '$lv_targetdisk' not found ..." 
echo "$msg"

		msg="mountpoint for HD with label: '$lv_targetdisk' not found: '/mnt/$mount_targetdisk' "
echo "$msg"
		msg="HD with label: '$lv_targetdisk' could not be mounted" 
echo "$msg"
		msg="HD with label: '$lv_targetdisk' could not be unmounted" 
echo "$msg"
		msg="rsync error in disk: '$lv_targetdisk'"
echo "$msg"
		msg="file rotate error in history, check backup disk for errors: '$lv_targetdisk'"
echo "$msg"
			msg="'$lv_targetdisk' done, min. one project has rsync errors, see log"
echo "$msg"
			msg="'$lv_targetdisk' successfully done"
echo "$msg"
			msg="'$lv_targetdisk' no project has timelimit reached, wait for next loop"
echo "$msg"
				msg="'$lv_targetdisk' is not connected with the server"
echo "$msg"
				msg="'$lv_targetdisk' returns with error: '$_RET', see log"
echo "$msg"
# EOF



