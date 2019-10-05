# file: src_log.sh
# version 19.04.1
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

function get_loopcounter {
	local ret=""
#	datelog "${FILENAME}: if [ -f loop_counter.log ]"
	if [ -f "loop_counter.log" ] 
	then
		ret=$(cat loop_counter.log |  awk  'END {print}' | cut -d ':' -f 2 |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	fi
#	datelog "${FILENAME}: loop_counter = $ret"
	echo $ret
}

function dlog {
        if [  -z ${FILENAME} ]
        then 
		echo "${FILENAME} is empty"
                exit
        fi
        datelog "${FILENAME}: $1"
}

# EOF

