#!/bin/bash

# file: bk_main.sh
# version 20.08.1


# Copyright (C) 2020 Richard Albrecht
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

# caller ./start_backup.sh
#        ./bk_main.sh main loop, runs forever


. ./cfg.working_folder
. ./cfg.test_vars

. ./src_exitcodes.sh
. ./src_log.sh


echo "in main"


readonly OPERATION="main"
readonly FILENAME="$OPERATION"

tlog "start"

_TODAY=`date +%Y%m%d-%H%M`

echo "$_TODAY"

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


dlog "pgrep -u $USER   bk_main.sh "
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

if [ -f main_lock ]
then
        echo "backup is running, main_lock exists"
        dlog "backup is running, main_lock exists"
        exit 1
fi


# loop, until 'main_loop.sh' returns  not 0

while true
do
	# set lock
	dlog "" 
	counter=$( get_loopcounter )
	runningnumber=$( printf "%05d"  $( get_loopcounter ) )
	tlog "counter $counter"
	dlog " ===== start main loop ($runningnumber) =====" 
	echo "create main_lock"
	touch main_lock
	echo "$runningnumber" > main_lock
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
	# call disks.sh to loop over all backup disks ############################################
	_TODAY1=`date +%Y%m%d-%H%M`
	echo "$runningnumber, start bk_disk: $_TODAY1"
	./bk_disks.sh 
	##########################################################################################
	RET=$?
	if [ -f main_lock ]
	then
		echo "remove main_lock"
		rm main_lock
	fi


	# increment counter after main_loop.sh and before exit
	counter=$( get_loopcounter )
	counter=$(( counter + 1 ))
	echo "loop counter: $counter" > loop_counter.log   
	echo "loop counter: $counter" 
	if [ $RET -gt 0 ] 
	then
		# STOPPED=101 in src_exitcodes.sh
		echo "STOPPED is value 101"
		echo "last loop counter: '$counter', RET=$RET " 
		tlog "end, return from bk_disks: $RET"
		sync
		exit 1
	fi
	
	dlog "loop counter for next loop: '$counter' " 
	tlog "next, $counter"
        dlog "" 
	
done

# end

dlog "execute loop: shouldn't be reached"
exit 0





