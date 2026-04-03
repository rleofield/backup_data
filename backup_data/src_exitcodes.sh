
# file exitcodes.sh 

# bk_version  26.04.1
# included with 'source'

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
#


# call chain:
# ./bk_main.sh, runs forever
#       ./bk_disks.sh,   all disks,  <- this file
#               ./bk_loop.sh    all projects in disk
#                       ./bk_project.sh, one project with 1-n folder trees
#                               ./bk_rsnapshot.sh,  do rsnapshot
#                               ./bk_archive.sh,    no history, rsync only

# prefixes of variables in backup:
# bv_*   - global vars, alle files
# lv_*   - local vars, global in file
# lc_*  - local constants, global in file
# _*     - local in functions or loops
# BK_*   - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_



readonly BK_SUCCESS=0
readonly BK_ARRAYSOK=0


# bash max return code is 125
# 126-255 is reserved
# https://flokoe.github.io/bash-hackers-wiki/scripting/basics/#exit-codes
readonly BK_FATAL=125


# disklabel was not given in call of script
readonly BK_DISKLABELNOTGIVEN=2


# used in 'bk_loop.sh', line 441, 
#   exit and checked  in 'bk_disks.sh'
#   reason: disk not found in '/dev/disk/by-uuid'
#     after if [[ $goodlink -eq 0 ]]
readonly BK_DISKLABELNOTFOUND=3

# evaluated in main_loop.sh, but not set 
# used in bk_loop.sh
readonly BK_DISKNOTUNMOUNTED=4
readonly BK_MOUNTDIRTNOTEXIST=5
readonly BK_TIMELIMITNOTREACHED=6
readonly BK_DISKNOTMOUNTED=7


# used in bk_rsnapshot.sh
# evaluated in bk_project.sh and set again in bk_project.sh
readonly BK_RSYNCFAILS=10

# used in bk_project.sh
readonly BK_NOINTERVALSET=11

# no rsnapshotroot 
# used in bk_rsnapshot.sh, set again in bk_project.sh
readonly BK_NORSNAPSHOTROOT=12

# set, when rsync finds disk is full, 'No space left on device' in log
readonly BK_DISKFULL=13

# rsnapshot rotate fails
readonly BK_ROTATE_FAILS=14

# used, when disk hasn't enough space
readonly BK_FREEDISKSPACETOOSMALL=15

# used, when remote source vanished
readonly BK_CONNECTION_UNEXPECTEDLY_CLOSED=16


# used, when $lv_cc_logname is empty
# $lv_cc_logname must be set at start of each bk_ file
readonly BK_DLOG_CC_LOGNAME_NOT_SET=17


readonly BK_DISK_IS_NOT_SET_IN_CONF=18

# do not execute bk_loop. with snapshot.
# return with 0 and logentry
readonly BK_LOOP_TEST_RETURN=20
readonly BK_DISK_TEST_RETURN=21

# if project_begin.sh or project_end.sh fails
readonly BK_PROJECT_BEGIN_FAILED=30
readonly BK_PROJECT_END_FAILED=31
readonly BK_DISK_BEGIN_FAILED=32
readonly BK_DISK_END_FAILED=33
readonly BK_MAIN_BEGIN_FAILED=34
readonly BK_MAIN_END_FAILED=35
readonly BK_PROJECT_DONE_REACHED=36
readonly BK_PROJECT_DONE_NOT_REACHED=37
readonly BK_PROJECT_DONE_WAITINTERVAL_REACHED=38



# associative arrays, values from 40 and more
#            associative
readonly BK_ASSOCIATIVE_ARRAY_EXISTS=40
readonly BK_ASSOCIATIVE_ARRAY_NOT_EXISTS=41
readonly BK_ASSOCIATIVE_ARRAY_IS_EMPTY=42
readonly BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY=43
readonly BK_ASSOCIATIVE_ARRAY_IS_OK=$BK_SUCCESS

# indexed arrays, values from 50 and more
#           indexed
readonly BK_INDEXED_ARRAY_EXISTS=50
readonly BK_INDEXED_ARRAY_NOT_EXISTS=51
readonly BK_INDEXED_ARRAY_IS_EMPTY=52
readonly BK_INDEXED_ARRAY_IS_NOT_EMPTY=53
readonly BK_INDEXED_ARRAY_IS_OK=$BK_SUCCESS



# in bk_main.sh check_arrays
# script is stopped. if arrays wre wrong
readonly BK_ARRAYSNOK=55

# normal loop, end disks loop
readonly BK_NORMALDISKLOOPEND=60

# in is_stopped.sh only
# values from 70 and more
readonly BK_WAITING=70
readonly BK_STOPPED=71
readonly BK_EXECONCESTOPPED=72
readonly BK_WAITINTERVAL=73
readonly BK_WAITEND=74
readonly BK_RUNNING=75

# 
readonly BK_ERRORINCOUNTERS=80

#########################
#  text messages
readonly text_project_begin_failed="project begin failed"
readonly text_project_end_failed="project end failed"
readonly text_disk_begin_failed="tx disk begin failed"
readonly text_disk_end_failed="disk end failed"
readonly text_main_begin_failed="main begin failed"
readonly text_main_end_failed="main end failed"

readonly text_marker="--- marker ---"

# used in 'check_stop' in 'bk_disks.sh'
readonly text_backup_stopped="backup stopped"  

# used 'stop_exit' in 'bk_disks.sh'
readonly text_stop_exit="backup exits with error"  

# used in 'bk_disks', if loop is in wait interval, calls 'check_stop wait interval loop' if in interval
# used in is_stopped.sh, exit $BK_WAITINTERVAL=102
readonly text_wait_interval_reached="wait interval reached"  

# used in 'bk_disks', only short info about end, if interval in log, no stop
# used in 'bk_disks.sh', 550, after wait time loop
readonly text_waittime_end="waittime end"  

# used in 'bk_disks.sh', after end of main loop
# used in 'is_stopped.sh', exit $BK_WAITING=100 
readonly text_marker_waiting="--- waiting ---"


# used in bk_main.sh:     '$do_once_counter = $bv_test_do_once_count' 
# used in bk_main.sh:     dlog "$text_marker_stop, end reached, start backup again with './start_backup.sh"
# used in bk_main.sh:     test only,  dlog "$text_marker_stop, end reached, bv_test_execute_once "
# used in is_stopped.sh:  vtest="$text_marker_stop", exit BK_STOPPED=101
readonly text_marker_stop="--- stopped ---"
readonly text_do_once_count_reached="$text_marker_stop, end, bv_test_do_once_count loops reached"


# used ins bk_main, after $bv_internalerrors length is not 0, 
#  shows internal errors (rsync, rsnapshot)
# used in is_stopped.sh   exit BK_FATAL
readonly text_marker_error="--- end, error     ---"
readonly text_marker_error_in_waiting="--- waiting, error ---"
readonly text_marker_error_in_stop="--- stop, error    ---"

# used in loop, if $do_once_counter -gt 0 and $do_once_counter is not reached
# not used in is_stopped.sh
readonly text_marker_test_counter="--- test with counter is running ---"


# not used
readonly text_marker_end="--- marker end ---" 


# all in 'is_stopped.sh'
# BK_NORMALDISKLOOPEND=
# BK_WAITING
# BK_STOPPED
# BK_EXECONCESTOPPED
# BK_WAITINTERVAL
# BK_WAITEND
# BK_RUNNING
# BK_ERRORINCOUNTERS
# BK_FATAL




# all
: <<exit_code_comment
BK_SUCCESS=0
BK_ARRAYSOK=0
BK_FATAL=125

BK_DISKLABELNOTGIVEN=2
BK_DISKLABELNOTFOUND=3
BK_DISKNOTUNMOUNTED=4
BK_MOUNTDIRTNOTEXIST=5
BK_TIMELIMITNOTREACHED=6
BK_DISKNOTMOUNTED=7

BK_RSYNCFAILS=10
BK_NOINTERVALSET=11
BK_NORSNAPSHOTROOT=12
BK_DISKFULL=13
BK_ROTATE_FAILS=14
BK_FREEDISKSPACETOOSMALL=15
BK_CONNECTION_UNEXPECTEDLY_CLOSED=16
BK_DLOG_CC_LOGNAME_NOT_SET=17
BK_DISK_IS_NOT_SET_IN_CONF=18

BK_LOOP_TEST_RETURN=20
BK_DISK_TEST_RETURN=21

BK_PROJECT_BEGIN_FAILED=30
BK_PROJECT_END_FAILED=31
BK_DISK_BEGIN_FAILED=32
BK_DISK_END_FAILED=33
BK_MAIN_BEGIN_FAILED=34
BK_MAIN_END_FAILED=35
BK_PROJECT_DONE_REACHED=36
BK_PROJECT_DONE_NOT_REACHED=37
BK_PROJECT_DONE_WAITINTERVAL_REACHED=38

BK_ASSOCIATIVE_ARRAY_EXISTS=40
BK_ASSOCIATIVE_ARRAY_NOT_EXISTS=41
BK_ASSOCIATIVE_ARRAY_IS_EMPTY=42
BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY=43
BK_ASSOCIATIVE_ARRAY_IS_OK=$BK_SUCCESS

BK_INDEXED_ARRAY_EXISTS=50
BK_INDEXED_ARRAY_NOT_EXISTS=51
BK_INDEXED_ARRAY_IS_EMPTY=52
BK_INDEXED_ARRAY_IS_NOT_EMPTY=53
BK_INDEXED_ARRAY_IS_OK=$BK_SUCCESS
BK_ARRAYSNOK=55

BK_NORMALDISKLOOPEND=60

BK_WAITING=70
BK_STOPPED=71
BK_EXECONCESTOPPED=72
BK_WAITINTERVAL=73
BK_WAITEND=74
BK_RUNNING=75

BK_ERRORINCOUNTERS=80
exit_code_comment


: <<msg_string_comment
readonly text_project_begin_failed="project begin failed"
readonly text_project_end_failed="project end failed"
readonly text_disk_begin_failed="tx disk begin failed"
readonly text_disk_end_failed="disk end failed"
readonly text_main_begin_failed="main begin failed"
readonly text_main_end_failed="main end failed"
readonly text_marker="--- marker ---"
readonly text_backup_stopped="backup stopped"  
readonly text_stop_exit="backup exits with error"  
readonly text_wait_interval_reached="wait interval reached"  
readonly text_waittime_end="waittime end"  
readonly text_marker_waiting="--- waiting ---"
readonly text_marker_stop="--- stopped ---"
readonly text_marker_error="--- end, error     ---"
readonly text_marker_error_in_waiting="--- waiting, error ---"
readonly text_marker_error_in_stop="--- stop, error    ---"
readonly text_marker_test_counter="--- test with counter is running ---"
readonly text_marker_end="--- marker end ---" 

msg_string_comment

# EOF

