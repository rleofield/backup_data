
# file exitcodes.sh 
# version 20.08.1
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



SUCCESS=0

# used in disk.sh, at start
# not evaluated
ARRAYSNOK=1


# used in disk.sh, at line  560
# not evaluated
MEDIAMOUNTcouldn_t_unmounted=1

# used in disk.sh, evaluated in main_loop,  
DISKLABELNOTFOUND=3
# evaluated in main_loop.sh,but not set
DISKNOTUNMOUNTED=4
MOUNTDIRTNOTEXIST=5
TIMELIMITNOTREACHED=6
DISKNOTMOUNTED=7




# set in bk_rsnapshot.sh
# evaluated in bk_project.sh and set again in bk_project.sh
RSYNCFAILS=8


# used in bk_project.sh
NOINTERVALSET=9

# no rsnapshotroot = NORSNAPSHOTROOT=12
# evaluatesd in bk_project.sh, set again in bk_project.sh
NORSNAPSHOTROOT=12


# in is_stopped.sh only
WAITING=100
WAITINTERVAL=102
WAITEND=104
RUNNING=105


# in is_stopped.sh and main_loop.sh
STOPPED=101

# only in project.sh, at not used place
ERRORINCOUNTERS=106

# in is_stopped.sh and main_loop.sh
readonly text_ready="waiting, backup ready"
readonly text_stopped="backup stopped"
readonly text_stop_exit="backup exits with error"
readonly text_interval="wait interval reached"
readonly text_waittime_end="waittime end"
readonly text_marker="--- marker ---"



