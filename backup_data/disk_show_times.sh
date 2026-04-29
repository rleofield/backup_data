#!/bin/bash

# file: show_times_disk.sh
# bk_version  26.01.1


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

# prefixes of variables in backup:
# bv_*  - global vars, all files
# lv_*  - local vars, global in file
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_



# set -u, which will exit your script if you try to use an uninitialised variable
set -u

. ./cfg.working_folder
. ./cfg.projects

. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_folders.sh


################

readonly lv_disk=$1
readonly lv_use_retains="$2"

################

readonly lv_cc_logname=""

# from cfg.projects
readonly lv_max_last_date="$max_last_date"

if [ -z $lv_disk  ]
then
	echo 	"Usage: show_times_disk.sh disklabel "
	exit 1
fi

readonly lc_DONE_REACHED=0
readonly lc_DONE_NOT_REACHED=1


function log {
   local msg=$1
   echo -e "$msg" >> "sst.log"
}



function stdatelog {
        local _TODAY=$( date +%Y%m%d-%H%M )
        log "$_TODAY ==>  $1"
}

function dateecho {
        local _TODAY=$( date +%Y%m%d-%H%M )
        echo "$_TODAY ==>  $1"
}

# copy from src_log.sh

function check_arrays {
	local arrays_ok=0

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
		return $BK_ARRAYSNOK
	fi
	return $BK_ARRAYSOK

}


function is_associative_array {
	local  testarray=$1
	#arraytestdlog "testarray: $testarray"
	local ret_val=$BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	local associative_array_pattern="declare -A"

	dc=$( declare -p $testarray )
	#echo "dc: $dc"

	if [[ "$(declare -p $testarray 2>/dev/null)" == ${associative_array_pattern}* ]]
	then
		empty_array_pattern="${associative_array_pattern} $testarray=()"
		#wc=$(declare -p $name) | wc -l
		# 1 bei arr
		if [[ "$(declare -p $testarray 2>/dev/null)" == ${empty_array_pattern}* ]]
		then
			ret_val=$BK_ASSOCIATIVE_ARRAY_IS_EMPTY
		fi
		if [ $ret_val -ne 0 ]
		then
			# declare -A a_waittim=([cdisk_dserver]="10-10" )
			not_empty_array_pattern="${associative_array_pattern} $testarray=(["
			if [[ "$(declare -p $testarray 2>/dev/null)" == ${not_empty_array_pattern}* ]]
			then
				ret_val=$BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY
			fi
		fi
	fi
	return $ret_val
}

function is_associative_array_ok {
	local testarray=$1
	#	dlog "is_associative_array_ok: '$nn'"
	is_associative_array "$testarray"
	ret=$?
	if [ $ret -eq $BK_ASSOCIATIVE_ARRAY_IS_EMPTY ] || [ $ret -eq $BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY ]
	then
		return $BK_ASSOCIATIVE_ARRAY_IS_OK
	fi
	return $ret
}


function associative_array_has_value {
	local -n name=$1
	#declare -p name 2>/dev/null
	local key=$2
	#arraytestdlog "has value array check start '$key'"
	local keys=(${!name[@]})
	#arraytestdlog "has value array  check inside key '$key'"
	#local kis=1
	for k in ${keys[@]}
	do
		if [ $k = $key ]
		then
			return 0
		fi
	done
	return 1
}


function targetdisk {

	declare -i RET
	# test for a variable that does contain a value 
	local _targetdrive="$lv_disk"
	local _array="a_targetdisk"
	is_associative_array_ok "a_targetdisk"
	array_RET=$?
	if test $array_RET -gt 0
	then
		echo $_targetdrive
		return 0
	fi

	associative_array_has_value "a_targetdisk" "$lv_disk"
	array_RET=$?
	if test $array_RET -gt 0
	then
		echo $_targetdrive
		return 0
	fi

	_targetdrive=${a_targetdisk[${lv_disk}]}
	if [[ $_targetdrive ]]
	then
		echo "$_targetdrive"
	fi
	return 0
}



# diff = old - new 
# h = 60, d = 1440, w=10080, m=43800,y=525600

# format `date +%Y-%m-%dT%H:%M`
# format `YYYY-mm-ddTHH:MM`
# 2026-03-28T16:01
function time_diff_minutes() {
        local _old=$1
        local _new=$2
	
        # convert the date "1970-01-01 hour:min:00" to seconds from Unix Date Stamp
        # "1980-01-01 00:00"
        local seconds_old=$(date +%s -d $_old)
        local seconds_new=$(date +%s -d $_new)
        echo "$(( (seconds_new - seconds_old) / 60 ))"

}


function check_disk_by_uuid {

	# 0 = success
	# 1 = error
	local _targetdisk=$( targetdisk )
	local _uuid=$( cat "uuid.txt" | grep -v '#' | grep -w $_targetdisk | gawk '{print $2}' )
	local _disk_by_uuid_link="/dev/disk/by-uuid/$_uuid"
	# test, if symbolic link
	if test -L ${_disk_by_uuid_link} 
	then
		return 0
	fi
	return 1
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

        # split into array at ':'
        local _array=(${_interval})
        local _length=${#_array[@]}

        IFS=$_oldifs

        # minutes only 'mm'
        local _result_minutes=10#${_array[0]}
	local _hours=0
	local _days=0
	local _minutes=0

        if test $_length -eq "2"
        then
                # is hh:mm - length 2
                _hours=10#${_array[0]}
                _minutes=10#${_array[1]}
                _result_minutes=$(( ( ${_hours} * 60 ) + ${_minutes} ))
        fi
        if test $_length -eq "3"
        then
                # is dd:hh:mm - length 3
                _days=10#${_array[0]}
                _hours=10#${_array[1]}
                _minutes=10#${_array[2]}
                _result_minutes=$(( ( ( ${_days} * 24 )  * 60 + ${_hours} * 60  ) + ${_minutes} ))
        fi

        echo $_result_minutes

}



# parameter is key in a_interval array
function decode_programmed_diff {
	local _lpkey=$1
	# value in array: string with time value, dd:hh:mm  
        local _array=${a_interval[${_lpkey}]}
	if test -z $_array 
	then
		echo "fatal error: a_interval ${_lpkey} is empty"
		exit 1
	fi 
        local _result_minutes=$( decode_programmed_diff_local $_array )
        echo $_result_minutes
}

# return
#  0, if number
#  1, if contains chars
#  1, if string doesn't exist
function is_number {
        local _input=$1
        if [[ -z $_input ]]
        then
                return 1
        fi
	_input1=$_input
	if test $_input -lt "0"
	then
		_input1=$(( $_input * (-1) ))
	fi
        # remove all numbers from _input
        #       ${_input//[0-9]/}
        #
        # if length is zero, then it was a number
        local _var=${_input1//[0-9]/}

        # -n = nicht length 
	# ! -n   length = 0
        if [[ ! -n ${_var} ]]
        then
                # is number
                return 0
        fi
        # not a number
        return 1
}



# format to 
# value in array: string with time value, dd:hh:mm  
#                                      or hh:mm  
#                                      or mm  
# par: time in minutes
function encode_minutes {

        local _hour=60
        local _day=$(( _hour * 24 ))
        local _minutes=$1

	_minutes_temp=$_minutes 
	if test $_minutes -lt "0"
	then
		_minutes_temp=$(( $_minutes * (-1) ))
	fi
	is_number "$_minutes_temp"
	is_number_ret=$?
	if [ $is_number_ret  -gt 0  ]
	then
		stdatelog "ret, not a number, minutes: $_minutues,  exit 1"
		exit 1
	fi


	local _ret=""
	local _is_negative="false"

	#stdatelog "testday: $_testday"
	if test $_minutes -lt "0"
	then
		_minutes=$(( $_minutes * (-1) ))
		_is_negative="true"
	fi
        
	local _days=$(( _minutes/_day  ))
        local _remainder=$(( _minutes - _days*_day   ))
	local _hours=$(( _remainder/_hour   ))
        local _minutes=$(( _remainder - _hours*_hour  ))
	local pdays=""
	local phours=""
	local pminutes=""

        if test $_days -eq 0
	then
		if test $_hours -eq 0
        	then
			ret=$_minutes
		else
			phours=$( printf "%02d\n"  $_hours )
			pminutes=$( printf "%02d\n"  $_minutes )
			ret="$phours:$pminutes"
		fi
	else
		pdays=$( printf "%02d\n"  $_days )
		phours=$( printf "%02d\n"  $_hours )
		pminutes=$( printf "%02d\n"  $_minutes )
		ret="$pdays:$phours:$pminutes"	
	fi

	# add minus sign, if negative 
	if test "$_is_negative" = "true" 
	then
		ret="-$ret"
	fi	
	echo "$ret"
}


# parameter
# $1 = Disklabel
# $2 = Projekt
# return 0, 1
# lc_DONE_REACHED=0
# lc_DONE_NOT_REACHED=1
function project_time_reached {
	
	local _lp_key=$1

        # 0 = success
        # 1 = error
        local _return=$lc_DONE_NOT_REACHED
        local _last_done_file="./${bv_donefolder}/${_lp_key}_done.log"
        #echo "in function project_done "
	# from cfg.projectsi, default
        local _last_done_time="$lv_max_last_date"

        if [  -f $_last_done_file ]
        then
                # last line from done file, is in T time format
		_last_done_time=$( gawk NF  $_last_done_file | gawk  'END {print }' -)
	fi
	# date T time
        local _current_time=`date +%Y-%m-%dT%H:%M`
	local _diff_minutes=$(time_diff_minutes  $_last_done_time  $_current_time  )
	local _programmed_diff_minutes=$( decode_programmed_diff ${_lp_key} )

	# minutes after last done >=  programmed diff
	if [  $_diff_minutes -ge "$_programmed_diff_minutes" ]
        then
		_return=$lc_DONE_REACHED
        fi
        return $_return
}


function check_pre_host {

	local _p=${1}
        local _lpkey=${lv_disk}_${_p}
	local _precondition=${bv_preconditionsfolder}/${_lpkey}.${bv_preconditionsfolder}.sh
	if [[  -f $_precondition ]]
	then
		($_precondition)
		local pre_RET=$?
		if [ $pre_RET -eq 0 ]
		then
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
	local _retains_count_file_name=${a_retains_count_file_names[$_index]}
	local _counter=0
	local _retain_value=${a_retains[$_index]}
	if [ -f ${_retains_count_file_name} ]
	then
		# count the lines
		# count is number of entries_keeped
		_counter=$(  wc  -l < ${_retains_count_file_name}  )
	fi
	echo $_counter
}

function do_retain_lines  {
	local p=${1}
        local lpkey=${lv_disk}_${p}
	# check, if config file ends with 'conf', then we do a backup with 'rsnapshot'
	local _rsnapshot_config=${lpkey}.conf
	stdatelog "#  '${_rsnapshot_config}' "
	local _rsnapshot_cfg_file=${bv_conffolder}/${_rsnapshot_config}
	local lv_archive_cfg_file=${bv_conffolder}/${lpkey}.arch
	if [ -f ./${lv_archive_cfg_file} ]
	then
		dateecho "archive cfg has no retain values"
		return 0
	fi

	# look up for lines with word 'retain'
	retainslist=$( cat ./${_rsnapshot_cfg_file} | grep ^retain )

	OIFS=$IFS
	IFS=$'\n'
	# convert to array of 'retain' lines
	# 0 = 'retain', 1 = level, 2 = count
	lines=($retainslist)
#echo "BBBB ${lines[*]}"
	IFS=$OIFS


	declare -A a_retainscount
	declare -A a_retains_count_file_names
	declare -A a_retains
	n=0
	for i in "${lines[@]}"
	do
		# split to array with ()
		local _line=($i)
		# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count

		local rlevel=${_line[1]}
		a_retains[$n]=$rlevel

		local rcount=${_line[2]}
		if [[ $rcount -lt 2 ]]
		then
			dateecho "retain count is < 2 in retain '$rlevel', this is not allowed in 'rsnapshot' and this backup"
			exit $BK_ERRORINCOUNTERS
		fi

		a_retainscount[$n]=$rcount
		a_retains_count_file_names[$n]=$bv_retainscountfolder/${lpkey}_${rlevel}

		local _entries_keeped=$(entries_keeped $n )
		#dateecho "keeped $ek"
		#dateecho "line $n"
		local print_result=$(  printf "%8s %4s (%2s)" ${a_retains[$n]} ${a_retainscount[$n]} $_entries_keeped )   
		dateecho "$lpkey  --> retain $n: $print_result"

		(( n++ ))
	done
	dateecho ""

}

function do_info_line  {

	local project=${1}
        lpkey=${lv_disk}_${project}
	stdatelog "lpkey: '$lpkey' "
        current_date=`date +%Y-%m-%dT%H:%M`

	# look up for last, next in    programmed     
        last_done_file="$bv_workingfolder/${bv_donefolder}/${lpkey}_done.log"
        last_done_date=$lv_max_last_date
        if [ -f $last_done_file  ]
        then
		# last line in done file
		last_done_date=$(gawk NF  $last_done_file | gawk  'END {print }' -)

	fi

	# 1- last
	last_done_minutes=$(   time_diff_minutes  "$last_done_date"  "$current_date"  )
	# 2. programmed
	programmed_diff_minutes=$(  decode_programmed_diff ${lpkey} )
	# 3. last done
	done_diff_minutes=$(( programmed_diff_minutes - last_done_minutes ))


        # ret , 0 = do backup, 1 = interval not reached, 2 = daytime not reached
        project_time_reached $lpkey 
        project_is_dirty=$?

        project_print=$( printf "%-14s\n"  $( echo "${project}" ) )
	
	# last
	last_done_formatted=$( encode_minutes  $last_done_minutes )
	last_done_print=$( printf "%8s"  $last_done_formatted )

	# last done
        done_diff_formatted=$( encode_minutes $done_diff_minutes )
	done_diff_print=$( printf "%8s\n"  $done_diff_formatted )

	# programmed
        programmed_formatted=$( encode_minutes  $programmed_diff_minutes )
	programmed_print=$( printf "%8s"  $programmed_formatted )


        if test $project_is_dirty -eq $lc_DONE_REACHED
        then
		check_pre_host $project 
		ispre=$?
		line="$lpkey --> $project_print   $last_done_print last, next in $done_diff_print,  programmed  $programmed_print,  reached,"
		if test $ispre -eq 0
		then
			# all is ok,  show line
                        dateecho "$line source is ok"
                else
			# not avail,  show line
                        dateecho "$line source not available"
                fi
	else
                line="$lpkey --> $project_print   $last_done_print last, next in $done_diff_print,  programmed  $programmed_print,  do nothing"
                dateecho "$line"
        fi
}


check_arrays 
check_arrays_return=$?

if [ "$check_arrays_return" -eq "$BK_ARRAYSNOK" ]
then
	exit $BK_ARRAYSNOK
fi


check_disk_by_uuid 
goodlink=$?

_targetdisk=$( targetdisk  )
_targetdisk_display_name="$_targetdisk"

if [ $_targetdisk != $lv_disk ]
then
	_targetdisk_display_name="${lv_disk}(${_targetdisk})"
fi


dateecho ""

dateecho "==== next disk: '$_targetdisk_display_name' ===="
dateecho ""
if test $goodlink -ne 0
then
	# disk label/uuid not found, or targetdisk/uuid
	_uuid=$( cat "uuid.txt" | grep -v '#' | grep -w $_targetdisk_display_name | gawk '{print $2}' )
	dateecho  "${lv_cc_logname}: disk '$_targetdisk_display_name' (UUID $_uuid) wasn't found in '/dev/disk/by-uuid'"
	dateecho ""
fi


array_projects=${a_projects[$lv_disk]}

ispre=1
mindiff=100000
minexpected=10000

stdatelog "==== next disk: '$_targetdisk_display_name' ===="
# find projects in time		
dateecho "                 dd:hh:mm               dd:hh:mm               dd:hh:mm"
for p in $array_projects
do
	do_info_line   $p
	if test $lv_use_retains -gt 0
	then
		do_retain_lines $p
	fi
done


exit 0

# EOF


