# file: scr_filenames.sh
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


# text file for success and unsuccess
readonly bv_successarray_tempfile="tempfile_successarray.txt"
readonly bv_unsuccessarray_tempfile="tempfile_unsuccessarray.txt"
readonly bv_internalerrors="errors.txt"

# in bk_disks.sh
# readonly successloglinestxt="successloglines.txt"


readonly bv_notifyfileprefix="Backup-HD"
readonly bv_createdatfileprefix="created_at_"



# now in bk_disks.sh
readonly bv_executedprojectsfile="tempfile_executedprojects.txt"

# in cron_start_backup.sh
# in bk_main

# arrays in cfg.projects
readonly bk_arr_properties="a_properties"
readonly bk_arr_projects="a_projects"
readonly bk_arr_interval="a_interval"
readonly bk_arr_targetdisk="a_targetdisk"
readonly bk_arr_waittime="a_waittime"
#readonly bk_arr_test="a_test"
#readonly bk_arr_cfglist="$bk_arr_properties $bk_arr_projects $bk_arr_interval $bk_arr_targetdisk $bk_arr_waittime $bk_arr_test"
readonly bk_arr_cfglist="$bk_arr_properties $bk_arr_projects $bk_arr_interval $bk_arr_targetdisk $bk_arr_waittime"



# EOF

