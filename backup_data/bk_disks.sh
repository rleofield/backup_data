#!/bin/bash

# file: bk_disk.sh
# bk_version 21.09.3

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



readonly iscron=$1

readonly OPERATION="disks"
FILENAME="$OPERATION"

readonly stopfile="stop"
SECONDS=0

readonly successloglinestxt="successloglines.txt"


waittimestart="09"
waittimeend="09"


function get_waittimeinterval() {
	local _waittimeinterval=$waittimeinterval
	local oldifs=$IFS
	IFS='-'
	
	# convert to array
	local dononearray=($_waittimeinterval)
	# read configured values from cfg.loop_time_duration
	if [ ${#dononearray[@]} = 2 ]
	then
		waittimestart=${dononearray[0]}
		waittimeend=${dononearray[1]}
	fi
	IFS=$oldifs
}



function rsyncerrorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $internalerrorstxt
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
#	dlog " $_TODAY: $line" 

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

	# use first entry in header array for grep 
	local firstheader=${successline[0]}

	# get count of lines without header
	local count=$( cat $successloglinestxt | grep -v $firstheader | wc -l )
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
		ff=$successloglinestxt
        	_TODAY=`date +%Y%m%d-%H%M`
		# append formatted header line
		echo "$_TODAY: $line1" >> $ff
	fi
}

dlog "=== disks start ==="
tlog "start"
check_stop  "at start of loop through disklist (bk_disks.sh)"

#IFS=' '
declare -a successlist
declare -a unsuccesslist

dlog "check all projects in disks: '$DISKLIST'"
dlog ""

dlog "found connected disks:"

####
# show disk connected with usb
_oldifs=$IFS
IFS='
'
for _d in $(ls -1 /dev/disk/by-uuid/)
do
	_g=$(grep  ${_d}  uuid.txt)
	# Following syntax deletes the longest match of $substring from front of $string
	# ${string##substring}
	if ! [ -z "${_g##*swap*}" ] && ! [ -z "${_g##*boot*}" ]
	then
		dlog "    connected disk:  $_g"
#		_disk=$( echo $_g | awk -F' ' '$0=$1')
		#dlog "    disk:  $_disk"
#		_last=$( find oldlogs -name "cc_log*" | grep -v save | xargs grep $_disk | grep 'is mounted' | sort | awk '{ print $1 }'| cut -d '/' -f 2 | tail -f -n1 )
#		dlog "    letztes Backup war: $_last "
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
	#dlog "RET nach loop: $RET"


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
		msg="rsync error in disk: '$_disk', RET: '$RET'"
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
		dlog "'$_disk' done, min. one project has rsync errors, see log"
		else
			dlog "'$_disk' successfully done"
		fi
#		dlog   "cat successarraytxt: $( cat $successarraytxt )"
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
                	dlog "'$_disk' no project has timelimit reached, wait for next loop"
                else
                	if [[ "${RET}" == "$DISKLABELNOTFOUND" ]]
			then
				dlog "'$_disk' is not connected with the server"
			else
				dlog  "'$_disk' returns with errors, see log"
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
_length_successlist=${#successlist[@]}
_length_unsuccesslist=${#unsuccesslist[@]}

if test "$_length_successlist" -eq "0" -a "$_length_unsuccesslist" -eq "0"  
then
	dlog "successarrays are empty, don't write an entry to: $successloglinestxt"
else
	dlog "successarrays are not empty, write success/error entry to: $successloglinestxt"
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


dlog ""

get_waittimeinterval

dlog "waittime interval:  $waittimestart - $waittimeend "


hour=$(date +%H)


# check for stop with 'execute_once'
if [ $execute_once -eq 1 ]
then
	# do_once_count=0
	dlog "'execute once' set, stop loop, max count: '$do_once_count'"
	exit $EXECONCESTOPPED
fi



# check for stop in wait interval

dlog "if  $hour >= $waittimestart  && $hour  < $waittimeend "
if [ "$hour" -ge "$waittimestart" ] && [ "$hour" -lt "$waittimeend"  ] && [ $use_minute_loop -eq 0 ] 
then
	# in waittime interval or minute loop used
	dlog "$text_marker $text_wait_interval_reached, current: $hour, begin wait interval: $waittimestart, end wait interval: $waittimeend"
	count=0
	while [  $hour -lt $waittimeend ] 
        do

		#dlog "time $(date +%H:%M:%S), wait until $waittimeend"
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
#	dlog "$text_marker ${text_waittime_end}, next check at $(date +%H):00"
	dlog "$text_marker ${text_waittime_end}, next check at $(date -d '+1 hour' '+%H'):00"
	tlog "wait 1 hour"
#	if [ $execute_once -eq 1 ]
#	then
#		dlog "'execute_once': stop in 'loop_to_full_next_hour'"
#	fi
# wait one hour or not
	loop_to_full_next_hour

else
	# not in waittime interval
	hour=$(date +%H:%M)
	dlog "time '$hour' not in waittime interval: '$waittimestart - $waittimeend'"

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


# EOF



