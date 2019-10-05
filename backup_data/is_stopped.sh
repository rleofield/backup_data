#!/bin/bash

# file: is_stopped.sh
# version 19.04.1

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


if test -f $LOGFILE 
then
        var=$(cat $LOGFILE | awk  'END {print }')
        test="$text_ready"
        if [[ $var = *"$test"* ]]
        then
                echo "log contains '$test' at end, exit $WAITING"
                exit $WAITING
        else
                test="$text_stopped"
                if [[ $var = *"$test"* ]]
                then
                        echo "log contains '$test' at end, exit $STOPPED"
                        exit $STOPPED
                else
                	test="$text_interval"
	                if [[ $var = *"$test"* ]]
        	        then
                	        echo "log contains '$test' at end, exit $WAITINTERVAL"
				exit $WAITINTERVAL
			else
                		test="$text_waittime_end"
		                if [[ $var = *"$test"* ]]
        		        then
                		        echo "log contains '$test' at end, exit $WAITEND"
					exit $WAITEND
				else
		                        echo "log shows no stop marker, backup is running, exit $RUNNING"
        		                exit $RUNNING
				fi
			fi
                fi
        fi
fi
exit 0


