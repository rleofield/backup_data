#!/bin/bash

# --------------------------------------------------------------------------
# Copyright 2015 by Richard Albrecht
# richard.albrecht@rleofield.de
# www.rleofield.de
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#------------------------------------------------------------------------------


# 

. ./arrays.sh



RSNAPSHOTS="${!a_interval[*]}"

WORKINGDIR="/home/rleo/bin/backup_data"

cd  ${WORKINGDIR}
 


CONFFOLDER="${WORKINGDIR}/conf"


for RSNAPSHOT in ${RSNAPSHOTS}
do
	echo "======"
	echo "$RSNAPSHOT"
	cfg="$CONFFOLDER/${RSNAPSHOT}.conf"
	RSNAPSHOT_ROOT=$(cat ${cfg} | grep ^snapshot_root | awk '{print $2}')
	echo "root folder: $RSNAPSHOT_ROOT"

	cat ${cfg} | grep ^retain 
	cat ${cfg} | grep ^backup 
		
done
echo ""
echo "DISKLIST"
cat target_disk_list.sh | grep -v '#' | grep DISKLIST
echo "a_projects"
cat arrays.sh | grep -v declare | grep a_projects
echo "a_interval"
cat arrays.sh | grep -v declare | grep -v pdiff | grep a_interval

	



