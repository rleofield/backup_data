#!/bin/bash


# file: del_logs.sh

# bk_version 21.05.1


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


. ./cfg.working_folder 
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./src_folders.sh


rm cc_log.log
rm stop

# loop disk list
for _disk in $DISKLIST
do
        PROJEKTLABELS=${a_projects[$_disk]}
        for p in $PROJEKTLABELS
        do
                lpkey=${_disk}_${p}
                echo "rm aa, rr, count, done with $lpkey"
		rm aa_${lpkey}.log
		rm rr_${lpkey}.log
		rm retains_count/${lpkey}_*
		rm $donefolder/${lpkey}_done.log
		rm interval_done/${lpkey}_done.txt

                echo "--------"
        done
done



