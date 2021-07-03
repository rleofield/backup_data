#!/bin/bash

# file: bk_disk.sh
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
#	./bk_disks.sh,   all disks,  <- this file
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./cfg.filenames

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_ssh.sh


. ./src_log_disks.sh




readonly iscron=$1

readonly OPERATION="disks"
FILENAME="$OPERATION"

readonly stopfile="stop"
SECONDS=0

readonly successloglinestxt="successloglines.txt"


readonly _waittimeinterval=$waittimeinterval
readonly oldifs=$IFS
IFS='-'

readonly dononearray=($_waittimeinterval)
# set default to 09-11
startdonone="09"
enddonone="09"
# read configured values from cfg.projekt
if [ ${#dononearray[@]} = 2 ]
then
        startdonone=${dononearray[0]}
        enddonone=${dononearray[1]}
fi

tlog "start"

IFS=$oldifs

#LLLUSER="rleo"
#DESKTOP_DIR=$( su -s /bin/sh $LLLUSER -c 'echo "$(xdg-user-dir DESKTOP)"' )


function rsyncerrorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	local msg=$( echo "$_TODAY err ==> '$1'" )
	#dlog "rsyncerrorlog write: $msg"
	echo -e "$msg" >> $internalerrorstxt
}


# parameter
# executed after 'is_number $_minutes'
function stop_exit(){
        local _name=$1
        dlog "$text_marker ${text_stop_exit}: by '$_name'"
        exit $STOPPED
}


# parameter
# 1 = Name des Ortes, in dem stop getestet wird
function check_stop(){
        local _name=$1
#	dlog "in check stop"
        #if test -f $stopfile
        #then
	#	dlog "stopfile exists"
	#	cat $stopfile
	#fi

        if test -f $stopfile
        then
		local msg=$( printf "%05d"  $( get_loopcounter  ) )
		#dlog "$text_backup_stopped in '$_name', counter: $msg  "
                rm $stopfile
#		if [ $execute_once -eq 1 ]
#		then
#			dlog "'execute_once': exec stop in 'check_stop', RET: '$STOPPED'"
#		fi
                exit $STOPPED
        fi
	return 0
}


function is_number(){
	local _input=$1	
	if [[ -z $_input ]]
	then
		return 1
	fi
	if [[ ! -n ${_input//[0-9]/} ]]
      	then
		return 0
      	fi
      	return 1
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
	if [ $short_minute_loop_seconds_10 -eq 1 ]
	then
		_seconds=$(( _minutes * 10 ))
	fi
	local _minute=$(date +%M)
	local _count=0
	if [ $short_minute_loop -eq 0 ]
	then
		while [  $_count -lt $_seconds ] 
		do
			#dlog "minute: '$_count -ne $_seconds'"
			# sleep 5 sec
			sleep  $_sleeptime
			_count=$(( _count + _sleeptime ))
			#if  [ ! (( _count % 30 )) ]
			#then
			dlog "in loop minutes: $_count seconds"
			#fi
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
#	dlog "end minute $1"
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
# waittime 2 < t < 1 hour
function loop_to_full_next_hour {
        local _minute=$(date +%M)
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


        declare -a slist=("${!1}")
        declare -a unslist=("${!2}")

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


	local ff=$successloglinestxt
	local _TODAY=`date +%Y%m%d-%H%M`
#	datelog "${FILENAME}:  $_TODAY: $line" 

	# add line to successloglinestxt
	echo "$_TODAY: $line" >> $ff

	# copy successloglinestxt to local folder, in any case, also if sshlogin is empty
	dlog "cp $successloglinestxt  backup_messages_test/${file_successloglines}"
	cp $successloglinestxt  backup_messages_test/${file_successloglines}


	#if [ ! -z $sshlogin ] # in successlog
	# if sshlogin is not empty, send successloglinestxt to remote Desktop
	# aus cfg: sshlogin=
	if [  -n  "$sshlogin" ] 
	then
		ssh_port=$( func_sshport )
#		dlog "successlog : login: '${sshlogin}', host: '${sshhost}', target: '${sshtargetfolder}', port: '${ssh_port}'"
		if [ "${sshhost}" == "localhost" ] || [ "${sshhost}" == "127.0.0.1" ]
		then
			COMMAND="cp ${ff} ${sshtargetfolder}${file_successloglines}"
			dlog "copy logs to local Desktop: $COMMAND"
			#eval $COMMAND
			#dlog "chown $sshlogin:$sshlogin ${sshtargetfolder}$ff"
			COMMAND="rsync -av --delete backup_messages_test/ ${sshtargetfolder}"
			dlog "rsync command; $COMMAND"
			eval $COMMAND
			dlog "chown -R $sshlogin:$sshlogin ${sshtargetfolder}"
			chown -R $sshlogin:$sshlogin ${sshtargetfolder}
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
				#COMMAND="rsync $ff -e 'ssh -p ${ssh_port}'  $sshlogin@$sshhost:${sshtargetfolder}${file_successloglines}"
				#dlog "$COMMAND"
				#eval $COMMAND
				#RET=$?
				#if [ $RET -gt 0 ]
				#then
				#	dlog "rsync failed, target for log messages down!  "
				#	dlog "COMMAND:  $COMMAND"
				#	dlog ""	
				#fi
				# copy message folder to remote target, with --delete 
				#_sshport=$( func_sshport )
				#_sshe="ssh -4 -p $_sshport" 
				#_sshtemp=$_sshe
				#_slash="'"
				#_sshe="${_slash}${_sshtemp}${_slash}" 
				dlog "rsync -av --delete -e 'ssh -4 -p 4194' backup_messages_test/ $sshlogin@$sshhost:${sshtargetfolder} -P"
				#rsync -av --delete -e 'ssh -4 -p 4194' backup_messages_test/ $sshlogin@$sshhost:${sshtargetfolder} -P
				rsync -a --delete -e 'ssh -4 -p 4194' backup_messages_test/ $sshlogin@$sshhost:${sshtargetfolder} -P
				RET=$?
				if [ $RET -gt 0 ]
				then
					dlog "rsync failed, target for log messages is not available  "
					dlog "COMMAND:  rsync -av --delete -e ssh -4 -p 4194 backup_messages_test/ $sshlogin@$sshhost:${sshtargetfolder}"
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

	# use one of the entries in header array for grep 
	local first=${successline[0]}

	#datelog "cat $successloglinestxt | grep -v $first | wc -l "
	local count=$( cat $successloglinestxt | grep -v $first | wc -l )
	#datelog "count: $count"
	local divisor=20
	local n=$(( count % divisor ))
	if test $n -eq 0 
	then
		# write header out at every 20'th line
		line1=""
		for _s in ${successline[@]}
        	do
        		txt=$( printf "%${SUCCESSLINEWIDTH}s" $_s )
			line1=${line1}${txt}
        	done
		ff=$successloglinestxt
        	_TODAY=`date +%Y%m%d-%H%M`
		echo "$_TODAY: $line1" >> $ff
	fi
}

dlog "=== disks start ==="
check_stop  "at start of loop through disklist (bk_disks.sh)"

IFS=' '
declare -a successlist
declare -a unsuccesslist

#datelog "${FILENAME}"
#dlog "is: $iscron"
#if [ $iscron == "cron" ]
#then
#	dlog "------  is cron start    ------"
#else
#	dlog "------  is manual start  ------"
#fi
dlog "check all projects in disks: '$DISKLIST'"
dlog ""

dlog "found connected Disks:"

####
# show disk connected with usb
_oldifs=$IFS
IFS='
'
for _d in $(ls -1 /dev/disk/by-uuid/)
do
	_g=$(grep  $_d uuid.txt)
	# Following syntax deletes the longest match of $substring from front of $string
	# ${string##substring}
	if ! [ -z "${_g##*swap*}" ] && ! [ -z "${_g##*boot*}" ]
	then
		dlog "    connected disk:  $_g"
	fi
done
IFS=$_oldifs
dlog ""

# loop disk list


tlog "execute list: $DISKLIST"
for _disk in $DISKLIST
do
	dlog ""
	dlog "==== next disk: '$_disk' ===="


	_FNOLD=$FILENAME
	FILENAME="$_disk"
	dlog ""
	dlog ""
	oldifs2=$IFS
	IFS=','
	RET=""
	# call loop.sh to loop one disk ############################################
	./bk_loop.sh "$_disk" 
	############################################################################
        RET=$?


	# possible exit values
	# ok, exit NOINTERVALSET
	# ok, exit DISKLABELNOTFOUND
	# ok, exit MOUNTDIRTNOTEXIST
	# ok, exit DISKNOTUNMOUNTED
	# ok, exit DISKNOTMOUNTED

	# ok, exit RSYNCFAILS
	# ok, exit SUCCESS

	# exit ARRAYSNOK
	#  after else exit TIMELIMITNOTREACHED
	#   ans  DISKLABELNOTFOUND


	IFS=$oldifs2
	dlog ""
	msg=""
	PROJECTERROR="false"
	FILENAME=$_FNOLD

	if [[ $RET = "$NOINTERVALSET" ]]
	then
		msg="for one project of disk '$_disk' time interval is not set"
	fi
	if [[ $RET = "$DISKLABELNOTFOUND" ]]
	then
		# no error, normal use of disks
		dlog "HD with label: '$_disk' not found ..." 
	fi
	if [[ $RET = "$MOUNTDIRTNOTEXIST" ]]
	then
		msg="mountpoint for HD with label: '$_disk' not found: '/mnt/$_disk' "
	fi

	# not in RET
	#if test $RET -eq $NOFOLDERRSNAPSHOT·
	#then
	#	msg="error: folder 'rsnapshot' doesn't exist"
	#fi
	
	# not in RET
	#if test $RET -eq $NORSNAPSHOTROOT
	#then
	#	msg="snapshot root folder doesn't exist, see log"
	#fi

	if [[ $RET = "$DISKNOTMOUNTED" ]]
	then
		msg="HD with label: '$_disk' couldn't be mounted" 
	fi
	if [[ ${RET} == "$DISKNOTUNMOUNTED" ]]
	then
		msg="HD with label: '$_disk' couldn't be unmounted" 
	fi
	if [[ ${RET} == "$RSYNCFAILS" ]]
	then
		msg="rsync error in disk: '$_disk'"
		PROJECTERROR="true"
		RET=$SUCCESS
	fi
	# test msg: msg="test abc"
	#msg="test abc"
	if [ "$msg" ]
	then
		rsyncerrorlog "$msg"
		#dlog "$msg" 
	fi

	if [[ ${RET} == "$SUCCESS" ]]
	then
		if [[ $PROJECTERROR == "true" ]]
		then
		datelog   "${FILENAME}: '$_disk' done, min. one project has rsync errors, see log"
		else
			datelog   "${FILENAME}: '$_disk' successfully done"
		fi
#		datelog   "${FILENAME}: cat successarraytxt: $( cat $successarraytxt )"
		# defined in  filenames.sh
		# successarraytxt and unsuccessarraytxt contain 
		# shortened names, like in header in var SUCCESSLINE="c:dserver ...."
		if test -f "$successarraytxt"
		then
			oldifs3=$IFS
			IFS=' '
			successlist=( ${successlist[@]} $(cat $successarraytxt) )
			IFS=$oldifs3
			rm $successarraytxt
		fi
		if test -f "$unsuccessarraytxt"
		then
			oldifs3=$IFS
			IFS=' '
			unsuccesslist=( ${unsuccesslist[@]} $(cat $unsuccessarraytxt) )
			IFS=$oldifs3
			rm $unsuccessarraytxt
		fi
	else
		if [[ "${RET}" == "$TIMELIMITNOTREACHED" ]]
		then
                	datelog "${FILENAME}: '$_disk' no project has timelimit reached, wait for next loop"
                else
                	if [[ "${RET}" == "$DISKLABELNOTFOUND" ]]
			then
				datelog "${FILENAME}: '$_disk' is not connected with the server"
			else
				datelog  "${FILENAME}: '$_disk' returns with errors, see log"
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


#datelog "${FILENAME}: write success disk: $_disk"
_length_successlist=${#successlist[@]}
_length_unsuccesslist=${#unsuccesslist[@]}

if test "$_length_successlist" -eq "0" -a "$_length_unsuccesslist" -eq "0"  
then
	dlog "successarrays are empty, don't write an entry to: $successloglinestxt"
else
	datelog "${FILENAME}: successarrays are not empty, write success/error entry to: $successloglinestxt"
	write_header
	successlog  successlist[@] unsuccesslist[@] 
fi


# SECONDS in bash hat die Zeit in Sekunden
dlog "-- used time: $SECONDS seconds"

# log used time in loop.log
TODAY2=`date +%Y%m%d-%H%M`
counter1=$( get_loopcounter )
projects=""
if [ -f $executedprojects ]
then
	projects=$( cat $executedprojects ) 
	rm $executedprojects
fi
#dlog "projects: $projects"
_seconds=$( printf  "%3d" $SECONDS )
_counter=$( printf  "%5d" $counter1 )

loopmsg=$(  echo "$TODAY2, seconds: $_seconds,  loop: $_counter, $projects" )

dlog "loopmsg: $loopmsg "
#echo "$loopmsg" >> loop.log


IFS=$oldifs

# end full backup loop


datelog "${FILENAME}:"

datelog "${FILENAME}: waittime interval:  $startdonone - $enddonone "


hour=$(date +%H)


# check for stop with 'execute_once'
if [ $execute_once -eq 1 ]
then
	# do_once_count=0
	dlog "'execute once' set, stop loop, max count: '$do_once_count'"
	exit $EXECONCESTOPPED
fi



# check for stop in wait interval

#dlog "if  $hour >= $startdonone  && $hour  < $enddonone &&  use_minute_loop = 0 && $execute_once = 0, then wait to end of interval"
if [ "$hour" -ge "$startdonone" ] && [ "$hour" -lt "$enddonone"  ] && [ $use_minute_loop -eq 0 ] 
then
	# in waittime interval or minute loop used
	datelog "${FILENAME}: $text_marker $text_wait_interval_reached, current: $hour, begin wait interval: $startdonone, end wait interval: $enddonone"
	count=0
	while [  $hour -lt $enddonone ] 
        do

		#datelog "${FILENAME}: time $(date +%H:%M:%S), wait until $enddonone"
		hour=$(date +%H)
		# every 30 min display a status message
		# 30 min = 1800 sec 
		# 180 counts = 30 min
		if [ $count -eq 180 ]
		then
			count=0
			mminute=$(date +%M)

			#datelog "${FILENAME}:  value of minute, in loop: $mminute"
			datelog "${FILENAME}: $text_marker ${text_wait_interval_reached}, time $(date +%H:%M:%S), wait until $enddonone"
		fi
		count=$(( count+1 ))

		# every 10 sec check stop file
		sleep "10s"

		#datelog "${FILENAME}:  before stop: "
		check_stop "wait interval loop"
	done
	_minute2=$(date +%M)
	#datelog "${FILENAME}:  value of minute, after stop interval: $_minute2"
	dlog "$text_marker ${text_waittime_end}, next check at $(date +%H):00"
	tlog "wait 1 hour"
#	if [ $execute_once -eq 1 ]
#	then
#		dlog "'execute_once': stop in 'loop_to_full_next_hour'"
#	fi
	loop_to_full_next_hour

else
	# not in waittime interval
	hour=$(date +%H:%M)
	datelog "${FILENAME}: time '$hour' not in waittime interval: '$startdonone - $enddonone'"

	loopcounter=$( printf "%05d"  $( get_loopcounter ) )

	# "--- marker ---"	
	# "waiting, backup ready"

	# first show errors
	if [ -s $internalerrorstxt ]
	then
		dlog ""
		dlog "show errors:"
		dlog "$( cat $internalerrorstxt )"
		dlog ""
		dlog "$text_marker_error_in_waiting , next check at $(date +%H --date='-1 hours ago' ):00, loop: $loopcounter,  stop backup with './stop.sh'"
	else
		dlog "$text_marker_waiting , next check at $(date +%H --date='-1 hours ago' ):00, loop: $loopcounter,  stop backup with './stop.sh'"
	fi
	# display message and wait
	# lastlogline, this is last line of log, if in wait state
	if [ $use_minute_loop -eq 1 ]
	then
		# use_minute_loop is set
		tlog "wait minutes: $minute_loop_duration"
		dlog "wait minutes: $minute_loop_duration"
		# default=2
		mlooptime=$minute_loop_duration

		if [ -z $mlooptime  ]
		then
			mlooptime=2
		fi
		dlog "'use_minute_loop' is set, wait '$mlooptime' minutes"
		if [ $short_minute_loop -eq 1 ]
		then
			dlog "'short_minute_loop' set, skip immediately, not waiting '$mlooptime' minutes"
		fi
		 
		if [ $short_minute_loop_seconds_10 -eq 1 ]
		then
			_seconds=$((  mlooptime * 10 ))
			dlog "'short_minute_loop_seconds_10' is set, one minute ist shortened to 10 seconds, '$_seconds' seconds "
		fi

		loop_minutes $mlooptime 
	else
	        # wait until next full hour
		# skipped if check_looptimes=0
		# stop is checked here
		tlog "wait 1 hour"
		#dlog "wait 1 hour", # don't enable this, 'is_stopped.sh' uses last line, and didn't work correct
		if [ $check_looptimes -eq 1 ]
		then
			loop_to_full_next_hour
		fi
	fi

fi
dlog "=== disks end  ==="
tlog "end"


# exit NORMALDISKLOOPEND for successful loop
# execute_once is 0

exit $NORMALDISKLOOPEND






