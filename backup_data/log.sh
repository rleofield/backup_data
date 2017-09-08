# log.sh

# file: log.sh

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


ERRORLOG="error.log"
LOGFILE="llog.log"



function log {
   local msg=$1
   #echo "$msg" | tee -a $LOGFILE
   echo -e "$msg" >> $LOGFILE
}



function datelog {
        local _TODAY=`date +%Y%m%d-%H%M`
        log "$_TODAY ==>  $1"
}

function errorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$msg" >> $ERRORLOG
}



# EOF
