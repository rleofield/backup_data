#!/bin/bash

# file: bk_loop.sh
# bk_version  26.02.1

# Copyright (C) 2017-2026 Richard Albrecht
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
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_

# which will exit your script if you try to use an uninitialised variable.
set -u

. ./cfg.working_folder
. ./cfg.projects

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_folders.sh

if ! typeset -f  execute_main_begin > /dev/null 
then 
	# used by
	# execute_disk_begin ${lv_disklabel}
	# execute_disk_end ${lv_disklabel}
	# execute_project_begin $lpkey
	# execute_project_end $lpkey
	. ./src_begin_end.sh
fi


# exit values
# exit $BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
# exit $BK_ARRAYSNOK         	- property arrays have errors
# exit $BK_DISKLABELNOTFOUND	- disk with uuid not found in /dev/disk/by-uuid, disk ist not in system 
# exit $BK_NOINTERVALSET	- no backup time inteval configured in 'cfg.projects'
# exit $BK_TIMELIMITNOTREACHED	- for none project at this disk time limit is not reached
# exit $BK_DISKNOTUNMOUNTED	- ddisk could not be unmounted
# exit $BK_MOUNTDIRTNOTEXIST	- mount folder for backup disk is not present in '/mnt'
# exit $BK_DISKNOTMOUNTED	- disk could not be mounted 
# exit $BK_RSYNCFAILS		- rsync error, see logs
# exit $BK_SUCCESS		- all was ok
# exit $BK_NORSNAPSHOTROOT	- no backup root set in  config
# exit $BK_DISKFULL		- back harddisk is full
# exit $BK_ROTATE_FAILS		- rotate for history fails
# exit $BK_FREEDISKSPACETOOSMALL - free disk space at backup harddisk ist too small


#set -u

# Label der Backup-HD = $1
readonly lv_disklabel=$1


if [ -z "$lv_disklabel" ]
then
	exit "$BK_DISKLABELNOTGIVEN";
fi

# used in src_log
readonly lv_cc_logname="$lv_disklabel:loop"
readonly lv_tracelogname="loop"


# result of function 'lookup_for_dirty_projects_and_show_timelines'
declare -a lv_dirty_projects_array
lv_min_one_project_found=0
lv_dirtyprojectcount=0


function init_local_variables() {

	# use media mount '/media/user/label' instead of '/mnt/label'?
	# 0 = use
	# 1 = don't use, use /mnt
	# default=1, don't use
	readonly lc_use_mediamount=1

	readonly lv_notifysendlog="tempnotifysend.log"

	# uppercase, local constants
	readonly lc_PROJECT_DONE_REACHED=$BK_PROJECT_DONE_REACHED
	readonly lc_PROJECT_DONE_NOT_REACHED=$BK_PROJECT_DONE_NOT_REACHED
	readonly lc_PROJECT_DONE_WAITINTERVAL_REACHED=$BK_PROJECT_DONE_WAITINTERVAL_REACHED

	lv_return_project_loop="$BK_SUCCESS"

	readonly lv_min_wait_for_next_loop=60
	lv_next_project_diff_minutes=10000
	lv_label_displayname="$lv_disklabel"
	lv_disk_uuid="empty"

	# set. if rsync fails with '$BK_RSYNCFAILS' 
	lv_error_in_rsync=0
	lv_dirty_projects_array=()
	lv_mountpoint="/mnt/$lv_disklabel"
	lv_markerfolder="$lv_mountpoint/marker"
	readonly lc_maxdiskspacepercent=$bv_maxfillbackupdiskpercent
	lv_diskfreespace_with_unit="5T"
	lv_diskfreespace="5"
	lv_usedspacepercent="5"


	# uppercase, local constants
	lc_DISKFULL=$BK_SUCCESS
	lc_CONNECTION_UNEXPECTEDLY_CLOSED=$BK_SUCCESS

	# copy from cfg-projects
	readonly lv_max_last_date=$max_last_date
	#readonly lv_marker_ignore_snapshot_root=$cfg_marker_ignore_snapshot_root

}


# get targetdisk from label, if exist
function get_targetdisk {
	# get targetdisk from label
	# configured in cfg.projects
	# must be used in snapshot_root
	readonly lv_targetdisk=$( targetdisk "$lv_disklabel" )
	lv_label_displayname="$lv_disklabel"
	if [ "$lv_disklabel" != "$lv_targetdisk" ]
	then
		lv_label_displayname="$lv_disklabel ($lv_targetdisk)"
	fi
	dlog "lookup targetdisk: '$lv_label_displayname'"
	
	# changed later to media mount, if lc_use_mediamount=0,  = use 
	# check for folder 'marker' at mounted backup disk
	lv_mountpoint="/mnt/$lv_targetdisk"
	lv_markerfolder="$lv_mountpoint/marker"
}


# check, get_projectwaittimeinterval() only for disk done 
# result is in, value is in hours
#       lv_temp_loopwaittimestart
#       lv_temp_loopwaittimeend
# backup for this project waits in this interval, nothing ist done
#  for example '08-10'
# parameter is project identifier, for example 'ddisk_dserver'
function get_projectwaittimeinterval {
	local temp_loopwaittimestart="09"
	local temp_loopwaittimeend="09"
	local _lpkey=$1
#	check, if array 'a_waittime' is an aasociative array
	is_associative_array_ok "a_waittime"
	ret=$?
	if [ ! $ret ]
	then
		dlog "'a_waittime' array doesn't exist "
		return $BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	fi
# 	array 'a_waittime' exists, check, if length > 0
	array_length=${#a_waittime[@]}
	if [ $array_length -gt 0 ]
	then
	#                echo "array length > 0 "
	# in script:         | Set and Not Null     | Set But Null     | Unset
	# ${parameter+word}  | substitute word      | substitute word  | substitute null


#		array 'a_waittime' exists and has length > 0, check, if projekt key is inside
		associative_array_has_value "a_waittime" "$_lpkey"
		ret=$?
#		dlog "associative_array_has_value ret  '$ret'"
		if [ $ret -eq 0 ]
		then
# 			array 'a_waittime' exists and has length > 0 and has project key is inside
#			get the value	
#			value is an array
#  			for example '08-10'
			local _waittime=${a_waittime[${_lpkey}]}
			if [ $_waittime ]
			then
# 				in src_log.sh: 488 function get_decimal_waittimestart()
# 				in src_log.sh: 508 function get_decimal_waittimeend()
#				file global values are overwritten with "09"at start of the functions 
				temp_loopwaittimestart=$( get_decimal_waittimestart $_waittime )
				temp_loopwaittimeend=$( get_decimal_waittimeend $_waittime )
			fi
		fi
	fi
	lv_temp_loopwaittimestart=$temp_loopwaittimestart
	lv_temp_loopwaittimeend=$temp_loopwaittimeend
	return $BK_SUCCESS
}


function get_project_properties {
	local _lpkey=$1
	local _value=""
	is_associative_array_ok "a_properties"
	ret=$?
	if [ ! $ret ]
	then
		dlog "'a_properties' array doesn't exist "
		return $BK_ASSOCIATIVE_ARRAY_NOT_EXISTS
	fi
#	dlog "'a_properties' array  exist "
	# array exists and has length > 0
	array_length=${#a_properties[@]}  # ok, if array=() is set
	if [ $array_length -gt 0 ]
	then
	#                echo "array length > 0 "
	# in script:         | Set and Not Null     | Set But Null     | Unset
	# ${parameter+word}  | substitute word      | substitute word  | substitute null

#		dlog "associative_array_has_value 'a_properties' '$_lpkey'"
		associative_array_has_value "a_properties" "$_lpkey"
		ret=$?
#		dlog "associative_array_has_value ret  '$ret'"
		if [ $ret -eq 0 ]
		then
			_value=${a_properties[${_lpkey}]}
#		dlog "value $_value"
		fi
	fi
	echo $_value
	return $BK_SUCCESS
}


function sendlog {
        local _msg=$1
        local _logdate=$( currentdate_for_log )
        echo -e "$_logdate  == Notiz: $_msg" >> $lv_notifysendlog
}


# par1 = old   
# par2 = new
# diff = new - old,   in minutes
# minutes for
#      h = 60, d = 1440, w = 10080, m = 43800, y = 525600
# parameter: dateold, datenew in unix-date format
#            dateold is before datenew
function date2seconds {
	# par = datestring
	# return date in seconds
	date +%s -d "$1"
}


function time_diff_minutes {
        local _old=$1
        local _new=$2

        # convert the date hour:min:00" in seconds from 
        #       Unix Date Stamp to seconds, "1970-01-01T00:00:00"
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


# use targetdisk to find in list 'uuid.txt' in backup folder
function get_disk_uuid {
	local _uuid="empty"
	if [[ $lv_targetdisk ]]
	then
#		https://unix.stackexchange.com/questions/60994/how-to-grep-lines-which-does-not-begin-with-or
#		How to grep lines which does not begin with “#” or “;”
#		local uuid=$( cat "uuid.txt" | grep  '^[[:blank:]]*[^[:blank:]#;]'  |  grep -w $_disk_label | awk '{print $2}' )

#		skip lines with '#' at start of line and print second entry
		_uuid=$( cat "uuid.txt" | grep -v '#' | grep -w "$lv_targetdisk" | awk '{print $2}' )

#		better, may be
#		_uuid=$( gawk -v pattern="$_disk_label" '$1 ~ "(^|[[:blank:]])" pattern "([[:blank:]]|$)"  {print $NF}' uuid.txt )
		
		if [[ ! $_uuid ]]
		then
			_uuid="unknown"
		fi
	fi
	echo "$_uuid"
}


# parameter: disklabel or targetdisk, if used
# 0 = success
# 1 = error, disk not in uuid list
function check_disk_uuid {
	# uses targetdisk
	local _uuid=$( get_disk_uuid )

#	test, if symbolic link exists
	if test -L "/dev/disk/by-uuid/$_uuid"
	then
		return 0
	fi
	return 1
}


function lookup_disk_by_uuid {
	# test, if uuid of disk is in device list:  /dev/disk/by-uuid
	# get from 'uuid.txt' and look up in device list 
	#dlog "-- UUID check: is HD '$lv_label_displayname' connected to the PC?" 

	# call 'check_disk_uuid'
	check_disk_uuid 
	local _uuid_RET=$?
	local _goodlink=$_uuid_RET

	#dlog "after check_disk_uuid: $lv_disklabel "
	# get_disk_uuid must be successful
	lv_disk_uuid=$( get_disk_uuid )

	# disk must be in /dev/disk/by-uuid
	# a USB disk must be connected
	# mount is not necessary here, is checked and done later

	if [[ $_goodlink -eq 0 ]]
	then
		dlog "-- UUID check: disk '$lv_label_displayname' " 
		dlog "-- -- UUID '$lv_disk_uuid' found in /dev/disk/by-uuid" 
		tlog "disk '$lv_label_displayname' with UUID '$lv_disk_uuid' found" 
	else
		dlog "-- UUID check: disk '$lv_label_displayname'" 
		dlog "-- -- UUID '$lv_disk_uuid' not found" 
	fi
	# disk with label and uuid found in device list
	# --
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

        # mm=minutes only
        local _result_minutes=10#${_array[0]}
	local _hours=0
	local _minutes=0
	local _days=0

        if test $_length -eq "2"
        then
                # is hh:mm=hours:minutes
                _hours=10#${_array[0]}
                _minutes=10#${_array[1]}
                _result_minutes=$(( ( ${_hours} * 60 ) + ${_minutes} ))
        fi
        if test $_length -eq "3"
        then
		# is dd:hh:mm  - length 3
		# = days:hours:minutes
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
function programmed_interval_minutes {
	local _lpkey=$1
	local _intervalvalue=${a_interval[${_lpkey}]}
	local _minutes=$( decode_pdiff_local ${_intervalvalue} )
	echo $_minutes
}


function is_in_waitinterval {
	local _lpkey=$1
	get_projectwaittimeinterval $_lpkey
	local _wstart=$lv_temp_loopwaittimestart
	local _wend=$lv_temp_loopwaittimeend
	is_in_waittime $_wstart $_wend
	local _wait_RET=$?
	return $_wait_RET
}


function last_done_time {

	local _lpkey=$1

	# format YYYY-mm-ddThh:mm
	local _last_done_time="$lv_max_last_date"

	# get last line from done file in ./done
	local _done_file="./${bv_donefolder}/${_lpkey}_done.log"
	if test -f $_done_file
	then
		_last_done_time=$(cat $_done_file | awk  'END {print }')
		# if doesn't exist, use last from cfg
		if [ -z "$_last_done_time" ]
		then
			_last_done_time="$lv_max_last_date"
		fi
	fi
	echo "$_last_done_time"
}


# par1 = disklabel_project_key
#   lc_PROJECT_DONE_REACHED = do backup, 
#   lc_PROJECT_DONE_NOT_REACHED = interval not reached, 
#   lc_PROJECT_DONE_WAITINTERVAL_REACHED = waittime interval reached
function check_disk_done {
	local _lpkey=$1

        if [ $bv_test_no_check_disk_done -eq 1 ]
        then
        #        dlog ""
        #        dlog "    test mode, done is not checked"
        #        dlog ""
		return $lc_PROJECT_DONE_REACHED
	fi

	is_in_waitinterval $_lpkey
	local _waitRET=$?
	if [ "$_waitRET" -eq 0  ] 
	then
		return $lc_PROJECT_DONE_WAITINTERVAL_REACHED
	fi


        # format YYYY-mm-ddThh:mm
        # get last line in done file
        local _last_done_time="$( last_done_time $_lpkey )"
        local _currenttime=$( currentdateT )
        local _time_diff_minutes=$( time_diff_minutes  $_last_done_time  $_currenttime  )
        local _programmed_interval=$( programmed_interval_minutes ${_lpkey} )

        if test $_time_diff_minutes -ge $_programmed_interval
        then
                # diff was greater than reference, take as success
                return $lc_PROJECT_DONE_REACHED
        fi
        return $lc_PROJECT_DONE_NOT_REACHED
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
		local _preRET=$?
		if test $_preRET -eq 0 
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
function umount_media_folder {

        local _mtab_line_mount_media=$1

        local mount_media_folder=""
        mount_media_folder=$( echo "$_mtab_line_mount_media" | awk '{ print $2 }' )
        dlog "try umount: $mount_media_folder"
        umount "$mount_media_folder"
        local umountRET=$?
        if [ "$umountRET" -ne 0 ]
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

        else # !!! to do, check luks uuid
		dlog "luks mapper by label doesn't exist: $luksmapper"

		# try with luks-uuid
		# use targetdisk 
        	local _luksuuid=$( get_disk_uuid )
        	local _lukslabel="luks-$_luksuuid"
        	local _luksmapper="/dev/mapper/$_lukslabel"
        	dlog "try mapper with uuid: $_luksmapper"
        	if [  -L "$_luksmapper" ]
        	then
			dlog "luks mapper exists: $luksmapper"
			dlog "do luksClose:  cryptsetup luksClose $_luksmapper"
			cryptsetup luksClose "$_lukslabel"
	        fi
	fi
        return $BK_SUCCESS
}


function check_media_folder {
	local _mtab_mount_media_folder=$( cat /etc/mtab  | grep media | grep "$lv_targetdisk"  | awk '{ print $2 }')
	local _mountpoint=$( findmnt -nl | grep "/media/" | awk '{ print $1 }' )
	# if media mount exists, umount
	if [ ! -z  "$_mtab_mount_media_folder" ]
	then
		dlog " ---  mediamount exists: $_mtab_mount_media_folder"

		# use media mount instead of /mnt?
		# 0 = use
		# 1 = don't use, use /mnt
		if test $lc_use_mediamount -gt 0
		then
			# try to umount media folder
			#dlog "in mediamount exists: $lv_disklabel "
			local _mtab_line_mount_media=$( cat /etc/mtab  |  grep media | grep "$lv_targetdisk" )
			if [ ! -z "$_mtab_line_mount_media" ]
			then
				umount_media_folder "$_mtab_line_mount_media"
				local mediaRET=$?
				if [ $mediaRET -eq $BK_DISKNOTUNMOUNTED ]
				then
					exit $BK_DISKNOTUNMOUNTED
				fi
			else
				# check mount at /mnt
				local _mtab_mount_mnt=$( cat /etc/mtab  |  grep mnt | grep "$lv_targetdisk" )
				if [  -n "$_mtab_mount_mnt" ]
				then
					local _mtab_mount_mnt_folder=$( echo "$_mtab_mount_mnt" | awk '{ print $2 }' )
					dlog "no mount at /mnt found with '$lv_targetdisk', mountpoint is at: $_mtab_mount_mnt_folder"
				fi
			fi
		else
			# ok use media folder
			# set new  lv_mountpoint
			dlog "media mount '$_mtab_mount_media_folder' exists"
			lv_mountpoint="$_mtab_mount_media_folder"
			lv_markerfolder="$lv_mountpoint/marker"
		fi
	fi  

	# close cryptsetup,  second try, if done
	# use targetdisk 
	local _mmuuid=$( get_disk_uuid )
	local _luks_uuid_label="luks-$_mmuuid"
	local _luks_uuid_label_mapper="/dev/mapper/$_luks_uuid_label"
	#dlog " --- look up for luks mapper with uuid: $_luks_uuid_label_mapper"
	if [  -L "$_luks_uuid_label_mapper" ]
	then
		dlog "luks mapper with uuid exists: $_luks_uuid_label"
		dlog "do luksClose:   cryptsetup luksClose $_luks_uuid_label"
		cryptsetup luksClose $_luks_uuid_label
		#	Error  codes are:
		#	1 wrong parameters,
		#	2 no permission (bad passphrase),
		#	3 out of memory,
		#	4 wrong device specified,
		#	5 device already exists or device is busy.
	fi
}


function mount_HD {

	# first, check mount at /media/user and umount, includes luks umount
	check_media_folder 

	if test ! -d $lv_mountpoint 
	then
		dlog " mount folder  '$lv_mountpoint' doesn't exist" 
		exit $BK_MOUNTDIRTNOTEXIST
	fi
	if test -d $lv_markerfolder 
	then
		# is fixed disk
		dlog " --- HD '$lv_targetdisk' is already mounted at '$lv_mountpoint'"
	else
		dlog " --- marker folder '$lv_markerfolder' doesn't exist, try mount" 
		./mount.sh "$lv_targetdisk" 
		local mountRET=$?
		if test $mountRET -ne 0
		then
			dlog " == end, could not mount disk '$lv_targetdisk' to  '$lv_mountpoint', mount error =="
			exit $BK_DISKNOTMOUNTED
		fi

		# check marker folder, if not ok, then disk is not mounted
		if test ! -d "$lv_markerfolder"
		then
			dlog " mount,  markerdir '$lv_markerfolder' not found"

			dlog " == end, could not mount disk '$lv_targetdisk' to  '$lv_mountpoint', marker folder doesn't exist =="
			exit $BK_DISKNOTMOUNTED
		fi
	fi
}


# look up for next project in time
function find_next_project_to_do {
	# empty external var 
	lv_next_project_name=""
	for _project in $lv_disk_project_list
        do
                local _lpkey=${lv_disklabel}_${_project}
                local _done_file="./${bv_donefolder}/${_lpkey}_done.log"
                local _last_date_in_done_file=$lv_max_last_date
                if test -f $_done_file
                then
                        _last_date_in_done_file=$(cat $_done_file | awk  'END {print }')
                fi

                # get configured project delta time

                local _pdiff=$( programmed_interval_minutes "${_lpkey}" )
                # get current delta after last date done 
                local _current_date=$( currentdateT )
                local _diff_since_last_backup=$(time_diff_minutes  "$_last_date_in_done_file"  "$_current_date"  )
                local _deltadiff=$(( _pdiff - _diff_since_last_backup ))

                # look for minimum
                if (( _deltadiff < lv_next_project_diff_minutes ))
                then
                        # copy to external vars
                        lv_next_project_diff_minutes=$_deltadiff
                        lv_next_project_name=$_project
#			dlog "AAAA, next project '$_project'"
                fi
        done
}


# par: $lv_notifysendlog $lv_disklabel $notifyfilepostfix
#       tempnotifysend.log  LABEL   last part of filename 
function sshnotifysend_bk_loop {
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

	dlog "send notify message of disk '$lv_label_displayname' to folder '${bv_backup_messages_testfolder}'"
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
	# defined in scr_filenames.sh
	#  readonly bv_internalerrors="errors.txt"
}


function remove_old_notify_files {
	# remove old "notifysend.log"
	# readonly lv_notifysendlog="notifysend.log", set in line 75
	#dlog "remove old notify log for disk '$lv_disklabel': '$lv_notifysendlog'"
	if test -f $lv_notifysendlog
	then
		rm $lv_notifysendlog
	fi

	# remove old Backup-HD_* files
	# bv_notifyfileprefix has value 'Backup-HD'
	local _files=$(ls ${bv_notifyfileprefix}_* 2> /dev/null | wc -l)

	if [ "$_files" != "0" ]
	then
		rm ${bv_notifyfileprefix}_*
	fi
}


function show_loopstart_message {
	dlog "== process disk, label: '$lv_label_displayname' =="
}


# func ends at line 987 ...
function lookup_for_dirty_projects_and_show_timelines {

	# is local var, used as counter in array

	# next is look up for dirty projects of this disk
	# projects - last time ist later then project time interval 
	# exit, if interval ist not set
	associative_array_has_value "a_projects" "$lv_disklabel"
	local lookupRET=$?
	if [ $lookupRET -gt 0 ]
	then
		dlog "key: '$lv_disklabel' not found in array 'a_projects' in 'cfg.projects'"
		exit $BK_DISKLABELNOTFOUND
	fi	

        # var is intialized here, not at start of bk_loop.sh
	# is global var
	readonly lv_disk_project_list=${a_projects[$lv_disklabel]}

	dlog ""
	dlog "-- disk '$lv_label_displayname', check projects: '$lv_disk_project_list'"

	# find for each project, if interval is reached, if not, exit

	# build list of last times for backup per project in disk
	# don't check the existence of the disk, this is done later
	dlog ""

	# write headline
	dlog "                      dd:hh:mm                dd:hh:mm               dd:hh:mm"

	lv_min_one_project_found=0
	lv_dirtyprojectcount=0

	local _lpkey=""
	local _interval=""
	local _tcurrent=""
	local _done_file=""
	local _last_done_time=""

	#   scan list of all projects in disk
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
		_last_done_time="$( last_done_time $_lpkey )"

		# ret 'check_disk_done',
		#   lc_PROJECT_DONE_REACHED = do backup, 
		#   lc_PROJECT_DONE_NOT_REACHED = interval not reached, 
		#   lc_PROJECT_DONE_WAITINTERVAL_REACHED = waittime interval reached
		check_disk_done "$_lpkey" 
		local _ret_check_disk_done=$?

		# print disklabel to field of 19 length
		local _disk_label_print=$( printf "%-19s\n"  "${_lpkey}" )
		local _project_interval_minutes=$(  programmed_interval_minutes "${_lpkey}" )

		# 1. entry, last
		# diff = tcurrent - last_done_time,   in minutes
		local _done_diff_minutes=$(   time_diff_minutes  "$_last_done_time"  "$_tcurrent"  )
		local _encoded_diffstring1=$( encode_diff_to_string  "$_done_diff_minutes" )
		local _done_diff_print8=$( printf "%8s"  "$_encoded_diffstring1" )

		# 2. entry, next
		local _deltadiff=$(( _project_interval_minutes - _done_diff_minutes ))
		local _delta_diff_print=$( printf "%6s\n"  $_deltadiff )
		local _encoded_diffstring2=$( encode_diff_to_string "$_delta_diff_print" )
		local _next_diff_print9=$( printf "%9s\n"  "$_encoded_diffstring2" )

		# 3. entry, programmed
		local _encoded_diffstring3=$( encode_diff_to_string  "$_project_interval_minutes" )
		local _project_interval_minutes_print8=$( printf "%8s"  "$_encoded_diffstring3" )

		# example: 01:15:32 last, next in    08:28,  programmed  02:00:00,  do nothing
		local timeline=$( echo "$_disk_label_print   $_done_diff_print8 last, next in $_next_diff_print9,  programmed  $_project_interval_minutes_print8," )

		# projectdone is reached, check reachability with 'check_pre_host'
		if test $_ret_check_disk_done -eq $lc_PROJECT_DONE_REACHED
		then
			# reached, if done
			# - test $_DIFF -ge $_pdiff,          = wait time reached
			# - if [ $bv_test_no_check_disk_done -eq 1 ]  = 'bv_test_no_check_disk_done' is set
			# - if [ $do_once -eq 1 ]             = 'do_once' is set
			# check. if reachable, add to list 'lv_dirty_projects_array'
			_precondition=$bv_preconditionsfolder/${_lpkey}.pre.sh
			#dlog "precondition: $_precondition"
			local _ispre_dirty=1
			if [  -f "$_precondition" ]
			then
				check_pre_host "$_lpkey"
				_ispre_dirty=$?
			#	dlog "check pre host, is pre: $_ispre_dirty"
			else
				dlog "----"
				dlog "$_precondition doesn't exist"
				dlog "----"
			fi

			if [ $_ispre_dirty -eq 0 ]
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
				# set result values of function
				lv_dirty_projects_array[lv_dirtyprojectcount]=$_project

				# is local var, used as counter in array
				lv_dirtyprojectcount=$(( lv_dirtyprojectcount + 1 ))
				lv_min_one_project_found=1
				#dlog "AAAA lv_dirtyprojectcount= '$lv_dirtyprojectcount', lv_min_one_project_found= '$lv_min_one_project_found' "
			else
				# is_pre=false
				# not ok,  no backup	
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
		if test "$_ret_check_disk_done" -eq $lc_PROJECT_DONE_NOT_REACHED
		then
			tlog "not in time: $_project"
			temp_timeline=$( echo "${timeline} do nothing")
			timeline=$temp_timeline
		fi

		# waittime interval reached
		if test "$_ret_check_disk_done" -eq $lc_PROJECT_DONE_WAITINTERVAL_REACHED
		then
			tlog "in wait interval: $_project"
			# project key = disklabel_project
			_lpkey=${lv_disklabel}_${_project}
			get_projectwaittimeinterval $_lpkey
			local _wstart=$lv_temp_loopwaittimestart
			local _wend=$lv_temp_loopwaittimeend
			temp_timeline=$( echo "${timeline} wait from $_wstart to $_wend")
			timeline=$temp_timeline
			#dlog "yyyy $timeline wait,  from '$_wstart' to '$_wend'"
		fi
		dlog "$timeline"

	done
	dlog ""

	# in 'lv_dirty_projects_array' are all projects we need a backup
	# --
	#dlog "CCCC"

}


# line in 'df -h'
#                             4. free      
#                                   5. free in %
# 1               2     3     4     5   6
# /dev/sdb1       1,9T  1,4T  466G  75% /mnt/adisk
function mountpoint_free_space_with_unit {
	local _mountpoint=$1
	local _diskfreespace_with_unit=$(  findmnt -D -M $_mountpoint  -nl |  awk '{print $5}' )
	echo "$_diskfreespace_with_unit"
}


# line in 'df -h'
#                             4. free      
#                                   5. free in %
# 1               2     3     4     5   6
# /dev/sdb1       1,9T  1,4T  466G  75% /mnt/adisk
# get field 'use%' from findmnt and remove last char (%)
function mountpoint_used_space_percent {
	local _mountpoint=$1
	local _diskfreespacepercent=$( findmnt  -lo use% --mountpoint $_mountpoint -nl | sed 's/.\{1\}$//' )
	echo "$_diskfreespacepercent"
}


function refresh_used_free_space_percent {
	local _mountpoint=$1
	lv_diskfreespace_with_unit=$( mountpoint_free_space_with_unit $_mountpoint )
	lv_diskfreespace=$( echo "$lv_diskfreespace_with_unit" | sed 's/.\{1\}$//' )
	lv_usedspacepercent=$( mountpoint_used_space_percent $_mountpoint )
}

#  check for disk size, disk must be mounted
# set lc_DISKFULL, if disk is full
# set lv_diskfreespace
# set lv_usedspacepercent
function check_disk_full {


#	dlog "   check_disk_full"
	# lc_DISKFULL = $BK_SUCCESS
	# or
	# lc_DISKFULL = $BK_FREEDISKSPACETOOSMALL
	# set, if disk is full
	# checked also after backup
	lc_DISKFULL=$BK_SUCCESS
	lc_CONNECTION_UNEXPECTEDLY_CLOSED=$BK_SUCCESS
	local _max=${lc_maxdiskspacepercent}
	local _used=${lv_usedspacepercent}


#	dlog "max:  ${_max}, is: ${_used}"
	if [ ${_max} -lt ${_used} ]
	then
		dlog "---"
		dlog "--- !!!  disk: '$lv_targetdisk', max allowed used space '${_max}%' is lower than current used space '${_used}%', continue with next disk !!!"
		dlog "---"
		lc_DISKFULL=$BK_FREEDISKSPACETOOSMALL
	fi

}


function check_snapshot_root {

	local lpkey=$1
	# check if root folder exists
	local snapshotroot=""
	local conffile="conf/${lpkey}.conf"
	# exists            not null          size > 0           is file           readable
	if test_normal_file $conffile
	then
		snapshotroot=$( grep snapshot_root  $conffile | grep '^[[:blank:]]*[^[:blank:]#;]' | awk '{print $2}' )
	else
		local archfile="conf/${lpkey}.arch"
		if test_normal_file $archfile
		then
			snapshotroot=$( grep archive_root  $archfile | grep  '^[[:blank:]]*[^[:blank:]#;]' | awk '{print $2}' )
		fi
	fi
	local _snapshotroot_backupdisk=""
	# extract backupdisklabel from snapshot_root
	if test -n $snapshotroot
	then
		_snapshotroot_backupdisk=$( echo "$snapshotroot" | cut -d'/' -f3 )
	fi

	# backupdisk is not null, snapshotroot is set for backup disk in cfg
	if [ -n "$_snapshotroot_backupdisk" ]
	then
		if [ "$_snapshotroot_backupdisk" != "$lv_targetdisk" ]
		then
			local disk_not_set_in_conf="  disk set in snapshot root '$snapshotroot' in 'conf/${lpkey}' is not equal to targetdisk: '$lv_targetdisk' !!!"
			dlog          "$disk_not_set_in_conf"
			rsyncerrorlog "$disk_not_set_in_conf"
			sendlog       "$disk_not_set_in_conf"
			return  $BK_DISK_IS_NOT_SET_IN_CONF
		fi
	fi
}


function execute_project  {

	local _project=$1
	local lpkey=${lv_disklabel}_${_project}

	# if 'ignore_snapshot_root' is set for this project
	#     use snapshot_root direct, don't use disk label for snapshot_root
	#     disk label from DISKLIST is ignored
	#     used to move a single project to another disk
	check_snapshot_root $lpkey
	local snapshot_root_RET=$?
	if [[ $snapshot_root_RET -gt 0 ]]
	then
		return $snapshot_root_RET
	fi

	dlog "=== start of project '$_project',  disk: '$lv_label_displayname' ==="
	tlog "do: '$_project'"

	# in conf folder
	# shell script, executed at start of project
	execute_project_begin $lpkey
	local _project_begin_RET=$?
	if [ $_project_begin_RET -gt 0 ] 
	then
		dlog "execute_project_begin: RET: '$_project_begin_RET'"
		dlog ""
		return $BK_PROJECT_BEGIN_FAILED
	fi

	# #############################################################################
	# calls bk_project.sh #########################################################
	./bk_project.sh $lv_disklabel $_project
	# #############################################################################
	local _pRET=$?
	if [ $_pRET -gt 0 ]
	then
		dlog "RET in bk_project: '$_pRET'"
	fi
	# BK_ARRAYSNOK=55  
	# BK_DISKLABELNOTGIVEN=2
	# BK_DISKLABELNOTFOUND=3
	# BK_DISKNOTUNMOUNTED=4
	# BK_MOUNTDIRTNOTEXIST=5
	# BK_TIMELIMITNOTREACHED=6
	# BK_DISKNOTMOUNTED=7

	# BK_RSYNCFAILS=10
	# BK_NOINTERVALSET=11
	# BK_NORSNAPSHOTROOT=12
	# BK_DISKFULL=13
	# BK_ROTATE_FAILS=14
	# BK_FREEDISKSPACETOOSMALL=15
	# BK_CONNECTION_UNEXPECTEDLY_CLOSED=16


	# check free space
	# lc_maxdiskspacepercent=$bv_maxfillbackupdiskpercent
	# data must be collected before disk is unmounted
	# line in 'df -h'
	# 1               2     3     4     5   6
	# /dev/sdb1       1,9T  1,4T  466G  75% /mnt/adisk
	#  df -h | sort | uniq | grep  -w fdisk -m1

	refresh_used_free_space_percent $lv_mountpoint
	local _usedspacepercent=$lv_usedspacepercent

	#  handle disk full err
	# disk full error ist also detected in bk_project.sh
	if [ $lc_maxdiskspacepercent -lt $_usedspacepercent ]
	then
		dlog "lc_maxdiskspacepercent -lt _usedspacepercent  ${lc_maxdiskspacepercent} -lt ${_usedspacepercent} "
		_pRET=$BK_DISKFULL
	fi
	if test $_pRET -eq $BK_DISKFULL
	then
		projecterrors[${_project}]="rsync error, no space left on device, check harddisk usage: $lv_targetdisk"
		dlog " !! no space left on device, check configuration for $lpkey !!"
		dlog " !! no space left on device, check file 'rr_${lpkey}.log' !!"
		lc_DISKFULL=$BK_FREEDISKSPACETOOSMALL
	fi
	# disk full handler ok


	if test $_pRET -eq $BK_CONNECTION_UNEXPECTEDLY_CLOSED
	then
		projecterrors[${_project}]="rsync error, 'connection unexpectedly closed', check harddisk usage: $lv_disklabel, $_project"
		dlog "rsync: connection unexpectedly closed' in $lv_disklabel, $_project"
		lc_CONNECTION_UNEXPECTEDLY_CLOSED=$BK_CONNECTION_UNEXPECTEDLY_CLOSED
	fi
	if test $_pRET -eq $BK_RSYNCFAILS
	then
		projecterrors[${_project}]="rsync error, check configuration or data source: $lv_disklabel, $_project"
		dlog " !! rsync error, check configuration for '$lv_disklabel', project: '$_project' !!)"
		rsyncerrorlog " !! rsync error, check configuration for '$lv_disklabel', project: '$_project' !!)"
		dlog " !! rsync error, check file 'rr_${lpkey}.log'  !! "
		rsyncerrorlog "!! rsync error, check file 'rr_${lpkey}.log'"
		lv_return_project_loop=$_pRET
	fi
	if test $_pRET -eq $BK_ROTATE_FAILS
	then
		projecterrors[${_project}]="rsync error, check backup disk for errors  or data source: $lv_disklabel, $_project"
		dlog ""
		dlog " !! rotate error, check configuration for '$lv_disklabel', project: '$_project' !!)"
		dlog " !! rotate error, check disk for errors, maybe command 'mv' in history doesn't work correctly !!)"
		dlog " !! rotate error, check file 'aa_${lpkey}.log'  !! "
		dlog ""
		lv_return_project_loop=$_pRET
	fi
	if test $_pRET -eq $BK_ERRORINCOUNTERS
	then
		local perror1="retain error, one value is lower than 2, "
		local perror2="check configuration of retain values: $lv_disklabel $_project"
		projecterrors[${_project}]="${perror1}${perror2}"
		dlog " !! retain error, check configuration for $lv_disklabel $_project !!"
		dlog " !! retain error, check file 'rr_${lpkey}.log'  !! "
		lv_return_project_loop=$_pRET
	fi
	if test $_pRET -eq $BK_NORSNAPSHOTROOT
	then
		projecterrors[${_project}]="snapshot root folder doesn't exist, see log"
		dlog "snapshot root folder doesn't exist, see log"
		lv_return_project_loop=$_pRET
		#exit $BK_NORSNAPSHOTROOT
	fi

	projectdone=true
	if test $_pRET -ne 0
	then
		projectdone=false
		dlog "projectdone = false"
	fi

	if test "$projectdone" = "true"
	then
		# projectdone entry is written in bk_project.sh, 101 for archive

		dlog "=== ok, end of project '$_project',  disk: '$lv_label_displayname' ==="
		sendlog "HD: '$lv_label_displayname' mit Projekt '$_project' gelaufen, keine Fehler"
		# write success to a single file 

		# collect success for report at end of main loop
		# shorten label, if label ends with luks or disk
		var=$( strip_disk_or_luks_from_disklabel )
		lv_loop_successlist=( "${lv_loop_successlist[@]}" "${var}:$_project" )
		#dlog "successlist: $( echo ${lv_loop_successlist[@]} )"
	else
		if test $_pRET -eq $BK_RSYNCFAILS
		then
			# error in rsync
			lv_error_in_rsync=$BK_RSYNCFAILS
			dlog "error: disk '$lv_label_displayname', project '$_project'"
			sendlog "HD: '$lv_label_displayname' mit Projekt  '$_project' hatte Fehler"
			sendlog "siehe File: 'rr_${lv_disklabel}_$_project.log' im Backup-Server"
			# write unsuccess to a single file 
			# collect unsuccess for report at end of main loop
			var=$( strip_disk_or_luks_from_disklabel )
			lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${var}:$_project" )
			dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
		fi
		if test $_pRET -eq $BK_ROTATE_FAILS
		then
			# error in rsync
			lv_error_in_rsync=$BK_ROTATE_FAILS
			dlog "error: disk '$lv_label_displayname', project '$_project'"
			slogmsg1="HD: '$lv_label_displayname' mit Projekt  '$_project' hatte Fehler, "
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
		execute_project_end $lpkey
		local _RET=$?
		if [ $_RET -gt 0 ] 
		then
			dlog "execute_project_end: RET: '$_RET'"
			return $BK_PROJECT_END_FAILED
		fi
	fi

}


function execute_projects  {
	# in 'dirty_projects_array' are all projects, which need backup
	# do backup for each project

	dlog "execute projects in time: '${lv_dirty_projects_array[*]}'"

	#  e.g. conf/sdisk_start,sh
	# in conf folder
	# shell script, executed at start of disk
	execute_disk_begin ${lv_disklabel}
	local _RET=$?
	if [ $_RET -gt 0 ]
	then
		dlog "execute_disk_begin: RET: $_RET"
		return $_RET
	fi

	#if disk '$lv_disklabel' == sdisk, do snapshot
	# in 'lv_dirty_projects_array' are all projects to backup
	# call bk_project.sh for each
	for _project in "${lv_dirty_projects_array[@]}"
	do
		local lpkey=${lv_disklabel}_${_project}

		#dlog " second reachability check, first was in first loop"
		check_pre_host $lpkey
		local _ispre_exec_p=$?
		#dlog ""
		if test "$_ispre_exec_p" -eq 0
		then
			#dlog "host of project source exists"
			dlog ""
		else
			dlog "host of project source doesn't exist"
		fi

		if test "$_ispre_exec_p" -eq 0
		then
			# ret
			# BK_PROJECT_BEGIN_FAILED
			# BK_DISK_IS_NOT_SET_IN_CONF

			execute_project $_project
			local _RET=$?
			if [ $_RET -gt 0 ]
			then
				return $_RET
			fi
		else
			tlog "    in time: $_project, but unavailable"
			dlog "${_project} time reached, but source is unavailable"
		fi

	done
	#  end of  [ ! $lc_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
	# backup of all dirty project are done
	# if errors, these are logged
	# --

	# disk end
	# in conf folder
	# shell script, executed at end of disk
	execute_disk_end ${lv_disklabel}
	_RET=$?
	if [ $_RET -gt 0 ]
	then
		dlog "execute_disk_end: RET: $_RET"
		return $_RET
	fi	
	return 0
}


function dont_execute_project  {
	#   disk is full
	# don't do backup, disk is full
	# write to errorlist
	for _project in "${lv_dirty_projects_array[@]}"
	do
		# write unsuccess to a single file 
		# collect unsuccess for report at end of main loop
		local _var=$( strip_disk_or_luks_from_disklabel  )
		lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${_var}:$_project" )
		dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
	done
	dlog "---> don't execute projects: '${lv_dirty_projects_array[*]}', disk full"
	dlog "---> max allowed used space '${lc_maxdiskspacepercent}%' is lower than current used space '${lv_usedspacepercent}%', continue with next disk"
	# --
}


# end of functions	
# =======================================================

# start of code
init_local_variables
get_targetdisk
tlog "start: '$lv_label_displayname'"

show_loopstart_message

remove_old_notify_files

lookup_disk_by_uuid
# disk with label and uuid found in device list
# --
# uuid is in lv_disk_uuid


lookup_for_dirty_projects_and_show_timelines 

# if none of the  project needs a backup, return 'BK_TIMELIMITNOTREACHED'



# 'lv_dirty_projects_array' has some entries, process backup
# _length_nextprojects is > 0
lv_nr_dirty_projects=${#lv_dirty_projects_array[@]}

# test
# lv_dirtyprojectcount=

#dlog "vor test, BBBB,  lv_dirtyprojectcount=  '$lv_dirtyprojectcount',  lv_nr_dirty_projects= '$lv_nr_dirty_projects', lv_min_one_project_found= '$lv_min_one_project_found' "

# test: lv_nr_dirty_projects=0

#dlog " BBBB  lv_dirtyprojectcount=  '$lv_dirtyprojectcount',  lv_nr_dirty_projects= '$lv_nr_dirty_projects', lv_min_one_project_found= '$lv_min_one_project_found' "

if [ $lv_nr_dirty_projects -eq 0 ] && [ $lv_min_one_project_found -gt 0 ]
then
	dlog "fatal error, lv_nr_dirty_projects = 0 '$lv_nr_dirty_projects', and lv_min_one_project_found > 0 '$lv_min_one_project_found'"
	exit $BK_FATAL
fi

if [ $lv_min_one_project_found -eq 0 ]
then
	dlog "== end disk '$lv_disklabel', nothing to do =="
	dlog ""
	exit $BK_TIMELIMITNOTREACHED
fi

dlog "time limit for at least one project is reached"
dlog "found  projects: '${lv_dirty_projects_array[*]}'"
dlog ""

# start of backup

# ======== check mount, do backup, if ok ====
# - mount disk
# - do rsnapshot with bk_project.sh and bk_rsnapshot.sh
# - umount, if programmed or no /media/user disk 
#

# copy projectlist for return to bk_disks.sh via a file 
#  'tempfile_executedprojects.txt', used for for loopmessage at end 
if [ -f $bv_executedprojectsfile ]
then
	readonly lv_msg=$( cat $bv_executedprojectsfile )
	echo "$lv_msg, $lv_disklabel: ${lv_dirty_projects_array[*]}" > $bv_executedprojectsfile
else
	echo "$lv_disklabel: ${lv_dirty_projects_array[*]}" >  $bv_executedprojectsfile
fi

dlog "continue with test of mount state of disk: '$lv_targetdisk'"
dlog ""


tlog "mount: '$lv_mountpoint'"

# mount HD, mountfolder exists
# uses $lv_mountpoint, $lv_markerfolder, $lv_targetdisk, 
# exit, if disk coudln't mounted
mount_HD

# mount check and mount of backup disk is ready


# set lv_usedspacepercent
# set lv_diskfreespace
# set lv_usedspacepercent
refresh_used_free_space_percent $lv_mountpoint

dlog " --- free space: ${lv_diskfreespace_with_unit}, used space: ${lv_usedspacepercent}%, max allowed space '${lc_maxdiskspacepercent}%' "
dlog ""

# set lc_DISKFULL, to BK_FREEDISKSPACETOOSMALL, if limit is reached
check_disk_full


# set done to false
projectdone=false

lv_next_project_name=""


declare -A projecterrors
projecterrors=()
declare -a lv_loop_successlist
lv_loop_successlist=()
declare -a lv_loop_unsuccesslist
lv_loop_unsuccesslist=()

lv_return_project_loop="$BK_SUCCESS"

# do backup, if disk is not full
#   if disk is full, see else part
if [ ! $lc_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
then
	# disk has free space
	execute_projects 
	execute_projects_RET=$?
	#if [ $execute_projects_RET -eq $BK_DISK_IS_NOT_SET_IN_CONF ]
	#then
		#dlog "CCCC BK_DISK_IS_NOT_SET_IN_CONF (18): $BK_DISK_IS_NOT_SET_IN_CONF'"
	#fi
	# ret
	# BK_PROJECT_BEGIN_FAILED
	# BK_DISK_IS_NOT_SET_IN_CONF
else
	# disk is full
	dont_execute_project
fi

# all backups are done
# end of disk


# find min diff after backup ist done, done file exists here
# find next project in time line

find_next_project_to_do

# data must be obtained before disk is unmounted
# get lv_diskfreespace
# get lv_usedspacepercent
refresh_used_free_space_percent $lv_mountpoint


dlog ""
dlog " --- free space: ${lv_diskfreespace_with_unit}, used space: ${lv_usedspacepercent}%, max allowed space '${lc_maxdiskspacepercent}%' "
dlog ""

# clean up
notifyfilepostfix="keine_Fehler_alles_ok"

# umount backup disk, if configured in 'cfg.projects'

# check for umount of backup disk

if test -d $lv_markerfolder 
then
	_oldifs15=$IFS
	#IFS=','
	# loopkup with original label
	parray_lv_disklabel=${a_properties[$lv_disklabel]}

	umount_is_configured=$(echo ${parray_lv_disklabel[@]} | grep -w -o "umount" | wc -l )
	if test $umount_is_configured -eq 1 
	then
		# umount with targetdisk, not with original label
		lv_mountpoint=/mnt/$lv_targetdisk
		dlog "umount  $lv_mountpoint"
		./umount.sh  $lv_targetdisk
		_umount_RET=$?
		if test $_umount_RET -ne 0
		then
			msg="HD '$lv_targetdisk' wurde nicht korrekt getrennt, bitte nicht entfernen"
			dlog "$msg"
			sendlog $msg
			notifyfilepostfix="Fehler_HD_nicht_getrennt"
		else
			#rmdir  $mountfolder
			dlog "'$lv_label_displayname' all is ok"
			sendlog "HD '$lv_label_displayname': alles ist ok"

			nextdiff=$lv_min_wait_for_next_loop
			# if duration < next project, then use next project 'lv_next_project_diff_minutes' as next time
			if ((nextdiff < lv_next_project_diff_minutes ))
			then
				nextdiff=$lv_next_project_diff_minutes
			fi
			_encoded_diffstring_next_diff=$( encode_diff_to_string $nextdiff )
			sendlog "HD mit Label '$lv_label_displayname' kann in den nächsten '${_encoded_diffstring_next_diff}' Stunden:Minuten vom Server entfernt werden "
		fi

		# check, if really unmounted
		if [ -d $lv_markerfolder ]
		then
			dlog "disk is still mounted: '$lv_label_displayname', at: '$lv_mountpoint' "
			dlog ""
			dlog "'$lv_label_displayname' ist noch verbunden, umount error"
			sendlog "HD mit Label: '$lv_label_displayname' konnte nicht ausgehängt werden, bitte nicht entfernen"
			logdate=$( currentdate_for_log )
			sendlog "=======  $logdate  ======="
			notifyfilepostfix="HD_konnte_nicht_getrennt_werden_Fehler"
			
		fi
	else
		dlog "no umount configured, maybe this is a fixed disk  at $lv_mountpoint"
		dlog "next run of '$lv_next_project_name' in '${lv_next_project_diff_minutes}' minutes"
		sendlog "'umount' wurde nicht konfiguriert, HD '$lv_label_displayname' ist noch verbunden, at $lv_mountpoint"
	fi
else
	dlog "is local disk, no umount"
fi
dlog "== end of backup to disk '$lv_label_displayname' =="
dlog ""

# umount done, if configured
# write some messages to log

# write message to User-Desktop, if configured in 'cfg.ssh_login'


readonly encoded_diffstring_next_project=$( encode_diff_to_string $lv_next_project_diff_minutes )
readonly diff_unit=$( encode_diff_unit $lv_next_project_diff_minutes )
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
msg="HD mit Label '$lv_label_displayname', nächster Lauf eines Projektes ('$lv_next_project_name')"
sendlog "$msg"
msg="    für diese Backup-HD ist in: '${encoded_diffstring_next_project}' $printable_diff_unit"
sendlog "$msg"

# in cfg.projects
readonly waittimeinterval=$bv_globalwaittimeinterval
sendlog "waittime interval:  $waittimeinterval "

msg="freier Platz auf Backup-HD '$lv_label_displayname': $lv_diskfreespace, belegt: ${lv_usedspacepercent}%"
sendlog "$msg"


# check again, after backup
# read before umount in 'refresh_used_free_space_percent', line 1518 
if [ $lc_maxdiskspacepercent -lt $lv_usedspacepercent ]
then
	lc_DISKFULL=$BK_FREEDISKSPACETOOSMALL
fi

if [ $lc_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
then
	msg="!!!  Festplatte '$lv_label_displayname': ist voll, kein Backup mehr möglich. !!!"
	sendlog "$msg"
	notifyfilepostfix="Festplatte_ist_voll_kein_Backup_möglich"
fi

if [ $lc_CONNECTION_UNEXPECTEDLY_CLOSED -eq $BK_CONNECTION_UNEXPECTEDLY_CLOSED ]
then
	msg="Rsync: Verbindung abgebrochen, kein Backup möglich."
	sendlog "$msg"
	notifyfilepostfix="Rsync_Verbindung_abgebrochen"
	
fi

msg="max. reservierter Platz auf Backup-HD '$lv_label_displayname' in Prozent '${lc_maxdiskspacepercent}%'"
sendlog "$msg"

hour=$(date +%H)
TODAY3=$( currentdate_for_log )
sendlog "=======  $TODAY3  ======="


#  handle disk full error
if [ $lc_maxdiskspacepercent -lt $lv_usedspacepercent ]
then
	msg="max. reservierter Platz auf Backup-HD '$lv_label_displayname' in Prozent '${lc_maxdiskspacepercent}%'"
	dlog "$msg"
	projecterrors[------]="maximaler reservierter Platz auf der Backup-HD wurde überschritten: "
	projecterrors[-----]="   max erlaubter Platz '${lc_maxdiskspacepercent}%' ist kleiner als verwendeter Platz  '${lv_usedspacepercent}%'"
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
	if [ $lc_maxdiskspacepercent -lt $lv_usedspacepercent ]
	then
		dlog "allowed space of disk '${lc_maxdiskspacepercent}%' is lower than current free space '${lv_usedspacepercent}%'"
		notifyfilepostfix="Backup-HD_ist_zu_voll"
	else
		notifyfilepostfix="Fehler_in_Projekten"
	fi

	if test $lv_return_project_loop -eq $BK_RSYNCFAILS
	then
		notifyfilepostfix="Rsync_Fehler"
	fi
        if test $lv_return_project_loop -eq $BK_ROTATE_FAILS
        then
		notifyfilepostfix="Rotate_in_History_ist_vermutlich_nicht_ok"
        fi
        if test $lv_return_project_loop -eq $BK_ERRORINCOUNTERS
        then
		notifyfilepostfix="retain_Zähler_sind_nicht_ok"
        fi
        if test $lv_return_project_loop -eq $BK_NORSNAPSHOTROOT
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
echo ${lv_loop_successlist[@]} > $bv_successarray_tempfile

# write unsuccessarray to disk, read in 'bk_disks.sh'
echo ${lv_loop_unsuccesslist[@]} > $bv_unsuccessarray_tempfile

if test $lv_error_in_rsync -gt 0 
then
	tlog "end: fails, '$lv_label_displayname'"
	dlog "bk_loop fails, '$lv_label_displayname'"
	exit $lv_error_in_rsync
fi

tlog "bk_loop end: ok, label: '$lv_label_displayname'"
dlog "bk_loop end: ok, label: '$lv_label_displayname'"
exit $BK_SUCCESS

# end loop over projects for backup disk
# --


# EOF

