#!/bin/bash

# file: bk_archive.sh
# bk_version 22.08.1


# Copyright (C) 2021 Richard Albrecht
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
#			./bk_project.sh, one project with n folder trees,   
#				./bk_rsnapshot.sh,  do rsnapshot   
#				./bk_archive.sh,    no history, rsync only,  <- this file

# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_


. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_global_strings.sh
. ./src_folders.sh
. ./src_log.sh


# exitvalues
# exit $BK_RSYNCFAILS  - one of the the backup lines fails



# set later with  ''rsync_command_log from config file
#    lv_temp=$(cat ./${lv_archiveconfigname} | grep ^rsync_command_log | grep -v '#' | awk '{print $2}')
#lv_rsync_command_logfilename="${bv_workingfolder}/rsync_archive.log"

function write_rsync_command_log() {
	local msg="$1"
	if test  -z "${lv_rsync_command_logfilename}"
	then
		echo "lv_rsync_command_logfilename is empty"
		exit
	fi
	echo "$msg" >> ${lv_rsync_command_logfilename}
}


# parameter
# $1 = $LABEL
# $2 = $PROJECT)
# par1 = label of backup-disk
readonly lv_disklabel=$1
# par2 = name of the project·
readonly lv_project=$2

readonly lv_lpkey=${lv_disklabel}_${lv_project}


if [ ! $lv_disklabel ] || [ ! $lv_project ]
then
	dlog "disk label '$lv_disklabel' or project '$lv_project' not set in 'bk_archive.sh'"
	exit 1
fi


readonly lv_tracelogname="archive"
readonly lv_cc_logname="${lv_disklabel}:${lv_project}:archive"


tlog "start: $lv_lpkey"

# rsnapshot exit values
# 0 All operations completed successfully
# 1 A fatal error occurred
# 2 Some warnings occurred, but the backup still finished


# lv_logdate=`date +%Y-%m-%dT%H:%M:%S`
lv_logdate=$( currentdateT )


dlog "== start bk_archive.sh =="

readonly lv_cfg_archive=${lv_lpkey}.arch
readonly lv_workingfolder=$bv_workingfolder

#   entries in config file
# archive_root /mnt/fluks/rs/ls5eth/
# rsync_command_log	aa_fluks_ls5.log
# rsync_log		rr_fluks_ls5.log
# rsync_args		-av --numeric-ids --relative·
# ssh_args		-p 22
# exclude_file		fluks_ls5
# backup	 		rleo@ls5eth:/media/rleo/ls5ssd/bilder  	.
# backup	 		rleo@ls5eth:/media/rleo/ls5ssd/pdf     	.
# backup	 		rleo@ls5eth:/media/rleo/ls5ssd/videos  	.

readonly lv_archiveconfigname="${bv_conffolder}/${lv_cfg_archive}"

# get archive_root 
readonly lv_archive_root=$(cat ./${lv_archiveconfigname} | grep ^archive_root | grep -v '#' | awk '{print $2}')

# get rsync_command 
# set var 'lv_rsync_command_logfilename' from config file
readonly lv_temp=$(cat ./${lv_archiveconfigname} | grep ^rsync_command_log | grep -v '#' | awk '{print $2}')
lv_rsync_command_logfilename=${lv_workingfolder}/${lv_temp}

# get rsync log name 
readonly lv_temp2=$(cat ./${lv_archiveconfigname} | grep ^rsync_log | grep -v '#' | awk '{print $2}')
readonly lv_rsync_log=${lv_workingfolder}/${lv_temp2}


# get rsync args in line 
# get all entries, except first
readonly lv_rsync_args=$(cat ./${lv_archiveconfigname} | grep ^rsync_args | grep -v '#' | awk '{ $1=""; print }')

# get exclude file name
readonly lv_temp3=$(cat ./${lv_archiveconfigname} | grep ^exclude_file | grep -v '#' | awk '{ print $2}')
readonly lv_excludefilename="${bv_excludefolder}/${lv_temp3}"

# no bv_preconditionsfolder file for archive
dlog "archive root:  $lv_archive_root"
dlog "rsync command logfile: $lv_rsync_command_logfilename"
dlog "rsync log:     ${lv_rsync_log}"
dlog "rsync args:    ${lv_rsync_args}"
dlog "exclude file:  ${lv_excludefilename}"


write_rsync_command_log "-- $lv_logdate, start -- " 
write_rsync_command_log "-- $lv_logdate, start backup from './${lv_archiveconfigname}' -- " 


readonly list_of_backuplines=$(  cat ./${lv_archiveconfigname} | grep -w ^backup )
oldifs=$IFS
IFS='
'
# convert to array of 'retain' lines
# 0 = 'backup', 1 = source, 2 = target, may be .
readonly backuplinesarray=($list_of_backuplines)
IFS=$oldifs
dlog "# number of backup entries  in './${lv_archiveconfigname}' : ${#backuplinesarray[@]}"

lineounter=0
RET=0
_ok=0


for _line in "${backuplinesarray[@]}"
do
	# split to array with ()
	_linearray=($_line)

	# 0 = keyword 'backup', 1 = source, 2 = target
	_source=${_linearray[1]}
	_target=${_linearray[2]}

	if test -z ${_target}
	then
		_target="."
	fi
	if test $_target = "." 
	then
		_target=""
	fi

	tlog "do: $_source"
	dlog "source : $_source"

	dlog "target: ${lv_archive_root}${_target}"

	rcommand="rsync ${lv_rsync_args}   $_source   ${lv_archive_root}${_target} --log-file=${lv_rsync_log}"
	if [ -f "${lv_excludefilename}" ]
	then
		#	                          --exclude-from=/usr/local/bin/backup_data/bv_excludefolder/dluks_dserver
		rcommand="rsync ${lv_rsync_args}  --exclude-from=${lv_excludefilename}  $_source   ${lv_archive_root}${_target} --log-file=${lv_rsync_log}"
	fi
	dlog "rsync command: $rcommand"
	write_rsync_command_log "$rcommand" 
	eval $rcommand
	RET=$?
	if test $RET -ne 0
	then
		dlog "rsync fails, source: $_source"
		_ok=1
	else
		dlog "rsync ok, source: $_source"
	fi

	(( lineounter++ ))
done

runningnumber=$( get_runningnumber )
lv_logdate=$( currentdateT )


# remove old logs
rm $lv_archive_root/${lv_lpkey}_created_at*

readonly final_created_at_filename_base="$lv_archive_root/${lv_lpkey}_created_at_${lv_logdate}_number_$runningnumber"

if test $_ok -eq 0 
then
	echo "created at: ${lv_logdate}, loop: $runningnumber" > ${final_created_at_filename_base}.txt
else
	echo "created_at: ${lv_logdate}, loop: $runningnumber, errors in rsync, see log" > ${final_created_at_filename_base}_with_errors.txt
	dlog "bk_archive.sh ends with errors, see '${lv_rsync_command_logfilename}'"
	tlog "end, error"
	exit $BK_RSYNCFAILS
fi


write_rsync_command_log "-- $lv_logdate, end backup from '${lv_archiveconfigname}' -- " 
write_rsync_command_log "-- $lv_logdate, end -- " 


dlog "== end bk_archive.sh =="
tlog "end" 

exit 0 

# rsync errors
#       0      Success
#       1      Syntax or usage error
#       2      Protocol incompatibility
#       3      Errors selecting input/output files, dirs
#       4      Requested  action not supported: an attempt was made to manipulate 64-bit files on a platform·
#              that cannot support them; or an option was specified that is supported by the client and not by the server.
#       5      Error starting client-server protocol
#       6      Daemon unable to append to log-file
#       10     Error in socket I/O
#       11     Error in file I/O
#       12     Error in rsync protocol data stream
#       13     Errors with program diagnostics
#       14     Error in IPC code
#       20     Received SIGUSR1 or SIGINT
#       21     Some error returned by waitpid()
#       22     Error allocating core memory buffers
#       23     Partial transfer due to error
#       24     Partial transfer due to vanished source files
#       25     The --max-delete limit stopped deletions
#       30     Timeout in data send/receive
#       35     Timeout waiting for daemon connection



# EOF


