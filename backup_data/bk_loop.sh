#!/bin/bash


# file: bk_loop.sh
# bk_version 23.12.2

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

# call chain:
# ./bk_main.sh 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk, <- this file
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


# set -u, which will exit your script if you try to use an uninitialised variable.
#set -u
# found by 'set -u', but ok
# ./bk_loop.sh: line 111: a_waittime[${lpkey}]: unbound variable
# ./bk_loop.sh: line 111: a_waittime[${lpkey}]: unbound variable
# ./bk_loop.sh: line 111: a_waittime[${lpkey}]: unbound variable


# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_



. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_global_strings.sh
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
readonly lv_max_last_date="2023-12-15T00:00"

readonly lv_loop_test_return=$BK_LOOP_TEST_RETURN
readonly lv_loop_test=$bv_loop_test


# changed later, if lv_use_mediamount=0,  = use 
# check for folder 'marker' at mounted backup disk
lv_mountfolder=/mnt/$lv_disklabel
lv_markerfolder=$lv_mountfolder/marker

tlog "start: '$lv_disklabel'"


# bk_loop starts at line > 450



# check, get_projectwaittimeinterval() only for disk done 
# result is in, value is in hours
#       lv_loopwaittimestart
#       lv_loopwaittimeend
function get_projectwaittimeinterval {
        local _lpkey=$1
        local _waittime=${a_waittime[${_lpkey}]}

        # read configured values from cfg.projects
        lv_loopwaittimestart="09"
        lv_loopwaittimeend="09"

        if [[ $_waittime ]]
        then

                local _oldifs=$IFS
                IFS='-'
                local darr=($_waittime)
                IFS=$_oldifs
                if [ ${#darr[@]} = 2 ]
                then
                        lv_loopwaittimestart=${darr[0]}
                        lv_loopwaittimeend=${darr[1]}
                fi
        fi
}


function check_existence_of_arrays_in_cfg {
        local _arrays_ok=0
        if test ${#a_properties[@]} -eq 0 
        then
                dlog "Array 'a_properties' doesn't exMOUNTDIRt"
                arrays_ok=1
        fi
        if test ${#a_interval[@]} -eq 0 
        then
                dlog "Array 'a_interval' doesn't exist"
                arrays_ok=1
        fi
        if test ${#a_waittime[@]} -eq 0 
        then
                dlog "Array 'a_waittime' doesn't exist"
                # should be tolerated
                #arrays_ok=1
        fi
        return $_arrays_ok
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
        local _sec_old=$( date2seconds $_old )
        local _sec_new=$( date2seconds $_new)

        # convert to minutes
        local _minutes=$(( (_sec_new - _sec_old) / 60 ))
        if test $_minutes -lt 0 
        then
                dlog "done: diff is smaller then zero !!!!!!!!!!!!!!!!!!!!!!!!"
        fi
        echo "$_minutes"
}

function get_disk_uuid {
	local _disk_label=$1
#		https://unix.stackexchange.com/questions/60994/how-to-grep-lines-which-does-not-begin-with-or
#		How to grep lines which does not begin with “#” or “;”
#		local uuid=$( cat "uuid.txt" | grep  '^[[:blank:]]*[^[:blank:]#;]'  |  grep -w $_disk_label | awk '{print $2}' )
	local uuid=$( cat "uuid.txt" | grep -w $_disk_label | awk '{print $2}' )
	uuid=$( cat "uuid.txt" | grep -v '#' | grep -w $_disk_label | awk '{print $2}' )
#		better
#		uuid=$( gawk -v pattern="$_disk_label" '$1 ~ "(^|[[:blank:]])" pattern "([[:blank:]]|$)"  {print $NF}' uuid.txt )
	echo "$uuid"
}

# parameter: disklabel
# 0 = success
# 1 = error, disk not in uuid list
function check_disk_label {
	local _disk_label=$1
	#dlog "check_disk_label: $_disk_label "
	local uuid=$( get_disk_uuid $_disk_label  )

#	test, if symbolic link exists
	if test -L "/dev/disk/by-uuid/$uuid"
	then
		return 0
	fi
	return 1
}

# parameter: string with time value, dd:hh:mm 
# value in array: string with time value, dd:hh:mm 
#                                      or hh:mm 
#                                      or mm 
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
                # dd:hh:mm  - length 3
                _days=10#${_array[0]}
                _hours=10#${_array[1]}
                _minutes=10#${_array[2]}
                _result_minutes=$(( ( ( ${_days} * 24 )  * 60 + ${_hours} * 60  ) + ${_minutes} ))
        fi

        echo $_result_minutes

}

# par: 'disklabel_project'  in a_interval array
# value in array: string with time value, dd:hh:mm 
#                                      or hh:mm 
#                                      or mm 
# return:  minutes 
function decode_programmed_interval {
	local _lpkey=$1
	local _intervalvalue=${a_interval[${_lpkey}]}
	local _minutes=$( decode_pdiff_local ${_intervalvalue} )
	echo $_minutes
}


function encode_diff_to_string {

        # testday is in minutes
	local testday=$1
        local ret=""
        local is_negative=1 # = "false"

        if test $testday -lt "0"
        then
                testday=$(( $testday * (-1) ))
                is_negative=0     # = "true"
        fi

        # all in minutes
        local hour=60
        local day=$(( hour * 24 ))
        local days=$(( testday/day  ))

        local remainder=$(( testday - days*day   ))
        local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq "0"
        then
                if test $hours -eq "0"
                then
                        ret=$( printf "%02d"  $minutes )
                else
                        ret=$( printf "%02d:%02d"  $hours $minutes )
                fi
        else
                ret=$( printf "%02d:%02d:%02d"  $days $hours $minutes )
        fi

        # add minus sign, if negative 
        if test $is_negative -eq "0" # = "true" 
        then
                ret="-$ret"
        fi
        local lv_encoded_diff_var="$ret"
        echo "$lv_encoded_diff_var"

}

function encode_diff_unit {

        # testday is in minutes
        local testday=$1
        local ret=""

        local hour=60
        local day=$(( hour * 24 ))

        local days=$(( testday/day  ))
        local remainder=$(( testday - days*day   ))
        local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq "0"
        then
                if test $hours -eq 0
                then
                        ret="minutes"
                else
                        ret="hours"
                fi
        else
                ret="days"
        fi

        local lv_state="$ret"
        echo "$lv_state"
}


readonly PROJECT_DONE_REACHED=0
readonly PROJECT_DONE_NOT_REACHED=1
readonly PROJECT_DONE_WAITINTERVAL_REACHED=2


# par1 = disklabel_project_key
# 0 = success, reached
# 1 = not reched
# 2 = in project waittime interval
# called by check_disk_done()
function check_disk_done_last_done {
        local _lpkey=$1

        if [ $bv_test_no_check_disk_done -eq 1 ]
        then
                #dlog ""
                #dlog "    test mode, done is not checked"
                #dlog ""
                return $PROJECT_DONE_REACHED
        fi


        # format: YYYY-MM-DDThh:mm
        local _currenttime=$( currentdateT )
        local _done_file="./${bv_donefolder}/${_lpkey}_done.log"

        # format YYYY-mm-ddThh:mm
        local _last_done_time="$lv_max_last_date"
        #echo "last time: $_last_done_time"

        # get last line in done file
        if test -f $_done_file
        then
                _last_done_time=$(cat $_done_file | awk  'END {print }')
                if [ -z "$_last_done_time" ]
                then
                        _last_done_time="$lv_max_last_date"
                fi
        fi

        # here waittime check
        # check, get_projectwaittimeinterval() only for disk done 
        # result is in:   ( value is in hours )
        #       lv_loopwaittimestart
        #       lv_loopwaittimeend
        get_projectwaittimeinterval $_lpkey
        local hour=$(date +%H)
        local wstart=$lv_loopwaittimestart
        local wend=$lv_loopwaittimeend
        if [ "$hour" -ge "$wstart" ] && [ "$hour" -lt "$wend"  ] && [ $bv_test_use_minute_loop -eq 0 ]
        then
        #       dlog "PROJECT_DONE_WAITINTERVAL_REACHED"
                return $PROJECT_DONE_WAITINTERVAL_REACHED
        fi

        #dlog "_last_done_time: '$_last_done_time'"
        local _DIFF=$( time_diff_minutes  $_last_done_time  $_currenttime  )
        local _pdiff=$( decode_programmed_interval ${_lpkey} )

        if test $_DIFF -ge $_pdiff
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
# par 2 = projekt
# return: label shortened by 4 chars 
function strip_disk_or_luks_from_disklabel {
        local _disklabel=$1
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
function umount_media_folder(){
#       mmMTAB=$( cat /etc/mtab  |  grep media | grep $lv_disklabel )
#       e.g.
#       '/dev/mapper/luks-14fdf334-cdfd-4452-b4cf-358408339375 /media/rleo/h40luks btrfs rw,nosuid,nodev,relatime,space_cache,subvolid=5,subvol=/ 0 0'
        local mmMTAB=$1
        #dlog "is mounted at media: $mmMTAB"
        local mmMOUNT=$( echo "$mmMTAB" | awk '{ print $2 }' )
        dlog "try umount: $mmMOUNT"
        umount $mmMOUNT
        local mountRET=$?
        if [ "$mountRET" -ne 0 ]
        then
                dlog "umount fails: 'umount $mmMOUNT'"
                return $BK_DISKNOTUNMOUNTED
        fi


        # luksClose 
        local mmLUKSLABEL="$lv_disklabel"
        local mmMAPPERLABEL="/dev/mapper/$mmLUKSLABEL"
        dlog "try mapper with HD label: $mmMAPPERLABEL"
        if [  -L "$mmMAPPERLABEL" ]
        then
                dlog "luks mapper exists: $mmMAPPERLABEL"
                dlog "do luksClose:   cryptsetup luksClose $mmLUKSLABEL"
                cryptsetup luksClose $mmLUKSLABEL
#»      Error  codes are:·
#»      1 wrong parameters,·
#»      2 no permission (bad passphrase),·
#»      3 out of memory,·
#»      4 wrong device specified,·
#»      5 device already exists or device is busy.

        else
                dlog "luks mapper doesn't exist: $mmMAPPERLABEL"

        fi
        #dlog "in umount_media_folder: $lv_disklabel "
        mmuuid=$( get_disk_uuid $lv_disklabel  )
        mmLUKSLABEL="luks-$mmuuid"
        mmMAPPERLABEL="/dev/mapper/$mmLUKSLABEL"
        dlog "try mapper with uuid: $mmMAPPERLABEL"
        if [  -L "$mmMAPPERLABEL" ]
        then
                dlog "luks mapper exists: $mmMAPPERLABEL"
                dlog "do luksClose:   cryptsetup luksClose $mmLUKSLABEL"
                cryptsetup luksClose $mmLUKSLABEL
        fi
        return $BK_SUCCESS

}

# look up for next projekt in time
function find_next_project_to_do(){
        # set external vars to a start values
        lv_next_project_diff_minutes=10000
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
                local pdiff=$(decode_programmed_interval ${lpkey} )
                # get current delta after last done, in LASTLINE is date in %Y-%m-%dT%H:%M
                local tcurrent=$( currentdateT )
                local diff_since_last_backup=$(time_diff_minutes  $LASTLINE  $tcurrent  )
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

        local _file=$1
        local _disk=$2
        local _notifyfilepostfix=$3
        if [ ! -f $_file ] 
        then
                return 0
        fi

        local _logdate=$( currentdate_for_log )

	#                     Backup-HD_LABEL_date_postfix
	#           z.B.:     Backup-HD_cdisk_20221226-0244_keine_Fehler_alles_ok.log
        local _tempfilename="${bv_notifyfileprefix}_${_disk}_${_logdate}_${_notifyfilepostfix}.log"

        dlog "send notify message of disk '$_disk' to folder '${bv_backup_messages_testfolder}'"
        dlog "backup notify file: ${_tempfilename}"
        #cat $_file 
        cat $_file > $_tempfilename 
        dlog ""
        dlog "backup notify message"
        dlog ""
        local _oldifs1=$IFS
        IFS=$'\n'
        for _notifyline in $( cat  $_tempfilename ) 
        do
                dlog "$_notifyline"
        done
        IFS=$_oldifs1
        dlog ""

        dlog ""
        dlog "end of backup notify message"
        dlog ""

        # remove old file
	#dlog "rm ${bv_backup_messages_testfolder}/${bv_notifyfileprefix}_${_disk}_*"
	# rm ${bv_backup_messages_testfolder}/${bv_notifyfileprefix}_${_disk}_*

        # default,  copy to local folder

        local COMMAND="cp ${_tempfilename} ${bv_backup_messages_testfolder}/"
        dlog "copy notify file to local folder"
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

check_existence_of_arrays_in_cfg
arrays_ok=$?
if [ $arrays_ok -ne 0 ]
then
	dlog "error in property arrays"
	exit $BK_ARRAYSNOK
fi

dlog "===== process disk, label: '$lv_disklabel' ====="



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
dlog "-- UUID check: is HD '$lv_disklabel' connected to the PC?" 

# call 'check_disk_label'
check_disk_label $lv_disklabel
goodlink=$?
#dlog "after check_disk_label: $lv_disklabel "
uuid=$( get_disk_uuid $lv_disklabel  )

# disk must be in /dev/disk/by-uuid
# a USB disk must be connected
# mount is not necessary here, is checked and done later

if [[ $goodlink -eq 0 ]]
then
	dlog "-- UUID check: disk '$lv_disklabel' with UUID '$uuid' found in /dev/disk/by-uuid" 
	tlog "disk '$lv_disklabel' with UUID '$uuid' found" 
else
	dlog "-- UUID check: disk '$lv_disklabel' with UUID '$uuid' not found in /dev/disk/by-uuid, exit '$BK_DISKLABELNOTFOUND'" 
	tlog " disk '$lv_disklabel' with UUID '$uuid' not found " 
        exit $BK_DISKLABELNOTFOUND
fi
# disk with label and uuid found in device list
# --

# next is look up for dirty projects of this disk
# projects - last time ist later then project time interval 
# exit, if interval ist not set
readonly lv_disk_project_list=${a_projects[$lv_disklabel]}
dlog "-- disk '$lv_disklabel', check projects: '$lv_disk_project_list'"

# start of disk, disk is unmounted
# find, if interval is reached, if not, exit


declare -a lv_dirty_projects_array

# build list of last times for backup per projekt in disk
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
	check_disk_done $_lpkey 
	_project_done_state=$?

	# print disklabel to field of 14
	_disk_label_print=$( printf "%-19s\n"  $( echo "${_lpkey}" ) )


	_project_interval_minutes=$(  decode_programmed_interval ${_lpkey} )


	# 1. entry, last
	# diff = tcurrent - last_done_time,   in minutes
	_done_diff_minutes=$(   time_diff_minutes  "$_last_done_time"  "$_tcurrent"  )
	_encoded_diffstring1=$( encode_diff_to_string  $_done_diff_minutes )
	done_diff_print8=$( printf "%8s"  $_encoded_diffstring1 )

	# 2. entry, next
	deltadiff=$(( _project_interval_minutes - _done_diff_minutes ))
	delta_diff_print=$( printf "%6s\n"  $deltadiff )
	_encoded_diffstring2=$( encode_diff_to_string $delta_diff_print )
	next_diff_print9=$( printf "%9s\n"  $_encoded_diffstring2 )

	# 3. entry, programmed
	_encoded_diffstring3=$( encode_diff_to_string  $_project_interval_minutes )
	project_interval_minutes_print8=$( printf "%8s"  $_encoded_diffstring3 )

	# example: 01:15:32 last, next in    08:28,  programmed  02:00:00,  do nothing
	timeline=$( echo "$_disk_label_print   $done_diff_print8 last, next in $next_diff_print9,  programmed  $project_interval_minutes_print8," )

	# projectdone is reached, check reachability via check_pre_host
	if test $_project_done_state -eq $PROJECT_DONE_REACHED
	then
		# reached, if done_ 
		# - test $_DIFF -ge $_pdiff,          = wait time reached
		# - if [ $bv_test_no_check_disk_done -eq 1 ]  = 'bv_test_no_check_disk_done' is set
		# - if [ $do_once -eq 1 ]             = 'do_once' is set
		# check. if reachable, add to list 'lv_dirty_projects_array'
		_precondition=$bv_preconditionsfolder/${_lpkey}.pre.sh
		_ispre=1
		if test  -f $_precondition
		then
			check_pre_host $_lpkey
			_ispre=$?
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
				dlog "${timeline} reached, ok"
			fi
			lv_dirty_projects_array[lv_dirtyprojectcount]=$_project
			lv_dirtyprojectcount=$(( lv_dirtyprojectcount + 1 ))
			lv_min_one_project_found=1

		#	isdone=true
		else
			tlog "    in time: $_project, but unavailable"
			if [ "$bv_test_no_check_disk_done" -eq 1 ]
			then
				dlog "${timeline} reached, not available, test mode, done not checked"
			else
				dlog "${timeline} reached, not available"
			fi
		fi
	fi
	
	# normal projectdone not reached
	if test "$_project_done_state" -eq $PROJECT_DONE_NOT_REACHED
	then
		tlog "not in time: $_project"
		dlog "$timeline do nothing"
	fi

	# waittime interval reached
	if test "$_project_done_state" -eq $PROJECT_DONE_WAITINTERVAL_REACHED
	then
		tlog "in wait interval: $_project"
		dlog "$timeline wait,  from $lv_loopwaittimestart to $lv_loopwaittimeend"
	fi
	
done

# in 'dirty_projects_array' are all projects where we need a backup
# --
 
dlog ""


# if none of the  project needs a backup, return 'BK_TIMELIMITNOTREACHED'

if test $lv_min_one_project_found -eq 0
then
	dlog "== end disk '$lv_disklabel', nothing to do =="
	dlog ""
	exit $BK_TIMELIMITNOTREACHED
fi

# 'dirty_projects_array' has some entries, process backup
# _length_nextprojects is > 0
_length_nextprojects=${#lv_dirty_projects_array[@]}


# ======== check mount, do backup, if ok ====
# start of backup
# - mount disk
# - do rsnapshot with bk_project.sh and bk_rsnapshot.sh
# - umount, if programmmed or no /media/user disk 
#


# remove old notifyfiles in backup_messages_test
dlog "rm ${bv_backup_messages_testfolder}/${bv_notifyfileprefix}_${lv_disklabel}_*"
rm ${bv_backup_messages_testfolder}/${bv_notifyfileprefix}_${lv_disklabel}_*

dlog "time limit for at least one project is reached, projects: ${lv_dirty_projects_array[*]}"

# copy projectlist to bk_disks.sh via file 'executedprojectsfile.txt', for loopmessage at end only
if [ -f $bv_executedprojectsfile ]
then
	# add 'dirty_projects_array' to 'executedprojects.txt' at top of file
	lv__msg=$( cat $bv_executedprojectsfile )
	echo "$lv_msg, $lv_disklabel: ${lv_dirty_projects_array[*]}" > $bv_executedprojectsfile
else
	#dlog "filename2: executedprojects.txt"
	echo "$lv_disklabel: ${lv_dirty_projects_array[*]}" >  $bv_executedprojectsfile
fi

dlog " continue with test of mount state of disk: '$lv_disklabel'"
dlog ""

# check mountdir at /mnt
dlog "check mountdir"


# first, check mount at /media/user
#set +u
dlog "cat /etc/mtab  | grep media | grep $lv_disklabel  | awk '{ print \$2 }'"

#set -x

_mtab_mount_media=$( cat /etc/mtab  | grep media | grep $lv_disklabel  | awk '{ print $2 }')

#set -x
# if media mount exists, umount
if test  "$_mtab_mount_media" != ""
then
	dlog "mediamount exists: $_mtab_mount_media"

	# use media mount instead of /mnt?
	# 0 = use
	# 1 = don't use, eg. gt 0, use /mnt
	if test $lv_use_mediamount -gt 0  
	then
		# try to umount media folder
		#dlog "in mediamount exists: $lv_disklabel "
		mmuuid=$( get_disk_uuid $lv_disklabel  )

		mmMTAB=$( cat /etc/mtab  |  grep media | grep $lv_disklabel )
		if [ ! -z "$mmMTAB" ]
		then
			umount_media_folder "$mmMTAB"
			RET=$?
			if [ $RET -eq $BK_DISKNOTUNMOUNTED ]
			then
				exit $BK_DISKNOTUNMOUNTED
			fi
		else
			# check mount at /mnt
			mmMTAB=$( cat /etc/mtab  |  grep mnt | grep $lv_disklabel )
			if [ ! -z "$mmMTAB" ]
			then
				mmMOUNT=$( echo "$mmMTAB" | awk '{ print $2 }' )
				dlog "no mediamount with '$lv_disklabel', mountpoint is at: $mmMOUNT"
			fi
		fi
	else
		# ok use media folder
		# set new  lv_mountfolder
		dlog "media mount '$_mtab_mount_media' exists"
		lv_mountfolder=$_mtab_mount_media
		lv_markerfolder=$lv_mountfolder/marker
	fi
fi  

# unmount second, to close cryptsetup
mmuuid=$( get_disk_uuid $lv_disklabel  )
mmLUKSLABEL="luks-$mmuuid"
mmMAPPERLABEL="/dev/mapper/$mmLUKSLABEL"
#dlog "second try mapper with uuid: $mmMAPPERLABEL"
if [  -L "$mmMAPPERLABEL" ]
then
	dlog "luks mapper already exists: $mmMAPPERLABEL"
	dlog "do luksClose:   cryptsetup luksClose $mmLUKSLABEL"
	cryptsetup luksClose $mmLUKSLABEL
#	Error  codes are: 
#	1 wrong parameters, 
#	2 no permission (bad passphrase), 
#	3 out of memory, 
#	4 wrong device specified, 
#	5 device already exists or device is busy.
fi


#set -x

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
	dlog " -- HD '$lv_disklabel' is mounted at '$lv_mountfolder'"
else
	dlog " marker folder '$lv_markerfolder' doesn't exist, try mount" 
	./mount.sh $lv_disklabel 
	RET=$?
	if test $RET -ne 0
	then
		dlog " == end, couldn't mount disk '$lv_disklabel' to  '$lv_mountfolder', mount error =="
	fi
	
	# check, if ok, if not, then disk is not mounted
	if test ! -d $lv_markerfolder
	then
		dlog " mount,  markerdir '$lv_markerfolder' not found"
		dlog " == end, couldn't mount disk '$lv_disklabel' to  '$lv_mountfolder', no marker folder =="
		exit $BK_DISKNOTMOUNTED
	fi
fi

dlog " -- disk '$lv_disklabel' is mounted, marker folder '$lv_markerfolder' exists"

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
diskfreespace=$( df -h | grep -m1 -w $lv_disklabel | awk '{print $4}')

temp1=$( df -h | grep -m1 -w $lv_disklabel | awk '{print $5}')
# remove % char
temp2=${temp1%?}
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
	dlog "!!!  disk: '$lv_disklabel', max allowed used space '${maxdiskspacepercent}%' is lower than current used space '${usedspacepercent}%', continue with next disk !!!"
	dlog "---"
	LV_DISKFULL=$BK_FREEDISKSPACETOOSMALL
fi

dlog "---> free space: ${diskfreespace}, used space: ${usedspacepercent}%"

# done to false
# checked in 941
projectdone=false

lv_next_project_diff_minutes=10000
lv_next_project_name=""



declare -A projecterrors
declare -a lv_loop_successlist
declare -a lv_loop_unsuccesslist

PRET="0"

# do backup, if disk is not full
#   disk is full, see else part
if [ ! $LV_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
then
	# in 'dirty_projects_array' are all projects, which need backup
	# do backup for each project

	dlog "execute projects in time and with valid precondition check: ${lv_dirty_projects_array[*]}"
	disk_begin="$bv_conffolder/${lv_disklabel}_begin.sh"
	#  e.g. conf/sdisk_start,sh

	dlog "check for '$disk_begin' shell script"
	# in conf folder
	# shell script, executed at start of disk


	if test -f "$disk_begin" 
	then
		dlog "execute: '$disk_begin' "
		eval ./$disk_begin 
	else
		dlog "'$disk_begin' not found, no special function is executed at begin of disk"
	fi


	#if disk '$lv_disklabel' == sdisk, do snapshot

	# in 'dirty_projects_array' are all projects to backup
	# call bk_project for each
	for _project in "${lv_dirty_projects_array[@]}"
	do

		dlog ""
		lpkey=${lv_disklabel}_${_project}


		# check current time
		tcurrent=$( currentdateT )

		# second check, first was in first loop
		check_pre_host $lpkey
		_ispre=$?
		dlog "    check, if host of project exists (must be 0): $_ispre"

		if test "$_ispre" -eq 0
		then
			dlog "=== disk: '$lv_disklabel', start of project '$_project' ==="
			tlog "do: '$_project'"

			project_begin="$bv_conffolder/${lpkey}_begin.sh"
#			e.g. conf/sdisk_start,sh

			dlog "check for '$project_begin' shell script"
			# in conf folder
			# shell script, executed at start of disk
			if test -f "$project_begin"·
			then
				dlog "execute: '$project_begin' "
				eval ./$project_begin·
			else
				dlog "'$project_begin' not found, no special function is executed at begin of project"
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

			_temp15=$( df -h | grep -w $lv_disklabel | awk '{print $5}')
			_temp16=${_temp15%?}
			_used_space_percent=$_temp16
			#  handle disk full err
			# dlog "  $maxdiskspacepercent -lt $_used_space_percent "
			if [ $maxdiskspacepercent -lt $_used_space_percent ]
			then
				RET=$BK_DISKFULL
				#dlog "set RET to BK_DISKFULL, allowed space of disk '${maxdiskspacepercent}%' is lower than current free space '${_used_space_percent}%'"
			fi
			if test $RET -eq $BK_DISKFULL
			then
				projecterrors[${_project}]="rsync error, no space left on device, check harddisk usage: $lv_disklabel, $_project"
				dlog " !! no space left on device, check configuration for $lv_disklabel, $_project !!"
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

			        dlog "all ok, disk: '$lv_disklabel', project '$_project'"
				sendlog "HD: '$lv_disklabel' mit Projekt '$_project' gelaufen, keine Fehler"
				# write success to a single file 

				# collect success for report at end of main loop
				# shorten label, if label ends with luks or disk
				var=$( strip_disk_or_luks_from_disklabel ${lv_disklabel} )
				lv_loop_successlist=( "${lv_loop_successlist[@]}" "${var}:$_project" )
				dlog "successlist: $( echo ${lv_loop_successlist[@]} )"
			else
				if test $RET -eq $BK_RSYNCFAILS
				then
					# error in rsync
					error_in_rsync=$BK_RSYNCFAILS
					dlog "error: disk '$lv_disklabel', project '$_project'"
					sendlog "HD: '$lv_disklabel' mit Projekt  '$_project' hatte Fehler"
					sendlog "siehe File: 'rr_${lv_disklabel}_$_project.log' im Backup-Server"
					errorlog "HD: '$lv_disklabel' mit Projekt  '$_project' hatte Fehler" 

					# write unsuccess to a single file 
					# collect unsuccess for report at end of main loop
					var=$( strip_disk_or_luks_from_disklabel ${lv_disklabel} )
					lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${var}:$_project" )
					dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
				fi
				if test $RET -eq $BK_ROTATE_FAILS
				then
					# error in rsync
					error_in_rsync=$BK_ROTATE_FAILS
					dlog "error: disk '$lv_disklabel', project '$_project'"
					slogmsg1="HD: '$lv_disklabel' mit Projekt  '$_project' hatte Fehler, "
					slogmsg2="rotate in history kann falsch sein, prüfe Backup-Festplatte mit 'fsck'"
					sendlog "${slogmsg1}${slogmsg2}"
					sendlog "siehe File: 'aa_${lv_disklabel}_$_project.log' im Backup-Server"
					errorlog "HD: '$lv_disklabel' mit Projekt  '$_project' hatte Fehler" 

					# write unsuccess to a single file 
					# collect unsuccess for report at end of main loop
					var=$( strip_disk_or_luks_from_disklabel ${lv_disklabel} )
					lv_loop_unsuccesslist=( "${lv_loop_unsuccesslist[@]}" "${var}:$_project" )
					dlog "unsuccesslist: $( echo ${lv_loop_unsuccesslist[@]} )"
				fi
			fi
			project_end="$bv_conffolder/${lpkey}_end.sh"
			dlog "check for '$project_end' shell script"
			# in conf folder
			# shell script, executed at end of disk

			if test -f "$project_end" 
			then
				dlog "execute: '$project_end', "
				eval ./$project_end 
			else
				dlog "'$project_end' not found, no special function is executed at end of project"
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

	disk_end="$bv_conffolder/${lv_disklabel}_end.sh"
	dlog ""
	dlog "check for '$disk_end' shell script"
	# in conf folder
	# shell script, executed at end of disk

	if test -f "$disk_end" 
	then
		dlog "execute: '$disk_end', "
		
		eval ./$disk_end 
	else
		dlog "'$disk_end' not found, no special function is executed at end of disk"
	fi


else
	#   disk is full
	# don't do backup, disk is full
	# write to errorlist
	for _project in "${lv_dirty_projects_array[@]}"
	do
		# write unsuccess to a single file 
		# collect unsuccess for report at end of main loop
		var=$( strip_disk_or_luks_from_disklabel ${lv_disklabel} )
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

readonly used_space_temp=$( df -h | grep -m1 -w $lv_disklabel | awk '{print $5}')
# remove % sign 
usedspacepercent=${used_space_temp%?}
diskfreespace=$( df -h /dev/disk/by-label/$lv_disklabel | grep -m1 -w $lv_disklabel | awk '{print $4}')

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
	#IFS=$_oldifs15

	umount_is_configured=$(echo ${parray[@]} | grep -w -o "umount" | wc -l )
	if test $umount_is_configured -eq 1 
	then
		dlog "umount  $lv_mountfolder"
		./umount.sh  $lv_disklabel
		RET=$?
		if test $RET -ne 0
		then
			msg="HD '$lv_disklabel' wurde nicht korrekt getrennt, bitte nicht entfernen"
			dlog "$msg"
			sendlog $msg
			notifyfilepostfix="Fehler_HD_nicht_getrennt"
		else
			#rmdir  $mountfolder
			dlog "'$lv_disklabel' all is ok"
			sendlog "HD '$lv_disklabel': alles ist ok"

			# set in cfg.loop_time_duration
			nextdiff=$MIN_WAIT_FOR_NEXT_LOOP
			# if duration < next project, then use next project 'lv_next_project_diff_minutes' as next time
			if ((nextdiff < lv_next_project_diff_minutes ))
			then
				nextdiff=$lv_next_project_diff_minutes
			fi
			_encoded_diffstring_next_diff=$( encode_diff_to_string $nextdiff )
			sendlog "HD mit Label '$lv_disklabel' kann in den nächsten '${_encoded_diffstring_next_diff}' Stunden:Minuten vom Server entfernt werden "
		fi

		# check, if really unmounted
		if [ -d $lv_markerfolder ]
		then
			dlog "disk is still mounted: '$lv_disklabel', at: '$lv_mountfolder' "
			dlog ""
			dlog "'$lv_disklabel' ist noch verbunden, umount error"
			sendlog "HD mit Label: '$lv_disklabel' konnte nicht ausgehängt werden, bitte nicht entfernen"
			logdate=$( currentdate_for_log )
			sendlog "=======  $logdate  ======="
			notifyfilepostfix="HD_konnte_nicht_getrennt_werden_Fehler"
			
		fi
	else
		dlog "no umount configured, maybe this is a fixed disk  at $lv_mountfolder"
		dlog "next run of '$lv_next_project_name' in '${lv_next_project_diff_minutes}' minutes"
		sendlog "'umount' wurde nicht konfiguriert, HD '$lv_disklabel' ist noch verbunden, at $lv_mountfolder"
	fi
else
	dlog "is local disk, no umount"
fi

# umount, if configured,  is ready

# --

# write some messages to log



# write message to User-Desktop, if configured in 'cfg.ssh_login'

dlog "== end of backup to disk '$lv_disklabel' =="
dlog ""

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

# change to full message
msg="HD mit Label '$lv_disklabel', nächster Lauf eines Projektes ('$lv_next_project_name')  für diese Backup-HD ist in '${lv_encoded_diffstring_next_project}' $printable_diff_unit"
sendlog "$msg"

sendlog "waittime interval:  $waittimeinterval "


msg="freier Platz auf Backup-HD '$lv_disklabel': $diskfreespace, belegt: ${usedspacepercent}%"
dlog "$msg"
sendlog "$msg"

# check again, after backup
if [ $maxdiskspacepercent -lt $usedspacepercent ]
then
	LV_DISKFULL=$BK_FREEDISKSPACETOOSMALL
fi



if [ $LV_DISKFULL -eq $BK_FREEDISKSPACETOOSMALL ]
then
	msg="!!!  Festplatte '$lv_disklabel': ist voll, kein Backup mehr möglich. !!!"
	sendlog "$msg"
	notifyfilepostfix="Festplatte_ist_voll_kein_Backup_möglich"
	
fi
if [ $LV_CONNECTION_UNEXPECTEDLY_CLOSED -eq $BK_CONNECTION_UNEXPECTEDLY_CLOSED ]
then
	msg="Rsync: Verbindung abgebrochen, kein Backup möglich."
	sendlog "$msg"
	notifyfilepostfix="Rsync_Verbindung_abgebrochen"
	
fi


msg="max. reservierter Platz auf Backup-HD '$lv_disklabel' in Prozent '${maxdiskspacepercent}%'"
sendlog "$msg"


hour=$(date +%H)
TODAY3=$( currentdate_for_log )
sendlog "=======  $TODAY3  ======="


#  handle disk full err
if [ $maxdiskspacepercent -lt $usedspacepercent ]
then
	msg="max. reservierter Platz auf Backup-HD '$lv_disklabel' in Prozent '${maxdiskspacepercent}%'"
	dlog "$msg"
	projecterrors[------]="maximaler reservierter Platz auf der Backup-HD wurde überschritten: "
	projecterrors[-----]="   max erlaubter Platz '${maxdiskspacepercent}%' ist kleiner als verwendeter Platz  '${usedspacepercent}%'"
fi


# x replaces projecterrors, if not empty,  and testet
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
sshnotifysend_bk_loop $lv_notifysendlog $lv_disklabel $notifyfilepostfix 

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
# write unsuccessarray, read again  in 'bk_disks.sh'
echo ${lv_loop_unsuccesslist[@]} > $bv_unsuccessarray_tempfile

if test $error_in_rsync -gt 0 
then
	tlog "end: fails, '$lv_disklabel'"
	dlog "bk_loop fails, '$lv_disklabel'"
	exit $error_in_rsync
fi

tlog "end: ok,    '$lv_disklabel'"
dlog "bk_loop end: ok,    '$lv_disklabel'"
exit $BK_SUCCESS

# end loop over projects for backup disk
# --


# EOF

