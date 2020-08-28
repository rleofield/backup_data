# file: src_log.sh
# version 20.08.1
# included with 'source'



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



ERRORLOG="cc_error.log"
LOGFILE="cc_log.log"
TRACEFILE="trace.log"


#bk_main.sh:33:readonly OPERATION="main"
#bk_disks.sh:36:readonly OPERATION="disks"
#bk_loop.sh:57:readonly OPERATION="loop"
#bk_project.sh:45:readonly OPERATION="project"
#bk_archive.sh:34:readonly OPERATION="archive"
#bk_rsnapshot.sh:39:readonly OPERATION="rsnapshot"


# ./bk_main.sh·
#	./bk_disks.sh,   all disks
#		./bk_loop.sh.   all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive,       no snapshot, rsync only, files accumulated



ltrace() {
        if [  -z ${TRACEFILE} ]
	then
		echo "tracefilename is empty "
		return 1
	fi
	space=""
	if [ $OPERATION == "disks" ]
	then
		space="  "
	fi
	if [ $OPERATION == "loop" ]
	then
		space="    "
	fi
	if [ $OPERATION == "project" ]
	then
		space="      "
	fi
	if [ $OPERATION == "archive" ]
	then
		space="        "
	fi
	if [ $OPERATION == "rsnapshot" ]
	then
		space="        "
	fi
	local _TODAY=`date +%Y%m%d-%H%M`
	local _msg="$_TODAY ${space}--» $1"
	echo -e "$_msg" >> $TRACEFILE
	return 0
}

tlog() {
        if [  -z ${OPERATION} ]
        then 
		echo "${OPERATION} is empty in trace"
                exit
        fi
        ltrace "${OPERATION}: $1"
}


# param = message
function datelog {
        local _TODAY=`date +%Y%m%d-%H%M`
   	local _msg="$_TODAY --» $1"
   	echo -e "$_msg" >> $LOGFILE
}

function errorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$msg" >> $ERRORLOG
}

# param = message
# insert FILENAME 
dlog() {
	if [  -z ${FILENAME} ]
	then 
		echo "${FILENAME} is empty"
		exit
	fi
	local _msg="${FILENAME}: $1"
        datelog "$_msg"
}

#        get_loopcounter
function get_loopcounter {
	local ret=""
	if [ -f "loop_counter.log" ] 
	then
		#ret=$(cat loop_counter.log |  awk  'END {print}' | cut -d ':' -f 2 |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		ret=$( gawk -F":" '{gsub(/ */,"",$2); print $2}' loop_counter.log )
	fi
	echo $ret
}

# EOF

