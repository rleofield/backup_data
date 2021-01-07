#!/bin/bash

# file: bk_archive.sh
# version 20.08.1



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


#   caller    ./bk_main.sh
#   caller    ./bk_disks.sh,      all disks
#   caller    ./bk_loop.sh        all projects in disk
#   caller    ./bk_project.sh,    one project with 1-n folder trees
#             ./bk_archive.sh,    do rsync 

. ./cfg.working_folder

. ./src_exitcodes.sh
. ./src_global_strings.sh
. ./src_folders.sh
. ./src_log.sh

# parameter
# $1 = projectkey  ($LABEL_$PROJECT)

readonly projectkey=$1 
readonly OPERATION="archive"
#readonly FILENAME="${OPERATION}:${projectkey}"
readonly FILENAME="${projectkey}:${OPERATION}"


tlog "start: $projectkey"

# rsnapshot exit values
# 0 All operations completed successfully
# 1 A fatal error occurred
# 2 Some warnings occurred, but the backup still finished


#readonly TODAY_LOG=`date +%Y-%m-%dT%H:%M:%S`
TODAY_LOG=`date +%Y-%m-%dT%H:%M`
RSYNCLOG=""


dlog "== start bk_archive.sh =="

readonly ARCHIVE_CONFIG=${projectkey}.arch
readonly wf=$WORKINGFOLDER

#archive_root /mnt/fluks/rs/ls5eth/
#rsync_command_log>      aa_fluks_ls5.log
#rsync_log>      rr_fluks_ls5.log
#rsync_args>     -av --numeric-ids --relative·
#ssh_args>       -p 22
#exclude_file>   fluks_ls5
#backup> rleo@ls5eth:/media/rleo/ls5ssd/bilder>  >       .
#backup> rleo@ls5eth:/media/rleo/ls5ssd/pdf>     >       .
#backup> rleo@ls5eth:/media/rleo/ls5ssd/videos>  >       .


# archive_root as arg2
readonly ARCHIVE_ROOT=$(cat ./$CONFFOLDER/${ARCHIVE_CONFIG} | grep ^archive_root | grep -v '#' | awk '{print $2}')
# rsync_command as arg2
readonly RSYNC_LOGFILE=$(cat ./$CONFFOLDER/${ARCHIVE_CONFIG} | grep ^rsync_command_log | grep -v '#' | awk '{print $2}')
# rsync_log as arg2
readonly RSYNC_LOG=$(cat ./$CONFFOLDER/${ARCHIVE_CONFIG} | grep ^rsync_log | grep -v '#' | awk '{print $2}')
# all args in line, except arg1
readonly RSYNC_ARGS=$(cat ./$CONFFOLDER/${ARCHIVE_CONFIG} | grep ^rsync_args | grep -v '#' | awk '{ $1=""; print }')
# exclude_file as arg2
readonly EXCLUDE_FILE=$(cat ./$CONFFOLDER/${ARCHIVE_CONFIG} | grep ^exclude_file | grep -v '#' | awk '{ print $2}')

# no pre file for archive
dlog "archive root:  $ARCHIVE_ROOT"
dlog "rsync logfile: $RSYNC_LOGFILE"
dlog "rsync log:     $RSYNC_LOG"
dlog "rsync args:    $RSYNC_ARGS"
dlog "exclude file:  exclude/$EXCLUDE_FILE"


echo "-- $TODAY_LOG, start -- " >> ${wf}/${RSYNC_LOGFILE}
echo "-- $TODAY_LOG, start backup from './${CONFFOLDER}/${ARCHIVE_CONFIG}' -- " >> ${wf}/${RSYNC_LOGFILE}

# 3 local arrays
declare -A backups
declare -A backuptarget

readonly backupslist=$(  cat ./$CONFFOLDER/${ARCHIVE_CONFIG} | grep -w ^backup )
#dlog " backups: $backupslist "
OIFS=$IFS
IFS='
'
# convert to array of 'retain' lines
# 0 = 'backup', 1 = source, 2 = target, may be .
readonly backuplines=($backupslist)
IFS=$OIFS
dlog "# number of backup entries  './${CONFFOLDER}/${ARCHIVE_CONFIG}' : ${#backuplines[@]}"

n=0
RET=0
_ok=0
for i in "${backuplines[@]}"
do
        # split to array with ()
	_line=($i)

	# 0 = keyword 'backup', 1 = source, 2 = target
	_source=${_line[1]}
	backuptarget[$n]=${_line[2]}
	if test -z ${backuptarget[$n]}
	then
		backuptarget[$n]="."
	fi

	#dlog "control backup  $n: ${backupsource[$n]},  ${backuptarget[$n]}"

	tlog "do: $_source"
	# strip host from source, all after : is path
	_spath=$( echo $_source | cut -d: -f 2 )
	if test "$_source" = "$_path"
	then
		dlog "source: $_source"
	else
		dlog "source: $_source,  $_spath"
	fi

	_target=${backuptarget[$n]}
	if test $_target = "." 
	then
		_target=""
	fi
	dlog "target: ${ARCHIVE_ROOT}${_target}"
	#r="rsync $RSYNC_ARGS   $_source   ${ARCHIVE_ROOT}${_target}${_spath} --log-file=${wf}/${RSYNC_LOG}"
	r="rsync $RSYNC_ARGS   $_source   ${ARCHIVE_ROOT}${_target} --log-file=${wf}/${RSYNC_LOG}"
	if [ -f "exclude/${EXCLUDE_FILE}" ]
	then
	#	--exclude-from=/usr/local/bin/backup_data/exclude/dluks_dserver
	r="rsync $RSYNC_ARGS  --exclude-from=exclude/${EXCLUDE_FILE}  $_source   ${ARCHIVE_ROOT}${_target} --log-file=${wf}/${RSYNC_LOG}"
	fi
	dlog "rsync command: $r"
	echo "$r" >> ${wf}/${RSYNC_LOGFILE}
	eval $r
	RET=$?
	if test $RET -ne 0
	then
		dlog "rsync fails, source: $_source"
		#exit $RSYNCFAILS
		_ok=1
	else
		dlog "rsync ok, source: $_source"
	fi

	(( n++ ))
done

runningnumber=$( printf "%05d"  $( get_loopcounter ) )

TODAY_LOG=`date +%Y-%m-%dT%H:%M`
if test $_ok -eq 0 
then
	echo "${prefix_created_at}${TODAY_LOG}, loop: $runningnumber" > $ARCHIVE_ROOT/${projectkey}_created_at_${TODAY_LOG}_number_$runningnumber.txt
else
	echo "${prefix_created_at}${TODAY_LOG}, loop: $runningnumber, errors in rsync, see log" > $ARCHIVE_ROOT/${projectkey}_created_at_${TODAY_LOG}_number_${runningnumber}_with_errors.txt
	dlog "bk_archive.sh ends with errors, see '${wf}/${RSYNC_LOG}'"
	tlog "end, error"
	exit $RSYNCFAILS
fi



echo "-- $TODAY_LOG, end backup from './${CONFFOLDER}/${ARCHIVE_CONFIG}' -- " >> ${wf}/${RSYNC_LOGFILE}
echo "-- $TODAY_LOG, end -- " >> ${wf}/${RSYNC_LOGFILE}


dlog "== end bk_archive.sh =="
tlog "end" 
#dlog "== RSYNCFAILS: $RSYNCFAILS,  end bk_archive.sh =="

exit 0 






