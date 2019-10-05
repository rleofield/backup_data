#!/bin/bash

# file: bk_project.sh
# version 19.04.1


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


# parameter:
#   $1 = DISK, Backup-HD
#   $2 = PROJECT,  Backup-Projekt auf dieser HD

. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.test_vars

. ./src_exitcodes.sh
. ./src_global_strings.sh
. ./src_folders.sh
. ./src_log.sh

readonly DISK=$1 
readonly PROJECT=$2 
if [ ! $DISK ] || [ ! $PROJECT ]
then
	echo "DISK '$DISK' or PROJECT '$PROJECT' is null"
	exit 1
fi

readonly projectkey=${DISK}_${PROJECT}
readonly FILENAME="project:${DISK}:$PROJECT"


#readonly CONFFOLDER="./conf"
readonly RSNAPSHOT_CONFIG=${projectkey}.conf
readonly RSNAPSHOT_ROOT=$(cat ./$CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^snapshot_root | grep -v '#' | awk '{print $2}')
readonly DO_RSYNC=$(cat ./$CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^rsync_root | grep -v '#' | wc -l)
# dlog "cat ./$CONFFOLDER/${RSNAPSHOT_CONFIG} | grep ^rsync_root | grep -v '#' | wc -l"

# if line with 'rsync_root' exists, exit
# 'rsync_root' is deprecated
if [ $DO_RSYNC -gt 0 ]
then
	dlog "line with 'rsync_root' exists, marker in log: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
	exit 0
fi

# 3 local arrays
declare -A retainscount
declare -A retain_count_files
declare -A retains




# parameter
#  $1 = file with lines = number of lines is retains count = number of current retains done at this retain key
# filename is 'disk_project_retain' and is located in folder 'done'
# get count_retain_lines  with ${retain_count_files[$index]}
function count_retain_lines {
        local _index=$1
	local _filename=${retain_count_files[$_index]}
        local _counter=0
        if [ -f ${_filename} ]
        then
		# count the lines
          	_counter=$(  wc  -l < ${_filename}  )
        fi
        echo $_counter
}


# used for final processing, after project is successfully done
function final_func {

	local _DISK=$1
	local _PROJECT=$2
	local _RSNAPSHOT_ROOT=$3
	local _firstretain=$4

	# do nothing
	return 0

	################################
	# final stage for rleo3
	# copy last backup to final disk,  

	local final_extern_disk=${FINAL_EXTERN_DISK}

	local finaldisk=${final_extern_disk}
	if test -d /mnt/$finaldisk/rs_final/$_DISK/$_PROJECT
	then
        	#datelog "##    /mnt/$finaldisk/rs_final/$DISK/$PROJECT exists"
	        dlog "final copy: rsync -avSAXH ${_RSNAPSHOT_ROOT}${_firstretain}.0/ /mnt/$finaldisk/rs_final/$_DISK/$_PROJECT"
        	rsync -avSAXH ${_RSNAPSHOT_ROOT}${_firstretain}.0/ /mnt/$finaldisk/rs_final/$_DISK/$_PROJECT --delete
	else
        	dlog "####  /mnt/$finaldisk/rs_final/$_DISK/$_PROJECT doesn't exist"
	fi

}

# parameter
# $1 = _currentretain
# $2 = _currenttime
# used, but has no effekt
function write_first_counter_file {
	local _currentretain=$1
	local _currenttime=$2
	local _folder="${RSNAPSHOT_ROOT}${_currentretain}.0" 
	local _txt="0_created_at_retain_${_currentretain}.0_${_currenttime}" 
	local _file="$_folder/$_txt.txt"
	#dlog "write marker file at counter 0, retain: $_currentretain, file: $_file" 
	#dlog "marker at counter 0, (outcommented) txt: $_txt" 
	#echo "$_txt" >  $_folder/$_txt.txt 
}




dlog ""
dlog "== start project '$PROJECT' at disk '$DISK'  =="
dlog "snapshot_root= '$RSNAPSHOT_ROOT'"


readonly retainslist=$( cat ./${CONFFOLDER}/${RSNAPSHOT_CONFIG} | grep ^retain )
OIFS=$IFS
IFS='
'
# convert to array of 'retain' lines
# 0 = 'retain', 1 = level, 2 = count
readonly lines=($retainslist)
dlog "# current number of retain entries  './${CONFFOLDER}/${RSNAPSHOT_CONFIG}' : ${#lines[@]}"

IFS=$OIFS


# split retains from conf file


readonly size=${#lines[@]}
if [ $size -ne 4 ]
then
	dlog "error in './$CONFFOLDER/${RSNAPSHOT_CONFIG}', number of retain entries is wrong, must be 4, but is '$size'"
        exit $RSYNCFAILS
fi
# retain values example
: << '--COMMENT--'
retain          eins    5
retain          zwei    4
retain          drei    4
retain          vier    4
--COMMENT--

n=0
for i in "${lines[@]}"
do
        # split to array with ()
	_line=($i)

	# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
	retains[$n]=${_line[1]}
	retainscount[$n]=${_line[2]}
	retain_count_files[$n]=$retainscountfolder/${projectkey}_${_line[1]}

	_t0=$(  printf "%8s %4s (%2s)" ${retains[$n]} ${retainscount[$n]} $( count_retain_lines $n )   )
	dlog "retain $n: $_t0"

	(( n++ ))
done

firstretain=${retains[0]}

dlog "firstretain: $firstretain"

# retain from conf splitted


readonly intervaldonefile="${projectkey}_done.txt"


# remove index 0 counter, set count to 0, = interval eins
# par = oldindex
function remove_counter_file {
	local _oldindex=$1
	local _oldretain=${retains[$_oldindex]}
	local _oldfile=${retain_count_files[$_oldindex]}
	dlog "remove counter file for retain '${_oldretain}', file: ${_oldfile}, means set 'count' to 0"
	# means: set filecounter at 0
	rm ${_oldfile}
}

# parameter
# $1 = index in retainsliststs
# increment index counter, indirect via number of lines in file
# means append line in retain_count_file[$index] with date 
function update_counter {
	local _index=$1
	local _currenttime=`date +%Y-%m-%dT%H:%M`
	local _currentretain=${retains[$_index]}
        local _counter_=$( count_retain_lines $_index )
	dlog " --- increment $_currentretain"
	dlog " --- increment file is:  ${retain_count_files[$_index]}, number of lines in this file is 'count' "

	# increment by one line
        echo "runs at: $_currenttime" >> ${retain_count_files[$_index]}

        # get back this entry
        #local _temp0=${retain_count_files[$_index]}
        local _counter=$( count_retain_lines $_index )
        local _max_count=${retainscount[$_index]}
        if [ $_counter -eq 1 ]
        then
                write_first_counter_file ${_currentretain} ${_currenttime}
        fi
	#dlog "get 'created at' from '${RSNAPSHOT_ROOT}${_currentretain}.$_index/created_at_*' file ===== "
	# get loop number from previous 'created at' at current retain
	# e.g.: /mnt/bdisk/rs/nc/eins.0/created_at_2019-10-05T10:49_number_03767.txt
	# loop number is at end
	local cr_file=$( ls -1 ${RSNAPSHOT_ROOT}${_currentretain}.0/created_at_*  )
	local _tt=""
	if [ ! -z $cr_file ]
	then
		# get last line, is only one line in file
		cr=$( cat ${cr_file}  )
		# prefix_created_at="created at: ", defined in src_global_strings.sh
		pat=${prefix_created_at}
		# line is: created at: 2019-06-13T13:25, loop: 02618
		# remove pattern 'created at: ', in _tt is '2019-06-13T13:25, loop: 02618'
		_tt=${cr#$pat}
	fi

	space="xxx"

	case $_index in
		0) 
			space=" "
			;;
		1) 
			space="  "
			;;
		2) 
			space="   "
			;;
		3) 
			space="    "
			;;
	esac
	local msg=""
	if [ $_max_count -lt 10 ]
	then
		msg=$( printf "%1d of %1d"  $_counter $_max_count )
	else
		msg=$( printf "%2d of %2d"  $_counter $_max_count )
	fi
        dlog "write reportline to '$intervaldonefolder/$intervaldonefile'"
        dlog "reportline is:  \"echo ($msg)${space}${_currentretain} at: $_currenttime created '$_tt'\""
        echo "($msg)${space}${_currentretain} at: $_currenttime created '$_tt'" >> $intervaldonefolder/$intervaldonefile


}


# parameter
# $1 = index in retainsliststs
function do_rs {
	local _index=$1
	local _currenttime=`date +%Y-%m-%dT%H:%M`
	local _currentretain=${retains[$_index]}


	dlog "do retain '$_currentretain': in '$PROJECT' at disk '$DISK'"
	dlog "--- rsync $_currentretain"
	# parameter $INTERVAL $DISK $PROJECT
	# do first rsnapshot, is real sync
	# ########################################
	./bk_rsnapshot.sh $_currentretain $DISK $PROJECT  
	# ########################################
	RET=$?

	if test $RET -eq $NORSNAPSHOTROOT 
	then
        	datelog "${FILENAME}: error in 'bk_rsnapshot.sh': rsnapshot root not found for '$PROJECT'"
		exit $NORSNAPSHOTROOT
	fi
	if test $RET -eq $RSYNCFAILS
	then
        	datelog "${FILENAME}: error in 'bk_rsnapshot.sh': rsync fails '$PROJECT'"
		exit $RSYNCFAILS
	fi
	return $RET

}

function do_rs_123 {
	# index is 1 2 or 3
	local _index=$1
##########  do rs ##########    
        do_rs $_index
        RET=$?

        if test $RET -eq 0
        then
                # increment index 1 counter
                update_counter $_index

                # remove index 0 counter, set count to 0, = interval eins
                remove_counter_file $(previous_index $_index)

        fi
	local _counter=$( count_retain_lines $_index)
	local _max_count=${retainscount[$_index]}
#	dlog "after sync"
	dlog "'${retains[$_index]}'    : $_counter"
	dlog "'${retains[$_index]}' max: $_max_count"

}



function do_rs_first {
	local _index=0
       	dlog " in do_rs_first '$PROJECT' "
##########  do rs ##########    
	do_rs $_index
	local RET=$?
	if test $RET -eq 0
	then
		# first was ok, update counter
        	datelog "${FILENAME}:  sync '$PROJECT' done"
        	# increment index 0 counter
	        update_counter $_index
        
	        # main done is written here
		local _currenttime=`date +%Y-%m-%dT%H:%M`
        	echo "$_currenttime" > ./done/${projectkey}_done.log
		datelog "${FILENAME}: write last date: '$_currenttime' to ./done/${projectkey}_done.log"

	fi
	local _counter=$( count_retain_lines $_index ) 
	local _max_count=${retainscount[$_index]}
	datelog "${FILENAME}: '${retains[$_index]}'    :   $_counter"
	datelog "${FILENAME}: '${retains[$_index]}' max:   $_max_count"

}

function previous_index {
	local _index=$1
	echo $(( _index -1 ))
}


# start of rsnpshot calls
##########  do_rs_first 0 ##########	
# index is 0
do_rs_first 


# index 0
index=0
counter=$( count_retain_lines $index ) 
max_count=${retainscount[$index]}

#  retain eins end


# check rotates
# if  index 0 filecounter >= max, do index 1
if test $counter -ge  $max_count
then	
	# do index 1 = second level
	index=1

	datelog "${FILENAME}: counter: $counter -ge  $max_count index: $index, root: $RSNAPSHOT_ROOT"
	##########  do rs ##########	
	do_rs_123 $index

	counter=$( count_retain_lines $index)
	max_count=${retainscount[$index]}
        
	# if index 1 counter >= max, do index 2
	m=$(( max_count )) 
	if test $counter -ge  $m
	then
 		# do index 2 = third level
		index=2
		datelog "${FILENAME}: counter: $counter -ge  $max_count index: $index, root: $RSNAPSHOT_ROOT"
	
		##########  do rs ##########	
		do_rs_123 $index
        
		counter=$( count_retain_lines $index )
		max_count=${retainscount[$index]}

        	# if index 2 counter >= max, do index 3
		m=$(( max_count )) 
	        if test $counter -ge  $m
        	then
	                # do index 3 = fourth level
			index=3
			datelog "${FILENAME}: counter: $counter -ge  $max_count index: $index, root: $RSNAPSHOT_ROOT"

			do_rs_123 $index

			counter=$( count_retain_lines $index )
			max_count=${retainscount[$index]}

			# last, no further loops
	               	# if index 3 counter >= max, do nothing more
			# too much levels, don't shift to next level, last level 
			m=$(( max_count )) 
			
			############## last compare not -ge, use -gt ###################
	               	if test $counter -gt  $m
        	       	then
				# fourth level is at end, counter reached
				#  remove counterfile for third level, if ok
                                # nothing do, no rotate, only counter control

		                # do index 4
				# oldindex 3
				index=4 # 1 after last

				datelog "${FILENAME}: counter: $counter -gt  $max_count index: $index, root: $RSNAPSHOT_ROOT"
        	        	#_oldfile=${retain_count_files[$oldindex]}
				#oldretain=${retains[$oldindex]}
				dlog ""
        		        dlog "(in index 4) do no rotate: '$PROJECT' at disk '$DISK'"

                		
	                       	# remove index 3 counter, set count to 0, = interval four
				remove_counter_file $(previous_index $index) 
                		

                                # nothing do, no rotate, only counter control
				datelog ""
				datelog "${FILENAME}: ======="
				datelog "${FILENAME}: (in last step)  '$(previous_index $index)', no rotate to next level"
				datelog "${FILENAME}: ======="
				datelog ""
				datelog ""
			fi
        	fi
	fi
fi

########### final generic start #####################
# final stage at end of project
# eg. copy last backup to final disk,  
#    is now done in acer /usr/local/bin/back
final_func "$DISK" "$PROJECT" "$RSNAPSHOT_ROOT" "$firstretain"
# end final stage 
########### final generic end  #####################


sync


datelog "${FILENAME}: ==  end project '$PROJECT' at disk '$DISK' =="
datelog ""




