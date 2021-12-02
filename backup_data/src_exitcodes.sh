
# file exitcodes.sh 
# bk_version 21.11.1
# included with 'source'

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
#


# call chain:
# ./bk_main.sh, runs forever
#       ./bk_disks.sh,   all disks,  <- this file
#               ./bk_loop.sh    all projects in disk
#                       ./bk_project.sh, one project with 1-n folder trees
#                               ./bk_rsnapshot.sh,  do rsnapshot
#                               ./bk_archive.sh,    no history, rsync only


# used in bk_disks.sh
# ARRAYSNOK             1
# DISKLABELNOTFOUND     3
# DISKNOTUNMOUNTED      4
# MOUNTDIRTNOTEXIST     5
# DISKNOTMOUNTED        7
# RSYNCFAILS            8
# NOINTERVALSET         9



readonly SUCCESS=0

# used in bk_projects.sh, line 91 
#   after check of existence of 'a_properties', 'a_projects', 'a_interval' in cfg.projects
#   reason: one of the arrays is wrong
readonly ARRAYSNOK=1  # exit, but checked in 'bk_disks.sh'

# not used
# MEDIAMOUNT  couldn_t_unmounted=1

# used in 'bk_loop.sh', line 441, 
#   exit and checked  in 'bk_disks.sh'
#   reason: disk not found in '/dev/disk/by-uuid'
#     after if [[ $goodlink -eq 0 ]]
readonly DISKLABELNOTFOUND=3

# evaluated in main_loop.sh,but not set 
# set in bk_loop.sh
readonly DISKNOTUNMOUNTED=4
readonly MOUNTDIRTNOTEXIST=5
readonly TIMELIMITNOTREACHED=6
readonly DISKNOTMOUNTED=7




# set in bk_rsnapshot.sh
# evaluated in bk_project.sh and set again in bk_project.sh
readonly RSYNCFAILS=8


# used in bk_project.sh
readonly NOINTERVALSET=9

# no rsnapshotroot 
# evaluated in bk_project.sh, set again in bk_project.sh
readonly NORSNAPSHOTROOT=12

# set, when rsync finds disk is full
readonly DISKFULL=13

# set, when disk has't enough space
readonly FREEDISKSPACETOOSMALL=15

# no folder 'rsnapshot' in working dir
readonly NOFOLDERRSNAPSHOT=14

# normal loop, end disks loop
readonly NORMALDISKLOOPEND=99


readonly FATAL=255


# in is_stopped.sh only

readonly WAITING=100  # used in is_stopped
# in is_stopped.sh and main_loop.sh
readonly STOPPED=101
readonly EXECONCESTOPPED=102

readonly WAITINTERVAL=103 
readonly WAITEND=104

# only used is RUNNING
readonly RUNNING=105

# only in project.sh, at not used place
readonly ERRORINCOUNTERS=106



readonly text_marker="--- marker ---"

readonly text_backup_stopped="backup stopped"  # used in 'check_stop' in 'bk_disks.sh'
readonly text_stop_exit="backup exits with error"  # used 'stop_exit' in 'bk_disks.sh'

	# used in 'bk_disks', 522, 538, if loop is in wait interval, calls 'check_stop wait interval loop' if in interval
	# used in is_stopped.sh, exit $WAITINTERVAL=102
readonly text_wait_interval_reached="wait interval reached"  

	# used in 'bk_disks', 5508, only shirt info aboute end if interval in log, no stop
readonly text_waittime_end="waittime end"  # used in 'bk_disks.sh', 550, after wait time loop

	# used in 'bk_disks.sh', 570, after end of main loop
	# used in 'is_stopped.sh', 58, exit $WAITING=100 
readonly text_marker_waiting="--- marker waiting ---"


	# used in bk_main.sh:191:     '$do_once_counter = $do_once_count' 
	# used in bk_main.sh:227:     dlog "$text_marker_stop, end reached, start backup again with './start_backup.sh"
	# used in bk_main.sh:237: test only,  dlog "$text_marker_stop, end reached, execute_once "
	# used in is_stopped.sh:62:   vtest="$text_marker_stop", exit STOPPED=101
readonly text_marker_stop="--- marker stopped ---"


	# used ins bk_main, 216, after $internalerrorstxt length is not 0, shows internal errors (rsync, rsnapshot)
	# used in is_stopped.sh   exit FATAL=255
readonly text_marker_error="--- marker end, error ---"
readonly text_marker_error_in_waiting="--- marker waiting, error ---"
readonly text_marker_error_in_stop="--- marker stop, error ---"

	# used in loop, if $do_once_counter -gt 0 and $do_once_counter is not reached
	# not used in is_stopped.sh
readonly text_marker_test_counter="--- test with counter is running ---"


readonly text_marker_end="--- marker end ---" # not used


# all 
# NORMALDISKLOOPEND=99
# WAITING=100
# STOPPED=101
# EXECONCESTOPPED=102
# WAITINTERVAL=103
# WAITEND=104
# RUNNING=105
# ERRORINCOUNTERS=106
# FATAL=255


# EOF

