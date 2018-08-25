#!/bin/bash

# file: main_loop.sh
# version 18.08.1

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

. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.exit_codes
. ./cfg.filenames
. ./cfg.projects
. ./lib.logger
. ./cfg.ssh_login



FILENAME="main"

stopfile="stop"

oldifs1=$IFS


if test -f $stopfile
then
	datelog "${FILENAME}: stopped" 
	rm $stopfile
	exit 1
fi


function sheader {

	declare -a successline=( $SUCCESSLINE )
	local line1=""
	for _s in ${successline[@]}
	do
                txt=$( printf "%${SUCCESSLINEWIDTH}s" $_s )
                line1=$line1$txt
	done
        local ff=$successloglines
        local _TODAY=`date +%Y%m%d-%H%M`
#        datelog "$_TODAY: $line1" 
        echo "$_TODAY: $line1" >> $ff

}

# parameter
# 1 = list successlist[@] 
# 2 = list unsuccesslist[@] 
# 3 = string "ready"
function successlog {

        declare -a successline=( $SUCCESSLINE )

	declare -a slist=("${!1}")
        declare -a unslist=("${!2}")
	local _disk=$3

	line="" 
	for _s in ${successline[@]}
	do
		value="-"
		for item in "${slist[@]}" 
		do
		    	if test "$_s" = "$item" 
		    	then
		    		value="ok"
			fi
		done    
		for item in "${unslist[@]}" 
		do
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
	datelog "${FILENAME}:  rsync $ff ${notifytargetsend}Backup_erfolgsliste.txt"
	rsync $ff ${notifytargetsend}Backup_erfolgsliste.txt

}
function write_header(){

	declare -a successline=( $SUCCESSLINE )

	# use one of the entries in array for grep later
	local first=${successline[0]}

	datelog "cat $successloglines | grep -v $first | wc -l "
	local count=$( cat $successloglines | grep -v $first | wc -l )
	#datelog "count: $count"
	local divisor=20
	local n=$(( count % divisor ))
	if test $n -eq 0 
	then
   		sheader
	fi
}


# rotate log
	
# daily rotate
_date=$(date +%Y-%m-%d)

oldlogdir=oldlogs/$_date
	

if [ ! -d "$oldlogdir" ]
then
	datelog "${FILENAME}: rotate log"
	mkdir "$oldlogdir"
	mv aa_* "$oldlogdir"
	mv rsync_* "$oldlogdir"
	mv rr_* "$oldlogdir"
	mv $LOGFILE "$oldlogdir"
	datelog "${FILENAME}: log rotated to '$oldlogdir'"
fi

IFS=' '
declare -a successlist
declare -a unsuccesslist

datelog "${FILENAME}"
datelog "${FILENAME}: check all projects in all disks: '$DISKLIST'"
	

datelog ""
datelog ""
for _disk in $DISKLIST
do
	# clean up ssh messages
	datelog ""
	datelog "${FILENAME}: ==== next disk: '$_disk' ===="
	datelog ""
	oldifs2=$IFS
	IFS=','
	RET=""
	# call disk.sh ############################################
	./disk.sh "$_disk"
	###########################################################
        RET=$?
	IFS=$oldifs2

	if [[ $RET = "$DISKLABELNOTFOUND" ]]
	then
		datelog "${FILENAME}: HD with label: '$_disk' not found"
        fi
        
	if [[ $RET = "$MOUNTDIRTNOTEXIST" ]]
        then
        	datelog "${FILENAME}: mountpoint for HD with label: '$_disk' not found: '/mnt/$_disk' "
        fi


        if [[ $RET = "$DISKNOTMOUNTED" ]]
        then
        	datelog "${FILENAME}: HD with label: '$_disk' couldn't be mounted" 
        fi

        if [[ ${RET} == "$DISKNOTUNMOUNTED" ]]
        then
          	datelog "${FILENAME}: HD with label: '$_disk' couldn't be unmounted" 
        fi

        if [[ ${RET} == "$SUCCESS" ]]
	then
        	datelog   "${FILENAME}: '$_disk' sucessfully done"
		datelog   "${FILENAME}: cat successarraytxt: $( cat $successarraytxt )"
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
		# datelog "${FILENAME}: write success disk: $_disk"
                # successlog  successlist[@] unsuccesslist[@] $_disk


        else
        	if [[ "${RET}" == "$TIMELIMITNOTREACHED" ]]
                then
                	datelog "${FILENAME}: '$_disk' time limit not reached, wait '${DURATION}' minutes"
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


datelog "${FILENAME}: write success disk: $_disk"
_ls=${#successlist[@]}
_luns=${#unsuccesslist[@]}

if test "$_ls" -eq "0" -a "$_luns" -eq "0"  
then
	datelog "${FILENAME}: successarrays are empty, no entry in: $successloglines"
else
	write_header
	successlog  successlist[@] unsuccesslist[@] "ready"
fi

	

IFS=$oldifs1

#datelog "${FILENAME}:"
#datelog "${FILENAME}: ====== sleep ${DURATION} ======"
datelog "${FILENAME}:"

#datelog "$do_none"
donone=$waittimeinterval
oldifs=$IFS
IFS='-'

dononearray=($donone)
startdonone="09"
enddonone=$startdonone
if [ ${#dononearray[@]} = 2 ]
then
        startdonone=${dononearray[0]}
        enddonone=${dononearray[1]}
fi
$IFS=$oldifs
#datelog "${FILENAME}: array: ${a[@]} "
#datelog "${FILENAME}: array 0: $startdonone "
#datelog "${FILENAME}: array 1: $enddonone "
datelog "${FILENAME}: waittime interval:  $startdonone - $enddonone "


#properties=${a_properties[$LABEL]}

minute=$(date +%M)


# if minute == 00, then loop 2 Minutes with counter
if  [  "$minute" == "00" ] 
then
	COUNTER=0
	d="2"
	# wait 2 minutes = 2 * 6 * 10 seconds
	d=$(( d * 6 )) 
	while [  $COUNTER -lt $d ] 
	do
		minute=$(date +%M)
		COUNTER=$(( COUNTER+1 )) 
	        sleep "10s"
        	if test -f $stopfile
	        then
        		datelog "${FILENAME}: backup stopped"
        		rm $stopfile
		        exit 1
		fi
	done
fi
# minute is 02 or more, but not 00

# wait, until minute == 00, (next full hour reached)
minute=$(date +%M)

hour=$(date +%H) 
if [ "$hour" -ge "$startdonone" ]
then
	#datelog "${FILENAME}: start waittime reached:  current '$hour' gt start wait '$startdonone'"
	#datelog "${FILENAME}: end   waittime is:       current '$hour' lt end wait '$enddonone'"
	count=0
	while [  "$hour" -lt "$enddonone" ] 
	do
		#datelog "${FILENAME}: in enddonone: $hour lt  $enddonone "
		# set minute to current full hour
		minute="00"
		hour=$(date +%H) 
		#datelog "${FILENAME}: count $count, time $(date +%H:%M:%S)  "
		# every 30 min display an status message
		if [ "$count" -eq "180" ]
		then
			count=0
		fi
		if [ "$count" -eq "0" ]
		then
			datelog "${FILENAME}: time $(date +%H:%M:%S), wait until $enddonone"
		fi
		count=$(( count+1 )) 
	        sleep "10s"
        	if test -f $stopfile
	        then
        	        datelog "${FILENAME}: backup stopped"
                	rm $stopfile
	                exit 1
		fi
	done
	
else
	datelog "${FILENAME}:  stop interval not reached, current: $hour, begin stop interval: $startdonone"
fi



if [ $minute -eq "00" ]
then
	datelog "${FILENAME}: waittime end, next check at $(date +%H):00"
else
	datelog "${FILENAME}: backup ready, next check at $(date +%H --date='-1 hours ago' ):00"
	# wait until next full hour
	while [  "$minute" != "00" ] 
	do
        	minute=$(date +%M)
		# check every ten seonds for stop
        	sleep "10s"
	        if test -f $stopfile
        	then
                	datelog "${FILENAME}: backup stopped"
	                rm $stopfile
        	        exit 1
	        fi
	done
fi
exit 0








