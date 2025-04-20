#!/bin/bash

# shellcheck disable=SC2155
# disable: Declare and assign separately to avoid masking return

# file: bk_project.sh
# bk_version 25.04.1



# Copyright (C) 2017-2025 Richard Albrecht
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
# ./bk_main.sh, runs forever 
#	./bk_disks.sh,   all disks  
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with n folder trees,   <- this file
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_


# parameter:
#   $1 = disklabel, label of backup-disk
#   $2 = projectname,  name of project at this disk

. ./cfg.working_folder
. ./cfg.projects

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_folders.sh
. ./src_log.sh


# set -u, which will exit your script if you try to use an uninitialised variable.
set -u

# exit values, in bk_loop.sh
# exit $BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
# exit $BK_ARRAYSNOK         	- property arrays have errors
# exit $BK_DISKLABELNOTFOUND	- disk with uuid nit found in /dev/disk/by-uuid, disk ist not in system 
# exit $BK_NOINTERVALSET	- no backup time inteval configured in 'cfg.projects'
# exit $BK_TIMELIMITNOTREACHED	- for none project at this disk time limit is not reached
# exit $BK_DISKNOTUNMOUNTED	- disk could not be unmounted
# exit $BK_MOUNTDIRTNOTEXIST	- mount folder for backup disk is not present in '/mnt'
# exit $BK_DISKNOTMOUNTED	- disk could not be mounted 
# exit $BK_DISKNOTMOUNTED	- rsync error, see logs
# exit $BK_SUCCESS		- all was ok

# exit $BK_RSYNCFAILS - exit from bk_archive.sh


# par1 = label of backup-disk
readonly lv_disklabel=$1
# par2 = name of the project 
readonly lv_project=$2

readonly lv_tracelogname="project"
readonly lv_cc_logname="${lv_disklabel}:project:${lv_project}"
readonly lv_lpkey=${lv_disklabel}_${lv_project}

if [ ! $lv_disklabel ] || [ ! $lv_project ]
then
	dlog "disklabel '$lv_disklabel' or project '$lv_project' not set in call of 'bk_projekt.sh'"
	exit 1
fi

readonly lv_targetdisk=$( targetdisk "$lv_disklabel" )
lv_label_name="$lv_disklabel"
if [ "$lv_disklabel" != "$lv_targetdisk" ]
then
	lv_label_name="$lv_disklabel ($lv_targetdisk)"
fi

tlog "start:  '$lv_lpkey'"

dlog ""
dlog "== start project '$lv_project' at disk '$lv_label_name'  =="

#DONE=${bv_donefolder}

# check, if config file ends with 'arch', then we do simple backup with rsync, not with 'rsnapshot'
readonly lv_archive_cfg_file=${bv_conffolder}/${lv_lpkey}.arch

lv_countarchiverootlines=0
if [ -f ./${lv_archive_cfg_file} ]
then
	dlog "check, is config is archive cfg: cat ./${lv_archive_cfg_file} | grep ^archive_root | grep -v '#' | wc -l "
	lv_countarchiverootlines=$(cat ./${lv_archive_cfg_file} | grep ^archive_root | grep -v '#' | wc -l)


	# if line with 'archive_root' exists, do 'bk_archive.sh' with project name
	# exact 1 archive_root exists
	if [ $lv_countarchiverootlines -eq 1 ]
	then
		ARCHIVE_ROOT=$(cat ./${lv_archive_cfg_file} | grep ^archive_root | grep -v '#' )
		dlog "archive_root= '$ARCHIVE_ROOT'"
		tlog "do archive:  '$lv_lpkey'"
		# parameter $lv_lpkey
		# do achive of files, no history, no delete, accumulate files
		# ###########    calls ./bk_archive.sh ${lv_disklabel} ${lv_project} ############################
		./bk_archive.sh  ${lv_disklabel} ${lv_project}
		# ############################################################################################
		RET=$?
		# 'BK_RSYNCFAILS=8' was set in bk_archive.sh
		if test $RET -eq $BK_RSYNCFAILS
		then
			dlog "error in 'bk_archive.sh': rsync to archive fails, disk: ${lv_disklabel}, project: '$lv_project'"
			# in archive call, exit $BK_RSYNCFAILS
			exit $BK_RSYNCFAILS
		fi
		if test $RET -eq 0 
		then
			# write current time to done file
			# archive: "write last date: ./${bv_donefolder}/${lv_lpkey}_done.log"
			dlog "write last date: ./${bv_donefolder}/${lv_lpkey}_done.log"
			_currenttime_=$( currentdateT )
			echo "$_currenttime_" > ./${bv_donefolder}/${lv_lpkey}_done.log
		fi
		exit $RET
	
	fi
	dlog "no archive_root found in '${lv_archive_cfg_file}'"
	exit  $BK_RSYNCFAILS
fi


# not reached, if simple rsync backup via archive config is used
# do normal rsnapshot

# check, if config file ends with 'conf', then we do a backup with 'rsnapshot'
readonly lv_rsnapshot_config=${lv_lpkey}.conf
readonly lv_rsnapshot_cfg_file=${bv_conffolder}/${lv_rsnapshot_config}


if  [ ! -f ./${lv_rsnapshot_cfg_file} ]
then
	dlog "'${lv_rsnapshot_cfg_file}' doesn't exist"
	exit $BK_RSYNCFAILS
fi

readonly lv_ro_rsnapshot_root=$(cat ./${lv_rsnapshot_cfg_file} | grep ^snapshot_root | grep -v '#' | awk '{print $2}')

dlog "snapshot_root: '$lv_ro_rsnapshot_root'"

# 3 local arrays
declare -A retainscount
declare -A retains_count_file_names
declare -A retains

# parameter
#  $1 = file with lines = number of lines in this file is retains count = number of current retains done at this retain key
# filename is 'disk_project_retains'
# get number_of_ entries keeped in history  
function entries_keeped {
	local _index=$1
	local _retains_count_file_name=${retains_count_file_names[$_index]}
	local _counter=0
	local _retain_value=${retains[$_index]}
	if [ -f ${_retains_count_file_name} ]
	then
		# count the lines
		# count is number of entries_keeped
		_counter=$(  wc  -l < ${_retains_count_file_name}  )
	fi
	echo $_counter
}



tlog "do project:  '$lv_lpkey'"

# look up for lines with word 'retain'
readonly retainslist=$( cat ./${lv_rsnapshot_cfg_file} | grep ^retain )
readonly OIFS=$IFS
IFS='
'
# convert to array of 'retain' lines
# 0 = 'retain', 1 = level, 2 = count
readonly lines=($retainslist)
#dlog "# current number of retain entries  './${lv_rsnapshot_cfg_file}' : ${#lines[@]}"

IFS=$OIFS


# split retains from conf file

readonly size=${#lines[@]}
if [ $size -ne 4 ]
then
	dlog "error in './${lv_rsnapshot_cfg_file}', number of retain entries is wrong, must be 4, but is '$size'"
	exit $BK_RSYNCFAILS
fi
# retain values example
: << '--COMMENT--'
retain          eins    5
retain          zwei    4
retain          drei    4
retain          vier    4

retain must be > 1
if < 1 then, rsnapshot complains with:
# [2020-04-04T10:23:11] /usr/bin/rsnapshot -c ./conf/wdg_dserver.conf sync: 
# ERROR: Can not have first backup level's retention count set to 1, and have a second backup level
--COMMENT--

n=0
for i in "${lines[@]}"
do
        # split to array with ()
	_line=($i)

	# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
	rlevel=${_line[1]}
	retains[$n]=$rlevel
	rcount=${_line[2]}
	if [[ $rcount -lt 2 ]]
	then
		dlog "retain count is < 2 in retain '$rlevel', this is not allowed in 'rsnapshot' and this backup"
		exit $BK_ERRORINCOUNTERS
	fi

	retainscount[$n]=$rcount
	retains_count_file_names[$n]=$bv_retainscountfolder/${lv_lpkey}_${rlevel}

	_t0=$(  printf "%8s %4s (%2s)" ${retains[$n]} ${retainscount[$n]} $( entries_keeped $n )   )
	dlog "retain $n: $_t0"

	(( n++ ))
done

firstretain=${retains[0]}

#dlog "firstretain: $firstretain"

# retain from conf splitted




# remove index 0 counter, set count to 0, = interval eins
# par = oldindex
function remove_counter_file {
	local _oldindex=$1
	local _oldretain=${retains[$_oldindex]}
	local _oldfile=${retains_count_file_names[$_oldindex]}
	dlog "set count for retain '${_oldretain}' to 0"
	# means: set linecounter to 0
	rm ${_oldfile}
	#touch ${_oldfile}
}

# parameter
# $1 = index in retainslists
# increment index counter, indirect via number of lines in file
# means append line in retains_count_file_names[$index] with date 
# done after rotate, if _created_time="", then error in filesystem
function update_counter {
	local _index=$1
	local _currenttime=$( currentdateT )
	local _currentretain=${retains[$_index]}
	local _counter_=$( entries_keeped $_index )
	local retains_count_file_name=${retains_count_file_names[$_index]}
	#dlog " --- increment retains count:  '${retains_count_file_name}', value: '${_counter_}'"
	dlog " --- increment retains count: value: '${_counter_},  file:  '${retains_count_file_name}'"
	#dlog " --- by one line, file '${retains_count_file_name}', retain level:  '$_currentretain'"


	zero_interval_folder=$( echo "${lv_ro_rsnapshot_root}${_currentretain}.0" )
#	dlog "interval.0 folder: ${zero_interval_folder} check"
	# test RET	
	# dlog "interval.0 folder: ${zero_interval_folder} check fails"
	# exit $BK_ROTATE_FAILS

	if test -d ${zero_interval_folder}
	then
		# increment by one line
		echo "runs at: $_currenttime" >> ${retains_count_file_name}

		local _counter=$( entries_keeped $_index )
		dlog " --- new value:                      '${_counter}'"
		local _max_count=${retainscount[$_index]}

		# get loop number from previous 'created at' at current retain
		# e.g.: /mnt/bdisk/rs/nc/eins.0/created_at_2019-10-05T10:49_number_03767.txt
		# loop number is at end
		#set -x
		# created in bk_rsnapshot.sh:191
		local cr_file=$( ls -1 ${lv_ro_rsnapshot_root}${_currentretain}.0/${bv_createdatfileprefix}*  )
		dlog "check created info file: '$cr_file'"
		local _created_time=""
		if [ ! -z $cr_file ]
		then
			# get last line, is only one line in file
			local last_line_in_cr_file=$( cat ${cr_file}  )
			#dlog "last_line_cr_file: $last_line_in_cr_file"
			# prefix_created_at="created at: "
			local pat="created at: "
			# line is: created at: 2019-06-13T13:25, loop: 02618
			# remove prefix 'created at: ', in 'cr', remainder is '2019-06-13T13:25, loop: 02618'
			local _created_time=${last_line_in_cr_file#$pat}
			#dlog "line in file: $_created_time"
			# check, if created time is not empty
		fi
	else
		dlog "interval.0 folder: '${zero_interval_folder}' check fails"
		exit $BK_ROTATE_FAILS
	fi

	space="xxx"
	#set +x
	case $_index in
		0) 
			space=" "
			;;
		1) 
			space="  "
			;;
		2) 
			space="   "
			;;
		3) 
			space="    "
			;;
	esac
	local msg=""
	if [ $_max_count -lt 10 ]
	then
		msg=$( printf "%1d of %1d"  $_counter $_max_count )
	else
		msg=$( printf "%2d of %2d"  $_counter $_max_count )
	fi
	local intervaldonefile="${lv_lpkey}_done.txt"
	dlog "write reportline to '$bv_intervaldonefolder/$intervaldonefile'"
	reportline=$(  echo "($msg)${space}${_currentretain} at: $_currenttime created '${_created_time}'" )
	dlog "reportline is:  $reportline"
	echo "$reportline" >> $bv_intervaldonefolder/$intervaldonefile

}


# parameter
# $1 = index in retainsliststs
function do_rs {
	local _index=$1
	local _currentretain=${retains[$_index]}

	dlog "do retain '$_currentretain': in '$lv_project' at disk '$lv_disklabel'"
#	dlog "--- rsync $_currentretain"
	# parameter $INTERVAL $lv_disklabel $lv_project
	# do first rsnapshot, is real sync
	# ############ calls ./bk_rsnapshot.sh $_currentretain $lv_disklabel $lv_project #########
	./bk_rsnapshot.sh $_currentretain $lv_disklabel $lv_project 
	# #############################################################################
	RET=$?
	dlog "return of 'bk_rsnapshot.sh': $RET"
	#    'rsnapshot_root'  doesn't exist 
	#	exit $BK_NORSNAPSHOTROOT = 12
	#    interval from caller is invalid
	#    	exit $BK_NOINTERVALSET = 9
	#    after .sync, disk full or rsync error
	#    	exit $BK_RSYNCFAILS = 8
	#    after rotate
	#    	exit BK_ROTATE_FAILS

	if test $RET -eq $BK_NORSNAPSHOTROOT 
	then
		dlog "error in 'bk_rsnapshot.sh': rsnapshot root not found for '$lv_project'"
		exit $BK_NORSNAPSHOTROOT
	fi
	if test $RET -eq $BK_NOINTERVALSET 
	then
		dlog "error in 'bk_rsnapshot.sh': interval not found in cfg of  '$lv_project'"
		exit $BK_NOINTERVALSET
	fi
	if test $RET -eq $BK_RSYNCFAILS
	then
		# check for space on backup disk
		# ${lv_disklabel}_${lv_project}
		dlog "check log 'rr_${lv_lpkey}' for text: 'No space left on device' ??'"
		wcgr=$( tail -3 rr_${lv_lpkey}.log | grep "No space left on device" | wc -l )
		#dlog "wcgr line: ${wcgrline}"
		dlog "count found text: $wcgr"
		if [ $wcgr -gt 0 ]
		then
			dlog "error in 'bk_rsnapshot.sh':  'No space left on device', '$lv_project'"
			exit $BK_DISKFULL
		fi	
		dlog "check log 'rr_${lv_lpkey}' for text: 'connection unexpectedly closed' ??'"
		wcgr=$( tail -2 rr_${lv_lpkey}.log | grep "connection unexpectedly closed" | wc -l )
		dlog "count found text: $wcgr"
		if [ $wcgr -gt 0 ]
		then
			dlog "error in 'bk_rsnapshot.sh':  'connection unexpectedly closed', '$lv_project'"
			dlog "RET in bk_project: '$BK_CONNECTION_UNEXPECTEDLY_CLOSED'"
			exit $BK_CONNECTION_UNEXPECTEDLY_CLOSED
		fi
		# files vanished before
		# file has vanished


		dlog "error in 'bk_rsnapshot.sh': rsync fails '$lv_project'"
		exit $BK_RSYNCFAILS
	fi
	if test $RET -eq $BK_ROTATE_FAILS
	then
		dlog ""
		dlog "check log 'aa_${lv_lpkey}', look for errors of command 'mv' "
		dlog "check log 'aa_${lv_lpkey}', look for errors of command 'mv' "
		dlog "check log 'aa_${lv_lpkey}', look for errors of command 'mv' "
		dlog ""
		exit $BK_ROTATE_FAILS
	fi

	return $RET

}

#only rotate
function do_rs_123 {
	# index is 1 2 or 3
	local _index=$1
	##########  do rs #############################################################    
	do_rs $_index
	# #############################################################################
        RET=$?
	#    exit $BK_NORSNAPSHOTROOT
	#     interval from caller is invalid
	#    exit $rs_exitcode = 0
	# after .sync
	#    rs_exitcode=$BK_RSYNCFAILS

	if test $RET -eq 0
	then
		# increment index 1 counter
		update_counter $_index
		
		# counter check is in caller: $counter -ge  $max_count 
		# remove index 0 counter, set count to 0, = interval eins
		# _index is current level
		# previous_index is one level lower 
		# e.g. rm 'cdisk_dserver_eins'
		remove_counter_file $(previous_index $_index)
	fi
	local _counter=$( entries_keeped $_index)
	local _max_count=${retainscount[$_index]}
	#dlog "after sync"
	dlog "'${retains[$_index]}'    : $_counter"
	dlog "'${retains[$_index]}' max: $_max_count"
	return $RET

}



function do_rs_first {
	local _index=0
#	dlog " in do_rs_first '$lv_project' "
	##########  do rs #############################################################    
	do_rs $_index
	# #############################################################################
	local RET=$?
	if test $RET -eq 0
	then
		# first was ok, update counter
		dlog "sync '$lv_project' done"
		# increment index 0 counter
		# counter file doesn't exist ??
		update_counter $_index
		# no remove index 0 counter, previous_index is -1

		# main done is written here
		# write _done.log
		# write_done_file
		# snapshot: "write last date: '$_currenttime' to ./${bv_donefolder}/${lv_lpkey}_done.log"
		local _currenttime=$( currentdateT )
		echo "$_currenttime" > ./${bv_donefolder}/${lv_lpkey}_done.log
		dlog "write last date to 'done' file: '$_currenttime' to ./${bv_donefolder}/${lv_lpkey}_done.log"

	fi
	local _counter=$( entries_keeped $_index ) 
	local _max_count=${retainscount[$_index]}
	dlog "'${retains[$_index]}'    :   $_counter"
	dlog "'${retains[$_index]}' max:   $_max_count"
	return $RET

}

function previous_index {
	local _index=$1
	echo $(( _index -1 ))
}


# start of rsnapshot calls
tlog "do first"
dlog "do first"
##########  do_rs_first 0 #####################################################
# index is 0
do_rs_first
##############################################################################


# index 0
index=0
counter=$( entries_keeped $index ) 
max_count=${retainscount[$index]}

#  retain eins end


# check rotates
# if  index 0 filecounter >= max, do index 1
if test $counter -ge  $max_count
then	
	# do index 1 = second level
	index=1
	dlog "counter: $counter -ge  $max_count index: $index, root: $lv_ro_rsnapshot_root"
	tlog "do second"
	##########  do rs index = 1  #############################################################
	do_rs_123 $index
	##########################################################################################

	counter=$( entries_keeped $index)
	max_count=${retainscount[$index]}
	# if index 1 counter >= max, do index 2
	m=$(( max_count )) 
	if test $counter -ge  $m
	then
		# do index 2 = third level
		index=2
		dlog "counter: $counter -ge  $max_count index: $index, root: $lv_ro_rsnapshot_root"
		tlog "do third"
		##########  do rs index = 2  #############################################################
		do_rs_123 $index
		##########################################################################################
		counter=$( entries_keeped $index )
		max_count=${retainscount[$index]}

		# if index 2 counter >= max, do index 3
		m=$(( max_count )) 
		if test $counter -ge  $m
		then
	                # do index 3 = fourth level
			index=3
			dlog "counter: $counter -ge  $max_count index: $index, root: $lv_ro_rsnapshot_root"
			tlog "do fourth"

			##########  do rs index = 3  #############################################################
			do_rs_123 $index
			##########################################################################################

			counter=$( entries_keeped $index )
			max_count=${retainscount[$index]}

			# last, no more loops
			# if index 3 counter >= max, do nothing more
			# too much levels, don't shift to next level, last level 
			m=$(( max_count )) 
			
			############## last compare not -ge, use -gt ###################
			if test $counter -gt  $m
			then
				# fourth level is at end, counter reached
				#  remove counterfile for third level, if ok
				# nothing do, no rotate, only counter control

				# do index 4
				# oldindex 3
				index=4 # 1 after last

				dlog "counter: $counter -gt  $max_count index: $index, root: $lv_ro_rsnapshot_root"
				#_oldfile=${retains_count_file_names[$oldindex]}
				#oldretain=${retains[$oldindex]}
				dlog ""
				dlog "(in index 4) do no rotate: '$lv_project' at disk '$lv_disklabel'"

				# remove index 3 counter, set count to 0, = interval four
				remove_counter_file $(previous_index $index) 
				# nothing do, no rotate, only counter control
				dlog ""
				dlog "======="
				dlog "(in last step)  '$(previous_index $index)', no rotate to next level"
				dlog "======="
				dlog ""
				dlog ""
			fi
		fi
	fi
fi

########### final generic start #####################
# final stage at end of project
# final_func "$lv_disklabel" "$lv_project" "$lv_ro_rsnapshot_root" "$firstretain"
# end final stage 
########### final generic end  #####################




tlog "end"

# lv_label_name="$lv_disklabel ($lv_targetdisk)"

dlog "==  end project '$lv_project' at disk '$lv_label_name' and sync =="
sync
dlog ""



# EOF

