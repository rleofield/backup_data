#!/bin/bash

# file: excecute_all.sh
# version 18.08.1


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

cd $WORKINGFOLDER


fullfile=$0


filename=$(basename "$fullfile")
filename="${filename%.*}"
#filename="${fullfile##*/}"


. ./lib.logger

datelog ""
datelog "========================"
datelog "===  start of backup ==="
datelog "========================"



echo "pidcount=$(  pgrep -u $USER   $filename | wc -l )"
pidcount=$(  pgrep -u $USER   $filename | wc -l )
                                                                      
# pid appears twice, because of the subprocess finding the pid
if [ $pidcount -lt 3 ]
then
        datelog "'$filename' is not running" 
    else
        datelog "'$filename' is running, exit"
        exit 1
fi



while true
do

	./main_loop.sh
	RET=$?

	if test $RET -eq 1 
	then
		exit 1
	fi

done

# end

datelog "execute loop: shouldn't be reached"
exit 0





