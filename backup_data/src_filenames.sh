# file: scr_filenames.sh

# bk_version 26.04.1
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

# prefixes of variables in backup:
# bv_*   - global vars, alle files
# lv_*   - local vars, global in file
# lc_*  - local constants, global in file
# _*     - local in functions or loops
# BK_*   - exitcodes, upper case, BK_
# cfg_*  - set in cfg.* file_




# == daily_rotate ==
# default = 1,  =  rotate logs
# checked in bk_main.sh:265:    "if [ $bv_daily_rotate -eq 1 ]"
readonly bv_daily_rotate=1



# text file for success and unsuccess
# used in bk_disks.sh
# used in bk_loop.sh
readonly bv_successarray_tempfile="tempfile_successarray.txt"
readonly bv_unsuccessarray_tempfile="tempfile_unsuccessarray.txt"

# used in bk_loop.sh
# used in bk_main.sh
# used in bk_disks.sh
readonly bv_internalerrors="errors.txt"

# used in bk_disks.sh
# used in bk_main.sh
readonly bv_stopfile="stop"

# used in bk_loop.sh
readonly bv_notifyfileprefix="Backup-HD"

# used in bk_project.sh
# used in bk_rsnapshot.sh
readonly bv_createdatfileprefix="created_at_"



# now in bk_disks.sh
# var is used in bk_loop.sh, bk_disks.sh
readonly bv_executedprojectsfile="tempfile_executedprojects.txt"

# in bk_main

# 5 arrays in cfg.projects
#readonly bk_arr_properties="a_properties"
#readonly bk_arr_projects="a_projects"
#readonly bk_arr_interval="a_interval"
#readonly bk_arr_targetdisk="a_targetdisk"
#readonly bk_arr_waittime="a_waittime"
#readonly bk_arr_cfglist="$bk_arr_properties $bk_arr_projects $bk_arr_interval $bk_arr_targetdisk $bk_arr_waittime"



# EOF

