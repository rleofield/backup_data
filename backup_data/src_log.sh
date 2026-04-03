# file: src_log.sh

# bk_version 26.02.1
# included with 'source'


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

# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_



: <<block_comment

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
block_comment



function variable_is_set {
	typeset -p "$1" &>/dev/null
	local ret=$?
	if [ $ret -eq 1 ]
	then
		return 1
	fi
	return 0
}


# set in cfg.ssh_login
function check_ssh_configuration(){
	if ! variable_is_set sshlogin
	then
		dlog "   ssh configuration: 'sshlogin' is not set"
		return 1
	fi
	if ! variable_is_set sshhost
	then
		dlog "   ssh configuration: 'sshhost' is not set"
		return 1
	fi
	if ! variable_is_set sshport
	then
		dlog "   ssh configuration: 'sshport' is not set"
		return 1
	fi
	if ! variable_is_set sshtargetfolder
	then
		dlog "   ssh configuration: 'sshtargetfolder' is not set"
		return 1
	fi
	dlog "   1: login: '$sshlogin', host: '$sshhost', port: '$sshport', folder: '$sshtargetfolder'"
	return 0
}

# set in cfg.ssh_login
function check_ssh_configuration2(){
	if ! variable_is_set sshlogin2 
	then
		dlog "   ssh configuration 2: 'sshlogin2' is not set"
		return 1
	fi
	if ! variable_is_set sshhost2
	then
		dlog "   ssh configuration 2: 'sshhost2' is not set"
		return 1
	fi
	if ! variable_is_set sshport2
	then
		dlog "   ssh configuration 2: 'sshport2' is not set"
		return 1
	fi
	if ! variable_is_set sshtargetfolder2
	then
		dlog "   ssh configuration 2: 'sshtargetfolder2' is not set"
		return 1
	fi
	dlog "   2: login: '$sshlogin2', host: '$sshhost2', port: '$sshport2', folder: '$sshtargetfolder2'"
	return 0
}



# shows all retain values in log
# cat cc_log.log | grep -e  "retain" | grep -w retain| grep -e eins -e zwei -e drei -e vier

#readonly bv_errorlog="cc_error.log"
readonly bv_logfile="cc_log.log"
readonly bv_tracefile="trace.log"


# == daily_rotate ==
# default = 1,  =  rotate logs
# checked in bk_main.sh:265:    "if [ $bv_daily_rotate -eq 1 ]"
readonly bv_daily_rotate=1



# standard date time format
# https://www.w3schools.com/XML/schema_dtypes_date.asp
# DateTime Data Type = YYYY-MM-DDThh:mm:ss
# Time Data Type = hh:mm:ss
# Date Data Type = YYYY-MM-DD
# dates used here are with minute accuracy, not seconds

function currentdateT() {
	# YYYY-MM-DDThh:mm
	date +%Y-%m-%dT%H:%M
}

function currentdate_for_log {
	# YYYYMMDD-hhmm
	date +%Y%m%d-%H%M
}


function tlog {
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


# if not empty, log is ignored
arraytestmarker="xxx"
#arraytestmarkerlog=""
function arraytestdlog {
	# is empty
	if [[ -z $arraytestmarker ]]
	then
		dlog "array test log $1"
	fi
}

# if not empty, log is ignored
startendtestmarker="xxx"
#startendtestmarkerlog=""
function startendtestlog {
	# is empty
	if [[ -z $startendtestmarker ]]
	then
		dlog "start end log ====== $1"
	fi
}
# if not empty, log is ignored
temptestmarker="xxx"
#temptestmarkerlog=""
function temptestlog {
	# is empty
	if [[ -z $temptestmarker ]]
	then
		dlog "temp log ====== $1"
	fi
}

# param = message
# insert lv_cc_logname 
# lv_cc_logname is set in local file, not here
function dlog {

	local msg=$1
	local cc_logname=$lv_cc_logname
	# is empty
	if test  -z "$cc_logname"
	then 
		cc_logname="log"
	fi
	local _msg="${cc_logname}: $msg"
	local _TODAY=$( currentdate_for_log )
	local _msg2="$_TODAY --  $_msg"
	echo -e "$_msg2" >> $bv_workingfolder/$bv_logfile
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


function is_associative_array {
	local  testarray=$1
	#arraytestdlog "testarray: $testarray"
	local retv=$BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	local associative_array_pattern="declare -A"

	dc=$( declare -p $testarray )
	#echo "dc: $dc"
	arraytestdlog "declare command: $dc"

	if [[ "$(declare -p $testarray 2>/dev/null)" == ${associative_array_pattern}* ]]
	then
		arraytestdlog "array '$testarray' exists and is associative array"
		empty_array_pattern="${associative_array_pattern} $testarray=()"
		#wc=$(declare -p $name) | wc -l
		# 1 bei arr
		if [[ "$(declare -p $testarray 2>/dev/null)" == ${empty_array_pattern}* ]]
		then
			arraytestdlog "array '$testarray' is empty"
			retv=$BK_ASSOCIATIVE_ARRAY_IS_EMPTY
		fi
		if test $retv -ne 0
		then
			# declare -A a_waittim=([cdisk_dserver]="10-10" )
			not_empty_array_pattern="${associative_array_pattern} $testarray=(["
			if [[ "$(declare -p $testarray 2>/dev/null)" == ${not_empty_array_pattern}* ]]
			then
				arraytestdlog "array '$testarray' is not empty"
				retv=$BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY
			fi
		fi
	else
		arraytestdlog "array '$testarray' is not an associative array"
	fi
	return $retv
}

function is_associative_array_ok {
	local nn=$1
	#	dlog "is_associative_array_ok: '$nn'"
	is_associative_array "$nn"
	ret=$?
	# return values BK_ASSOCIATIVE_ARRAY_NOT_EXISTS, BK_ASSOCIATIVE_ARRAY_IS_EMPTY, BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY
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
			arraytestdlog "has key '$k'"
			return 0
		fi
	done
	arraytestdlog "key '$key' not found"
	return 1
}


function is_indexed_array {
	local name=$1
	local retv=$BK_INDEXED_ARRAY_NOT_EXISTS
	local indexed_array_pattern="declare -a"
	if !  [[ "$(declare -p $name 2>/dev/null)" == ${indexed_array_pattern}* ]] 
	then 
		arraytestdlog "array '$name' is not an indexed array"
		return $BK_INDEXED_ARRAY_NOT_EXISTS
	fi
		
	arraytestdlog "array '$name' exists and is indexed array"
	empty_array_pattern="${indexed_array_pattern} $name=()"
	#wc=$(declare -p $name) | wc -l
	if [[ "$(declare -p $name 2>/dev/null)" == ${empty_array_pattern}* ]] 
	then
		arraytestdlog "array '$name' is empty"
		return $BK_INDEXED_ARRAY_IS_EMPTY
	fi
	# declare -a a_wait=([0]="abc," [1]="def")
	not_empty_array_pattern="${indexed_array_pattern} $name=(["
	if [[ "$(declare -p $name 2>/dev/null)" == ${not_empty_array_pattern}* ]]   
	then
		arraytestdlog "array '$name' is not empty"
		#arraytestdlog "33333 array '$name' is not empty"
		return $BK_INDEXED_ARRAY_IS_NOT_EMPTY
	fi
	return $retv
}


function targetdisk {
	local _disk_label=$1
	arraytestdlog " in targetdisk  '$_disk_label'"

	# test for a variable that does contain a value 
	local _retval="empty"
	if ! [[ $_disk_label ]]
	then
		arraytestdlog "label is empty"
		echo $_retval
		return 1
	fi
	local _array="a_targetdisk"
	is_associative_array_ok "a_targetdisk"
	local RET=$?
	arraytestdlog "return from 'is_associative_array_ok': $RET"
	if test $RET -gt 0
	then
		arraytestdlog "array '$_array' is empty, use normal disklabel '$_disk_label'"
		echo "$_disk_label"
		return 0
	fi

	arraytestdlog "targetdisk array '$_array' check key, if inside, key '$_disk_label'"
	associative_array_has_value "a_targetdisk" "$_disk_label"
	RET=$?
	if test $RET -gt 0 
	then
		arraytestdlog "targetdisk array '$_array': disklabel not found '$_disk_label'"
		echo "$_disk_label"
		return 0
	fi
	local _targetdisk=${a_targetdisk[${_disk_label}]}
	arraytestdlog "targetdisk array '$_array' is not empty, found disklabel '$_targetdisk'"
	echo "$_targetdisk"
	return 0
}

function get_label_of_mountpoint {
	local _disk_label=$1
	local _label=$(findmnt -lo label,target | grep $_disk_label | cut -d' ' -f1)
	echo $_label
}



# return 0, if is  in wait time
# return 1, if not in wait time
function is_in_waittime10 {

	local first10=$1
	local second10=$2
	local hour=$(date +%H)

	# convert to base 10
#	local first10=$(( 10#"${first}" ))
#	local second10=$(( 10#"${second}" ))
	local hour10=$(( 10#"${hour}" ))

#	dlog "waittime, first: $first10, second: $second10, current hour: $hour10"


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
	return 1
}


function get_decimal_waittimestart {
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
	IFS=_oldifs
	#set +x
	IFS=_oldifs

	# convert to base 10
	local start10=$(( 10#"${_start}" ))

	echo $start10
}

function get_decimal_waittimeend {
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
	IFS=_oldifs

	# convert to base 10
	local end10=$(( 10#"${_end}" ))
	echo $end10
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
# -e  true, if exists.
# -f  true, if exists and is a regular file.
# -r  true, if exists and is readable.
# -x  true, if exists and is executable.
# -s  true, if exists and has size bigger than 0 (not empty).
# -n  true, string is not null 
function test_script_file {
	local name=$1
#	   exists            not null          size > 0           is file           readable         executable
	[ -e "$name" ] &&  [ -n "$name" ] && [ -s "$name" ] && [ -f "$name" ] && [ -r "$name" ] && [ -x "$name" ]
}
function test_is_executable {
	local name=$1
#	   is file           readable         executable
	local real=$( realpath $name )
	[ -f "$real" ] && [ -r "$real" ] && [ -x "$real" ]
}

# normal file test

# normal file test
# -e     True if exists.
# -f     True, if exists and is a regular file.
# -r     True, if exists and is readable.
# -s     True, if exists and has size bigger than 0 (not empty).
# -n    string is not null 
function test_normal_file {
	local name=$1
#	   exists            not null          size > 0           is file           readable
	[ -e "$name" ] &&  [ -n "$name" ] && [ -s "$name" ] && [ -f "$name" ] && [ -r "$name" ] 
}

: <<list_of_functions
8:function variable_is_set {
90:function check_ssh_configuration(){
116:function check_ssh_configuration2(){
165:function currentdateT() {
170:function currentdate_for_log {
176:function tlog {
228:function arraytestdlog {
239:function startendtestlog {
249:function temptestlog {
260:function dlog {
277:function get_loopcounter {
293:function get_runningnumber {
304:function is_associative_array {
341:function is_associative_array_ok {
355:function associative_array_has_value {
376:function is_indexed_array {
406:function targetdisk {
444:function get_label_of_mountpoint {
454:function is_in_waittime10 {
503:function get_decimal_waittimestart {
531:function get_decimal_waittimeend {
554:function encode_diff_to_string {
598:function encode_diff_unit {
635:function test_script_file {
640:function test_is_executable {
655:function test_normal_file {
list_of_functions



# EOF

