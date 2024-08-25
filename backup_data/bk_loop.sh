#!/bin/bash


# file: bk_loop.sh
# bk_version 24.08.1

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

# call chain:
# ./bk_main.sh 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk, <- this file
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only



# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_



. ./cfg.working_folder
. ./cfg.projects

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_folders.sh

# exit values
# exit $BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
# exit $BK_ARRAYSNOK         	- property arrays have errors
# exit $BK_DISKLABELNOTFOUND	- disk with uuid nit found in /dev/disk/by-uuid, disk ist not in system 
# exit $BK_NOINTERVALSET	- no backup time inteval configured in 'cfg.projects'
# exit $BK_TIMELIMITNOTREACHED	- for none project at this disk time limit is not reached
# exit $BK_DISKNOTUNMOUNTED	- ddisk couldn't be unmounted
# exit $BK_MOUNTDIRTNOTEXIST	- mount folder for backup disk is not present in '/mnt'
# exit $BK_DISKNOTMOUNTED	- disk couldn't be mounted 
# exit $BK_RSYNCFAILS		- rsync error, see logs
# exit $BK_SUCCESS		- all was ok
# exit $BK_NORSNAPSHOTROOT	- no backup root set in  config
# exit $BK_DISKFULL		- back harddisk is full
# exit $BK_ROTATE_FAILS		- rotate for history fails
# exit $BK_FREEDISKSPACETOOSMALL - free disk space at backup harddisk ist too small


set -u

# Label der Backup-HD = $1
readonly lv_disklabel=$1

if [ -z "$lv_disklabel" ]
then
	exit "$BK_DISKLABELNOTGIVEN";
fi


# use media mount '/media/user/label' instead of '/mnt/label'?
# 0 = use
# 1 = don't use, use /mnt
# default=1, don't use
readonly lv_use_mediamount=1

readonly lv_tracelogname="loop"
readonly lv_cc_logname="$lv_disklabel:loop"
readonly lv_notifysendlog="tempnotifysend.log"

# in cfg.projects
readonly waittimeinterval=$bv_globalwaittimeinterval

# get targetdisk from label
# configured in cfg.projects
# must be used in snapshot_root
dlog "look up targetdisk '$lv_disklabel'"
readonly lv_targetdisk=$( targetdisk "$lv_disklabel" )
lv_label_name="$lv_disklabel"
if [ "$lv_disklabel" != "$lv_targetdisk" ]
then
	lv_label_name="$lv_disklabel ($lv_targetdisk)"
fi

dlog "targetdisk is '$lv_targetdisk'"

readonly lv_loop_test_return=$BK_LOOP_TEST_RETURN
#readonly lv_loop_test=$bv_loop_test
readonly lv_min_wait_for_next_loop=60
lv_next_project_diff_minutes=10000



# changed later in line 966 to media mount, if lv_use_mediamount=0,  = use 
# check for folder 'marker' at mounted backup disk
lv_mountfolder=/mnt/$lv_targetdisk
lv_markerfolder=$lv_mountfolder/marker

tlog "start: '$lv_label_name'"



# check, get_projectwaittimeinterval() only for disk done 
# result is in, value is in hours
#       lv_loopwaittimestart
#       lv_loopwaittimeend
# backup for this project waits in this interval, nothing ist done
#  for example '08-10'
# parameter is project identifier, for example 'ddisk_dserver'
lv_loopwaittimestart="09"
lv_loopwaittimeend="09"
function get_projectwaittimeinterval {
	lv_loopwaittimestart="09"
	lv_loopwaittimeend="09"
	local _lpkey=$1
#	local _waittime=""
	is_associative_array_ok "a_waittime"
	ret=$?
	if [ ! $ret ]
	then
		dlog "'a_waittime' array doesn't exist "
		return $BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	fi
	# array exists and has length > 0
	array_length=${#a_waittime[@]}  # ok, if array=() is set
	if [ $array_length -gt 0 ]
	then
	#                echo "array length > 0 "
	# in script:         | Set and Not Null     | Set But Null     | Unset
	# ${parameter+word}  | substitute word      | substitute word  | substitute null

#		dlog "associative_array_has_value 'a_waittime' '$_lpkey'"
		associative_array_has_value "a_waittime" "$_lpkey"
		ret=$?
#		dlog "associative_array_has_value ret  '$ret'"
		if [ $ret -eq 0 ]
		then
			local _waittime=${a_waittime[${_lpkey}]}
			if [ $_waittime ]
			then
				#get_waittimeinterval $_waittime
				lv_loopwaittimestart=$( get_waittimestart $_waittime )
				lv_loopwaittimeend=$( get_waittimeend $_waittime )
			fi
		fi
	fi
	return $BK_SUCCESS
}


function sendlog {
        local _msg=$1
        local _logdate=$( currentdate_for_log )
        echo -e "$_logdate  == Notiz: $_msg" >> $lv_notifysendlog
}


# par1 = old   (yyyy-mm-ddThh:mm) or (yyyy-mm-ddThh:mm:ss)
# par2 = new
# diff = new - old,   in minutes
# minutes for
#      h = 60, d = 1440, w = 10080, m = 43800, y = 525600
# parameter: dateold, datenew in unix-date format
#            dateold is before datenew
# format YYYY-mm-ddThh:mm
function time_diff_minutes {
        local _old=$1
        local _new=$2

        # convert the date hour:min:00" in seconds from 
        #       Unix Date Stamp to seconds, "1970-01-01T00:00:00Z"
        #       Unix Date Stamp to seconds, or "1970-01-01T00:01:00"  
        local _sec_old=$( date2seconds "$_old" )
        local _sec_new=$( date2seconds "$_new")

        # convert to minutes
        local _minutes=$(( (_sec_new - _sec_old) / 60 ))
        if test $_minutes -lt 0 
        then
                dlog "done: diff is smaller then zero !!!"
        fi
        echo "$_minutes"
}


function get_disk_uuid {
	local uuid="empty"
	if [[ $lv_targetdisk ]]
	then
#		https://unix.stackexchange.com/questions/60994/how-to-grep-lines-which-does-not-begin-with-or
#		How to grep lines which does not begin with “#” or “;”
#		local uuid=$( cat "uuid.txt" | grep  '^[[:blank:]]*[^[:blank:]#;]'  |  grep -w $_disk_label | awk '{print $2}' )
		uuid=$( cat "uuid.txt" | grep -v '#' | grep -w "$lv_targetdisk" | awk '{print $2}' )
#		better
#		uuid=$( gawk -v pattern="$_disk_label" '$1 ~ "(^|[[:blank:]])" pattern "([[:blank:]]|$)"  {print $NF}' uuid.txt )
		
		if [[ ! $uuid ]]
		then
			uuid="unknown"
		fi
	fi
	echo "$uuid"
}



# parameter: disklabel or targetdisk, if used
# 0 = success
# 1 = error, disk not in uuid list
function check_disk_uuid {
	local uuid=$( get_disk_uuid )

#	test, if symbolic link exists
	if test -L "/dev/disk/by-uuid/$uuid"
	then
		return 0
	fi
	return 1
}

# parameter: string with time value, dd:hh:mm 
# value in array: string with time value, 
#    dd:hh:mm 
#    hh:mm 
#    mm 
# return:    minutes
function decode_pdiff_local {
        local _interval=$1
        local _oldifs=$IFS
        IFS=':'

        # split into array
        local _array=(${_interval})
        local _length=${#_array[@]}

        IFS=$_oldifs

	# use num# = use base 10,  to prevent interpretation as octal numbers.

        # mm only
        local _result_minutes=10#${_array[0]}
	local _hours=0
	local _minutes=0
	local _days=0

        if test $_length -eq "2"
        then
                # is hh:mm
                _hours=10#${_array[0]}
                _minutes=10#${_array[1]}
                _result_minutes=$(( ( ${_hours} * 60 ) + ${_minutes} ))
        fi
        if test $_length -eq "3"
        then
                # is dd:hh:mm  - length 3
                _days=10#${_array[0]}
                _hours=10#${_array[1]}
                _minutes=10#${_array[2]}
                _result_minutes=$(( ( ( ${_days} * 24 )  * 60 + ${_hours} * 60  ) + ${_minutes} ))
        fi

        echo $_result_minutes

}

# par: 'disklabel_project'  in a_interval array
# value in array: string with time value 
#    dd:hh:mm 
#    hh:mm 
#    mm 
# return:  minutes 
function decode_programmed_interval {
	local _lpkey=$1
	local _intervalvalue=${a_interval[${_lpkey}]}
	local _minutes=$( decode_pdiff_local ${_intervalvalue} )
	echo $_minutes
}




readonly PROJECT_DONE_REACHED=0
readonly PROJECT_DONE_NOT_REACHED=1
readonly PROJECT_DONE_WAITINTERVAL_REACHED=2


function is_in_waitinterval {
        local _lpkey=$1

        get_projectwaittimeinterval $_lpkey
#		dlog "ZZZZZZZZZZZ in 'is_in_waitinterval' lpkey: '$_lpkey',  from $lv_loopwaittimestart to $lv_loopwaittimeend"
        local wstart=$lv_loopwaittimestart
        local wend=$lv_loopwaittimeend

        local hour=$(date +%H)
        if [ $bv_test_use_minute_loop -eq 0 ]
	then
		if [ "$hour" -ge "$wstart" ] && [ "$hour" -lt "$wend"  ] 
		then
			return 0
		fi
	fi
	return 1


}

# par1 = disklabel_project_key
# 0 = success, reached
# 1 = not reched
# 2 = in project waittime interval
# called by check_disk_done()
function check_disk_done_last_done {
        local _lpkey=$1

        if [ $bv_test_no_check_disk_done -eq 1 ]
        then
        #        dlog ""
        #        dlog "    test mode, done is not checked"
        #        dlog ""
                return $PROJECT_DONE_REACHED
        fi

	is_in_waitinterval $_lpkey
	RET=$?

	if [ "$RET" -eq 0  ] 
	then
		return $PROJECT_DONE_WAITINTERVAL_REACHED
	fi

        # format: YYYY-MM-DDThh:mm
        local _currenttime=$( currentdateT )
        local _done_file="./${bv_donefolder}/${_lpkey}_done.log"

        # format YYYY-mm-ddThh:mm
        local _last_done_time="$lv_max_last_date"

        # get last line in done file
        if test -f $_done_file
        then
                _last_done_time=$(cat $_done_file | awk  'END {print }')
                if [ -z "$_last_done_time" ]
                then
                        _last_done_time="$lv_max_last_date"
                fi
        fi

        local _time_diff_minutes=$( time_diff_minutes  $_last_done_time  $_currenttime  )
        local _programmed_interval=$( decode_programmed_interval ${_lpkey} )

        if test $_time_diff_minutes -ge $_programmed_interval
        then
                # diff was greater than reference, take as success
                return $PROJECT_DONE_REACHED
        fi
        return $PROJECT_DONE_NOT_REACHED
}


# par1 = disklabel_project_key
# 0 = success, reached
# 1 = not reched
# 2 = in project waittime interval
function check_disk_done {
        local _lpkey=$1

        # 0 = success
        # 1 = error
        # check, if time interval is over
        check_disk_done_last_done ${_lpkey} 
        local RET=$?
        return $RET
}

# check preconditon for project
# source exists
# remote host exists
# or more
# 0 - ok, or checkfile doesn't exist
# 0 - nok, checkfile doesn't exist
# 1 - nok, source host or source doesn't exist or ssh check wrong

function check_pre_host {
	local _lpkey=$1
	local _rsnapshot_config=${_lpkey}.conf
	local _rsnapshot_cfg_file=${bv_conffolder}/${_rsnapshot_config}

	local _precondition=$bv_preconditionsfolder/${_lpkey}.pre.sh
	local _RETfunc=1
	if test  -f $_precondition 
	then
		eval $_precondition
		local _RET=$?
		if test $_RET -eq 0 
		then
			_RETfunc=0
		fi
	fi
	return $_RETfunc
}

# par 1 = disklabel
# par 2 = project
# used in lv_loop_successlist, lv_loop_unsuccesslist
# return: label shortened by 4 chars 
function strip_disk_or_luks_from_disklabel {
        local _disklabel=$lv_disklabel
        local ll="${_disklabel}"
        if [[ "$ll" = *"disk"* ]]; 
        then
                local tt1=${ll::-4} 
                ll=$tt1
        fi
        if [[ "$ll" = *"luks"* ]]; 
        then
                local tt2=${ll::-4} 
                ll=$tt2
        fi
        local var="${ll}"
        echo "${var}"
}

# lookup in mtab for mount at 'media'
#  mount_media=$( cat /etc/mtab  |  grep media | grep $lv_disklabel )
#  device mountpoint options,  $2 is mountpoint
function umount_media_folder() {

        local _mtab_line_mount_media=$1

        local mount_media_folder=""
        mount_media_folder=$( echo "$_mtab_line_mount_media" | awk '{ print $2 }' )
        dlog "try umount: $mount_media_folder"
        umount "$mount_media_folder"
        local mountRET=$?
        if [ "$mountRET" -ne 0 ]
        then
                dlog "umount fails: 'umount $mount_media_folder'"
                return $BK_DISKNOTUNMOUNTED
        fi


        # luksClose  
        local lukstargetdisk="$lv_targetdisk"
        local luksmapper="/dev/mapper/$lukstargetdisk"
        dlog "find luks mapping with HD label: $lukstargetdisk"
        if [  -L "$luksmapper" ]
        then
                dlog "luks mapping exists: $luksmapper"
                dlog "do luksClose:   cryptsetup luksClose $luksmapper"
                cryptsetup luksClose "$luksmapper"

#       Error  codes are:
#       1 wrong parameters,
#       2 no permission (bad passphrase),
#       3 out of memory,
#       4 wrong device specified,
#       5 device already exists or device is busy.

        else
		dlog "luks mapper by label doesn't exist: $luksmapper"

		# try with luks-uuid
        	luksuuid=$( get_disk_uuid )
        	lukslabel="luks-$luksuuid"
        	luksmapper="/dev/mapper/$lukslabel"
        	dlog "try mapper with uuid: $luksmapper"
        	if [  -L "$luksmapper" ]
        	then
			dlog "luks mapper exists: $luksmapper"
			dlog "do luksClose:  cryptsetup luksClose $luksmapper"
			cryptsetup luksClose "$lukslabel"
	        fi
	fi

        return $BK_SUCCESS

}

# look up for next project in time
function find_next_project_to_do(){
        # set external vars to a start values
        lv_next_project_name=""

        for _project in $lv_disk_project_list
        do
                local lpkey=${lv_disklabel}_${_project}
                local DONE_FILE="./${bv_donefolder}/${lpkey}_done.log"
                local LASTLINE=$lv_max_last_date
                if test -f $DONE_FILE
                then
                        LASTLINE=$(cat $DONE_FILE | awk  'END {print }')
                fi

                # get configured project delta time

                local pdiff=$(decode_programmed_interval "${lpkey}" )
                # get current delta after last done, in LASTLINE is date in %Y-%m-%dT%H:%M
                local tcurrent=$( currentdateT )
                local diff_since_last_backup=$(time_diff_minutes  "$LASTLINE"  "$tcurrent"  )
                local deltadiff=$(( pdiff - diff_since_last_backup ))

                # look for minimum
                if ((deltadiff < lv_next_project_diff_minutes ))
                then
                        # copy to external vars
                        lv_next_project_diff_minutes=$deltadiff
                        lv_next_project_name=$_project
                fi
        done
}


# par: $lv_notifysendlog $lv_disklabel $notifyfilepostfix
#       tempnotifysend.log  LABEL   last part of filename 
function  sshnotifysend_bk_loop {
	#$lv_notifysendlog $lv_disklabel
        local _file=$lv_notifysendlog
        local _disklabel=$lv_disklabel
        local _notifyfilepostfix=$1
        if [ ! -f $_file ] 
        then
                return 0
        fi

        local _logdate=$( currentdate_for_log )

	#     Backup-HD_LABEL_date_postfix
	#     z.B.:     Backup-HD_cdisk_20221226-0244_keine_Fehler_alles_ok.log
        local _tempfilename="${bv_notifyfileprefix}_${_disklabel}_${_logdate}_${_notifyfilepostfix}.log"

	dlog "send notify message of disk '$lv_label_name' to folder '${bv_backup_messages_testfolder}'"
        dlog "backup notify file: ${_tempfilename}"
        #cat $_file 
        cat $_file > $_tempfilename 
        dlog ""
        dlog "-- backup notify message"
        dlog ""
        local _oldifs1=$IFS
        IFS=$'\n'
        for _notifyline in $( cat  $_tempfilename ) 
        do
                dlog "$_notifyline"
        done
        IFS=$_oldifs1

        dlog ""
        dlog "-- end of backup notify message"
        dlog ""

        # remove old file in 'backup_messages_test'
	dlog "rm ${bv_backup_messages_testfolder}/${bv_notifyfileprefix}_${_disklabel}_*"
	rm ${bv_backup_messages_testfolder}/${bv_notifyfileprefix}_${_disklabel}_*

        # copy to 'backup_messages_test'
        local COMMAND="cp ${_tempfilename} ${bv_backup_messages_testfolder}/"
        dlog "copy notify file to 'backup_messages_test'"
        dlog "command: $COMMAND"
        eval $COMMAND
        rm $_tempfilename
}

function rsyncerrorlog {
	local _TODAY=$( currentdate_for_log )
	local _msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$_msg" >> $bv_internalerrors
}

# =======================================================

# start of code

if [ "$lv_disklabel" != "$lv_targetdisk" ]
then
	dlog "===== process disk, label: '$lv_disklabel', targetdisk is: '$lv_targetdisk' ====="
else
	dlog "===== process disk, label: '$lv_disklabel' ====="
fi

# set. if rsync fails with '$BK_RSYNCFAILS' 
error_in_rsync=0



# remove old "notifysend.log"
# readonly lv_notifysendlog="notifysend.log", set in line 75
#dlog "remove old notify log for disk '$lv_disklabel': '$lv_notifysendlog'"
if test -f $lv_notifysendlog
then
	rm $lv_notifysendlog
fi

# remove old Backup-HD_* files
# bv_notifyfileprefix has value 'Backup-HD'
readonly lv_files=$(ls ${bv_notifyfileprefix}_* 2> /dev/null | wc -l)

if [ "$lv_files" != "0" ]
then
	rm ${bv_notifyfileprefix}_*
fi

# test, if uuid of disk is in device list:  /dev/disk/by-uuid
# get from 'uuid.txt' and look up in device list 
dlog "-- UUID check: is HD '$lv_label_name' connected to the PC?" 

# call 'check_disk_uuid'
check_disk_uuid 
goodlink=$?
#dlog "after check_disk_uuid: $lv_disklabel "
# get_disk_uuid must be successful
uuid=$( get_disk_uuid )

# disk must be in /dev/disk/by-uuid
# a USB disk must be connected
# mount is not necessary here, is checked and done later

if [[ $goodlink -eq 0 ]]
then
	dlog "-- UUID check: disk '$lv_label_name' with UUID '$uuid' found in /dev/disk/by-uuid" 
	tlog "disk '$lv_label_name' with UUID '$uuid' found" 
else
	dlog "-- UUID check: disk '$lv_label_name' with UUID '$uuid' not found in /dev/disk/by-uuid," 
#	dlog "  check array 'a_targetdisk' in 'cfg.projects', if array has a value" 
#	dlog " exit 'BK_DISKLABELNOTFOUND'" 
	tlog " disk '$lv_label_name' with UUID '$uuid' not found " 
	exit $BK_DISKLABELNOTFOUND
fi
# disk with label and uuid found in device list
# --

# next is look up for dirty projects of this disk
# projects - last time ist later then project time interval 
# exit, if interval ist not set
associative_array_has_value "a_projects" "$lv_disklabel"
RET=$?
if [ $RET -gt 0 ]
then
	dlog "key: '$lv_disklabel' not found in array 'a_projects' in 'cfg.projects'"
	exit $BK_DISKLABELNOTFOUND
fi	
readonly lv_disk_project_list=${a_projects[$lv_disklabel]}
dlog "-- disk '$lv_label_name', check projects: '$lv_disk_project_list'"

# start of disk, disk is unmounted
# find, if interval is reached, if not, exit

declare -a lv_dirty_projects_array
lv_dirty_projects_array=()

# build list of last times for backup per project in disk
# don't check the existence of the disk, this is done later
dlog ""

# write headline
dlog "                      dd:hh:mm                dd:hh:mm               dd:hh:mm"

lv_dirtyprojectcount=0
lv_min_one_project_found=0



# print list of all projects in disk
#   and show, if valid
#   collect dirty projects (in time)

for _project in $lv_disk_project_list
do
	# project key = disklabel_project
	_lpkey=${lv_disklabel}_${_project}

	# check, if  time interval entry exists	
	_interval=${a_interval[${_lpkey}]}
	if [ -z "$_interval" ]
	then
		dlog "ERROR: in 'cfg.projects' in array 'a_interval', '$_lpkey' is not set, "
		exit $BK_NOINTERVALSET
	fi
	
	_tcurrent=$( currentdateT )
	_done_file="./${bv_donefolder}/${_lpkey}_done.log"

	_last_done_time=$lv_max_last_date
	if test -f $_done_file 
	then
		# last line in done file
		_last_done_time=$(cat $_done_file | awk  'END {print }')  	
	fi
	if [ -z "$_last_done_time" ]
	then
        	_last_done_time="$lv_max_last_date"
	fi


	# ret 'check_disk_done', 0 = do backup, 1 = interval not reached, 2 = waittime interval not reached
	# PROJECT_DONE_REACHED=0
	# PROJECT_DONE_NOT_REACHED=1
	# PROJECT_DONE_WAITINTERVAL_REACHED=2
	check_disk_done "$_lpkey" 
	_project_done_state=$?

	# print disklabel to field of 19 length
	_disk_label_print=$( printf "%-19s\n"  "${_lpkey}" )
	_project_interval_minutes=$(  decode_programmed_interval "${_lpkey}" )

	# 1. entry, last
	# diff = tcurrent - last_done_time,   in minutes
	_done_diff_minutes=$(   time_diff_minutes  "$_last_done_time"  "$_tcurrent"  )
	_encoded_diffstring1=$( encode_diff_to_string  "$_done_diff_minutes" )
	done_diff_print8=$( printf "%8s"  "$_encoded_diffstring1" )

	# 2. entry, next
	deltadiff=$(( _project_interval_minutes - _done_diff_minutes ))
	delta_diff_print=$( printf "%6s\n"  $deltadiff )
	_encoded_diffstring2=$( encode_diff_to_string "$delta_diff_print" )
	next_diff_print9=$( printf "%9s\n"  "$_encoded_diffstring2" )

	# 3. entry, programmed
	_encoded_diffstring3=$( encode_diff_to_string  "$_project_interval_minutes" )
	project_interval_minutes_print8=$( printf "%8s"  "$_encoded_diffstring3" )

	# example: 01:15:32 last, next in    08:28,  programmed  02:00:00,  do nothing
	timeline=$( echo "$_disk_label_print   $done_diff_print8 last, next in $next_diff_print9,  programmed  $project_interval_minutes_print8," )

	# projectdone is reached, check reachability via check_pre_host
	if test $_project_done_state -eq $PROJECT_DONE_REACHED
	then
		# reached, if done
		# - test $_DIFF -ge $_pdiff,          = wait time reached
		# - if [ $bv_test_no_check_disk_done -eq 1 ]  = 'bv_test_no_check_disk_done' is set
		# - if [ $do_once -eq 1 ]             = 'do_once' is set
		# check. if reachable, add to list 'lv_dirty_projects_array'
		_precondition=$bv_preconditionsfolder/${_lpkey}.pre.sh
		#dlog "precondition: $_precondition"
		_ispre=1
		if [  -f "$_precondition" ]
		then
			check_pre_host "$_lpkey"
			_ispre=$?
		#	dlog "check pre host, is pre: $_ispre"
		else
			dlog "----"
			dlog "$_precondition doesn't exist"
			dlog "----"
		fi

		if test $_ispre -eq 0
		then
			tlog "    in time: $_project"
			# all is ok,  do backup	
			if [ $bv_test_no_check_disk_done -eq 1 ]
			then
				dlog "${timeline} reached, ok, test mode, done not checked"
			else
				temp_timeline=$( echo "${timeline} reached, ok")
				timeline=$temp_timeline
			fi
			lv_dirty_projects_array[lv_dirtyprojectcount]=$_project
			lv_dirtyprojectcount=$(( lv_dirtyprojectcount + 1 ))
			lv_min_one_project_found=1

		else
		#	is_pre=false
			tlog "    in time: $_project, but unavailable"
			if [ $bv_test_no_check_disk_done -eq 1 ]
			then
				dlog "${timeline} reached, not available, test mode, done not checked"
			else
				temp_timeline=$( echo "${timeline} reached, not available")
				timeline=$temp_timeline
			fi
		fi
	fi
	
	# normal projectdone not reached
	if test "$_project_done_state" -eq $PROJECT_DONE_NOT_REACHED
	then
		tlog "not in time: $_project"
		temp_timeline=$( echo "${timeline} do nothing")
		timeline=$temp_timeline
	fi

	# waittime interval reached
	if test "$_project_done_state" -eq $PROJECT_DONE_WAITINTERVAL_REACHED
	then
		tlog "in wait interval: $_project"
		# project key = disklabel_project
		_lpkey=${lv_disklabel}_${_project}
		get_projectwaittimeinterval $_lpkey
		wstart=$lv_loopwaittimestart
		wend=$lv_loopwaittimeend
		temp_timeline=$( echo "${timeline} wait from $wstart to $wend")
		timeline=$temp_timeline
#		dlog "$timeline wait,  from $lv_loopwaittimestart to $lv_loopwaittimeend"
	fi
	dlog "$timeline"
	
done

# in 'lv_dirty_projects_array' are all projects where we need a backup
# --
dlog ""

# if none of the  project needs a backup, return 'BK_TIMELIMITNOTREACHED'

if test $lv_min_one_project_found -eq 0
then
	dlog "== end disk '$lv_disklabel', nothing to do =="
	dlog ""
	exit $BK_TIMELIMITNOTREACHED
fi

# 'lv_dirty_projects_array' has some entries, process backup
# _length_nextprojects is > 0
_length_nextprojects=${#lv_dirty_projects_array[@]}


# ======== check mount, do backup, if ok ====
# start of backup
# - mount disk
# - do rsnapshot with bk_project.sh and bk_rsnapshot.sh
# - umount, if programmmed or no /media/user disk 
#

dlog "time limit for at least one project is reached, projects: ${lv_dirty_projects_array[*]}"

# copy projectlist as return to bk_disks.sh via file 'tempfile_executedprojects.txt', for loopmessage at end only
if [ -f $bv_executedprojectsfile ]
then
	# add 'dirty_projects_array' to 'tempfile_executedprojects.txt' at top of file
	lv_msg=$( cat $bv_executedprojectsfile )
	echo "$lv_msg, $lv_disklabel: ${lv_dirty_projects_array[*]}" > $bv_executedprojectsfile
else
	#dlog "filename2: executedprojects.txt"
	echo "$lv_disklabel: ${lv_dirty_projects_array[*]}" >  $bv_executedprojectsfile
fi


dlog " continue with test of mount state of disk: '$lv_targetdisk'"
dlog ""

# check mountdir at /mnt
dlog "check mountdir"


# first, check mount at /media/user
#set +u
dlog "cat /etc/mtab  | grep media | grep $lv_targetdisk  | awk '{ print \$2 }'"

#set -x

_mtab_mount_media_folder=$( cat /etc/mtab  | grep media | grep "$lv_targetdisk"  | awk '{ print $2 }')

#set -x
# if media mount exists, umount
if [ ! -z  "$_mtab_mount_media_folder" ]
then
	dlog "mediamount exists: $_mtab_mount_media_folder"

	# use media mount instead of /mnt?
	# 0 = use
	# 1 = don't use, eg. gt 0, use /mnt
	if test $lv_use_mediamount -gt 0
	then
		# try to umount media folder
		#dlog "in mediamount exists: $lv_disklabel "
		mtab_line_mount_media=$( cat /etc/mtab  |  grep media | grep "$lv_targetdisk" )
		if [ ! -z "$mtab_line_mount_media" ]
		then
			umount_media_folder "$mtab_line_mount_media"
			RET=$?
			if [ $RET -eq $BK_DISKNOTUNMOUNTED ]
			then
				exit $BK_DISKNOTUNMOUNTED
			fi
		else
			# check mount at /mnt
			mtab_mount_mnt=$( cat /etc/mtab  |  grep mnt | grep "$lv_targetdisk" )
			if [  -n "$mtab_mount_mnt" ]
			then
				mtab_mount_mnt_folder=$( echo "$mtab_mount_mnt" | awk '{ print $2 }' )
				dlog "no mount at /mnt found with '$lv_targetdisk', mountpoint is at: $mtab_mount_mnt_folder"
			fi
		fi
	else
		# ok use media folder
		# set new  lv_mountfolder
		dlog "media mount '$_mtab_mount_media_folder' exists"
		lv_mountfolder=$_mtab_mount_media_folder
		lv_markerfolder=$lv_mountfolder/marker
	fi
fi  

# close cryptsetup
mmuuid=$( get_disk_uuid )
luks_uuid_label="luks-$mmuuid"
luks_uuid_label_mapper="/dev/mapper/$luks_uuid_label"
#dlog "second try mapper with uuid: $mmMAPPERLABEL"
if [  -L "$luks_uuid_label" ]
then
	dlog "luks mapper with uuid exists: $luks_uuid_label"
	dlog "do luksClose:   cryptsetup luksClose $luks_uuid_label"
	cryptsetup luksClose $luks_uuid_label
#	Error  codes are:
#	1 wrong parameters,
#	2 no permission (bad passphrase),
#	3 out of memory,
#	4 wrong device specified,
#	5 device already exists or device is busy.

fi


# show results
tlog "mount: '$lv_mountfolder'"
dlog "mount folder   '$lv_mountfolder'" 
dlog "marker folder  '$lv_markerfolder'" 

if test ! -d $lv_mountfolder 
then
	dlog " mount folder  '$lv_mountfolder' doesn't exist" 
	exit $BK_MOUNTDIRTNOTEXIST
fi

# mount HD, mountfolder exists
if test -d $lv_markerfolder 
then
	# is fixed disk
	dlog " -- HD '$lv_targetdisk' is mounted at '$lv_mountfolder'"
else
	dlog " marker folder '$lv_markerfolder' doesn't exist, try mount" 
	./mount.sh $lv_targetdisk 
	RET=$?
	if test $RET -ne 0
	then
		dlog " == end, couldn't mount disk '$lv_targetdisk' to  '$lv_mountfolder', mount error =="
	fi
	
	# check marker folder, if not ok, then disk is not mounted
	if test ! -d $lv_markerfolder
	then
		dlog " mount,  markerdir '$lv_markerfolder' not found"
		dlog " == end, couldn't mount disk '$lv_targetdisk' to  '$lv_mountfolder', no marker folder =="
		exit $BK_DISKNOTMOUNTED
	fi
fi

dlog " -- disk '$lv_targetdisk' is mounted, marker folder '$lv_markerfolder' exists"

# mount check and mount of backup disk is ready
# --


#  check for disk size, disk must be mounted
# set LV_DISKFULL, if disk is full
maxdiskspacepercent=$bv_maxfillbackupdiskpercent


dlog "---> max allowed used space: '${maxdiskspacepercent}%'"

# line in 'df -h'
# 1               2     3     4     5   6
# /dev/sdb1       1,9T  1,4T  466G  75% /mnt/adisk
 
# dsdevice=$( blkid | grep -w $lv_disklabel| awk '{print $1}'| sed 's/.$//')
diskfreespace=$( df -h /dev/disk/by-label/$lv_targetdisk | grep -m1 -w $lv_targetdisk | awk '{print $4}')

used_space_temp1=$( df -h /dev/disk/by-label/$lv_targetdisk | grep -m1 -w $lv_targetdisk | awk '{print $5}')
# remove % char
temp2=${used_space_temp1%?}
usedspacepercent=$temp2

# LV_DISKFULL = $BK_SUCCESS
# or
# LV_DISKFULL = $BK_FREEDISKSPACETOOSMALL
# set, if disk is full
# checked also after backup
LV_DISKFULL=$BK_SUCCESS
LV_CONNECTION_UNEXPECTEDLY_CLOSED=$BK_SUCCESS

if [ $maxdiskspacepercent -lt $usedspacepercent ]
then
	dlog "---"
	dlog "!!!  disk: '$lv_targetdisk', max allowed used space '${maxdiskspacepercent}%' is lower than current used space '${usedspacepercent}%', continue with next disk !!!"
	dlog "---"
	LV_DISKFULL=$BK_FREEDISKSPACETOOSMALL
fi

dlog "---> free space: ${diskfreespace}, used space: ${usedspacepercent}%"

# done to false
# checked in 941
projectdone=false

lv_next_project_name=""



declare -A projecterrors
projecterrors=()
declare -a lv_loop_successlist
lv_loop_successlist=()
declare -a lv_loop_unsuccesslist
lv_loop_unsuccesslist=()

PRET=""

# do backup, if disk is not full
#   if disk is full, see else part
if [ ! $LV_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
then
	# in 'dirty_projects_array' are all projects, which need backup
	# do backup for each project

	dlog "execute projects in time and with valid precondition check: ${lv_dirty_projects_array[*]}"

	#  e.g. conf/sdisk_start,sh
	# in conf folder
	# shell script, executed at start of disk
	disk_begin="$bv_conffolder/${lv_disklabel}_begin.sh"
	if  test_script_file "$disk_begin"
	then
		dlog "'$disk_begin' found"
		dlog "execute: '$disk_begin' "
		eval ./$disk_begin  
	else
		startendtestlog "'$disk_begin' not found"
	fi


	#if disk '$lv_disklabel' == sdisk, do snapshot

	# in 'lv_dirty_projects_array' are all projects to backup
	# call bk_project for each
	for _project in "${lv_dirty_projects_array[@]}"
	do

		lpkey=${lv_disklabel}_${_project}

		# check current time
		tcurrent=$( currentdateT )

		# second reachability check, first was in first loop
		check_pre_host $lpkey
		_ispre=$?
		dlog "check, if host of project exists (must be 0): $_ispre"
		dlog ""

		if test "$_ispre" -eq 0
		then
			# check if root folder exists
			#dlog "grep snapshot_root  conf/${lpkey}.conf | grep '^[[:blank:]]*[^[:blank:]#;]'"
			snapshotroot=""
			conffile="conf/${lpkey}.conf"
			if test_normal_file $conffile
			then
				snapshotroot=$( grep snapshot_root  $conffile | grep '^[[:blank:]]*[^[:blank:]#;]' | awk '{print $2}' )
			else
				archfile="conf/${lpkey}.arch"
				if test_normal_file $archfile
				then
					snapshotroot=$( grep archive_root  $archfile | grep  '^[[:blank:]]*[^[:blank:]#;]' | awk '{print $2}' )
				fi
			fi
			backupdisk=""
			if test -n $snapshotroot
			then
				backupdisk=$( echo "$snapshotroot" | cut -d'/' -f3 )
			fi
			#dlog "echo $snapshotroot | cut -d'/' -f3 "
			#dlog "backup disk: $backupdisk "
			if [ -n "$backupdisk" ]
			then
				if [ "$backupdisk" != "$lv_targetdisk" ]
				then
					dlog "- snapshot_root in 'conf/${lpkey}': '$snapshotroot'"
					dlog "- targetdisk in configuration: '$lv_targetdisk'"
					dlog "!!! backup disk in configuration: '$backupdisk' is != targetdisk: '$lv_targetdisk' !!! "
					exit $BK_RSYNCFAILS
				fi
			fi
			if [ "$lv_disklabel" != "$lv_targetdisk" ]
			then
				dlog "=== disk '$lv_disklabel', start of project '$_project', targetdisk: '$lv_targetdisk'=="
			else
				dlog "=== disk '$lv_disklabel', start of project '$_project' ==="
			fi

			tlog "do: '$_project'"

			# e.g. conf/sdisk_start,sh
			# in conf folder
			# shell script, executed at start of disk
			project_begin="$bv_conffolder/${lpkey}_begin.sh"
			if  test_script_file "$project_begin"
			then
				dlog "'$project_begin' found"
				dlog "execute: '$project_begin' "
				eval ./$project_begin  
			else
				startendtestlog "'$project_begin' not found"
			fi

			# #############################################################################
			# calls bk_project.sh #########################################################
			./bk_project.sh $lv_disklabel $_project
			# #############################################################################
			RET=$?
			#dlog "RET in bk_project: '$RET'"
			# BK_ARRAYSNOK=1  
			# BK_DISKLABELNOTGIVEN=2
			# BK_DISKLABELNOTFOUND=3
			# BK_DISKNOTUNMOUNTED=4
			# BK_MOUNTDIRTNOTEXIST=5
			# BK_TIMELIMITNOTREACHED=6
			# BK_DISKNOTMOUNTED=7
			# BK_RSYNCFAILS=8
			# BK_NOINTERVALSET=9
			# BK_NORSNAPSHOTROOT=12
			# BK_DISKFULL=13
			# BK_ROTATE_FAILS=14
			# BK_FREEDISKSPACETOOSMALL=15
			# BK_CONNECTION_UNEXPECTEDLY_CLOSED=16


			# check free space
			maxdiskspacepercent=$bv_maxfillbackupdiskpercent
			# data must be collected before disk is unmounted
			# line in 'df -h'
			# 1               2     3     4     5   6
			# /dev/sdb1       1,9T  1,4T  466G  75% /mnt/adisk

			#  df -h | sort | uniq | grep  -w fdisk -m1
			_temp15=$( df -h | grep -m1 -w $lv_targetdisk  | awk '{print $5}')
			# remove % from string, is used space in percent, 'df -h'
			_temp16=${_temp15%?}
			_used_space_percent=$_temp16
			#  handle disk full err
			if [ $maxdiskspacepercent -lt $_used_space_percent ]
			then
				dlog "maxdiskspacepercent -lt _used_space_percent  ${maxdiskspacepercent} -lt ${_used_space_percent} "
				RET=$BK_DISKFULL
			fi
			if test $RET -eq $BK_DISKFULL
			then
				projecterrors[${_project}]="rsync error, no space left on device, check harddisk usage: $lv_targetdisk"
				dlog " !! no space left on device, check configuration for $lpkey !!"
				dlog " !! no space left on device, check file 'rr_${lpkey}.log' !!"
				LV_DISKFULL=$BK_FREEDISKSPACETOOSMALL
			fi
			# disk full handler ok


			if test $RET -eq $BK_CONNECTION_UNEXPECTEDLY_CLOSED
			then
				projecterrors[${_project}]="rsync error, 'connection unexpectedly closed', check harddisk usage: $lv_disklabel, $_project"
				dlog "rsync: connection unexpectedly closed' in $lv_disklabel, $_project"
				LV_CONNECTION_UNEXPECTEDLY_CLOSED=$BK_CONNECTION_UNEXPECTEDLY_CLOSED
			fi
			if test $RET -eq $BK_RSYNCFAILS
			then
				projecterrors[${_project}]="rsync error, check configuration or data source: $lv_disklabel, $_project"
				dlog " !! rsync error, check configuration for '$lv_disklabel', project: '$_project' !!)"
				rsyncerrorlog " !! rsync error, check configuration for '$lv_disklabel', project: '$_project' !!)"
				dlog " !! rsync error, check file 'rr_${lpkey}.log'  !! "
				rsyncerrorlog "!! rsync error, check file 'rr_${lpkey}.log'"
				PRET=$RET
			fi
			if test $RET -eq $BK_ROTATE_FAILS
			then
				projecterrors[${_project}]="rsync error, check backup disk for errors  or data source: $lv_disklabel, $_project"
				dlog ""
				dlog " !! rotate error, check configuration for '$lv_disklabel', project: '$_project' !!)"
				dlog " !! rotate error, check disk for errors, maybe command 'mv' in history doesn't work correctly !!)"
				dlog " !! rotate error, check file 'aa_${lpkey}.log'  !! "
				dlog ""
				PRET=$RET
			fi
			if test $RET -eq $BK_ERRORINCOUNTERS
			then
				perror1="retain error, one value is lower than 2, "
				perror2="check configuration of retain values: $lv_disklabel $_project"
				projecterrors[${_project}]="${perror1}${perror2}"
				dlog " !! retain error, check configuration for $lv_disklabel $_project !!"
				dlog " !! retain error, check file 'rr_${lpkey}.log'  !! "
				PRET=$RET
			fi
			if test $RET -eq $BK_NORSNAPSHOTROOT
			then
				projecterrors[${_project}]="snapshot root folder doesn't exist, see log"
				dlog "snapshot root folder doesn't exist, see log"
				PRET=$RET
				#exit $BK_NORSNAPSHOTROOT
			fi

			projectdone=true
			if test $RET -ne 0
			then
				projectdone=false
				dlog "projectdone = false"
			fi

			if test "$projectdone" = "true"
			then
				# projectdone entry is written in bk_project.sh, 101 for archive
				# projectdone entry is written in bk_project.sh, 450 for projects

				dlog "all ok, disk: '$lv_label_name', project '$_project'"
				sendlog "HD: '$lv_label_name' mit Projekt '$_project' gelaufen, keine Fehler"
				# write success to a single file 

				# collect success for report at end of main loop
				# shorten label, if label ends with luks or disk
				var=$( strip_disk_or_luks_from_disklabel )
				lv_loop_successlist=( "${lv_loop_successlist[@]}" "${var}:$_project" )
				dlog "successlist: $( echo ${lv_loop_successlist[@]} )"
			else
				if test $RET -eq $BK_RSYNCFAILS
				then
					# error in rsync
					error_in_rsync=$BK_RSYNCFAILS
					dlog "error: disk '$lv_label_name', project '$_project'"
					sendlog "HD: '$lv_label_name' mit Projekt  '$_project' hatte Fehler"
					sendlog "siehe File: 'rr_${lv_disklabel}_$_project.log' im Backup-Server"

					# write unsuccess to a single file 
					# collect unsuccess for report at end of main loop
					var=$( strip_disk_or_luks_from_disklabel )
					lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${var}:$_project" )
					dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
				fi
				if test $RET -eq $BK_ROTATE_FAILS
				then
					# error in rsync
					error_in_rsync=$BK_ROTATE_FAILS
					dlog "error: disk '$lv_label_name', project '$_project'"
					slogmsg1="HD: '$lv_label_name' mit Projekt  '$_project' hatte Fehler, "
					slogmsg2="rotate in history kann falsch sein, prüfe Backup-Festplatte mit 'fsck'"
					sendlog "${slogmsg1}${slogmsg2}"
					sendlog "siehe File: 'aa_${lv_disklabel}_$_project.log' im Backup-Server"

					# write unsuccess to a single file 
					# collect unsuccess for report at end of main loop
					var=$( strip_disk_or_luks_from_disklabel )
					lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${var}:$_project" )
					dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
				fi
			fi

			# in conf folder
			# shell script, executed at end of disk
			if test "$projectdone" = "true"
			then
				project_end="$bv_conffolder/${lpkey}_end.sh"
				if  test_script_file "$project_end"
				then
					dlog "'$project_end' found"
					dlog "execute: '$project_end', "
					eval ./$project_end  
				else
					startendtestlog "'$project_end' not found"
				fi
			fi

		else
			tlog "    in time: $_project, but unavailable"
			dlog "${_project} reached, not available"
		fi

	done
	#  end of  [ ! $LV_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
	# backup of all dirty project are done
	# if errors, these are logged
	# --

	# disk end
	# in conf folder
	# shell script, executed at end of disk
	disk_end="$bv_conffolder/${lv_disklabel}_end.sh"
	if  test_script_file "$disk_end"
	then
		dlog "'$disk_end' found"
		dlog "execute: '$disk_end', "
		eval ./$disk_end  
	else
		startendtestlog "'$disk_end' not found"
	fi
else
	#   disk is full
	# don't do backup, disk is full
	# write to errorlist
	for _project in "${lv_dirty_projects_array[@]}"
	do
		# write unsuccess to a single file 
		# collect unsuccess for report at end of main loop
		var=$( strip_disk_or_luks_from_disklabel  )
		lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${var}:$_project" )
		dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
	done

	dlog "---> don't execute projects: '${lv_dirty_projects_array[*]}', disk full"
	dlog "---> max allowed used space '${maxdiskspacepercent}%' is lower than current used space '${usedspacepercent}%', continue with next disk"
	# --
fi

# all backups are done
# end of disk


# find min diff after backup ist done, done file exists here
# find next project in time line

find_next_project_to_do

# data must be collected before disk is unmounted
# line in 'df -h'
#                             4. free      
#                                   5. free in %
# 1               2     3     4     5   6
# /dev/sdb1       1,9T  1,4T  466G  75% /mnt/adisk

readonly used_space_temp=$( df -h /dev/disk/by-label/$lv_targetdisk | grep -m1 -w $lv_targetdisk | awk '{print $5}')
# remove % from string, is used space in percent, 'df -h'
usedspacepercent=${used_space_temp%?}
diskfreespace=$( df -h /dev/disk/by-label/$lv_targetdisk | grep -m1 -w $lv_targetdisk | awk '{print $4}')

maxdiskspacepercent=$bv_maxfillbackupdiskpercent


# clean up
notifyfilepostfix="keine_Fehler_alles_ok"

# umount backup disk, if configured in 'cfg.projects'

# check for umount of backup disk
if test -d $lv_markerfolder 
then
	_oldifs15=$IFS
	#IFS=','
	parray=${a_properties[$lv_disklabel]}

	umount_is_configured=$(echo ${parray[@]} | grep -w -o "umount" | wc -l )
	if test $umount_is_configured -eq 1 
	then

		lv_mountfolder=/mnt/$lv_targetdisk
		dlog "umount  $lv_mountfolder"
		./umount.sh  $lv_targetdisk
		RET=$?
		if test $RET -ne 0
		then
			msg="HD '$lv_targetdisk' wurde nicht korrekt getrennt, bitte nicht entfernen"
			dlog "$msg"
			sendlog $msg
			notifyfilepostfix="Fehler_HD_nicht_getrennt"
		else
			#rmdir  $mountfolder
			dlog "'$lv_label_name' all is ok"
			sendlog "HD '$lv_label_name': alles ist ok"

			nextdiff=$lv_min_wait_for_next_loop
			# if duration < next project, then use next project 'lv_next_project_diff_minutes' as next time
			if ((nextdiff < lv_next_project_diff_minutes ))
			then
				nextdiff=$lv_next_project_diff_minutes
			fi
			_encoded_diffstring_next_diff=$( encode_diff_to_string $nextdiff )
			sendlog "HD mit Label '$lv_label_name' kann in den nächsten '${_encoded_diffstring_next_diff}' Stunden:Minuten vom Server entfernt werden "
		fi

		# check, if really unmounted
		if [ -d $lv_markerfolder ]
		then
			dlog "disk is still mounted: '$lv_label_name', at: '$lv_mountfolder' "
			dlog ""
			dlog "'$lv_label_name' ist noch verbunden, umount error"
			sendlog "HD mit Label: '$lv_label_name' konnte nicht ausgehängt werden, bitte nicht entfernen"
			logdate=$( currentdate_for_log )
			sendlog "=======  $logdate  ======="
			notifyfilepostfix="HD_konnte_nicht_getrennt_werden_Fehler"
			
		fi
	else
		dlog "no umount configured, maybe this is a fixed disk  at $lv_mountfolder"
		dlog "next run of '$lv_next_project_name' in '${lv_next_project_diff_minutes}' minutes"
		sendlog "'umount' wurde nicht konfiguriert, HD '$lv_label_name' ist noch verbunden, at $lv_mountfolder"
	fi
else
	dlog "is local disk, no umount"
fi

dlog "== end of backup to disk '$lv_label_name' =="
dlog ""

# umount done, if configured
# write some messages to log

# write message to User-Desktop, if configured in 'cfg.ssh_login'


readonly lv_encoded_diffstring_next_project=$( encode_diff_to_string $lv_next_project_diff_minutes )
diff_unit=$( encode_diff_unit $lv_next_project_diff_minutes )

printable_diff_unit="nichts"

if test $diff_unit = "minutes" 
then
	printable_diff_unit="Minuten"
fi
if test $diff_unit = "hours" 
then
	printable_diff_unit="Stunden:Minuten"
fi
if test $diff_unit = "days" 
then
	printable_diff_unit="Tagen:Stunden:Minuten"
fi

# build full message
msg="HD mit Label '$lv_label_name', nächster Lauf eines Projektes ('$lv_next_project_name')"
sendlog "$msg"
msg="    für diese Backup-HD ist in: '${lv_encoded_diffstring_next_project}' $printable_diff_unit"
sendlog "$msg"

sendlog "waittime interval:  $waittimeinterval "

msg="free space at backup disk '$lv_label_name': $diskfreespace, used: ${usedspacepercent}%"
dlog "$msg"
msg="freier Platz auf Backup-HD '$lv_label_name': $diskfreespace, belegt: ${usedspacepercent}%"
sendlog "$msg"

# check again, after backup
if [ $maxdiskspacepercent -lt $usedspacepercent ]
then
	LV_DISKFULL=$BK_FREEDISKSPACETOOSMALL
fi

if [ $LV_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
then
	msg="!!!  Festplatte '$lv_label_name': ist voll, kein Backup mehr möglich. !!!"
	sendlog "$msg"
	notifyfilepostfix="Festplatte_ist_voll_kein_Backup_möglich"
fi

if [ $LV_CONNECTION_UNEXPECTEDLY_CLOSED -eq $BK_CONNECTION_UNEXPECTEDLY_CLOSED ]
then
	msg="Rsync: Verbindung abgebrochen, kein Backup möglich."
	sendlog "$msg"
	notifyfilepostfix="Rsync_Verbindung_abgebrochen"
	
fi

msg="max. reservierter Platz auf Backup-HD '$lv_label_name' in Prozent '${maxdiskspacepercent}%'"
sendlog "$msg"

hour=$(date +%H)
TODAY3=$( currentdate_for_log )
sendlog "=======  $TODAY3  ======="


#  handle disk full error
if [ $maxdiskspacepercent -lt $usedspacepercent ]
then
	msg="max. reservierter Platz auf Backup-HD '$lv_label_name' in Prozent '${maxdiskspacepercent}%'"
	dlog "$msg"
	projecterrors[------]="maximaler reservierter Platz auf der Backup-HD wurde überschritten: "
	projecterrors[-----]="   max erlaubter Platz '${maxdiskspacepercent}%' ist kleiner als verwendeter Platz  '${usedspacepercent}%'"
fi


# x replaces projecterrors, if not empty,  and testet
projecterrorssize=0
if [ ${#projecterrors[@]} -eq 0 ]
then
	projecterrorssize=0
else
	projecterrorssize=${#projecterrors[@]}
fi


if test ${projecterrorssize} -gt 0 
then

	#  handle disk full err
	if [ $maxdiskspacepercent -lt $usedspacepercent ]
	then
		dlog "allowed space of disk '${maxdiskspacepercent}%' is lower than current free space '${usedspacepercent}%'"
		notifyfilepostfix="Backup-HD_ist_zu_voll"
	else
		notifyfilepostfix="Fehler_in_Projekten"
	fi

	if test $PRET -eq $BK_RSYNCFAILS
	then
		notifyfilepostfix="Rsync_Fehler"
	fi
        if test $PRET -eq $BK_ROTATE_FAILS
        then
		notifyfilepostfix="Rotate_in_History_ist_vermutlich_nicht_ok"
        fi
        if test $PRET -eq $BK_ERRORINCOUNTERS
        then
		notifyfilepostfix="retain_Zähler_sind_nicht_ok"
        fi
        if test $PRET -eq $BK_NORSNAPSHOTROOT
        then
		notifyfilepostfix="kein_Root_Verzeichnis_gefunden"
        fi



	#sendlog "listsize: '${#projecterrors[@]}',  $notifyfilepostfix"
	# loop over keys in array with !
	# array: for i in "${!projecterrors[@]}"
	for i in "${!projecterrors[@]}"
	do
		sendlog "Projekt: '$i'  Nachricht: ${projecterrors[$i]}"
	done
	sendlog "---"
fi


# send to local folder 'backup_messages_test'
# create temp file with postfix in name
sshnotifysend_bk_loop $notifyfilepostfix 

#set +x

# end of loop, remove lv_notifysendlog
if test -f $lv_notifysendlog
then
	rm $lv_notifysendlog
fi

# write collected success labels to disk
# don't delete files, is > redirection
# files are used in bk_disks
# write successarray, read again  in 'bk_disks.sh'
#echo "222  ${lv_loop_successlist[@]} "
echo ${lv_loop_successlist[@]} > $bv_successarray_tempfile
#dlog "UUUUU file: '$bv_successarray_tempfile'"
#cp $bv_successarray_tempfile fff.txt
#dlog "UUUUU lv_loop_successlist: ${lv_loop_successlist[@]} "
# write unsuccessarray, read again  in 'bk_disks.sh'
echo ${lv_loop_unsuccesslist[@]} > $bv_unsuccessarray_tempfile
#dlog "FFFFF cat $bv_successarray_tempfile"
#echo "cat $bv_successarray_tempfile"
#cat $bv_successarray_tempfile

if test $error_in_rsync -gt 0 
then
	tlog "end: fails, '$lv_label_name'"
	dlog "bk_loop fails, '$lv_label_name'"
	exit $error_in_rsync
fi

tlog "bk_loop end: ok, label: '$lv_label_name'"
dlog "bk_loop end: ok, label: '$lv_label_name'"
exit $BK_SUCCESS

# end loop over projects for backup disk
# --


# EOF

