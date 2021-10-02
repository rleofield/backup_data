#!/bin/bash

# file: bk_main.sh
# bk_version 21.09.1


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

# call chain:
# ./bk_main.sh, runs forever, <- this file 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


. ./cfg.working_folder

. ./src_test_vars.sh
. ./src_filenames.sh
. ./src_exitcodes.sh
. ./src_log.sh
. ./src_folders.sh



echo " pwd $PWD"

readonly iscron=$1

readonly OPERATION="main"
readonly FILENAME="$OPERATION"
SECONDS=0
tlog "start"

_TODAY=`date +%Y%m%d-%H%M`

echo "$_TODAY"

if [ -d $WORKINGFOLDER ] && [ $PWD = $WORKINGFOLDER ]
then
	dlog ""
	dlog "========================"
	dlog "===  start of backup ==="
	dlog "===  version 21.09.1 ==="
	dlog "========================"

	if [ $iscron == "cron" ]
	then
		dlog "------  is cron start    ------"
	else
		dlog "------  is manual start  ------"
	fi

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

if [ -f  rsnapshot.pid ]
then
        dlog "old rsnapshot.pid found, has backup_data crashed before?"
        rm rsnapshot.pid
fi



# empty '$internalerrorstxt'
# do not empty in loop
# errors must be present until solved
dlog " == "
dlog " == truncate -s 0 $internalerrorstxt   ==" 
truncate -s 0 $internalerrorstxt
dlog " == "


function shatestfile(){
        local _file1=$1
        local _lsum1=$2
        local sum=$( sha256sum $_file1 )
        local a=$( echo $sum | cut -f1 -d " " )
#       echo "$a, found sum $a"
        if [ $_lsum1 != $a ]
        then
                dlog "$_file was changed. sha256sum  $a, "
                dlog "         sha256sum  must be $_lsum1 "
                return 1
        fi
        return 0

}

function shatestfiles(){
        local _testfile=$1
	local exitval=0
        while IFS=' ' read -r _lsum _file 
        do
                if [ -f $_file ]
                then
                        shatestfile  $_file $_lsum 
                        RET=$?
                        if [ $RET -eq 0 ]
                        then
                                dlog "$_file is ok"
			else
				exitval=1
                        fi
                fi
        done < <(cat $_testfile )
	return $exitval
}




# create sha file, if needed
# sha256sum *.sh > sha256.txt.sh
if [ -f "sha256sum.txt.sh" ]
then
	dlog " ==  test sha256sums"
	#RETSHA256=$( sha256sum -c --quiet sha256sum.txt.sh )
	shatestfiles sha256sum.txt.sh
	RETSHA256=$?
	if [ ${RETSHA256} -gt 0  ]
	then
		dlog "sha256sum check fails, see: 'sha256sum.txt.sh'"
		exit 0
	else
		dlog "sha256sum check ok"
	fi
fi

dlog ""

dlog " ==  list test flags and variables =="
dlog "maxfillbackupdiskpercent (90):    $maxfillbackupdiskpercent"
dlog "no_check_disk_done (0):           $no_check_disk_done"
dlog "check_looptimes (1):              $check_looptimes"
dlog "execute_once (0):                 $execute_once"
dlog "do_once_count (0):                $do_once_count"
dlog "use_minute_loop (0):              $use_minute_loop"
dlog "short_minute_loop (0):            $short_minute_loop"
dlog "short_minute_loop_seconds_10 (0): $short_minute_loop_seconds_10"
dlog "minute_loop_duration (2):         $minute_loop_duration"
dlog "daily_rotate (1):                 $daily_rotate"
dlog " == "




# folder for rsnapshot configuration files
folderlist="$CONFFOLDER $intervaldonefolder $retainscountfolder $rsynclogfolder $backup_messages_test $donefolder $exclude $oldlogs $pre $retains_count"
for ff in $folderlist
do
	dlog "check folder: '$ff'"
	if  [ ! -d $ff   ]
	then
		dlog "folder: '$ff' doesn't exist, exit 1"
		dlog "===================="
		exit 1
	fi
done


# loop, until 'bk_disks.sh' returns  not 0

do_once_counter=0

while true
do
	dlog "" 
	counter=$( get_loopcounter )
	runningnumber=$( printf "%05d"  $( get_loopcounter ) )
	tlog "counter $counter"
	dlog " ===== start main loop ($runningnumber) =====" 

	# rotate log
	# daily rotate
	_date=$(date +%Y-%m-%d)
	oldlogdir=oldlogs/$_date
	if [ ! -d "$oldlogdir" ]
	then
		if [ $daily_rotate -eq 1 ]
		then
			dlog "rotate log to '$oldlogdir'"
			mkdir "$oldlogdir"
			mv aa_* "$oldlogdir"
			mv rr_* "$oldlogdir"
			mv $BK_LOGFILE "$oldlogdir"
			mv $ERRORLOG "$oldlogdir"
			mv $TRACEFILE "$oldlogdir"
			mv label_not_found.log "$oldlogdir"
			# and create new and empty files
			touch $BK_LOGFILE
			touch $ERRORLOG
			touch $TRACEFILE
			dlog "log rotated to '$oldlogdir'"
#			dlog "date:  '$_date'"
			_date01=$(date +%Y-%m-01)
#			dlog "date01:  '$_date01'"
			if [[ ${_date01} == ${_date} ]]
			then
				dlog "rotate monthly at '$_date'"
				mv successlog.txt "$oldlogdir"
				touch successlog.txt 
				mv successloglines.txt "$oldlogdir"
				touch successloglines.txt 
				mv $rsynclogfolder "$oldlogdir"
				if [ ! -d "$rsynclogfolder" ]
				then
					mkdir $rsynclogfolder
				fi
			fi
		fi
	fi

	dlog ""
	
	# set lock
	LOCK_DATE=`date +%Y%m%d-%H%M%S`
	echo "$LOCK_DATE: create file 'main_lock'"
	touch main_lock
	echo "$runningnumber" > main_lock

	# call 'bk_disks.sh' to loop over all backup disks ############################################
	_TODAY1=`date +%Y%m%d-%H%M`
	#dlog "$runningnumber, start 'bk_disks.sh': $_TODAY1"
	./bk_disks.sh $iscron
	##########################################################################################
	RET=$?

	# release lock
	if [ -f main_lock ]
	then

		LOCK_DATE=`date +%Y%m%d-%H%M%S`
		echo "$LOCK_DATE: remove file 'main_lock'"
		rm main_lock
	fi

	# increment counter after main_loop.sh and before exit
	counter=$( get_loopcounter )
	counter=$(( counter + 1 ))
	TODAY2=`date +%Y%m%d-%H%M`
	echo "loop counter: $counter" > loop_counter.log   
	#echo "loop counter: $counter" 


#       RET = NORMALDISKLOOPEND,  if all is ok and normal loop
#       RET = STOPPED,            if stop ist executed by hand and execute_once = 0
#       RET = EXECONCESTOPPED,    if stop ist executed by execute_once = 1


	dlog "---  last return was: '$RET'"
	dlog "---    values are: normal loop (99), manually stopped (101), run once only (102)"
	sleep 0.5
	
	#  all was ok, check for next loop
	if [ $RET -eq $NORMALDISKLOOPEND ] 
	then
		if [ -s $internalerrorstxt ]
		then
			dlog "" 
			dlog "errors in backup loop: "
			dlog "" 
			dlog "errors:" 
			dlog "$( cat $internalerrorstxt )"
			dlog "" 
			dlog "$text_marker_error, last loop counter: '$counter'"
			dlog "" 
		fi
	fi	

	# STOPPED, exit
	if [ $RET -eq $STOPPED ]
	then
		if [ -s $internalerrorstxt ]
		then
			dlog "" 
			dlog "--- stop was set, errors in backup: "
			dlog "" 
			dlog "errors:" 
			dlog "$( cat $internalerrorstxt )" 
			dlog "" 
			dlog "$text_marker_error_in_stop, last loop counter: '$counter', RET=$RET "
		else
			dlog "$text_marker_stop, end reached, start backup again with './start_backup.sh"
		fi
		# normal stop via stop.sh
		# no 'do_once_count' is set in 'src_test_vars.sh'
		#dlog "stopped with 'stop' file"
		tlog "end, return from bk_disks: $RET"
		sync
		exit 1
	fi

	if [ $RET -eq $EXECONCESTOPPED ]
	then
		if [ -s $internalerrorstxt ]
		then
			dlog "" 
			dlog "'execute_once' was set, errors in backup: "
			dlog "" 
			dlog "errors:" 
			dlog "$( cat $internalerrorstxt )" 
			dlog "" 
			dlog "$text_marker_error, last loop counter: '$counter', RET=$RET "
		fi


		# check, if _'do_once_count' is set
		if [ $do_once_count -gt 0 ]
		then
			# increment 'do_once_counter' and check nr of counts
			((do_once_counter=do_once_counter+1))
			dlog "do_once_counter = $do_once_counter"
			if [ $do_once_counter -lt $do_once_count ]
			then
				# 'do_once_count' is not reached, start new loop
				dlog "$text_marker_test_counter, count loops not reached, '$do_once_counter -lt $do_once_count' "
				sleep 5
			else
				# 'do_once_count' is reached, exit
				dlog "$text_marker_stop, end, do_once_count loops reached, '$do_once_counter -eq $do_once_count' "
				sync
				exit 1
			fi
		else
			# 'execute_once' is set, exit
			dlog "$text_marker_stop, end reached, 'execute_once', RET: '$RET', exit 1 "
			tlog "end, 'execute_once', return from bk_disks: $RET"
			sync
			exit 1
		fi
	fi

	# no stop set
	dlog " ----> goto next loop  <----"
#	tlog " ----> goto next loop  <----"
	sleep 10

done

# end

dlog "execute loop: shouldn't be reached"
exit 0

# EOF



