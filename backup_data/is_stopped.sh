#!/bin/bash

# file: is_stopped.sh

# bk_version 21.11.1

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


# bei hs
# WAITING=100
# STOPPED=101
# WAITINTERVAL=102
# RUNNING=105  
# FATAL=255

# if [ ! $RET -eq $RUNNING  ] is ok




. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_log.sh

cd $WORKINGFOLDER
if [ ! -d $WORKINGFOLDER ] && [ ! $( pwd ) = $WORKINGFOLDER ]
then
        echo "WD '$WORKINGFOLDER'"
        echo "WD is wrong"
        exit 1
fi


# WAITING=100  
# STOPPED=101

# WAITING=100
# STOPPED=101
# EXECONCESTOPPED=102
# WAITINTERVAL=103


# only used if rsync is running
# RUNNING=105



if test -f $BK_LOGFILE 
then
	lastlogline=$( awk  'END { print }'  $BK_LOGFILE )

	# waiting, backup ready, normal waiting for next hour
	vtest="$text_marker_waiting"
        if [[ $lastlogline == *"$vtest"* ]]
        then
                echo "log contains '$vtest' at end, exit 'waiting': $WAITING"
                exit $WAITING
	fi

	# stopped run one, backup stopped by hand './stop.sh', 
        vtest="$text_marker_stop, end, do_once_count loops reached"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, exit 'stopped do once count loops end': $EXECONCESTOPPED"
                exit $EXECONCESTOPPED
	fi

	# stopped run one, backup stopped by hand './stop.sh', 
        vtest="$text_marker_stop, end reached, 'execute_once', RET: '102'"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, exit 'stopped run once': $EXECONCESTOPPED"
                exit $EXECONCESTOPPED
	fi
	# stopped, backup stopped by hand './stop.sh', 
        vtest="$text_marker_stop"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, exit 'stopped': $STOPPED"
                exit $STOPPED
	fi


	# wait interval
        vtest="$text_wait_interval_reached"
        if [[ $lastlogline == *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, in interval waiting, exit 'waitinterval': $WAITINTERVAL"
                exit $WAITINTERVAL
	fi


	# waiting error
        vtest="$text_marker_error_in_waiting"
        if [[ $lastlogline  = *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, errors in projekt, exit 'rsyncfails': $RSYNCFAILS"
                exit $RSYNCFAILS
	fi
	# stop with error
        vtest="$text_marker_error_in_stop"
        if [[ $lastlogline  = *"$vtest"* ]]
        then
		echo "log contains '$vtest' at end, stopped, errors in projekt, exit 'rsyncfails': $RSYNCFAILS"
                exit $RSYNCFAILS
	fi
	
	
	echo "log shows no stop marker, backup is running, exit 'running': $RUNNING"
        exit $RUNNING
			


fi

exit 0

# EOF

