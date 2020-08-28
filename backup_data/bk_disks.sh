#!/bin/bash

# file: bk_disk.sh
# version 20.08.1

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

# caller ./bk_main.sh
#        ./bk_disks.sh,   all disks


. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./cfg.test_vars
. ./cfg.filenames
. ./cfg.log_disks

. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_ssh.sh

readonly OPERATION="disks"
readonly FILENAME="$OPERATION"

readonly stopfile="stop"
SECONDS=0

readonly _waittimeinterval=$waittimeinterval
readonly oldifs=$IFS
IFS='-'

readonly dononearray=($_waittimeinterval)
# set default to 09-11
startdonone="09"
enddonone="11"
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


# parameter
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
                dlog "$text_marker $text_stopped in '$_name', counter: $msg"
                rm $stopfile
                exit $STOPPED
        fi
	return 0
}

dlog "=== disks start ==="
check_stop  "at start of loop through disklist (bk_disks.sh)"

is_number(){
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
  
# par1 = number of minutes waiting
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
                	# sleep 10 sec
	                sleep  $_sleeptime
			_count=$(( _count + _sleeptime ))
#			dlog "in loop minutes: $_count seconds"
	                check_stop "in loop_minutes, value of seconds: $_seconds"
        	done
	fi
        check_stop "in loop_minutes, end"
        return 0
}

# par1 = target minute 00 < par1 < 59
function loop_until_minute  {
        local _endminute=$1
	#dlog "end minute $1"
	is_number $_endminute 
	RET=$?
	if [ $RET -eq 1 ]
	then
		stop_exit "minute '$_endminute' is not a stringi with numbers"
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

	declare -a successline=( $SUCCESSLINE )

        declare -a slist=("${!1}")
        declare -a unslist=("${!2}")

	local line="" 
	for _s in "${successline[@]}"
	do
		#dlog "successlog: item '$_s'"
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

        local ff=$successloglines
        local _TODAY=`date +%Y%m%d-%H%M`
	datelog "${FILENAME}:  $_TODAY: $line" 
	echo "$_TODAY: $line" >> $ff
	if [ ! -z $sshlogin ] 
	then
		if [ "${sshhost}" == "localhost" ] || [ "${sshhost}" == "127.0.0.1" ]
		then
			dlog "local"
			COMMAND="cp ${ff} ${sshtargetfolder}${file_successloglines}"
			dlog "copy successfile to local Desktop: $COMMAND"
			eval $COMMAND
			dlog "chown $sshlogin:$sshlogin ${sshtargetfolder}$ff"
			chown $sshlogin:$sshlogin ${sshtargetfolder}${file_successloglines}
		else
			# is in cfg.ssh_login
			# in 'successlog' do_ping_host 
			do_ping_host ${sshlogin} ${sshhost} ${sshtargetfolder}
			RET=$?
			if [ $RET -eq  0 ]
			then
				ssh_port=$( sshport )
				COMMAND="rsync $ff -e 'ssh -p $ssh_port'  $sshlogin@$sshhost:${sshtargetfolder}${file_successloglines}"
				dlog "$COMMAND"
				eval $COMMAND
				RET=$?
				if [ $RET -gt 0 ]
				then
					dlog "rsync failed, target for log messages down!  "
					dlog "COMMAND:  $COMMAND"
					dlog ""	
				fi
			else
				dlog "host $sshlogin@$sshhost is not up, successfile is not copied"
			fi
		fi
	fi
	cp $ff  backup_messages_test/${file_successloglines}

}
function write_header(){

	declare -a successline=( $SUCCESSLINE )

	# use one of the entries in header array for grep 
	local first=${successline[0]}

	#datelog "cat $successloglines | grep -v $first | wc -l "
	local count=$( cat $successloglines | grep -v $first | wc -l )
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
	        ff=$successloglines
        	_TODAY=`date +%Y%m%d-%H%M`
	        echo "$_TODAY: $line1" >> $ff
	fi
}


# rotate log
	
# daily rotate
_date=$(date +%Y-%m-%d)

oldlogdir=oldlogs/$_date
	

if [ ! -d "$oldlogdir" ]
then
	if [ $daily_rotate -eq 1 ]
	then
		dlog "rotate log to '$oldlogdir'"
		mkdir "$oldlogdir"
		mv aa_* "$oldlogdir"
		mv rr_* "$oldlogdir"
		mv $LOGFILE "$oldlogdir"
		mv trace.log "$oldlogdir"
		mv label_not_found.log "$oldlogdir"
		# and create new and empty files
		touch $LOGFILE 
		touch trace.log 
		dlog "log rotated to '$oldlogdir'"
	fi
fi

IFS=' '
declare -a successlist
declare -a unsuccesslist

#datelog "${FILENAME}"
dlog "check all projects in disks: '$DISKLIST'"



# do_once=1	
if [ $do_once -eq 1 ]
then
	_wd=$WORKINGFOLDER
	touch ${_wd}/${stopfile}
fi

# loop disk list
tlog "execute list: $DISKLIST"
for _disk in $DISKLIST
do
	datelog ""
	dlog "==== next disk: '$_disk' ===="
	oldifs2=$IFS
	IFS=','
	RET=""
	# call loop.sh to loop one disk ############################################
	./bk_loop.sh "$_disk"
	############################################################################
        RET=$?
	IFS=$oldifs2

	if [[ $RET = "$NOINTERVALSET" ]]
	then
		datelog "${FILENAME}: for one project of disk '$_disk' time interval is not set"
        fi
	if [[ $RET = "$DISKLABELNOTFOUND" ]]
	then
		datelog "${FILENAME}: HD with label: '$_disk' not found"
        fi
        
	if [[ $RET = "$MOUNTDIRTNOTEXIST" ]]
        then
        	datelog "${FILENAME}: mountpoint for HD with label: '$_disk' not found: '/mnt/$_disk' "
        fi
        if [[ $RET = "$DISKNOTUNMOUNTED" ]]
        then
        	datelog "${FILENAME}: HD with label: '$_disk' couldn't be unmounted" 
        fi


        if [[ $RET = "$DISKNOTMOUNTED" ]]
        then
        	datelog "${FILENAME}: HD with label: '$_disk' couldn't be mounted" 
        fi

        if [[ ${RET} == "$DISKNOTUNMOUNTED" ]]
        then
          	datelog "${FILENAME}: HD with label: '$_disk' couldn't be unmounted" 
        fi
	if [[ ${RET} == "$RSYNCFAILS" ]]
	then
		datelog "${FILENAME}: rsync error in disk: '$_disk' " 
		RET=$SUCCESS
	fi

	if [[ ${RET} == "$SUCCESS" ]]
	then
        	datelog   "${FILENAME}: '$_disk' successfully done"
#		datelog   "${FILENAME}: cat successarraytxt: $( cat $successarraytxt )"
		# defined in  filenames.sh
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
                	datelog "${FILENAME}: '$_disk' time limit not reached, wait for next loop"
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
datelog "${FILENAME}: "
datelog "${FILENAME}: -- end disk list --"
datelog "${FILENAME}: "
tlog "end list"


#datelog "${FILENAME}: write success disk: $_disk"
_length_successlist=${#successlist[@]}
_length_unsuccesslist=${#unsuccesslist[@]}

if test "$_length_successlist" -eq "0" -a "$_length_unsuccesslist" -eq "0"  
then
	datelog "${FILENAME}: successarrays are empty, don't write an entry to: $successloglines"
else
	datelog "${FILENAME}: successarrays are not empty, write entry to: $successloglines"
	write_header
	successlog  successlist[@] unsuccesslist[@] 
fi


# SECONDS in bash hat die Zeit in Sekunden
dlog "-- used time: $SECONDS seconds"

IFS=$oldifs

# end full backup loop


datelog "${FILENAME}:"

datelog "${FILENAME}: waittime interval:  $startdonone - $enddonone "


hour=$(date +%H)


# check for waiting in stop interval
#dlog "if  $hour >= $startdonone  && $hour  < $enddonone &&  use_minute_loop = 0 , then wait to end of interval"
if [ "$hour" -ge "$startdonone" ] && [ "$hour" -lt "$enddonone"  ] && [ $use_minute_loop -eq 0 ] 
then
       	datelog "${FILENAME}: $text_marker $text_interval, current: $hour, begin wait interval: $startdonone, end wait interval: $enddonone"
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
			m=$(date +%M)
			#datelog "${FILENAME}:  value of minute, in loop: $m"
               	        datelog "${FILENAME}: $text_marker ${text_interval}, time $(date +%H:%M:%S), wait until $enddonone"
               	fi
                count=$(( count+1 ))

		# every 10 sec check stop file
               	sleep "10s"
		
	       	#datelog "${FILENAME}:  before stop: "
		check_stop "wait interval loop"
        done
	_minute2=$(date +%M)
	#datelog "${FILENAME}:  value of minute, after stop interval: $_minute2"
       	datelog "${FILENAME}: $text_marker ${text_waittime_end}, next check at $(date +%H):00"
	#loop_to_full_next_hour

else
	# not in waittime intervali or minute loop used
	hour=$(date +%H:%M)
#        datelog "${FILENAME}: waittime interval not reached, current time: $hour"
        datelog "${FILENAME}: time '$hour' not in waittime interval: '$startdonone - $enddonone'"

	# add 1 to current hour
    	#_minute2=$(date +%M)
	#datelog "${FILENAME}: value of minute, after stop interval: $_minute2"
	msg1=$( printf "%05d"  $( get_loopcounter ) )
	
        datelog "${FILENAME}: $text_marker ${text_ready}, next check at $(date +%H --date='-1 hours ago' ):00, loop: $msg1"
	if [ $use_minute_loop -eq 1 ]
	then
		_m=$loop_minutes_duration
		m=$_m
		if [ -z $m  ]
		then
			m=10
		fi

		dlog "'use_minute_loop' is set, wait until next minute '$m'"
		loop_minutes $m 
	else
        	#datelog "${FILENAME}: wait until next full hour"
	        # wait until next full hour
		tlog "wait 1 hour"
		loop_to_full_next_hour
	fi

fi
dlog "=== disks end  ==="
tlog "end"

exit 0






