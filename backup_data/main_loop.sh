#!/bin/bash

# file: main_loop.sh

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

. ./loop_time_duration.sh
. ./target_disk_list.sh
. ./exit_codes.sh
. ./filenames.sh
. ./arrays.sh
. ./log.sh
. ./ssh_login.sh



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
                txt=$( printf "%15s" $_s )
                line1=$line1$txt
	done
        local ff=$successloglines
        local _TODAY=`date +%Y%m%d-%H%M`
#        datelog "$_TODAY: $line1" 
        echo "$_TODAY: $line1" >> $ff

}


function successlog {

	declare -a successline=( $SUCCESSLINE )

	# use one of the entries in array for grep later
	local first=${successline[2]}

	#datelog "cat $successloglines | grep -v $first | wc -l "
	local count=$( cat $successloglines | grep -v $first | wc -l )
	#datelog "count: $count"
	local divisor=20
	local n=$(( count % divisor ))
	if test $n -eq 0 
	then
   		sheader
	fi

        declare -a slist=("${!1}")
        declare -a unslist=("${!2}")
	local _disk=$3

	#datelog "${FILENAME}:  sline   in func   : $( echo ${slist[@]} ) "
	#datelog "${FILENAME}:  unsline in func   : $( echo ${unslist[@]} ) "
	#datelog "${FILENAME}:  _disk   in func   : $( echo ${_disk} ) "
	#datelog "successline in func all: $( echo ${successline[@]} ) "

       	#line="d: $_disk, = " 
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
	#		datelog "un: $_s, item: $item"
		    	if test "$_s" = "$item" 
		    	then
		    		value="nok"
			fi
		done    
                txt=$( printf "%15s" $value )
                line=$line$txt
		#datelog "s: $_s, val: $value"

	done

        local ff=$successloglines
        local _TODAY=`date +%Y%m%d-%H%M`
        datelog "${FILENAME}:  $_TODAY: $line" 
        echo "$_TODAY: $line" >> $ff
	datelog "${FILENAME}:  rsync $ff $notifytargetsend"
	#rsync $ff ${notifytargetsend}erfolgsliste.txt

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
	mv llog.log "$oldlogdir"
	datelog "${FILENAME}: log rotated to '$oldlogdir'"
fi

IFS=' '
declare -a successlist
declare -a unsuccesslist

## loop over all disks with label ... (in ./target_disk_list.sh )
	
for _disk in $DISKLIST
do
	# clean up ssh messages
	datelog "${FILENAME}: next disk: '$_disk'"
	oldifs2=$IFS
	IFS=','
	RET=""
	./disk.sh "$_disk"
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
                	datelog "${FILENAME}: '$_disk' wait"
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
	#datelog "${FILENAME}: successarrays are not empty, write entry to: $successloglines"
	successlog  successlist[@] unsuccesslist[@] "ready"
fi

	

IFS=$oldifs1

datelog "${FILENAME}:"
datelog "${FILENAME}: ====== sleep ${DURATION} ======"
datelog "${FILENAME}:"

# check for file 'stop'
COUNTER=0
d=$DURATIONx
d=$(( d * 60 )) 
while [  $COUNTER -lt $d ] 
do
     	#echo The counter is $COUNTER
	COUNTER=$(( COUNTER+1 )) 
	#datelog "c: $COUNTER"
	#datelog "d: $d"
        sleep "1s"
	 #               sleep "1m"
        if test -f $stopfile
        then
        	datelog "${FILENAME}: stopped"
        	rm $stopfile
	        exit 1
	fi
done

exit 0








