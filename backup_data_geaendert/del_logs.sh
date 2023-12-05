#!/bin/bash


# file: del_logs.sh

# bk_version 23.12.1



# Copyright (C) 2017-2023 Richard Albrecht
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


echo "don't execute, not ready"
exit 1

. ./cfg.working_folder 
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects
. ./src_folders.sh


rm cc_log.log
rm stop

readonly bv_disklist=$DISKLIST

# loop disk list
for _disk in $bv_disklist
do
        PROJEKTLABELS=${a_projects[$_disk]}
        for p in $PROJEKTLABELS
        do
                lpkey=${_disk}_${p}
                echo "rm aa, rr, count, done with $lpkey"
	echo "rm aa_${lpkey}.log"
	echo "rm rr_${lpkey}.log"
	echo "rm $bv_retainscountfolder/${lpkey}_*"
	echo "rm $bv_donefolder/${lpkey}_done.log"
	echo "rm $bv_intervaldonefolder/${lpkey}_done.txt"

                echo "--------"
        done
done


# EOF

