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


# shows all retain values in log
# cat cc_log.log | grep -e  "retain" | grep -w retain| grep -e eins -e zwei -e drei -e vier

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


# must be defined here
readonly bv_logfile="cc_log.log"
readonly bv_tracefile="trace.log"
readonly bv_loopcounter="loop_counter.log"



# used in bk_disks.sh
function variable_is_set {
	typeset -p "$1" &>/dev/null
	local _ret=$?
	if [ $_ret -eq 1 ]
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

# standard date time format
# https://www.w3schools.com/XML/schema_dtypes_date.asp
# DateTime Data Type = YYYY-MM-DDThh:mm:ss
# Time Data Type = hh:mm:ss
# Date Data Type = YYYY-MM-DD
# times used here are with minute accuracy, not seconds
function currentdateT() {
	# YYYY-MM-DDThh:mm
	date +%Y-%m-%dT%H:%M
}

function currentdate_for_log {
	# YYYYMMDD-hhmm
	date +%Y%m%d-%H%M
}

# lv_tracelogname is set in:
#   bk_main.sh:readonly lv_tracelogname="main"
#   bk_loop.sh:readonly lv_tracelogname="loop"
#   bk_disks.sh:readonly lv_tracelogname="disks"
#   bk_project.sh:readonly lv_tracelogname="project"
#   bk_archive.sh:readonly lv_tracelogname="archive"
#   bk_rsnapshot.sh:readonly lv_tracelogname="rsnapshot"
function tlog {
	local _tracelogname=$lv_tracelogname
	if [  -z "${_tracelogname}" ]
	then 
		echo "${_tracelogname} is empty in trace"
		_tracelogname="not set"
	fi

	if [  -z ${bv_tracefile} ]
	then
		echo "tracefilename is empty "
		return 1
	fi

	# calulate leading spaces for log of lv_tracelogname
	local _space=""
	if test $_tracelogname = "main" 
	then
		_space=" "
	fi
	if test $_tracelogname = "disks" 
	then
		_space="  "
	fi
	if test $_tracelogname = "loop" 
	then
		_space="    "
	fi
	if test $_tracelogname = "project" 
	then
		_space="      "
	fi
	if test $_tracelogname = "archive" 
	then
		_space="        "
	fi
	if test $_tracelogname = "rsnapshot" 
	then
		_space="        "
	fi
	local _TODAY=$( currentdate_for_log )
	local _msg="$_TODAY ${_space} ${_tracelogname}--   $1"
	echo -e "$_msg" >> $bv_tracefile
	return 0
}










# param = message
# insert lv_cc_logname 
# lv_cc_logname is set in local file, not here
function dlog {
	local _msg=$1
	local _cc_logname=$lv_cc_logname
	# is empty
	if test  -z "$_cc_logname"
	then 
		_cc_logname="log"
	fi
	local _msg1="${_cc_logname}: $_msg"
	local _TODAY=$( currentdate_for_log )
	local _msg2="$_TODAY --  $_msg1"
	echo -e "$_msg2" >> $bv_workingfolder/$bv_logfile
}

# test logs, can be enabled by an variable

# if not empty, log is ignored
readonly arraytestmarker="xxx"
#readonly arraytestmarker=""
function arraytestdlog {
	# is empty
	if [[ -z $arraytestmarker ]]
	then
		local _grep_marker="'array_test_log'"
		dlog "$_grep_marker ====== $1"
	fi
}

# if not empty, log is ignored
readonly startendtestmarker="xxx"
#readonly startendtestmarker=""
function startendtestlog {
	# is empty
	if [[ -z $startendtestmarker ]]
	then
		local _grep_marker="'start_end_log"
		dlog "$_grep_marker ====== $1"
	fi
}
# if not empty, log is ignored
readonly temptestmarker="xxx"
#readonly temptestmarker=""
function temptestlog {
	# is empty
	if [[ -z $temptestmarker ]]
	then
		local _grep_marker="'temp_log'"
		dlog "$_grep_marker ====== $1"
	fi
}


# get_loopcounter
function get_loopcounter {
	local _ret="0"
	# declared in line 56: bv_loopcounter="loop_counter.log"
	local _loopcounter="$bv_workingfolder/$bv_loopcounter"
	if test -f "$_loopcounter"  
	then
		#ret=$(cat loop_counter.log |  awk  'END {print}' | cut -d ':' -f 2 |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		wc=$( cat  $_loopcounter | wc -l )
		if [ $wc -eq 1 ]
		then
			#ret=$( gawk -F ":" '{gsub(/ */,"",$2); print $2}' loop_counter.log )
			_ret=$( tail  -n1 $_loopcounter | cut -d' ' -f3 )
		fi	
	fi
	echo $_ret
}

# get formatted loop counter
# 5 digits
function get_runningnumber {
	local _number=$( get_loopcounter )
	# format with 5 digits
	# < 99999
	local _fmt="%05d"
	# > 5 digits, doesn't occur
	local _runningnumber=$( printf ${_fmt}  ${_number} )
	echo $_runningnumber
}


function is_associative_array {
	local testarray=$1
	arraytestdlog "testarray: $testarray"
	local retv=$BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	local associative_array_pattern="declare -A"

	dc=$( declare -p $testarray )
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
	local testarray=$1
	#	dlog "is_associative_array_ok: '$nn'"
	is_associative_array "$testarray"
	local ret=$?
	# return values BK_ASSOCIATIVE_ARRAY_NOT_EXISTS, BK_ASSOCIATIVE_ARRAY_IS_EMPTY, BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY
	if [ $ret -eq $BK_ASSOCIATIVE_ARRAY_IS_EMPTY ] || [ $ret -eq $BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY ]
	then
		return $BK_ASSOCIATIVE_ARRAY_IS_OK
	fi
	return $ret
}


function associative_array_has_value {
	# -n   Give each name the nameref attribute, making it a name reference to another variable.
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

# par = mountfolder
# ret = used disklabel
function get_label_of_mountpoint {
	local _disk_label=$1
	local _label=$(findmnt -lo label,target | grep $_disk_label | cut -d' ' -f1)
	echo $_label
}


: <<block_comment

# waittime check
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

# return 0, if is  in wait time
# return 1, if not in wait time
function is_in_waittime10 {

	local first10=$1
	local second10=$2
	local hour=$(date +%H)

	# convert to base 10
	local hour10=$(( 10#"${hour}" ))

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
		fi
	fi
	return 1
}

# waittime=start-end

function get_decimal_waittime {
	local _index=$1
	local _waittimeinterval=$2
	local _value="09"
	local _oldifs=$IFS

	IFS='-'
	# split to array with ()
	local waittimearray=($_waittimeinterval)
	IFS=$_oldifs

	# read configured values from cfg.waittimeinterval
	# must contain 2 values
	if [ ${#waittimearray[@]} = 2 ]
	then
		_value=${waittimearray[$_index]}
	fi

	# convert to base 10
	local _value10=$(( 10#"${_value}" ))

	echo $_value10
}
function get_decimal_waittimestart {
	local _index="0"
	local _waittimeinterval=$1
	local _start=$( get_decimal_waittime $_index "$_waittimeinterval" )
	echo $_start
}

function get_decimal_waittimeend {
	local _index="1"
	local _waittimeinterval=$1
	local _end=$( get_decimal_waittime $_index "$_waittimeinterval" )
	echo $_end
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
# -e     True if exists.
# -f     True, if exists and is a regular file.
# -r     True, if exists and is readable.
# -s     True, if exists and has size bigger than 0 (not empty).
# -n    string is not null 
function test_normal_file {
	local name=$1
#	   exists            not null          size > 0           is file           readable
	[ -e "$name" ] &&  [ -n "$name" ] && [ -s "$name" ] && [ -f "$name" ] && [ -r "$name" ] 
	local _ret=$?
	#dlog "test_normal_file: $_ret, file: $name"
	return $_ret
}



# EOF

