# file: src_test_vars.sh
# bk_version 24.08.2
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

: << '--COMMENT--'
--COMMENT--



# ==
# == max fill of backupdisk in percent ==
# default = 70

# used in
#     bk_loop.sh: (3x)  maxdiskspacepercent=$bv_maxfillbackupdiskpercent
readonly bv_maxfillbackupdiskpercent=70



# ==
# == no_check_disk_done ==

# no check of done files in folder ./done
# default = 0

# checked in
#   bk_loop.sh:  (3x) if [ $bv_test_no_check_disk_done -eq 1 ]
readonly bv_test_no_check_disk_done=0


## hour loop and minute loop skipped if 0
# default = 1

# checked in
#   bk_disks.sh:   if [ $bv_test_check_looptimes -eq 1 ]
readonly bv_test_check_looptimes=1


#####################################
## execute loop one time and stops
#####################################

# ==
# == execute_once ==

# stops after one loop
# default = 0

#  bk_disks.sh:   if [ $bv_test_execute_once -eq 1 ]
readonly bv_test_execute_once=0


# ignore rsnapshot in loop
# default = 0
#  not used
#readonly bv_loop_test=0

# ==
# == do_once_count ==

# stops after count loops
# default = 0

# 'bv_test_execute_once' must be 1
#   bk_main.sh:   if [ $bv_test_do_once_count -gt 0 ]
#   bk_main.sh:   if [ $do_once_counter -lt $bv_test_do_once_count ]
readonly bv_test_do_once_count=0


#####################################
## shorten wait time in loop 
## bv_test_execute_once=0
#####################################

# ==
# == use_minute_loop ==

# 1 = use loop of one minute, not one hour
# 0 = use one hour loop
# default = 0

# used in
#   bk_disks.sh:   if [ $bv_test_use_minute_loop -eq 0 ]
#   bk_disks.sh:   if [ $bv_test_use_minute_loop -eq 1 ]
#   bk_loop.sh:    if [ $bv_test_use_minute_loop -eq 0 ]
readonly bv_test_use_minute_loop=0


# ==
# == short_minute_loop ==

# don't count seconds in minute loop, return immediately, needs 'bv_test_use_minute_loop'=1
# default = 0

# used in
#   bk_disks.sh:   if [ $bv_test_short_minute_loop -eq 0 ]
#   bk_disks.sh:   if [ $bv_test_short_minute_loop -eq 1 ]
readonly bv_test_short_minute_loop=0


# ==
# == short_minute_loop_seconds_10  ==

# dto for a 10 second interval
# 1 = use loop of 10 seconds, not one minute
# 
# 'bv_test_short_minute_loop' must be 0
# 'bv_test_use_minute_loop' must be 1
# default = 0

# used in
#   bk_disks.sh:   (2x)  if [ $bv_test_short_minute_loop_seconds_10 -eq 1 ]
readonly bv_test_short_minute_loop_seconds_10=0


# ==
# == minute_loop_duration ==


# minutes looptime 
# default = 2,  needs 'bv_test_use_minute_loop=1'

# used in 
#   bk_disks.sh:   mlooptime=$bv_test_minute_loop_duration
readonly bv_test_minute_loop_duration=2


# EOF

