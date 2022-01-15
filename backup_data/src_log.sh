# file: src_log.sh
# bk_version 22.01.1
# included with 'source'

#set -o nounset                              # Treat unset variables as an error

# Copyright (C) 2021 Richard Albrecht
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
	echo `date +%Y%m%d-%H%M`
}

function date2seconds(){
	echo "$(date +%s -d $1)"
}



function tlog() {
	if [  -z ${lv_tracelogname} ]
	then 
		echo "${lv_tracelogname} is empty in trace"
		exit
	fi

	if [  -z ${bv_tracefile} ]
	then
		echo "tracefilename is empty "
		return 1
	fi

	# calulate leading spaces for log of lv_tracelogname
	space=""
	if [ $lv_tracelogname == "disks" ]
	then
		space="  "
	fi
	if [ $lv_tracelogname == "loop" ]
	then
		space="    "
	fi
	if [ $lv_tracelogname == "project" ]
	then
		space="      "
	fi
	if [ $lv_tracelogname == "archive" ]
	then
		space="        "
	fi
	if [ $lv_tracelogname == "rsnapshot" ]
	then
		space="        "
	fi

	local _TODAY=$( currentdate_for_log )
	local _msg="$_TODAY ${space}--» $1"
	echo -e "$_msg" >> $bv_tracefile
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
function dlog() {
	if [  -z ${lv_cc_logname} ]
	then 
		echo "${lv_cc_logname} is empty"
		exit
	fi
	local _msg="${lv_cc_logname}:  $1"
	local _TODAY=$( currentdate_for_log )
	local msg2="$_TODAY --» $_msg"
	echo -e "$msg2" >> $bv_logfile

#	datelog "$_msg"
}



#	get_loopcounter
function get_loopcounter {
	local ret="0"
	if [ -f "loop_counter.log" ] 
	then
		#ret=$(cat loop_counter.log |  awk  'END {print}' | cut -d ':' -f 2 |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		ret=$( gawk -F":" '{gsub(/ */,"",$2); print $2}' loop_counter.log )
	fi
	echo $ret
}

# EOF

