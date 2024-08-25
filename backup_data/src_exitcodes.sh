
# file exitcodes.sh 
# bk_version 24.08.1
# included with 'source'

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
#


# call chain:
# ./bk_main.sh, runs forever
#       ./bk_disks.sh,   all disks,  <- this file
#               ./bk_loop.sh    all projects in disk
#                       ./bk_project.sh, one project with 1-n folder trees
#                               ./bk_rsnapshot.sh,  do rsnapshot
#                               ./bk_archive.sh,    no history, rsync only


# used in bk_disks.sh

# BK_SUCCESS=0
# BK_ARRAYSNOK=1  # exit, but checked in 'bk_disks.sh'
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
# BK_DLOG_CC_LOGNAME_NOT_SET=17
# BK_LOOP_TEST_RETURN=18


# BK_NORMALDISKLOOPEND=99

# BK_FATAL=255


readonly BK_SUCCESS=0

# used in bk_projects.sh, line 91 
#   after check of existence of 'a_properties', 'a_projects', 'a_interval' in cfg.projects
#   reason: one of the arrays is wrong
readonly BK_ARRAYSNOK=1  # exit, but checked in 'bk_disks.sh'

# disklabel was not given in call of script
readonly BK_DISKLABELNOTGIVEN=2


# used in 'bk_loop.sh', line 441, 
#   exit and checked  in 'bk_disks.sh'
#   reason: disk not found in '/dev/disk/by-uuid'
#     after if [[ $goodlink -eq 0 ]]
readonly BK_DISKLABELNOTFOUND=3

# evaluated in main_loop.sh,but not set 
# set in bk_loop.sh
readonly BK_DISKNOTUNMOUNTED=4
readonly BK_MOUNTDIRTNOTEXIST=5
readonly BK_TIMELIMITNOTREACHED=6
readonly BK_DISKNOTMOUNTED=7


# set in bk_rsnapshot.sh
# evaluated in bk_project.sh and set again in bk_project.sh
readonly BK_RSYNCFAILS=8

# used in bk_project.sh
readonly BK_NOINTERVALSET=9

# no rsnapshotroot 
# evaluated in bk_rsnapshot.sh, set again in bk_project.sh
readonly BK_NORSNAPSHOTROOT=12

# set, when rsync finds disk is full, 'No space left on device' in log
readonly BK_DISKFULL=13

# rsnapshot rotate fails
readonly BK_ROTATE_FAILS=14

# set, when disk has't enough space
readonly BK_FREEDISKSPACETOOSMALL=15

# set, when remote source vanished
readonly BK_CONNECTION_UNEXPECTEDLY_CLOSED=16


# set, when $lv_cc_logname is empty
# $lv_cc_logname must be set at start of each bk_ file
readonly BK_DLOG_CC_LOGNAME_NOT_SET=17


# do not execute bk_loop. with snapshot.
# return with 0 and logentry
readonly BK_LOOP_TEST_RETURN=18



# associative arrays, values from 50 and more
#            associative
readonly BK_ASSOCIATIVE_ARRAY_EXISTS=50
readonly BK_ASSOCIATIVE_ARRAY_NOT_EXISTS=51
readonly BK_ASSOCIATIVE_ARRAY_IS_EMPTY=52
readonly BK_ASSOCIATIVE_ARRAY_IS_NOT_EMPTY=53
readonly BK_ASSOCIATIVE_ARRAY_IS_OK=$BK_SUCCESS

# indexed arrays, values from 60 and more
#           indexed
readonly BK_INDEXED_ARRAY_EXISTS=60
readonly BK_INDEXED_ARRAY_NOT_EXISTS=61
readonly BK_INDEXED_ARRAY_IS_EMPTY=62
readonly BK_INDEXED_ARRAY_IS_NOT_EMPTY=63
readonly BK_INDEXED_ARRAY_IS_OK=$BK_SUCCESS



readonly BK_FATAL=255


# normal loop, end disks loop
readonly BK_NORMALDISKLOOPEND=99

# in is_stopped.sh only
# values from 100 and more
readonly BK_WAITING=100
readonly BK_STOPPED=101
readonly BK_EXECONCESTOPPED=102
readonly BK_WAITINTERVAL=103
readonly BK_WAITEND=104
readonly BK_RUNNING=105

# 
readonly BK_ERRORINCOUNTERS=106



readonly text_marker="--- marker ---"

readonly text_backup_stopped="backup stopped"  # used in 'check_stop' in 'bk_disks.sh'
readonly text_stop_exit="backup exits with error"  # used 'stop_exit' in 'bk_disks.sh'

# used in 'bk_disks', if loop is in wait interval, calls 'check_stop wait interval loop' if in interval
# used in is_stopped.sh, exit $BK_WAITINTERVAL=102
readonly text_wait_interval_reached="wait interval reached"  

# used in 'bk_disks', only short info about end, if interval in log, no stop
readonly text_waittime_end="waittime end"  # used in 'bk_disks.sh', 550, after wait time loop

# used in 'bk_disks.sh', after end of main loop
# used in 'is_stopped.sh', exit $BK_WAITING=100 
readonly text_marker_waiting="--- waiting ---"


# used in bk_main.sh:     '$do_once_counter = $bv_test_do_once_count' 
# used in bk_main.sh:     dlog "$text_marker_stop, end reached, start backup again with './start_backup.sh"
# used in bk_main.sh:     test only,  dlog "$text_marker_stop, end reached, bv_test_execute_once "
# used in is_stopped.sh:  vtest="$text_marker_stop", exit BK_STOPPED=101
readonly text_marker_stop="--- stopped ---"


# used ins bk_main, after $bv_internalerrors length is not 0, shows internal errors (rsync, rsnapshot)
# used in is_stopped.sh   exit BK_FATAL=255
readonly text_marker_error="--- end, error     ---"
readonly text_marker_error_in_waiting="--- waiting, error ---"
readonly text_marker_error_in_stop="--- stop, error    ---"

# used in loop, if $do_once_counter -gt 0 and $do_once_counter is not reached
# not used in is_stopped.sh
readonly text_marker_test_counter="--- test with counter is running ---"


readonly text_marker_end="--- marker end ---" # not used


# all in is_stopped.sh
# BK_NORMALDISKLOOPEND=99
# BK_WAITING=100
# STOPPED=101
# BK_EXECONCESTOPPED=102
# BK_WAITINTERVAL=103
# BK_WAITEND=104
# BK_RUNNING=105
# BK_ERRORINCOUNTERS=106
# BK_FATAL=255


# EOF

