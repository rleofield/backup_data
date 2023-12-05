#!/bin/bash

# file: is_stopped.sh

# bk_version 23.12.1

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


# bei hs
# BK_WAITING=100
# STOPPED=101
# BK_WAITINTERVAL=102
# BK_RUNNING=105  
# BK_FATAL=255

# if [ ! $RET -eq $BK_RUNNING  ] is ok




. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_log.sh

cd $bv_workingfolder
if [ ! -d $bv_workingfolder ] && [ ! $( pwd ) = $bv_workingfolder ]
then
        echo "WD '$bv_workingfolder'"
        echo "WD is wrong"
        exit 1
fi


# BK_WAITING=100  
# STOPPED=101

# BK_WAITING=100
# STOPPED=101
# BK_EXECONCESTOPPED=102
# BK_WAITINTERVAL=103


# only used if rsync is running
# BK_RUNNING=105



if test -f $bv_logfile 
then
	lastlogline=$( awk  'END { print }'  $bv_logfile )

	# waiting, backup ready, normal waiting for next hour
	vtest="$text_marker_waiting"
        if [[ $lastlogline == *"$vtest"* ]]
        then
                echo "log contains '$vtest' at end, exit 'waiting': $BK_WAITING"
                exit $BK_WAITING
	fi

	# stopped run one, backup stopped by hand './stop.sh', 
        vtest="$text_marker_stop, end, bv_test_do_once_count loops reached"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, exit 'stopped do once count loops end': $BK_EXECONCESTOPPED"
                exit $BK_EXECONCESTOPPED
	fi

	# stopped run one, backup stopped by hand './stop.sh', 
        vtest="$text_marker_stop, end reached, 'bv_test_execute_once', RET: '102'"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, exit 'stopped run once': $BK_EXECONCESTOPPED"
                exit $BK_EXECONCESTOPPED
	fi
	# stopped, backup stopped by hand './stop.sh', 
        vtest="$text_marker_stop"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, exit 'stopped': $BK_STOPPED"
                exit $BK_STOPPED
	fi


	# wait interval
        vtest="$text_wait_interval_reached"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, in interval waiting, exit 'waitinterval': $BK_WAITINTERVAL"
                exit $BK_WAITINTERVAL
	fi


	# waiting error
        vtest="$text_marker_error_in_waiting"
        if [[ $lastlogline  = *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, errors in projekt, exit 'rsyncfails': $BK_RSYNCFAILS"
                exit $BK_RSYNCFAILS
	fi
	# stop with error
        vtest="$text_marker_error_in_stop"
        if [[ $lastlogline  = *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, stopped, errors in projekt, exit 'rsyncfails': $BK_RSYNCFAILS"
                exit $BK_RSYNCFAILS
	fi
	
	
	echo "log shows no stop marker, backup is running, exit 'running': $BK_RUNNING"
        exit $BK_RUNNING
			


fi

exit 0

# EOF

