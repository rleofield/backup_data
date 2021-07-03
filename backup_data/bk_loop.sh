#!/bin/bash


# file: bk_loop.sh
# bk_version 21.05.1

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

# call chain:
# ./bk_main.sh 
#	./bk_disks.sh,   all disks
#		./bk_loop.sh	all projects in disk, <- this file
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


# comment: delete 
# comment:   rm retains_count/*
# comment:   rm done/*
# comment: before first use


. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./cfg.working_folder

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_log.sh
. ./src_ssh.sh
. ./src_global_strings.sh
#. ./src_folders.sh


TODAY=`date +%Y-%m-%dT%H:%M`
readonly LABEL=$1

if [ -z $LABEL ]
then
	exit 1;
fi

# use media mount '/media/user/label' instead of '/mnt/label'
# 0 = use
# 1 = don't use, use /mnt
# default=1, don't use
# 1, if PL
# 1, if HS
readonly use_mediamount=1

arrays_ok=0
readonly OPERATION="loop"
readonly FILENAME="$LABEL:${OPERATION}"

tlog "start: '$LABEL'"


if test ${#a_properties[@]} -eq 0 
then
	dlog "Array 'a_properties' doesn't exist"
	arrays_ok=1
fi
if test ${#a_projects[@]} -eq 0 
then
	dlog "Array 'a_projects' doesn't exist"
	arrays_ok=1
fi
if test ${#a_interval[@]} -eq 0 
then
	dlog "Array 'a_interval' doesn't exist"
	arrays_ok=1
fi
if test "$arrays_ok" -eq "1" 
then
	exit $ARRAYSNOK
fi

# changed later, if use_mediamount=0,  = use 
MOUNTDIR=/mnt/$LABEL
MARKERDIR=$MOUNTDIR/marker

# set. if rsync fails with '$RSYNCFAILS' 
error_in_rsync=0

readonly properties=${a_properties[$LABEL]}


dlog ""
dlog "===== process disk, label: '$LABEL' ====="
readonly oldifs=$IFS
IFS=','
parray=($properties)
IFS=$oldifs
readonly ausgabe=$( echo ${parray[@]} )

# not used
# used for future ideas
local_in_array=0

if test $local_in_array -eq 1
then
	dlog "label: '$LABEL'  "
	dlog "properties: '$ausgabe',  'local' is set in properties: '$local_in_array' = 1  (local disks only)"
fi


readonly NOTIFYSENDLOG="notifysend.log"

# now in src_filenames.sh
#readonly notifybasefile="Backup-HD"

readonly successlogtxt="successlog.txt"
readonly maxLASTDATE="2021-03-01T00:00"


function sendlog {
        local msg=$1
        echo -e "$_TODAY  == Notiz: $msg" >> $NOTIFYSENDLOG
}


function sshnotifysend {
        local _disk=$1
        local _ok=$2

        if [ ! -f $NOTIFYSENDLOG ] 
        then
		return 0
	fi

        local _TODAY=`date +%Y%m%d-%H%M`
        local temp="${notifybasefile}_${_disk}_${_TODAY}_${_ok}.log"
        dlog "    send message of disk: '$_disk'"
        dlog "tempfile: ${temp}"
        $( cat $NOTIFYSENDLOG > $temp )


	# default,  copy to local folder
        COMMAND="cp $temp backup_messages_test/"
        dlog "copy notify file to local folder: $COMMAND"
        eval $COMMAND
        rm $temp

}


# par1 = old   (yyyy-mm-ddThh:mm) or (yyyy-mm-ddThh:mm:ss)
# par2 = new
# diff = new - old,   in minutes
# minutes for
#      h = 60, d = 1440, w=10080, m=43800, y=525600
# parameter: dateold, datenew in date format
function time_diff_minutes() {
        local old=$1
        local new=$2
	#dlog "tdiff old: $old"
	#dlog "tdiff new: $new"
        # convert the date "1970-01-01 hour:min:00" in seconds from Unix Date Stamp to seconds
        # "1980-01-01 00:00"
        local sec_old=$(date +%s -d $old)
        local sec_new=$(date +%s -d $new)
	#dlog "sec old: $sec_old"
	#dlog "sec new: $sec_new"
	# convert to minutes
	ret=$(( (sec_new - sec_old) / 60 ))
	if test $ret -lt 0 
	then
		dlog "done diff ist kleiner als Null !!!!!!!!!!!!!!!!!!!!!!!!"
	fi
        echo "$ret"
}


# parameter: disklabel
# 0 = success
# 1 = error, disk not in uuid list
function check_disk_label {
        local _LABEL=$1
        if test $local_in_array -eq 1
	then
	#	dlog "return 0, array"
        	return 0
	else
		local uuid=$( cat "uuid.txt" | grep -w $_LABEL | awk '{print $2}' )
		# local uuid=$( gawk -v pattern="$_LABEL" '$1 ~ pattern  {print $NF}' uuid.txt )
		# better
		# uuid=$( gawk -v pattern="$_LABEL" '$1 ~ "(^|[[:blank:]])" pattern "([[:blank:]]|$)"  {print $NF}' uuid.txt )
		# echo "uuid: $uuid"
	        # test, if symbolic link
        #	dlog "if test -L /dev/disk/by-uuid/$uuid"
        	if test -L "/dev/disk/by-uuid/$uuid"
	        then
	#		dlog "return 0"
			return 0
	        fi
	fi
	#		dlog "return 1"
        return 1
}

# parameter: string with time value, dd:hh:mm 
# return:    minutes
function decode_pdiff_local {
	local v=$1
	local _oldifs=$IFS
	IFS=':' 

	local a=($v)
	local l=${#a[@]}

	# mm only
	local r_=${a[0]}
	if test $l -eq 2 
	then
		# hh:mm
        	r_=$(( ( ${a[0]} * 60 ) + ${a[1]} ))
	fi
        if test $l -eq 3
        then
		# dd:hh:mm
                r_=$(( ( ( ${a[0]} * 24 )  * 60 + ${a[1]} * 60  ) + ${a[2]} ))
        fi

	IFS=$_oldifs
	echo $r_

}

# parameter is key=label_project  in a_interval array
# return projekt interval in minutes 
function decode_pdiff {
	local _key=$1
	local _interval=${a_interval[${_key}]}
        local _r2=$( decode_pdiff_local ${_interval} )
	#local bb=$( ./cpp/rs_cpp_decode_pdiff ${_interval} )
	#dlog "interval: $_interval"
	#dlog "pdiff old: $_r2"
	#dlog "new: $bb"
        echo $_r2
        #echo $bb
}

encode_diff_var=""
encode_state=""

function encode_diff {

	# testday is in minutes
        local testday=$1
	local ret=""
	local negativ="false"
	#bb=$(  ./cpp/rs_cpp_encode_pdiff ${testday}  )


	#dlog " encode_diff, testday: $testday"
	if test $testday -lt 0
	then
		#datelog "${FILENAME}: is negative '$testday'"
		testday=$(( $testday * (-1) ))
		negativ="true"
	fi

        local hour=60
        local day=$(( hour * 24 ))
	local days=$(( testday/day  ))
        local remainder=$(( testday - days*day   ))
	local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq 0
	then
    	  	if test $hours -eq 0
        	then
                        ret=$minutes
			encode_state="minutes"
		else
			ret=$( printf "%02d:%02d"  $hours $minutes )
			encode_state="hours"
		fi
	else
		ret=$( printf "%02d:%02d:%02d"  $days $hours $minutes )
		encode_state="days"
	fi

	# add minus sign, if negative 
	if test "$negativ" = "true" 
	then
		ret="-$ret"
	fi	
	#dlog "bb:  $bb"
        encode_diff_var="$ret"
}

# parameter
# $1 = Disklabel
# $2 = Projekt
# return 0, 1, 2, 3  
# 0 = success, no daytime
# 1 = error
# done in main
# 	2 = daytime not reached
# 	3 = reached, but daytime

readonly DONE_REACHED=0
readonly DONE_NOT_REACHED=1
DONE_TEST_MODE=0

function check_disk_done_last_done {

	if [ $no_check_disk_done -eq 1 ]
	then
		#dlog ""
		#dlog "    test mode, done is not checked"
		#dlog ""
		DONE_TEST_MODE=1
		return $DONE_REACHED
	fi

	local _lpkey=$1

	local _LASTLINE=""
	local _current=`date +%Y-%m-%dT%H:%M`

	# 0 = success, backup was done
	# 1 = error
	local _DONEFILE="./${donefolder}/${_lpkey}_done.log"
	#dlog "DONEFILE: '$_DONEFILE'"
	local _LASTLINE=""
	#echo "in function check_disk_done "
	_LASTLINE="$maxLASTDATE"

	if test -f $_DONEFILE
	then
		_LASTLINE=$(cat $_DONEFILE | awk  'END {print }')
	fi

	#dlog "_LASTLINE: '$_LASTLINE'"
	if [ -z "$_LASTLINE" ]
	then
		_LASTLINE="$maxLASTDATE"
	fi
	#dlog "_LASTLINE: '$_LASTLINE'"
	local _DIFF=$(time_diff_minutes  $_LASTLINE  $_current  )
	local _pdiff=$( decode_pdiff ${_lpkey} )

	#dlog "if test _DIFF -ge _pdiff"
	#dlog "if test $_DIFF -ge $_pdiff"

	if test $_DIFF -ge $_pdiff
	then
		# diff was greater than reference, take as success
		# diff was greater than reference, take as success
		#dlog "'$_DIFF' -ge '$_pdiff'  check_disk_done_last_done, done reached"
		return $DONE_REACHED
	fi
	return $DONE_NOT_REACHED
}


# 0 = success, reached
# 1 = not reched
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
# 0 - ok
# 1 - nok, host or disk doesn't exist, ssh login wrong
function check_pre_host {

        local _LABEL=$1
        local _p=$2

        local _precondition=pre/${_LABEL}_${_p}.pre.sh

        if [[  -f $_precondition ]]
        then
                eval $_precondition
                _RET=$?
                if [ $_RET -ne 0 ]
                then
                        return 1
                else
			# ok
                        return 0
                fi
        fi
	# ok, file doesn't exist
        return 0
}



# remove intermediate files
# readonly NOTIFYSENDLOG="notifysend.log"
if test -f $NOTIFYSENDLOG
then
	rm $NOTIFYSENDLOG
fi


dlog "-- UUID check: is HD '$LABEL' connected to the PC?" 

# call 'check_disk_label'
check_disk_label $LABEL
goodlink=$?

uuid=$( cat "uuid.txt" | grep -w $LABEL | awk '{print $2}' )
label_not_found_file="label_not_found.log"
label_not_found_date=`date +%Y%m%d-%H%M`
if [[ $goodlink -eq 0 ]]
then
	dlog "-- UUID check: disk '$LABEL' with UUID '$uuid' found in /dev/disk/by-uuid" 
	tlog "disk '$LABEL' with UUID '$uuid' found" 
#	echo "$label_not_found_date: disk '$LABEL' with UUID '$uuid' found in '/dev/disk/by-uuid'" >> $label_not_found_file
else
	dlog "-- UUID check: disk '$LABEL' with UUID '$uuid' not found in /dev/disk/by-uuid, exit '$DISKLABELNOTFOUND'" 
	tlog " disk '$LABEL' with UUID '$uuid' not found " 
	echo "$label_not_found_date: disk '$LABEL' with UUID '$uuid' not found in '/dev/disk/by-uuid', exit '$DISKLABELNOTFOUND'" >> $label_not_found_file
        exit $DISKLABELNOTFOUND
fi



PROJEKTLABELS=${a_projects[$LABEL]}

dlog "-- disk '$LABEL', check projects: '$PROJEKTLABELS'"

# start of disk, disk is unmounted

# find, if interval is reached, if not exit

ispre=1
declare -a nextprojects

# build list of last times for backup per projekt in disk
# don't check the disk, this is later
dlog "               dd:hh:mm                 dd:hh:mm               dd:hh:mm"
pcount=0
for p in $PROJEKTLABELS
do
	lpkey=${LABEL}_${p}

	l_interval=${a_interval[${lpkey}]}
	if [ -z "$l_interval" ]
	then
		dlog "ERROR: in 'cfg.projects' in array 'a_interval', '$lpkey' is not set, "
		exit $NOINTERVALSET
	fi
	
	tcurrent=`date +%Y-%m-%dT%H:%M`
	DONE_FILE="./${donefolder}/${lpkey}_done.log"
	LASTLINE=$maxLASTDATE
	if test -f $DONE_FILE 
	then
		# last line in done file
		LASTLINE=$(cat $DONE_FILE | awk  'END {print }')  	
	fi
	#dlog "_LASTLINE 2222: '$_LASTLINE'"
	if [ -z "$_LASTLINE" ]
	then
        	_LASTLINE="$maxLASTDATE"
	fi

	pdiff=$(  decode_pdiff ${lpkey} )
	done_diff_minutes=$(   time_diff_minutes  "$LASTLINE"  "$tcurrent"  )
	deltadiff=$(( pdiff - done_diff_minutes ))

	# ret , 0 = do backup, 1 = interval not reached, 2 = daytime not reached

	DONE_TEST_MODE=0
	check_disk_done $lpkey 
	RET=$?
	#dlog "DONE_TEST_MODE: $DONE_TEST_MODE"
	DISKDONE=$RET
	# test only
	#dlog "PROJECT: ${p}"
	txt=$( printf "%-12s\n"  $( echo "${p}," ) )
	n0=$( printf "%5s\n"  $done_diff_minutes )
	pdiff_print=$( printf "%5s\n"  $pdiff )
	ndelta=$( printf "%6s\n"  $deltadiff )

	encode_diff $ndelta
	fndelta=$encode_diff_var 
	fndelta=$( printf "%8s\n"  $fndelta )
	encode_diff  $n0
	fn0=$encode_diff_var
	fn0=$( printf "%8s"  $fn0 )
	encode_diff  $pdiff_print 
	pdiff_minutes_print=$encode_diff_var
	pdiff_minutes_print=$( printf "%8s"  $pdiff_minutes_print )

	#dlog "if test DISKDONE -eq DONE_REACHED"
	timeline=$( echo "$txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print," )
	if test $DISKDONE -eq $DONE_REACHED
	then
		# reached, if done_ 
		# - test $_DIFF -ge $_pdiff,          = wait time reached
		# - if [ $no_check_disk_done -eq 1 ]  = 'no_check_disk_done' is set
		# - if [ $do_once -eq 1 ]             = 'do_once' is set
		# check. if reachable, add to list 'nextprojects'
		check_pre_host $LABEL $p 
		ispre=$?
		if test $ispre -eq 0
		then
			tlog "    in time: $p"
			# all is ok,  do backup	
			if [ $DONE_TEST_MODE -eq 1 ]
			then
				dlog "${timeline} reached, source is ok, test mode, done not checked"
			else
				dlog "${timeline} reached, source is ok"
			fi
			nextprojects[pcount]=$p
			pcount=$(( pcount + 1 ))
		#	isdone=true
		else
			tlog "    in time: $p, but unavailable"
			if [ $DONE_TEST_MODE -eq 1 ]
			then
				dlog "${timeline} reached, but source is not available, test mode, done not checked"
			else
				dlog "${timeline} reached, but source is not available"
			fi
		fi
	fi
	if test "$DISKDONE" -eq $DONE_NOT_REACHED
	then
		tlog "not in time: $p"
		dlog "$timeline do nothing"
	fi
	DONE_TEST_MODE=0

done

# in 'nextprojects' are all projects where we need a backup
# if no project needs backup, return
lnextprojects=${#nextprojects[@]}

if test $lnextprojects -eq 0
then
	datelog "${FILENAME}: == end disk '$LABEL', nothing to do =="
	datelog "${FILENAME}:"
	exit $TIMELIMITNOTREACHED
fi

# ======== check mount, do backup if ok ====
# start of backup
# - mount disk
# - do rsnapshot with bk_project.sh and bk_rsnapshot.sh
# - umount, if programmmed or no /media/user disk 
#

# remove old notifyfiles in backup_messages_test
dlog "rm backup_messages_test/${notifybasefile}_${LABEL}_*"
rm backup_messages_test/${notifybasefile}_${LABEL}_*



#datelog "${FILENAME}:  next projects: ${nextprojects[*]}"
dlog "time limit for at least one project is reached, projects: ${nextprojects[*]}"

if [ -f $executedprojects ]
then
	_msg=$( cat $executedprojects )
	echo "$_msg, $LABEL: ${nextprojects[*]}" > $executedprojects
else
	echo "$LABEL: ${nextprojects[*]}" >  $executedprojects
fi
dlog " continue with test of mount state of disk: '$LABEL'"
dlog ""

# no 'local' in a_properties check disk against uuid and mount 
if test $local_in_array -eq 0
then

	# check mountdir at /mnt
	dlog "check mountdir"


	# first, check mount at /media/user
	dlog "cat /etc/mtab  | grep media | grep $LABEL  | awk '{ print $2 }'"

	MEDIAMOUNT=$( cat /etc/mtab  | grep media | grep $LABEL  | awk '{ print $2 }')
	if test  "$MEDIAMOUNT" != ""
	then
		dlog "mediamount exists: $MEDIAMOUNT"

		# use media mount instead of /mnt
		# 0 = use
		# 1 = don't use, eg. gt 0, use /mnt
		if test $use_mediamount -gt 0  
		then
			# try to umount media folder
			mmuuid=$( cat "uuid.txt" | grep -w $LABEL | awk '{print $2}' )
			mmMTAB=$( cat /etc/mtab  |  grep media | grep $LABEL )
			if [ ! -z "$mmMTAB" ]
			then
				dlog "is mounted at media: $mmMTAB"
				mmMOUNT=$( echo "$mmMTAB" | awk '{ print $2 }' )
				dlog "try umount: $mmMOUNT"
				umount $mmMOUNT
				mountRET=$?
				if [ "$mountRET" -ne 0 ]
				then
					dlog "umount fails: 'umount $mmMOUNT'"
					exit $DISKNOTUNMOUNTED
				fi

				mmLUKSLABEL="$LABEL"
				mmMAPPERLABEL="/dev/mapper/$mmLUKSLABEL"
				dlog "try mapper with HD label: $mmMAPPERLABEL"
				if [  -L "$mmMAPPERLABEL" ]
				then
					dlog "luks mapper exists: $mmMAPPERLABEL"
					dlog "do luksClose:   cryptsetup luksClose $mmLUKSLABEL"
					cryptsetup luksClose $mmLUKSLABEL
				else
					dlog "luks mapper doesn't exist: $mmMAPPERLABEL"

				fi
				mmLUKSLABEL="luks-$mmuuid"
				mmMAPPERLABEL="/dev/mapper/$mmLUKSLABEL"
				dlog "try mapper with uuid: $mmMAPPERLABEL"
				if [  -L "$mmMAPPERLABEL" ]
				then
					dlog "luks mapper exists: $mmMAPPERLABEL"
					dlog "do luksClose:   cryptsetup luksClose $mmLUKSLABEL"
					cryptsetup luksClose $mmLUKSLABEL
				fi
			else
				# check mount at /mnt
				mmMTAB=$( cat /etc/mtab  |  grep mnt | grep $LABEL )
				if [ ! -z "$mmMTAB" ]
				then
					mmMOUNT=$( echo "$mmMTAB" | awk '{ print $2 }' )
					dlog "no mediamount with '$LABEL', mountpoint ia at: $MOUNT"
				fi
			fi
		else
			# ok use media folder
			datelog "media mount '$MEDIAMOUNT' exists"
			MOUNTDIR=$MEDIAMOUNT
			MARKERDIR=$MOUNTDIR/marker
		fi
	# if test  "$MEDIAMOUNT" != ""
	fi  

	# is /mnt, if media folder not found
	tlog "mount: '$MOUNTDIR'"
	dlog "mount folder   '$MOUNTDIR'" 
	dlog "marker folder  '$MARKERDIR'" 

	if test ! -d $MOUNTDIR 
	then
       		dlog " mount folder  '$MOUNTDIR' doesn't exist" 
	        exit $MOUNTDIRTNOTEXIST
	fi

	# mount HD
	if test -d $MARKERDIR 
	then
		# is fixed disk
        	dlog " -- HD '$LABEL' is mounted at '$MOUNTDIR'"
	else
        	dlog " marker folder '$MARKERDIR' doesn't exist, try mount" 
		./mount.sh $LABEL 
        	RET=$?
		if test $RET -ne 0
		then
                	dlog " == end, couldn't mount disk '$LABEL' to  '$MOUNTDIR', mount error =="
		fi	
        	if test ! -d $MARKERDIR 
        	then
			dlog " mount,  markerdir '$MARKERDIR' not found"
	                dlog " == end, couldn't mount disk '$LABEL' to  '$MOUNTDIR', no marker folder =="
        	        exit $DISKNOTMOUNTED
        	fi
	fi

	dlog " -- disk '$LABEL' is mounted, marker folder '$MARKERDIR' exists"
else
	# if test $local_in_array -ne 0
	dlog " test $local_in_array -ne 0"
	dlog " disk '$LABEL' not checked, ist marked with 'local' in properties, this is ok"
fi

# disk is mounted 

## place for disk size
	dsmaxfree=$maxfillbackupdiskpercent

	dlog "---> max allowed used space: '${dsmaxfree}%'"
	#dlog "free_space=$( df -h | grep -w $LABEL | awk '{print $4}')"
	dsfree_space=$( df -h | grep -w $LABEL | awk '{print $4}')

	#dlog "used_space_percent=$( df -h | grep -w $LABEL | awk '{print $5}')"
	dstempused=$( df -h | grep -w $LABEL | awk '{print $5}')
	dstemp=${dstempused%?}
	dsused_space_percent=$dstemp

	if [ $dsmaxfree -lt $dsused_space_percent ]
	then
		dlog "max allowed used space '${dsmaxfree}%' is lower than current used space '${dsused_space_percent}%', continue with next disk"
		#continue
	fi


	dsfreemsg="free space: $dsfree_space, used space: ${dsused_space_percent}%"
	dlog "---> $dsfreemsg"


## end disk size


# done to false
done=false

dlog "execute projects in time and with valid pre check"


declare -A projecterrors
declare -a successlist
declare -a unsuccesslist



# in 'nextprojects' are all projects to backup
# call bk_project for each
for p in "${nextprojects[@]}"
do

	dlog ""
	lpkey=${LABEL}_${p}
	# second check, first was in first loop
	# is already checked, see above
	DISKDONE=0 
	ispre=0    

	pdiff=$( decode_pdiff ${lpkey} )

	# check current time
	tcurrent=`date +%Y-%m-%dT%H:%M`
	# set lastline to 01.01.1980
        LASTLINE=$maxLASTDATE
	DONE_FILE="./${donefolder}/${lpkey}_done.log"
	# read last line fron done file
        if test -f $DONE_FILE
        then
                LASTLINE=$(cat $DONE_FILE | awk  'END {print }')
        fi
	# get delta from lastline and current time
	DIFF=$(time_diff_minutes  $LASTLINE  $tcurrent  )

        if test "$DISKDONE" -eq 0
        then
		datelog "${FILENAME}: === disk: '$LABEL', start of project '$p' ==="
		tlog "do: '$p'"
		# calls bk_project.sh #########################################################
		./bk_project.sh $LABEL $p 
		# #############################################################################
		RET=$?
		#dlog "RET: $RET"
		#dlog "NOFOLDERRSNAPSHOT=14 : $NOFOLDERRSNAPSHOT"

		# check free space
		_maxfree=$maxfillbackupdiskpercent
		_used_space_percent=$( df -h | grep -w $LABEL | awk '{print $5}')
		_temp=${_used_space_percent%?}
		_used_space_percent=$_temp
		#  handle disk full err
		if [ $_maxfree -lt $_used_space_percent ]
		then
			RET=$DISKFULL
			#dlog "set RET to DISKFULL, allowed space of disk '${_maxfree}%' is lower than current free space '${_used_space_percent}%'"
		fi	


		if test $RET -eq $DISKFULL
		then
			projecterrors[${p}]="rsync error, no space left on device, check harddisk usage: $LABEL $p"
			datelog "${FILENAME}:  !! no space left on device, check configuration !! ($LABEL $p)"
			datelog "${FILENAME}:  !! no space left on device, check file 'rr_${LABEL}_${p}.log' !!"
		fi
		if test $RET -eq $RSYNCFAILS
		then
			projecterrors[${p}]="rsync error, check configuration or data source: $LABEL $p"
			datelog "${FILENAME}:  !! rsync error, check configuration !! (disk: '$LABEL', project: '$p')"
			datelog "${FILENAME}:  !! rsync error, check file 'rr_${LABEL}_${p}.log'  !! "
		fi
		if test $RET -eq $ERRORINCOUNTERS
		then
			projecterrors[${p}]="retain error, one valus is lower than 2, check configuration of retain values: $LABEL $p"
			datelog "${FILENAME}:  !! retain error, check configuration !! ($LABEL $p)"
			datelog "${FILENAME}:  !! retain error, check file 'rr_${LABEL}_${p}.log'  !! "
		fi

		
		if test $RET -eq $NOFOLDERRSNAPSHOT
		then
			projecterrors[${p}]="error, folder '$rsynclogfolder' is not present"
			datelog "${FILENAME}:  folder '$rsynclogfolder' doesn't exist"
		fi
		if test $RET -eq $NORSNAPSHOTROOT
		then
			projecterrors[${p}]="snapshot root folder doesn't exist, see log"
			dlog "snapshot root folder doesn't exist, see log"
#			exit $NORSNAPSHOTROOT
		fi

		done=true
		if test $RET -ne 0
		then
			done=false
			dlog "done = false"
		fi



		current=`date +%Y-%m-%dT%H:%M`
		__TODAY=`date +%Y%m%d-%H%M`
		if test "$done" == "true"
		then
			# set current at last line to done file
			# done entry is written in bk_project.sh, 131
		        datelog "${FILENAME}:  all ok, disk: '$LABEL', project '$p'"
			sendlog "HD: '$LABEL' mit Projekt '$p' gelaufen, keine Fehler"
			# write success to a single file 
			echo "$__TODAY ==> '$LABEL' mit '$p' ok" >> $successlogtxt

			# collect success for report at end of main loop
			ll="${LABEL}"

			# shorten label, if label ends with luks or disk
			if [[ "$ll" = *"disk"* ]]; 
			then
				tt=${ll::-4} 
				ll=$tt
			fi
			if [[ "$ll" = *"luks"* ]]; 
			then
				tt=${ll::-4} 
				ll=$tt
			fi
			var="${ll}:$p"
			successlist=( "${successlist[@]}" "$var" )
			datelog "${FILENAME}: successlist: $( echo ${successlist[@]} )"

			#echo "$__TODAY" > ./$donefolder/${LABEL}_${p}_done.log
			#datelog "${FILENAME}: write last date: ./$donefolder/${LABEL}_${p}_done.log"

		else
			# error in rsync
			error_in_rsync=$RSYNCFAILS
			datelog "${FILENAME}:  error: disk '$LABEL', project '$p'"
			sendlog "HD: '$LABEL' mit Projekt  '$p' hatte Fehler"
			sendlog "siehe File: 'rr_${LABEL}_$p.log' im Backup-Server"
			errorlog "HD: '$LABEL' mit Projekt  '$p' hatte Fehler" 
			# write unsuccess to a single file 
			echo "$__TODAY ==> '$LABEL' mit '$p' not ok" >> $successlogtxt
			
			# collect unsuccess for report at end of main loop
			ll="${LABEL}"
			if [[ "$ll" = *"disk"* ]]; 
			then
				tt=${ll::-4} 
				ll=$tt
			fi
			if [[ "$ll" = *"luks"* ]]; 
			then
				tt=${ll::-4} 
				ll=$tt
			fi
			var="${ll}:$p"
			unsuccesslist=( "${unsuccesslist[@]}" "$var" )
			datelog "${FILENAME}: unsuccesslist: $( echo ${unsuccesslist[@]} )"
		fi
	fi
done
# all backups are done
# end of disk

# find min diff after backup ist done, done file exists here
mindiff=10000
minp=""
for p in $PROJEKTLABELS
do
	lpkey=${LABEL}_${p}
        DONE_FILE="./${donefolder}/${lpkey}_done.log"
	#datelog "donefile: $DONE_FILE"
        LASTLINE=$maxLASTDATE
        if test -f $DONE_FILE
        then
                LASTLINE=$(cat $DONE_FILE | awk  'END {print }')
        fi

	# get project delta time
	pdiff=$(decode_pdiff ${lpkey} )
	# get current delta after last done, in LASTLINE is date in %Y-%m-%dT%H:%M
        tcurrent=`date +%Y-%m-%dT%H:%M`
        DIFF=$(time_diff_minutes  $LASTLINE  $tcurrent  )
        deltadiff=$(( pdiff - DIFF ))
#	datelog "$p, configured value $pdiff"
#	datelog "$p, lastline   value $DIFF"
#	datelog "$p, delta=pdiff-DIFF $deltadiff, mindiff: $mindiff"
        if ((deltadiff < mindiff ))
        then
                mindiff=$deltadiff
		minp=$p
        fi
	#datelog "after b delta $deltadiff, mindiff: $mindiff"
	#datelog "programmed diff: $pdiff, lastDIFF: $DIFF, mindiff: $mindiff, delta: $deltadiff"
done


# data must be collected before disk is unmounted
used_space_percent=$( df -h | grep -w $LABEL | awk '{print $5}')
temp=${used_space_percent%?}
used_space_percent=$temp
free_space=$( df -h | grep -w $LABEL | awk '{print $4}')

# clean up
notifyfilepostfix="keine_Fehler_alles_ok"

if test -d $MARKERDIR 
then
	#ucommand=$( grep -e properties cfg.projects | grep fluks | cut -d '=' -f 2 | sed 's/"//' | sed 's/"$//' )
	umount_is_inarray=$(echo ${parray[@]} | grep -w -o "umount" | wc -l )
	RET=1
        if test $umount_is_inarray -eq 1 
	then
		datelog "${FILENAME}: umount  $MOUNTDIR"
		./umount.sh  $LABEL
		RET=$?
		if test $RET -ne 0
		then
			msg="HD '$LABEL' wurde nicht korrekt getrennt, bitte nicht entfernen"
			datelog $msg
			sendlog $msg
			notifyfilepostfix="Fehler_HD_nicht_getrennt"
		else
			#rmdir  $MOUNTDIR
			datelog "${FILENAME}: '$LABEL' all is ok"
			sendlog "HD '$LABEL': alles ist ok"

			# set in cfg.loop_time_duration
			nextdiff=$MIN_WAIT_FOR_NEXT_LOOP
			# if duration < next project, then use next project mindiff as next time
			if ((nextdiff < mindiff ))
			then
			        nextdiff=$mindiff
			fi
			encode_diff $nextdiff 
			_nextdiff=$encode_diff_var
			sendlog "HD mit Label '$LABEL' kann in den nächsten '${_nextdiff}' Minuten vom Server entfernt werden "
		fi
		if [ -d $MARKERDIR ]
		then
        		datelog "${FILENAME}: disk is still mounted: '$LABEL', at: '$MOUNTDIR' "
        		datelog ""
	  		datelog "${FILENAME}: '$LABEL' ist noch verbunden, umount error"
                        sendlog "HD mit Label: '$LABEL' konnte nicht ausgehängt werden, bitte nicht entfernen"
			TODAY=`date +%Y%m%d-%H%M`
			sendlog "=======  $TODAY  ======="
			notifyfilepostfix="HD_konnte_nicht_getrennt_werden_Fehler"
			
		fi
	else
		datelog "${FILENAME}: no umount configured, maybe this is a fixed disk  at $MOUNTDIR"
		datelog "${FILENAME}: next run of '$minp' in '${mindiff}' minutes"
		sendlog "'umount' wurde nicht konfiguriert, HD '$LABEL' ist noch verbunden, at $MOUNTDIR"
	fi
else
	dlog "is local disk, no umount"
fi



datelog "${FILENAME}: == end disk with '$LABEL' =="
datelog ""
encode_state="empty"
encode_diff_var="empty"

# don't call with $(  ), the subshell cant't change 'encode_state' 
encode_diff $mindiff 
_mind=$encode_diff_var

Tagen_Stunden_Minuten="nichts"


if test $encode_state = "minutes" 
then
	Tagen_Stunden_Minuten="Minuten"
fi
if test $encode_state = "hours" 
then
	Tagen_Stunden_Minuten="Stunden:Minuten"
fi
if test $encode_state = "days" 
then
	Tagen_Stunden_Minuten="Tagen:Stunden:Minuten"
fi


msg="HD mit Label '$LABEL', nächster Lauf eines Projektes ('$minp')  auf dieser HD ist in '${_mind}' $Tagen_Stunden_Minuten"
dlog "====================================================================================================="
dlog "$msg"
sendlog "$msg"

sendlog "waittime interval:  $waittimeinterval "


msg="freier Platz auf HD '$LABEL': $free_space, belegt: ${used_space_percent}%"
dlog "$msg"
sendlog "$msg"


maxfree=$maxfillbackupdiskpercent
msg="max. reservierter Platz auf HD '$LABEL' in Prozent '${maxfree}%'"
dlog "$msg"
sendlog "$msg"

dlog "====================================================================================================="

hour=$(date +%H)
TODAY=`date +%Y%m%d-%H%M`
sendlog "=======  $TODAY  ======="

#  handle disk full err
if [ $maxfree -lt $used_space_percent ]
then
	msg="max. reservierter Platz auf HD '$LABEL' in Prozent '${maxfree}%'"
	dlog "$msg"
	projecterrors[------]="maximaler reservierter Platz auf der Backup-Festplatte wurde überschritten: "
	projecterrors[-----]="   max erlaubter Platz '${maxfree}%' ist kleiner als verwendeter Platz  '${used_space_percent}%'"
fi

if test ${#projecterrors[@]} -gt 0 
then

	#  handle disk full err
	if [ $maxfree -lt $used_space_percent ]
	then
		dlog "allowed space of disk '${maxfree}%' is lower than current free space '${used_space_percent}%'"
		notifyfilepostfix="Backup-Festplatte_ist_zu_voll"
	else
		notifyfilepostfix="Fehler_in_Projekten"
	fi
	sendlog "${#projecterrors[@]}  $notifyfilepostfix"
	# loop over keys in array  (!)
	for i in "${!projecterrors[@]}"
	do
		sendlog "Projekt: '$i'  Nachricht: ${projecterrors[$i]}"
	done
	sendlog "---"
fi

# send to local folder 'backup_messages_test'
# create temp file with postfix in name
sshnotifysend $LABEL $notifyfilepostfix 

# end of loop, remove NOTIFYSENDLOG
rm $NOTIFYSENDLOG

# write collected success labels to disk
# don't delete files, is > redirection
# files are used in bk_disks
echo ${successlist[@]} > $successarraytxt
echo ${unsuccesslist[@]} > $unsuccessarraytxt

if [[ $error_in_rsync == $RSYNCFAILS ]]
then
	tlog "end: fails, '$LABEL'"
	dlog "end: fails, '$LABEL'"
	exit $RSYNCFAILS
fi

tlog "end: ok,    '$LABEL'"
dlog "end: ok,    '$LABEL'"
exit $SUCCESS


