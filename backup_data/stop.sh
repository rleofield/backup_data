#!/bin/bash

# file: stop.sh

# bk_version  25.01.1

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
if [[ $(id -u) != 0 ]]
then
        echo "we are not root, use root for stop of backup"
        exit
fi
. ./cfg.working_folder
. ./src_log.sh
. ./src_exitcodes.sh


# in src_exitcodes.sh
# readonly text_marker_stop="--- stopped ---"

cd $bv_workingfolder

lv_cc_logname="stop"


#bv_logfile
lastlogline=$( awk  'END { print }'  $bv_logfile )
readonly vtest="$text_marker_stop"
if [[ $lastlogline == *"$vtest"* ]]
then
	dlog "  backup is already stopped, see last line of log"
	dlog "$text_marker_stop, end reached, start backup again with './start_backup.sh'"
	exit
fi

readonly vtest1="$text_marker_error_in_stop"
if [[ $lastlogline == *"$vtest1"* ]]
then
	dlog "  backup is already stopped, see last line of log"
	dlog "$text_marker_error_in_stop, end reached, start backup again with './start_backup.sh'"
	exit
fi



touch stop
dlog "  stop is set, backup stops at next chance"

# EOF

