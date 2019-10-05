#!/bin/bash

# file: bk_main.sh
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
. ./cfg.test_vars

. ./src_exitcodes.sh
. ./src_log.sh




readonly FILENAME="main"


if [ -d $WORKINGFOLDER ] && [ $PWD = $WORKINGFOLDER ]
then
	dlog ""
	dlog "========================"
	dlog "===  start of backup ==="
	dlog "========================"
	dlog ""
	dlog "--> WORKINGFOLDER: $WORKINGFOLDER"
else
	dlog "WORKINGFOLDER '$WORKINGFOLDER' is wrong, stop, exit 1 "
	exit 1
fi


dlog "grep -u $USER   bk_main.sh "
pidcount=$(  pgrep -u $USER   "bk_main.sh" | wc -l )
                      
# pid appears twice, because of the subprocess finding the pid
if [ $pidcount -lt 3 ]
then
        dlog "backup is not running, start" 
    else
        dlog "backup is running, exit"
        dlog "pid = $pidcount"

        exit 1
fi




# loop, until 'main_loop.sh' returns  not 0

while true
do

	dlog "" 
	counter=$( get_loopcounter )
	dlog " ===== start main loop ($counter)=====" 
	if [ $no_check_disk_done -eq 1 ]
	then
		dlog "  === test mode ===, no times checked"

	fi
	if [ $do_once -eq 1 ]
	then
		dlog "  === test mode ===, run once and stop"

	fi
	if [ $daily_rotate -eq 1 ]
	then
		dlog "  === daily log rotate is on ==="
	else	
		dlog "  === daily log rotate is off ===, set daily_rotate in cfg.test_vars to 1"
	fi
	dlog ""
	./bk_disks.sh 
	RET=$?

	# increment counter after main_loop.sh and before exit
	counter=$( get_loopcounter )
	counter=$(( counter + 1 ))
	echo "loop counter: $counter" > loop_counter.log   
	#echo "loop counter: $counter" 
	if [ $RET -gt 0 ] 
	then
		echo "last loop counter: '$counter', RET=$RET " 
		sync
		exit 1
	fi
	
	dlog "loop counter for next loop: '$counter' " 
        dlog "" 
	
done

# end

dlog "execute loop: shouldn't be reached"
exit 0





