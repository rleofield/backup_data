#!/bin/bash

# file: project.sh

# parameter:
#   $1 = DISK, Backup-HD
#   $2 = PROJECT,  Backup-Projekt auf dieser HD

. ./exit_codes.sh
. ./log.sh



# parameter
#  $1 = file with lines = number of lines is retains count = number of current retains done at this retain key
function count_retain_lines {
        local _file=$1
        local _counter=0
        if test -f ${_file}
        then
		# count the lines
          	_counter=$(cat ${_file} | wc -l )
        fi
        echo $_counter
}

#  $1 = file with lines = number of lines is retains count = number of current retains done at this retain key
function count_retains {
        local _rsnapshot_root=$1
	local _retain=$2
        local _counter=0


        if test -d ${_rsnapshot_root}
        then
                # count the lines
		_counter=$( ls -al $_rsnapshot_root  | grep $_retain | wc -l )
        fi
        echo $_counter
}



readonly TODAY_LOG=`date +%Y%m%d-%H%M`

OIFS=$IFS


DISK=$1 
PROJECT=$2 

FILENAME=$(basename "$0" .sh)
FILENAME="project"
FILENAME=${FILENAME}:${DISK}:$PROJECT

datelog ""
datelog "${FILENAME}: == start disk with project: '$DISK', '$PROJECT' =="

readonly CONFFOLDER="./conf"
RSNAPSHOT_CONFIG=${DISK}_${PROJECT}.conf
RSNAPSHOT_ROOT=$(cat $CONFFOLDER/${RSNAPSHOT_CONFIG} | grep snapshot_root | grep -v '#' | awk '{print $2}')

line=$( cat ${CONFFOLDER}/${RSNAPSHOT_CONFIG} | grep ^snapshot_root )
larray=( $line )
snapshot_root=${larray[1]}

retainslist=$( cat ${CONFFOLDER}/${RSNAPSHOT_CONFIG} | grep ^retain )
IFS='
'
# convert to array
lines=($retainslist)
datelog "${FILENAME}: # current status of retains in '${CONFFOLDER}/${RSNAPSHOT_CONFIG}' : ${#lines[@]}"

IFS=$OIFS

declare -A retainscount
declare -A file_counter_filenames
declare -A retains

n=0
for i in "${lines[@]}"
do
        # split to array with ()
	line=($i)
	_retain=${line[1]}
	retainscount[$n]=${line[2]}
        _file=retains_count/${DISK}_${PROJECT}_${_retain}
	file_counter_filenames[$n]=$_file
	_count=$( count_retain_lines $_file )
	#_counter=$( count_retains $RSNAPSHOT_ROOT ${_retain} )
	datelog "${FILENAME}: retain $n:    ${_retain}\t${retainscount[$n]} ($_count)"
	retains[$n]=$_retain
        let n=n+1
done



# first interval

#datelog "${FILENAME}: first retainscount file: ${file_counter_filenames[0]}"

# get next index, level 0


# do first
index=0
oldindex=0
currentretain=0
counter=0 
_counter=0
max_count=0
intervaldonefolder="interval_done"
intervaldonefile="${DISK}_${PROJECT}_done.txt"


currentretain=${retains[$index]}

datelog "${FILENAME}: do retain '$currentretain': in '$PROJECT' at disk '$DISK'"
# parameter $INTERVAL $DISK $PROJECT
# do first !!!!!!!!!!!
./rs.sh $currentretain $DISK $PROJECT
RET=$?

if test $RET -eq $NORSNAPSHOTROOT 
then
        datelog "${FILENAME}: rs.sh: rsnapshot root not found for '$PROJECT'"
	exit $NORSNAPSHOTROOT
fi
if test $RET -eq $RSYNCFAILS
then
        datelog "${FILENAME}: rs.sh: rsync fails '$PROJECT'"
	exit $RSYNCFAILS
fi


current=`date +%Y-%m-%dT%H:%M`
currentretain=${retains[$index]}



if test $RET -eq 0 
then
	# increment index 0 counter, indirect via number of lines in file
	# append line in file_counter_filenames[$index] with date 
        echo "runs at: $current" >> ${file_counter_filenames[$index]}
	# get back this entry
        _file=${file_counter_filenames[$index]}
	counter=$( count_retain_lines $_file ) 
	max_count=${retainscount[$index]}
	echo "($counter of $max_count) ${currentretain} at: $current" >> $intervaldonefolder/$intervaldonefile
	#
	# main done is written here
	#
	echo "$current" > ./done/${DISK}_${PROJECT}_done.log
	datelog "${FILENAME}: write last date: ./done/${DISK}_${PROJECT}_done.log"
fi





_file=${file_counter_filenames[$index]}
counter=$( count_retain_lines $_file ) 
max_count=${retainscount[$index]}

#datelog "${FILENAME}: print intervals"
#datelog "${FILENAME}: '_counter'    : $_counter"
#datelog "${FILENAME}: '${currentretain}'    : $counter"

datelog "${FILENAME}: status after sync '$PROJECT'"
datelog "${FILENAME}: '${currentretain}'    :   $counter"
datelog "${FILENAME}: '${currentretain}' max:   $max_count"

# check rotates

# if  index 0 count >= max, do index 1
# too much first levels, shift to next level 
if test $counter -ge  $max_count
then

	# do index 1
	oldindex=$index
	index=1
	_oldfile=${file_counter_filenames[$oldindex]}
	_file=${file_counter_filenames[$index]}
	currentretain=${retains[$index]}
	oldretain=${retains[$oldindex]}
#	datelog "in: if test $counter -ge  $max_count "
	datelog "${FILENAME}: (in index 1)    do rotate '${currentretain}':  '$PROJECT' at disk '$DISK'"
	# parameter $INTERVAL $DISK $PROJECT
        ./rs.sh ${currentretain} $DISK $PROJECT
	RET=$?
	if test $RET -eq $RSYNCFAILS
	then
        	datelog "${FILENAME}: rs.sh: rsync fails '$PROJECT'"
		exit $RSYNCFAILS
	fi
	if test $RET -eq 0 
	then
		# increment index 1 counter
                echo "runs at: $current" >> ${_file}
		counter=$( count_retain_lines $_file )
		max_count=${retainscount[$index]}
		echo "($counter of $max_count)  ${currentretain} at: $current" >> $intervaldonefolder/$intervaldonefile

		# remove index 0 counter, set count to 0, = interval eins
		datelog "${FILENAME}: remove counter file for retain '${oldretain}', file: ${_oldfile}"
		rm ${_oldfile}
	fi

	counter=$( count_retain_lines $_file)
	max_count=${retainscount[$index]}
	datelog "${FILENAME}: print intervals"
	#datelog "${FILENAME}: '_counter'    : $_counter"
	datelog "${FILENAME}: '${currentretain}'    : $counter"
	datelog "${FILENAME}: '${currentretain}' max: $max_count"
        
	# if index 1 counter >= max, do index 2
	# too much levels, shift to next level 
	if test $counter -ge  $max_count
	then

 		# do index 2
		oldindex=$index
		index=2
        	_oldfile=${file_counter_filenames[$oldindex]}
        	_file=${file_counter_filenames[$index]}
		currentretain=${retains[$index]}
		oldretain=${retains[$oldindex]}
		datelog ""
	        datelog "${FILENAME}: (in index2)  do rotate '${currentretain}': '$PROJECT' at disk '$DISK'"
		# parameter $INTERVAL $DISK $PROJECT
        	./rs.sh ${retains[$index]} $DISK $PROJECT
        	RET=$?
		if test $RET -eq $RSYNCFAILS
		then
		        datelog "${FILENAME}: rs.sh: rsync fails '$PROJECT'"
			exit $RSYNCFAILS
		fi
	        if test $RET -eq 0 
        	then
                	# increment index 2 counter
	             	echo "runs at: $current" >> ${_file}
			counter=$( count_retain_lines $_file )
			max_count=${retainscount[$_index]}
			echo "($counter of $max_count)    ${currentretain} at: $current" >> $intervaldonefolder/$intervaldonefile
        	        # remove index 1 counter, set count to 0, = interval zwei
	                datelog "${FILENAME}: remove counter file for retain '${oldretain}', file ${_oldfile}"
	                rm ${_oldfile}
		fi
        
		counter=$( count_retain_lines $_file)
		max_count=${retainscount[$index]}
		datelog "${FILENAME}: print intervals"
	        #datelog "${FILENAME}: '_counter'    :   $_counter"
	        datelog "${FILENAME}: '${currentretain}'    :   $counter"
	        datelog "${FILENAME}: '${currentretain}' max:   $max_count"


        	# if index 2 counter >= max, do index 3
		# too much levels, shift to next level 
	        if test $counter -ge  $max_count
        	then

	                # do index 3
			oldindex=$index
			index=3
                	_oldfile=${file_counter_filenames[$oldindex]}
                	_file=${file_counter_filenames[$index]}
			currentretain=${retains[$index]}
			oldretain=${retains[$oldindex]}
			datelog ""
        	        datelog "${FILENAME}: #### do rotate '${retains[$index]}': '$PROJECT' at disk '$DISK'"
			# parameter $INTERVAL $DISK $PROJECT
	                ./rs.sh ${retains[$index]} $DISK $PROJECT
                	RET=$?
			if test $RET -eq $RSYNCFAILS
			then
			        datelog "${FILENAME}: rs.sh: rsync fails '$PROJECT'"
				exit $RSYNCFAILS
			fi
                	if test $RET -eq 0 
                	then
                        	# increment index 3 counter
                                echo "runs at: $current" >> ${file_counter_filenames[$index]}
				counter=$( count_retain_lines $_file )
				max_count=${retainscount[$_index]}
				echo "($counter of $max_count)      ${currentretain} at: $current" >> $intervaldonefolder/$intervaldonefile
                        	# remove index 2 counter, set count to 0, = interval drei
                        	datelog "${FILENAME}: remove counter file for retain '${oldretain}', file ${_oldfile}"
                        	rm ${_oldfile}
                	fi

			counter=$( count_retain_lines $_file )
			max_count=${retainscount[$_index]}
			datelog "${FILENAME}: print intervals"
	                #datelog "${FILENAME}: '_counter' :      $_counter"
	                datelog "${FILENAME}: '${currentretain}' :      $counter"
        	        datelog "${FILENAME}: '${currentretain}' max:   $max_count"

			# last, no further loops
	               	# if index 3 counter >= max, do nothing more
			# too much levels, son't shift to next level, last level 
	               	if test $counter -ge  $max_count
        	       	then
                                # nothing more to do
                        	_file=${file_counter_filenames[$index]}
				datelog ""
				datelog "${FILENAME}: ======="
				datelog "${FILENAME}: in last '${currentretain}', repeat all"
				datelog "${FILENAME}: ======="
				datelog ""
                       		# remove index 3 counter, set count to 0, = interval vier
                        	datelog "${FILENAME}: remove counter file for retain '$currentretain', eg. set to 0, rm ${_file}"
				datelog ""
				datelog ""
                                # rm _file is not _oldfile, is currentf
                        	rm ${_file}

			fi
        	fi
	fi
#else
	#datelog "${FILENAME}: no retain max reached"
fi

sync


datelog "${FILENAME}: ==  end disk with project: '$DISK', '$PROJECT' =="
datelog ""




