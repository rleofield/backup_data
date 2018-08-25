#!/bin/bash

# file: start_excecute.sh
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




# only place of STARTFOLDER

STARTFOLDER=/home/test/backup_data 
WORKINGFOLDER=$STARTFOLDER


# for github
echo "WORKINGFOLDER=$WORKINGFOLDER" > cfg.working_folder


wc=$( ps aux | grep execute_all.sh | grep -v grep | wc -l )
if [ $wc -gt 0 ]
then
       	echo "Backup is running, exit"	
	echo "==  end == "
	exit
fi

cd $STARTFOLDER
pwd

echo "Backup is not running, start in '$STARTFOLDER'"	
#exit




echo "nohup ./execute_all.sh  nohupexecute.out " 
nohup ./execute_all.sh > nohupexecute.out &


sync

#sleep 1

exit 0

