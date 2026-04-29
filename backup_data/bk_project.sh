#!/bin/bash

# shellcheck disable=SC2155
# disable: Declare and assign separately to avoid masking return

# file: bk_project.sh
# bk_version  26.05.1



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
# ./bk_main.sh, runs forever 
#	./bk_disks.sh,   all disks  
#		./bk_loop.sh	all projects in disk
#			./bk_project.sh, one project with n folder trees,   <- this file
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive.sh,    no history, rsync only


# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_



# parameter:
#   $1 = disklabel, label of backup-disk
#   $2 = projectname,  name of project at this disk

# set -u, which will exit your script if you try to use an uninitialised variable.
set -u

. ./cfg.working_folder
. ./cfg.projects

. ./src_test_vars.sh
. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_folders.sh
. ./src_log.sh



# exit values, in bk_loop.sh
# exit $BK_DISKLABELNOTGIVEN 	- disk label from caller is empty
# exit $BK_ARRAYSNOK         	- property arrays have errors
# exit $BK_DISKLABELNOTFOUND	- disk with uuid not found in /dev/disk/by-uuid, disk ist not in system 
# exit $BK_NOINTERVALSET	- no backup time inteval configured in 'cfg.projects'
# exit $BK_TIMELIMITNOTREACHED	- for none project at this disk time limit is not reached
# exit $BK_DISKNOTUNMOUNTED	- disk could not be unmounted
# exit $BK_MOUNTDIRTNOTEXIST	- mount folder for backup disk is not present in '/mnt'
# exit $BK_DISKNOTMOUNTED	- disk could not be mounted 
# exit $BK_DISKNOTMOUNTED	- rsync error, see logs
# exit $BK_SUCCESS		- all was ok

# exit $BK_ERRORINCOUNTERS
# exit $BK_ROTATE_FAILS
# exit $BK_NORSNAPSHOTROOT
# exit $BK_NOINTERVALSET
# exit $BK_DISKFULL
# exit $BK_CONNECTION_UNEXPECTEDLY_CLOSED
# exit $BK_RSYNCFAILS - exit from bk_archive.sh




if [ ! "$1" ] || [ ! "$2" ]
then
	dlog "disklabel '$1' or project '$2' not set in call of 'bk_projekt.sh'"
	exit $BK_DISKLABELNOTGIVEN
fi


# par1 = label of backup-disk
readonly lv_disklabel=$1
# par2 = name of the project 
readonly lv_project=$2


# check, if config file ends with 'arch', then we do simple backup with rsync, not with 'rsnapshot'
readonly lv_archive_cfg_file=${bv_conffolder}/${lv_disklabel}_${lv_project}.arch

if [ -f ./"${lv_archive_cfg_file}" ]
then
	lv_cc_logname="${lv_disklabel}:archive:${lv_project}"
	############ calls ./bk_archive.sh ${lv_disklabel} ${lv_project} ############################
	dlog "call archive, conf: '${lv_archive_cfg_file}' "
	./bk_archive.sh  "${lv_disklabel}" "${lv_project}"
	#############################################################################################
	archive_ret=$?
	exit  $archive_ret
fi
##########  end archive ##########################
##################################################






#############################################
### functions ###############################
#############################################

# write date to folder "done"
function write_last_date {
	dlog "- write project done date: ./${bv_donefolder}/${lv_lpkey}_done.log"
	_currenttime_=$( currentdateT )
	echo "$_currenttime_" > ./${bv_donefolder}/"${lv_lpkey}"_done.log
}



# parameter
#  $1 = file with lines = number of lines in this file is retains count = number of current retains done at this retain key
# filename is 'disk_project_retains'
# get number of entries keeping in history  
# index is > 0 and < 5
#i old function entries_keeped {
function retain_file_lines {
	local _retains_count_file_name=$1
	local _counter=0
	# if not exists, counter = 0 
	if [ -f "${_retains_count_file_name}" ]
	then
		# count the lines
		# linecount is number of entries keeped
		_counter=$(  wc  -l < "${_retains_count_file_name}"  )
	fi
	echo "$_counter"
}

function retain_lines {
	local _index=$1
	local _retains_count_file_name=${retainscountfiles[_index]}
	local _counter=$( retain_file_lines "$_retains_count_file_name" )
	echo "$_counter"
}



# remove index 0 counter, means set count to 0, = interval eins
# par = oldindex
function remove_counter_file {
	local _oldindex=$1
	local _oldretain=${retainlevel[_oldindex]}
	local _oldfile=${retainscountfiles[_oldindex]}
	dlog "set count for retain '${_oldretain}' to 0"
	# means: set linecounter to 0
	rm "${_oldfile}"
	#touch ${_oldfile}
}


# parameter
# $1 = index in retainslists
# increment index counter = number of lines in file
# in retainscountfiles[$_index]
# index is > 0 and < 5
function update_counter {
	local _index=$1
	local _currenttime=$( currentdateT )
	local _currentretain=${retainlevel[_index]}
	local _retains_count_file_name=${retainscountfiles[_index]}
	local _nr_old_retain_lines=$( retain_file_lines "$_retains_count_file_name" )

	# set, if created_at exists
	local _created_time=""
	#  "retains_count"
	dlog "- increment retains count: value: '${_nr_old_retain_lines}',  file:  '${_retains_count_file_name}'"
	local _zero_interval_folder=$( echo "${lv_rsnapshot_root}${_currentretain}.0" )
	#dlog "- _zero_interval_folder $_zero_interval_folder"
	# plausibility check of zero interval folder, must be present
	if test -d ${_zero_interval_folder}
	then
		# add one line retains count file
		echo "runs at: $_currenttime" >> ${_retains_count_file_name}

		local _counternext=$( retain_file_lines $_retains_count_file_name )
		dlog "- new value:                      '${_counternext}'"
		local _max_count=${retainscount[_index]}

		# get loop number from previous 'created at' at current retain
		# e.g.: /mnt/bdisk/rs/nc/eins.0/created_at_2019-10-05T10:49_number_03767.txt
		# loop number is at end
		# created in bk_rsnapshot.sh:191
		# defined in src_filenames.sh:readonly bv_createdatfileprefix="created_at_"
		local cr_file=$( ls -1 ${lv_rsnapshot_root}${_currentretain}.0/${bv_createdatfileprefix}*  )
		# created_at_date_number_nnnnn
		dlog "- check created info file: '$cr_file'"
		if [ ! -z $cr_file ]
		then
			local line_in_cr_file=$( cat ${cr_file}  )
			local pat="created at: "
			# look up pattern after pat
			# used at end of function
			_created_time=${line_in_cr_file#$pat}
		else
			dlog "- info file not found: '$cr_file'"
		fi
	else
		dlog "interval.0 folder: '${_zero_interval_folder}' check fails"
		exit $BK_ROTATE_FAILS
	fi

	space="xxx"
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
		msg=$( printf "%1d of %1d"  $_nr_old_retain_lines $_max_count )
	else
		msg=$( printf "%2d of %2d"  $_nr_old_retain_lines $_max_count )
	fi
	# "interval_done"
	local intervaldonefile="${bv_intervaldonefolder}/${lv_lpkey}_done.txt"
	dlog "- write reportline to '$intervaldonefile'"
	reportline=$(  echo "($msg)${space}${_currentretain} at: $_currenttime created '${_created_time}'" )
	dlog "- reportline is:  $reportline"
	echo "$reportline" >> "$intervaldonefile"

}


# parameter
# $1 = index in retainsliststs
function do_rs {
	local _index=$1
	local _currentretain=${retainlevel[_index]}

	dlog "- do retain '$_currentretain': in '$lv_project' at disk '$lv_disklabel'"
#	dlog "--- rsync $_currentretain"
	# parameter $INTERVAL $lv_disklabel $lv_project
	# do first rsnapshot, is real sync
	# ############ calls ./bk_rsnapshot.sh $_currentretain $lv_disklabel $lv_project #########
	./bk_rsnapshot.sh $_currentretain $lv_disklabel $lv_project 
	# #############################################################################
	local RET=$?
	dlog "- return of 'bk_rsnapshot.sh': $RET"
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
        local rs_123_RET=$?
	#    exit $BK_NORSNAPSHOTROOT
	#     interval from caller is invalid
	#    exit $rs_exitcode = 0
	# after .sync
	#    rs_exitcode=$BK_RSYNCFAILS

	if test $rs_123_RET -eq 0
	then
		# increment index 1 counter
		update_counter $_index
		
		# counter check is in caller: $counter -ge  $max_count 
		# remove index 0 counter, set count to 0, = interval eins
		# _index is current level
		# previous_index is one level lower 
		# e.g. rm 'cdisk_dserver_eins'
		# previous_index is alway set to 0, previous list is now obsolete
		remove_counter_file $(previous_index $_index)
	fi
	return $rs_123_RET
}


function do_rs_first {
	local _index=0
#	dlog " in do_rs_first '$lv_project' "
	##########  do rs #############################################################    
	do_rs $_index
	# #############################################################################
	local rs_first_RET=$?
	if test $rs_first_RET -eq 0
	then
		# first was ok, update counter
		dlog "- sync '$lv_project' done"
		# increment index 0 counter
		# counter file doesn't exist 
		update_counter $_index
		# no remove index 0 counter, previous_index is -1

		# main done is written here
		# write _done.log
		# write_done_file
		# snapshot: "write last date: '$_currenttime' to ./${bv_donefolder}/${lv_lpkey}_done.log"
		# only in last entry at first retain the done date is written
		write_last_date 
	fi
	return $rs_first_RET
}


function previous_index {
	local _index=$1
	echo $(( _index - 1 ))
}


#############################################
### start  ##################################
#############################################

# defined at start of file
######
# par1 = label of backup-disk
#### readonly lv_disklabel=$1
# par2 = name of the project 
#### readonly lv_project=$2
######


# do normal rsnapshot
readonly lv_lpkey=${lv_disklabel}_${lv_project}
# used in dlog() in 'src_log.sh'
lv_cc_logname="${lv_disklabel}:project:${lv_project}"

# used in tlog() in 'src_log.sh'
readonly lv_tracelogname="project"

readonly lv_targetdisk=$( targetdisk "$lv_disklabel" )

lv_label_displayname="$lv_disklabel"
if [ "$lv_disklabel" != "$lv_targetdisk" ]
then
	lv_label_displayname="$lv_disklabel ($lv_targetdisk)"
fi


tlog "start:  '$lv_lpkey'"

dlog ""
dlog "== start project '$lv_project' at disk '$lv_label_displayname' =="

# check, if config file exists, then we do a backup with 'rsnapshot'
readonly lv_rsnapshot_cfg_file=${bv_conffolder}/${lv_lpkey}.conf
if  [ ! -f ./"${lv_rsnapshot_cfg_file}" ]
then
	dlog "'${lv_rsnapshot_cfg_file}' doesn't exist"
	exit $BK_RSYNCFAILS
fi

readonly lv_rsnapshot_root=\
$(cat ./"${lv_rsnapshot_cfg_file}" | grep ^snapshot_root | grep -v '#' | gawk '{print $2}')

dlog "- snapshot_root: '$lv_rsnapshot_root'"


# define 3 local arrays
# values: retain          eins          5
#                         retainlevel   retainscount
declare -a retainscount
declare -a retainlevel
# name of the files with actual retain count
declare -a retainscountfiles


tlog "do project:  '$lv_lpkey'"

# look up for lines with word 'retain'
readonly retainslist=$(  cat ./"${lv_rsnapshot_cfg_file}" | grep ^retain  )
readonly OIFS=$IFS
# IFS is \n
IFS='
'

# convert to array of 'retain' lines
# 0 = 'retain', 1 = level, 2 = count
readonly lines=($retainslist)
IFS=$OIFS

# obtain retains from conf file

declare -i size=${#lines[@]}
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

retaincount must be > 1
if < 2 then, rsnapshot complains with:
# [2020-04-04T10:23:11] /usr/bin/rsnapshot -c ./conf/wdg_dserver.conf sync: 
# ERROR: Can not have first backup level's retention count set to 1, and have a second backup level


20260420-2248 --  ddisk:project:lserver: - retain 0:     eins    3 ( 0)
20260420-2248 --  ddisk:project:lserver: - retain 1:     zwei    4 ( 0)
20260420-2248 --  ddisk:project:lserver: - retain 2:     drei    5 ( 2)
20260420-2248 --  ddisk:project:lserver: - retain 3:     vier    6 ( 1)
is printed here

--COMMENT--



declare -i n=0
for linearray in "${lines[@]}"
do
        # split to array 
	# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
	line=($linearray)
	retainlevel[n]=${line[1]}
	retainscount[n]=${line[2]}
	if [[ ${line[2]}  -lt 2 ]]
	then
		dlog "retain count is < 2 in retain '${line[2]}', this is not allowed in 'rsnapshot' and this backup"
		exit $BK_ERRORINCOUNTERS
	fi

	# folder: "retains_count"
	retainscountfiles[n]=$bv_retainscountfolder/${lv_lpkey}_${retainlevel[n]}

	_retains_count_file=${retainscountfiles[n]}
	print_line=$(printf "%8s %4s (%2s)" "${retainlevel[n]}" "${retainscount[n]}" $(retain_file_lines "$_retains_count_file"))
	dlog "- retain $n: $print_line"

	(( n++ ))
done


# start of rsnapshot calls
tlog "do first"
dlog "- do first"
##########  do_rs_first 0 #####################################################
# index is 0
do_rs_first
##############################################################################


# index 0
declare -i index=0
declare -i counter=$( retain_lines $index ) 
declare -i max_count=${retainscount[index]}

#  retain eins end


# check rotates, after first retain
# if  index 0 filecounter >= max, do index 1
if test $counter -ge  $max_count
then	
	# do index 1 = second level
	index=1
	dlog "- counter: $counter -ge  $max_count index: $index, root: $lv_rsnapshot_root"
	tlog "do second"
	##########  do rs index = 1  #############################################################
	do_rs_123 $index
	##########################################################################################

	counter=$( retain_lines $index )
	#icnter=$(( counter ))
	max_count=${retainscount[$index]}
	# if index 1 counter >= max, do index 2
	#intm=$(( max_count )) 
	if test $counter -ge  $max_count
	then
		# do index 2 = third level
		index=2
		dlog "- counter: $counter -ge  $max_count index: $index, root: $lv_rsnapshot_root"
		tlog "do third"
		##########  do rs index = 2  #############################################################
		do_rs_123 $index
		##########################################################################################
		counter=$( retain_lines $index )
		max_count=${retainscount[index]}

		# if index 2 counter >= max, do index 3
		m=$(( max_count )) 
		if test $counter -ge  $m
		then
	                # do index 3 = fourth level
			index=3
			dlog "- counter: $counter -ge  $max_count index: $index, root: $lv_rsnapshot_root"
			tlog "do fourth"

			##########  do rs index = 3  #############################################################
			do_rs_123 $index
			##########################################################################################

			counter=$( retain_lines $index )
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

				dlog "- counter: $counter -gt  $max_count index: $index, root: $lv_ro_rsnapshot_root"
				#_oldfile=${retainscountfiles[$oldindex]}
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


tlog "end"

dlog "==  end project '$lv_project' at disk '$lv_label_displayname' and sync =="
sync
dlog ""


# EOF

