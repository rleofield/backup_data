# file: src_log.sh
# bk_version 23.01.1
# included with 'source'

#set -o nounset                              # Treat unset variables as an error

# Copyright (C) 2017-2023 Richard Albrecht
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


# ./bk_main.sh·
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


readonly bv_errorlog="cc_error.log"
readonly bv_logfile="cc_log.log"
readonly bv_tracefile="trace.log"

# if empty, no log is written
#readonly bv_sequencefile="programmablauf.log"
readonly bv_sequencefile=""

# == daily_rotate ==
# default = 1,  =  rotate logs
# checked in bk_main.sh:265:    "if [ $bv_daily_rotate -eq 1 ]"
readonly bv_daily_rotate=1



# all time, dates with minute accuracy, not seconds
function currentdateT() {
	# YYYY-MM-DDThh:mm
	echo `date +%Y-%m-%dT%H:%M`
}

function currentdate_for_log() {
	# YYYYMMDD-hhmm
	date +%Y%m%d-%H%M
}

function date2seconds(){
	echo "$(date +%s -d $1)"
}



function tlog() {
	local tracelogname=$lv_tracelogname
	if [  -z ${tracelogname} ]
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
	local _msg="$_TODAY ${space} ${tracelogname}--» $1"
	echo -e "$_msg" >> $bv_tracefile
	return 0
}

# not ready
function seqlog() {

	local tracelogname=$lv_tracelogname
	if [  -z ${tracelogname} ]
	then 
		echo "${tracelogname} is empty in trace"
		tracelogname="not set"
		# exit
	fi

	if [  -z ${bv_sequencefile} ]
	then
		# echo "sequencefilename is empty "
		# can be not existent, return 0
		return 0
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
	local _msg="$_TODAY ${space} ${tracelogname}--» $1"
	echo -e "$_msg" >> $bv_sequencefile
	return 0
}




function errorlog {
	local _TODAY=$( currentdate_for_log )
	msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$msg" >> $bv_errorlog
}

# param = message
# insert lv_cc_logname 
# lv_cc_logname is set in local file, not here
function dlog {
	local cc_logname=$lv_cc_logname
	if test  -z "$cc_logname"
	then 
		cc_logname="not set"
		#echo "22222 is empty, cc_log; '$lv_cc_logname'"
		#echo "${logname} is empty"
	fi
	local _msg="${cc_logname}:  $1"
	local _TODAY=$( currentdate_for_log )
	local msg2="$_TODAY --» $_msg"
	echo -e "$msg2" >> $bv_logfile
}



# get_loopcounter
function get_loopcounter {
	local ret="0"
	if test -f "loop_counter.log"  
	then
		#ret=$(cat loop_counter.log |  awk  'END {print}' | cut -d ':' -f 2 |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		ret=$( gawk -F":" '{gsub(/ */,"",$2); print $2}' loop_counter.log )
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
	# normallly not more than 10.000 loops are used in rsnapshot
	# see './show_config.sh | g -e total -e Project'
	if (( _counter > 99999 ))
	then
		_counter=0
	fi
	echo "loop counter: $_counter" > loop_counter.log

}



# EOF

