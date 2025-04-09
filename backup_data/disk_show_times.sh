#!/bin/bash


# file: show_times_disk.sh

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




. ./cfg.working_folder
. ./cfg.projects

. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_folders.sh


TODAY=`date +%Y-%m-%dT%H:%M`
use_retains=$2

readonly _disk=$1
readonly lv_cc_logname=""
readonly lv_max_last_date="$max_last_date"

if [ -z $_disk  ]
then
	echo 	"Usage: show_times_disk.sh disklabel "
	exit 1
fi


# copy from src_log.sh

function targetdisk {

	local _disk_label=$1
	#${a_targetdisk[${_disk_label}]}
	# test for a variable that does contain a value 
#set -x
	local _targetdrive="empty"
	if [[ $_disk_label ]]
	then
		_targetdrive=${a_targetdisk[${_disk_label}]}
		if [[ $_targetdrive ]]
		then
			echo "$_targetdrive"
		else
			echo "$_disk_label"
		fi
	else
		echo "empty"
	fi
#set -x	
}


function log {
   local msg=$1
#   echo -e "$msg" >> "show_times.log"
}



function stdatelog {
        local _TODAY=$( date +%Y%m%d-%H%M )
        log "$_TODAY ==>  $1"
}

function dateecho {
        local _TODAY=$( date +%Y%m%d-%H%M )
        echo "$_TODAY ==>  $1"
}

_targetdisk=$( targetdisk $_disk )


if [ $_targetdisk != $_disk ]
then
	_targetdisk="${_disk}(${_targetdisk})"
fi



# use media mount instead of /mnt
# 0 = use
# 1 = don't use, use /mnt
readonly use_mediamount=0

arrays_ok=0

if test ${#a_properties[@]} -eq 0 
then
	stdatelog "Array 'a_properties' doesn't exist"
	arrays_ok=1
fi
if test ${#a_projects[@]} -eq 0 
then
	stdatelog "Array 'a_projects' doesn't exist"
	arrays_ok=1
fi
if test ${#a_interval[@]} -eq 0 
then
	stdatelog "Array 'a_interval' doesn't exist"
	arrays_ok=1
fi
if test "$arrays_ok" -eq "1" 
then
	exit $BK_ARRAYSNOK
fi


# diff = old - new 
# h = 60, d = 1440, w=10080, m=43800,y=525600
function time_diff_minutes() {
        local _old=$1
        local _new=$2
	
        # convert the date "1970-01-01 hour:min:00" in seconds from Unix Date Stamp
        # "1980-01-01 00:00"
        local sec_old=$(date +%s -d $_old)
        local sec_new=$(date +%s -d $_new)
	#stdatelog "diff minutes: old '$_old', new: '$_new' "
	#stdatelog "diff seconds: old '$sec_old', new: '$sec_new' "
        echo "$(( (sec_new - sec_old) / 60 ))"
}



function check_disk_label {
        local _LABEL=$1

        # 0 = success
        # 1 = error
        local goodlink=1

	local _targetdisk=$( targetdisk $_LABEL )
	local uuid=$( cat "uuid.txt" | grep -v '#' | grep -w $_targetdisk | awk '{print $2}' )
	#local uuid=$( gawk -v pattern="$_LABEL" '$1 ~ pattern  {print $NF}' $bv_workingfolder/uuid.txt )

        local disklink="/dev/disk/by-uuid/$uuid"

	# test, if symbolic link
        if test -L ${disklink} 
        then
                # test, if exists
                #if [ -e ${disklink} ]
                #then
                        goodlink=0
                #fi
        fi
        return $goodlink
}
# parameter: string with time value, dd:hh:mm  
# value in array: string with time value, dd:hh:mm  
#                                      or hh:mm  
#                                      or mm  
# return:    minutes
function decode_programmed_diff_local {
	
        local _interval=$1
        local _oldifs=$IFS
        IFS=':'

        # split into array
        local _array=(${_interval})
        local _length=${#_array[@]}

        IFS=$_oldifs

        # mm only
        local _result_minutes=10#${_array[0]}
	local _hours=0
	local _days=0
	local _minutes=0

        if test $_length -eq "2"
        then
                # is hh:mm
                _hours=10#${_array[0]}
                _minutes=10#${_array[1]}
                _result_minutes=$(( ( ${_hours} * 60 ) + ${_minutes} ))
        fi
        if test $_length -eq "3"
        then
                # dd:hh:mm  - length 3
                _days=10#${_array[0]}
                _hours=10#${_array[1]}
                _minutes=10#${_array[2]}
                _result_minutes=$(( ( ( ${_days} * 24 )  * 60 + ${_hours} * 60  ) + ${_minutes} ))
        fi

        echo $_result_minutes

}



# parameter is key in a_interval array
function decode_programmed_diff {
	local _k=$1
        local _arr=${a_interval[${_k}]}
	if test -z $_arr 
	then
		echo "fatal error: a_interval ${_k} is empty"
		exit 1
	fi 
        local _r2=$( decode_programmed_diff_local $_arr )
        echo $_r2
}



function encode_diff {

        local hour=60
        local day=$(( hour * 24 ))
        local testday=$1
	local ret=""
	local negativ="false"
	if test $testday -lt "0"
	then
		testday=$(( $testday * (-1) ))
		negativ="true"
	fi

	local days=$(( testday/day  ))
        local remainder=$(( testday - days*day   ))
	local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq 0
	then
		if test $hours -eq 0
        	then
			ret=$minutes
		else
			phours=$( printf "%02d\n"  $hours )
			pminutes=$( printf "%02d\n"  $minutes )
			ret="$phours:$pminutes"
		fi
	else
		pdays=$( printf "%02d\n"  $days )
		phours=$( printf "%02d\n"  $hours )
		pminutes=$( printf "%02d\n"  $minutes )
		ret="$pdays:$phours:$pminutes"	
	fi

	# add minus sign, if negative 
	if test "$negativ" = "true" 
	then
		ret="-$ret"
	fi	

	echo "$ret"
}


# parameter
# $1 = Disklabel
# $2 = Projekt
# return 0, 1 
function check_disk_done {
	
        local _label=$1
        local _p=$2
	local _key=${_label}_${_p}

        local _LASTLINE=""
        local _current=`date +%Y-%m-%dT%H:%M`

        # 0 = success
        # 1 = error
        local _DONEINTERVAL=1
        local _DONEFILE="./${bv_donefolder}/${_key}_done.log"
        local _LASTLINE=""
        #echo "in function check_disk_done "
        local _last_done_time="$lv_max_last_date"

        if test -f $_DONEFILE
        then
                # last line in done file
		_last_done_time=$(awk NF  $_DONEFILE | awk  'END {print }' -)

        fi
        local _DIFF=$(time_diff_minutes  $_last_done_time  $_current  )
        #local _pdiff=${a_interval[${_key}]}
	local _pdiff=$( decode_programmed_diff ${_key} )
	if test $_DIFF -ge "$_pdiff"
        then
                _DONEINTERVAL=0
        fi
	
        echo $_DONEINTERVAL
}


function check_pre_host {

	local _LABEL=$1
	local _p=$2

        local _precondition=${bv_preconditionsfolder}/${_LABEL}_${_p}.${bv_preconditionsfolder}.sh

        if [[  -f $_precondition ]]
        then
                ($_precondition)
                _RET=$?
                if [ $_RET -ne 0 ]
                then
                        return 1
                else
                        return 0
                fi
	fi
        return 1
}




# parameter
#  $1 = file with lines = number of lines in this file is retains count = number of current retains done at this retain key
# filename is 'disk_project_retains'
# get number_of_ entries keeped in history  
function entries_keeped {
	local _index=$1
	local _retains_count_file_name=${retains_count_file_names[$_index]}
#	dateecho "$_retains_count_file_name   = ${retains_count_file_names[$_index]}"
	local _counter=0
	local _retain_value=${retains[$_index]}
	if [ -f ${_retains_count_file_name} ]
	then
		# count the lines
		# count is number of entries_keeped
		_counter=$(  wc  -l < ${_retains_count_file_name}  )
	fi
	echo $_counter
}



_targetdisk=$( targetdisk $_disk )
stdatelog "label: $_disk"
stdatelog "target: $_targetdisk"
check_disk_label $_disk
goodlink=$?

dateecho ""



if [ $_targetdisk != $_disk ]
then
	_targetdisk="${_disk}(${_targetdisk})"
fi
dateecho "==== next disk: '$_targetdisk' ===="
dateecho ""
if test $goodlink -ne 0
then
	# disk label/uuid not found, or targetdisk/uuid
	dateecho  "${lv_cc_logname}: disk '$_targetdisk' wasn't found in '/dev/disk/by-uuid'"
	dateecho ""
fi


PROJEKTLABELS=${a_projects[$_disk]}

DONE_REACHED=0
lv_done_not_reached=1
ispre=1
mindiff=100000
minexpected=10000
declare -A nextprojects
nextprojekt=""
#DONE=$bv_donefolder
#stdatelog "DONE: '$DONE'"

stdatelog "==== next disk: '$_targetdisk' ===="
# find projects in time		
dateecho "                 dd:hh:mm               dd:hh:mm               dd:hh:mm"
for p in $PROJEKTLABELS
do
        lpkey=${_disk}_${p}
	stdatelog "lpkey: '$lpkey' "
	lv_lpkey=$lpkey
        _current=`date +%Y-%m-%dT%H:%M`
        DONE_FILE="$bv_workingfolder/${bv_donefolder}/${lpkey}_done.log"
        LASTLINE=$lv_max_last_date
        if [ -f $DONE_FILE  ]
        then
                # last line in done file
		LASTLINE=$(awk NF  $DONE_FILE | awk  'END {print }' -)

        fi
        pdiff=$(  decode_programmed_diff ${lpkey} )

	done_diff_minutes=$(   time_diff_minutes  "$LASTLINE"  "$_current"  )
	stdatelog "pdiff: '$pdiff', done: '$done_diff_minutes' "
	deltadiff=$(( pdiff - done_diff_minutes ))

        # ret , 0 = do backup, 1 = interval not reached, 2 = daytime not reached
        DISKDONE=$(check_disk_done $_disk $p )

        txt=$( printf "%-14s\n"  $( echo "${p}" ) )
        n0=$( printf "%5s\n"  $done_diff_minutes )
        pdiff_print=$( printf "%5s\n"  $pdiff )
        ndelta=$( printf "%6s\n"  $deltadiff )

        fndelta=$( encode_diff $ndelta )
        fndelta=$( printf "%8s\n"  $fndelta )
        fn0=$( encode_diff  $n0 )
        fn0=$( printf "%8s"  $fn0 )
        pdiff_minutes_print=$( encode_diff  $pdiff_print )
        pdiff_minutes_print=$( printf "%8s"  $pdiff_minutes_print )

        if test $DISKDONE -eq $DONE_REACHED
        then
                diskdonetext="ok"
                check_pre_host $_disk $p 
		ispre=$?
                if test $ispre -eq 0
                then
                        # all is ok,  do backup
                        dateecho "$txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  reached, source is ok"
                        nextprojects["$p"]=$p
                #       isdone=true
                else
                        dateecho "$txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  reached, source not available"
                fi
        fi


        if test "$DISKDONE" -eq $lv_done_not_reached
        then
                diskdonetext="not"
                dateecho "$txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  do nothing"
        fi
if test $use_retains -gt 0
then
	# check, if config file ends with 'conf', then we do a backup with 'rsnapshot'
	lv_rsnapshot_config=${lpkey}.conf
	log "#  '${lv_rsnapshot_config}' "
	lv_rsnapshot_cfg_file=${bv_conffolder}/${lv_rsnapshot_config}

	# look up for lines with word 'retain'
	retainslist=$( cat ./${lv_rsnapshot_cfg_file} | grep ^retain )
	OIFS=$IFS
IFS='
'
	# convert to array of 'retain' lines
	# 0 = 'retain', 1 = level, 2 = count
	lines=($retainslist)
	#dateecho "# current number of retain entries  './${lv_rsnapshot_cfg_file}' : ${#lines[@]}"

	IFS=$OIFS


	declare -A retainscount
	declare -A retains_count_file_names
	declare -A retains
	n=0
	for i in "${lines[@]}"
	do
		# split to array with ()
		_line=($i)

		# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
		rlevel=${_line[1]}
		retains[$n]=$rlevel
		rcount=${_line[2]}
		if [[ $rcount -lt 2 ]]
		then
			dateecho "retain count is < 2 in retain '$rlevel', this is not allowed in 'rsnapshot' and this backup"
			exit $BK_ERRORINCOUNTERS
		fi

		retainscount[$n]=$rcount
		retains_count_file_names[$n]=$bv_retainscountfolder/${lv_lpkey}_${rlevel}

		ek=$(entries_keeped $n )
		#dateecho "keeped $ek"
		#dateecho "line $n"
		_t0=$(  printf "%8s %4s (%2s)" ${retains[$n]} ${retainscount[$n]} $( entries_keeped $n )   )
		dateecho "retain $n: $_t0"

		(( n++ ))
	done
	dateecho ""
fi
done


exit 0

# EOF


