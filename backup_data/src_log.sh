# file: src_log.sh
# bk_version 25.04.1
# included with 'source'


# Copyright (C) 2017-2025 Richard Albrecht
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

# short names for files, used for tracelog

# 'filename' is in normal logging: "${DISK}:$PROJECT:${lv_tracelogname}"'

# bk_main.sh:33:readonly lv_tracelogname="main"
# bk_disks.sh:36:readonly lv_tracelogname="disks"
# bk_loop.sh:57:readonly lv_tracelogname="loop"
# bk_project.sh:45:readonly lv_tracelogname="project"
# bk_archive.sh:34:readonly lv_tracelogname="archive"
# bk_rsnapshot.sh:39:readonly lv_tracelogname="rsnapshot"



# ./bk_main.sh  
#	./bk_disks.sh, all disks
#		./bk_loop.sh.   all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive, no snapshot, rsync only, files accumulated




# standard date time format
# https://www.w3schools.com/XML/schema_dtypes_date.asp
# DateTime Data Type = YYYY-MM-DDThh:mm:ss
# Time Data Type = hh:mm:ss
# Date Data Type = YYYY-MM-DD

# default old date: used, if no value in folder 'done' ist set
readonly lv_max_last_date="$max_last_date"


# cat cc_log.log | grep -e  "retain" | grep -w retain| grep -e eins -e zwei -e drei -e vier

#readonly bv_errorlog="cc_error.log"
readonly bv_logfile="cc_log.log"
readonly bv_tracefile="trace.log"


# == daily_rotate ==
# default = 1,  =  rotate logs
# checked in bk_main.sh:265:    "if [ $bv_daily_rotate -eq 1 ]"
readonly bv_daily_rotate=1



# all time, dates with minute accuracy, not seconds


function currentdateT() {
	# YYYY-MM-DDThh:mm
	date +%Y-%m-%dT%H:%M
}

function currentdate_for_log() {
	# YYYYMMDD-hhmm
	date +%Y%m%d-%H%M
}

function date2seconds(){
	# par = datestring
	# return date in seconds
	date +%s -d "$1"
}



function tlog() {
	local tracelogname=$lv_tracelogname
	if [  -z "${tracelogname}" ]
	then 
		echo "${tracelogname} is empty in trace"
		tracelogname="not set"
		#exit
	fi

	if [  -z ${bv_tracefile} ]
	then
		echo "tracefilename is empty "
		return 1
	fi

	# calulate leading spaces for log of lv_tracelogname
	space=""
	if test $tracelogname = "main" 
	then
		space=" "
	fi
	if test $tracelogname = "disks" 
	then
		space="  "
	fi
	if test $tracelogname = "loop" 
	then
		space="    "
	fi
	if test $tracelogname = "project" 
	then
		space="      "
	fi
	if test $tracelogname = "archive" 
	then
		space="        "
	fi
	if test $tracelogname = "rsnapshot" 
	then
		space="        "
	fi

	local _TODAY=$( currentdate_for_log )
	local _msg="$_TODAY ${space} ${tracelogname}--   $1"
	echo -e "$_msg" >> $bv_tracefile
	return 0
}


# AAAA used to log test of arrays
# if not empty, dlog is ignored
arraytestmarkerlog="AAAA"
#arraytestmarkerlog=""
function arraytestlog {
	dlog "$arraytestmarkerlog $1"
}

# DDDD used to log use of scripts, at main, at start/end disks, start/end project
# if not empty, dlog is ignored
startendtestmarkerlog="DDDD"
#startendtestmarkerlog=""
function startendtestlog {
	dlog "$startendtestmarkerlog $1"
}
# XXXX used to temporary usage if dlog,
# if not empty, dlog is ignored
temptestmarkerlog="XXXX"
#temptestmarkerlog=""
function temptestlog {
	dlog "$temptestmarkerlog $1"
}

# param = message
# insert lv_cc_logname 
# lv_cc_logname is set in local file, not here
function dlog {

	local msg=$1
	local oldifs=$IFS
	local prefixlist="$temptestmarkerlog $startendtestmarkerlog $arraytestmarkerlog"
	#local prefixlist="$startendtestmarkerlog $arraytestmarkerlog"
	# set IFS to <space><tab><newline>
	# default IFS=$' \t\n'
	IFS=$' \t\n'
	# XXXX used to temporary usage of dlog,
	# DDDD used to log use of scripts, at main, at start/end disks, start/end project
	# AAAA used to log test of arrays
	for _pre in $prefixlist
	do
		if [[ $msg == "$_pre"* ]]
		then
#			echo -e "early return pre: $_pre, msg: $msg" >> $bv_workingfolder/$bv_logfile
			return 0;
		fi
	done
	IFS=$oldifs
	local cc_logname=$lv_cc_logname
	if test  -z "$cc_logname"
	then 
		cc_logname="log"
	fi
	local _msg="${cc_logname}:  $msg"
	local _TODAY=$( currentdate_for_log )
	local msg2="$_TODAY --   $_msg"
	echo -e "$msg2" >> $bv_workingfolder/$bv_logfile
	
}


# get_loopcounter
function get_loopcounter {
	local ret="0"
	if test -f "loop_counter.log"  
	then
		#ret=$(cat loop_counter.log |  awk  'END {print}' | cut -d ':' -f 2 |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		wc=$( cat  loop_counter.log | wc -l )
		if [ $wc -eq 1 ]
		then
			#ret=$( gawk -F ":" '{gsub(/ */,"",$2); print $2}' loop_counter.log )
			ret=$( tail  -n1 loop_counter.log | cut -d' ' -f3 )
		fi	
	fi
	echo $ret
}

# get formatted loop counter
function get_runningnumber {
	local number=$( get_loopcounter )
	# 5 digits
	# < 99999
	local fmt="%05d"
	# > 5 digits, doesn't occur
	local _runningnumber=$( printf ${fmt}  ${number} )
	echo $_runningnumber
}

# increment counter, if all disk are executed 
function increment_loop_counter(){
	# increment counter after main_loop.sh and before exit
	local _counter=$( get_loopcounter )
	_counter=$(( _counter + 1 ))

	# wraps at 99.999 = 100.000 loops
	# normally not more than 10.000 loops are used in rsnapshot
	# see './show_config.sh | g -e total -e Project'
	if (( _counter > 99999 ))
	then
		_counter=0
	fi
	# write back to 'loop_counter.log'
	echo "loop counter: $_counter" > loop_counter.log
}


function is_associative_array {
	local  testarray=$1
	#arraytestlog "testarray: $testarray"
	local retv=$BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	local associative_array_pattern="declare -A"

	dc=$( declare -p $testarray )
	#echo "dc: $dc"
	arraytestlog "declare command: $dc"

	if [[ "$(declare -p $testarray 2>/dev/null)" == ${associative_array_pattern}* ]]
	then
		arraytestlog "array '$testarray' exists and is associative array"
		empty_array_pattern="${associative_array_pattern} $testarray=()"
		#wc=$(declare -p $name) | wc -l
		# 1 bei arr
		if [[ "$(declare -p $testarray 2>/dev/null)" == ${empty_array_pattern}* ]]
		then
			arraytestlog "array '$testarray' is empty"
			retv=$BK_ASSOCIATIVE_ARRAY_IS_EMPTY
		fi
		if test $retv -ne 0
		then
			# declare -A a_waittim=([cdisk_dserver]="10-10" )
			not_empty_array_pattern="${associative_array_pattern} $testarray=(["
			if [[ "$(declare -p $testarray 2>/dev/null)" == ${not_empty_array_pattern}* ]]
			then
				arraytestlog "array '$testarray' is not empty"
				retv=$BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY
			fi
		fi
	else
		arraytestlog "array '$testarray' is not an associative array"
	fi
	return $retv
}

function is_associative_array_ok {
	local nn=$1
	#	dlog "is_associative_array_ok: '$nn'"
	is_associative_array "$nn"
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
	#arraytestlog "has value array check start '$key'"
	local keys=(${!name[@]})
	#arraytestlog "has value array  check inside key '$key'"
	#local kis=1
	for k in ${keys[@]}
	do
		if [ $k = $key ]
		then
			arraytestlog "has key '$k'"
			return 0
		fi
	done
	arraytestlog "key '$key' not found"
	return 1
}


function is_indexed_array {
	local name=$1
	local retv=$BK_INDEXED_ARRAY_NOT_EXISTS
	local indexed_array_pattern="declare -a"
	if !  [[ "$(declare -p $name 2>/dev/null)" == ${indexed_array_pattern}* ]] 
	then 
		arraytestlog "array '$name' is not an indexed array"
		return $BK_INDEXED_ARRAY_NOT_EXISTS
	fi
		
	arraytestlog "array '$name' exists and is indexed array"
	empty_array_pattern="${indexed_array_pattern} $name=()"
	#wc=$(declare -p $name) | wc -l
	if [[ "$(declare -p $name 2>/dev/null)" == ${empty_array_pattern}* ]] 
	then
		arraytestlog "array '$name' is empty"
		return $BK_INDEXED_ARRAY_IS_EMPTY
	fi
	# declare -a a_wait=([0]="abc," [1]="def")
	not_empty_array_pattern="${indexed_array_pattern} $name=(["
	if [[ "$(declare -p $name 2>/dev/null)" == ${not_empty_array_pattern}* ]]   
	then
		arraytestlog "array '$name' is not empty"
		#arraytestlog "33333 array '$name' is not empty"
		return $BK_INDEXED_ARRAY_IS_NOT_EMPTY
	fi
	return $retv
}


function targetdisk {
	local _disk_label=$1
	arraytestlog " in targetdisk  '$_disk_label'"

	# test for a variable that does contain a value 
	local retval="empty"
	if ! [[ $_disk_label ]]
	then
		arraytestlog "label is empty"
		echo $retval
		return 1
	fi
	local _targetdrive="empty"
	local _array="a_targetdisk"
	retval=$_disk_label
	is_associative_array_ok "a_targetdisk"
	RET=$?
	arraytestlog "RET $RET"
	if test $RET -gt 0 
	then
		arraytestlog "array '$_array' is empty, use normal disklabel '$_disk_label'"
		echo $retval
		return 0
	fi

	arraytestlog "targetdisk array '$_array' check key, if inside, key '$_disk_label'"
	associative_array_has_value "a_targetdisk" "$_disk_label"
	RET=$?
	if test $RET -gt 0 
	then
		arraytestlog "targetdisk array '$_array': disklabel not found '$retval'"
		retval=$_disk_label
		echo $retval
		return 0
	fi

	retval=${a_targetdisk[${_disk_label}]}
	arraytestlog "targetdisk array '$_array' is not empty, found disklabel '$retval'"

	echo $retval
	return 0
}

function check_arrays {
	dlog " ==  check arrays in 'cfg.projects'"
	local aok=0
	for _arr in $bk_arr_cfglist
	do
#		dlog "checked array: '$_arr'"
		is_associative_array $_arr
		RET=$?
#		dlog "checked array ret: '$RET'"
		if [ $RET -ne 0 ]
		then
			if [ $RET -eq $BK_ASSOCIATIVE_ARRAY_NOT_EXISTS ]
			then
				dlog "   array '$_arr' doesn't exist"
				dlog "   -- add array entry with"
				dlog "      'declare -A $_arr'"
				dlog "      '$_arr=()'"
				dlog "      ------"
				aok=1
			fi
			if [ $RET -eq $BK_ASSOCIATIVE_ARRAY_IS_EMPTY ]
			then
				dlog "   array '$_arr' is empty"
			fi
			if [ $RET -eq $BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY ]
			then
				dlog "   array '$_arr' is not empty"
			fi
		fi
	done
	return $aok
}

: <<Kommentar

# here waittime check
	if  (( first != second )) 
	then
		if  (( first < second ))
		then
			if (( hour  >= first )) && (( hour <  second ))
			then
				return 0
			fi
		else
			if (( hour >= first )) && (( hour < 24 ))
			then
				return 0
			fi
			if (( 0 <   first )) && (( hour < second ))
			then
				return 0
			fi
		fi
	fi
	return 1
}
Kommentar



function is_in_waittime() {
	local first=$1
	local second=$2
	local first10=10#"$first"
	local second10=10#"$second"
	local hour=$(date +%H)
	local hour10=10#"$hour"

	# skip, if fast test loop is used
	if [ $bv_test_use_minute_loop -eq 0 ]
	then
		# first value equal second, no wait, ret = 1
		if  (( first10 != second10 )) 
		then
			# first value is lower than the second
			if  (( first10 < second10 ))
			then
			#	echo "first value is lower than the second"
				#            >=                           <
				if (( hour10  >= first10 )) && (( hour10 <  second10 ))
				then
					return 0
				fi
			else
				# first value is greater than the second
				if (( hour10 >= first10 )) && (( hour10 < 24 ))
				then
					return 0
				fi
				#	echo "if [ 0 -le  $first ] && [ $hour -lt $second ]"
				if (( 0 <   first10 )) && (( hour10 < second10 ))
				then
					return 0
				fi
			fi
		#else	
			#echo "first value is equal to the the second"
		fi
	fi
	#echo "end"
	return 1
}


function get_waittimestart() {
	local _waittimeinterval=$1
	local _oldifs=$IFS
	local _start="09"
	IFS='-'
	# split to array with ()
	local waittimearray=($_waittimeinterval)
	IFS=$_oldifs
	# read configured values from cfg.waittimeinterval
	# must be 2 values
	#set -x
	if [ ${#waittimearray[@]} = 2 ]
	then
	#	echo "log array 0 : ${waittimearray[0]}"
		_start=${waittimearray[0]}
	fi
	#set +x
	echo $_start
}

function get_waittimeend() {
	local _waittimeinterval=$1
	local _oldifs=$IFS
	local _end="09"
	IFS='-'
	# split to array with ()
	local waittimearray=( $_waittimeinterval )
	IFS=$_oldifs
	# read configured values from cfg.waittimeinterval
	# must be 2 values
	if [ ${#waittimearray[@]} = 2 ]
	then
	#	echo "log array 1 : ${waittimearray[1]}"
		_end=${waittimearray[1]}
	fi
	echo $_end
}


function encode_diff_to_string {

        # testday is in minutes
        local testday=$1
        local ret=""
        local is_negative=1 # = "false"

        if test $testday -lt "0"
        then
                testday=$(( testday * (-1) ))
                is_negative=0     # = "true"
        fi

        # all in minutes
        local hour=60
        local day=$(( hour * 24 ))
        local days=$(( testday/day  ))

        local remainder=$(( testday - days*day   ))
        local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq "0"
        then
                if test $hours -eq "0"
                then
                        ret=$( printf "%02d"  $minutes )
                else
                        ret=$( printf "%02d:%02d"  $hours $minutes )
                fi
        else
                ret=$( printf "%02d:%02d:%02d"  $days $hours $minutes )
        fi

        # add minus sign, if negative 
        if test $is_negative -eq "0" # = "true" 
        then
                ret="-$ret"
        fi
        local _encoded_diff_var="$ret"
        echo "$_encoded_diff_var"

}

function encode_diff_unit {

        # testday is in minutes
        local testday=$1
        local ret=""

        local hour=60
        local day=$(( hour * 24 ))

        local days=$(( testday/day  ))
        local remainder=$(( testday - days*day   ))
        local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq "0"
        then
                if test $hours -eq 0
                then
                        ret="minutes"
                else
                        ret="hours"
                fi
        else
                ret="days"
        fi

        local _state="$ret"
        echo "$_state"
}

# script file test
# -e     True if exists.
# -f     True, if exists and is a regular file.
# -r     True, if exists and is readable.
# -x     True, if exists and is executable.
# -s     True, if exists and has size bigger than 0 (not empty).
# -n    string is not null 
function test_script_file {
	local name=$1
#	   exists            not null          size > 0           is file           readable         executable
	[ -e "$name" ] &&  [ -n "$name" ] && [ -s "$name" ] && [ -f "$name" ] && [ -r "$name" ] && [ -x "$name" ]
}

function test_normal_file {
	local name=$1
#	   exists            not null          size > 0           is file           readable
	[ -e "$name" ] &&  [ -n "$name" ] && [ -s "$name" ] && [ -f "$name" ] && [ -r "$name" ] 
}

# EOF

