# file: src_test_vars.sh
# bk_version 21.09.1
# included with 'source'

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




# 1 = use
# 0 = don't use



# ==
# == max fill of backupdisk in percent ==
# default = 90

# used in
#     bk_disks.sh:405:        maxfree=$maxfillbackupdiskpercent
#     bk_loop.sh:717: dsmaxfree=$maxfillbackupdiskpercent
#     bk_loop.sh:793:         _maxfree=$maxfillbackupdiskpercent
#     bk_loop.sh:1046:maxfree=$maxfillbackupdiskpercent
readonly maxfillbackupdiskpercent=90



# ==
# == no_check_disk_done ==

# no check of done files in folder ./done
# default = 0

# checked in
#    bk_loop.sh:360: if [ $no_check_disk_done -eq 1 ]
#    bk_main.sh:101: if [ $no_check_disk_done -eq 1 ]
readonly no_check_disk_done=0

## hour loop and minute loop skipped if 0
# in bk_disks.sh:693:                if [ $check_looptimes -eq 1 ]

# default = 1
readonly check_looptimes=1


#####################################
## execute loop one time and stops
#####################################

# ==
# == execute_once ==

# stops after one loop
# default = 0
readonly execute_once=0



# ==
# == do_once_count ==


# stops after count loops
# default = 0

# 'execute_once' must be 1
#  only in 'bk_main'
readonly do_once_count=0


#####################################
## shorten wait time in loop 
## execute_once=0
#####################################

# ==
# == use_minute_loop ==

# 1 = use loop of one minute, not one hour
# 0 = use one hour loop
# default = 0
readonly use_minute_loop=0


# ==
# == short_minute_loop ==

# don't count seconds in minute loop, return immediately, needs use_minute_loop=1
# default = 0
readonly short_minute_loop=0


# ==
# == short_minute_loop_seconds_10  ==

# dto for a 10 second interval
# 1 = use loop of 10 seconds, not one minute
# 
# 'short_minute_loop' must be 0
# 'use_minute_loop' must be 1
# default = 0
readonly short_minute_loop_seconds_10=0


# ==
# == minute_loop_duration ==


# minutes looptime 
# default = 2,  needs 'use_minute_loop=1'

readonly minute_loop_duration=2



# ==
# == daily_rotate ==

# do daily rotate
# default = 1, rotate logs
# checked in
# bk_disks.sh:338:        if [ $daily_rotate -eq 1 ]
# bk_main.sh:111: if [ $daily_rotate -eq 1 ]

readonly daily_rotate=1


# EOF

