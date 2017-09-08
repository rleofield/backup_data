# arrays.sh


# file: arrays.sh

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



# keys for control a disk
# umount = disk is unmounted, for external USB
# xumount = disk stays at system, for internal disks
declare -A a_properties
a_properties['bluks']="xumount"


# sub projects per disk
declare -A a_projects
a_projects['bluks']="l0 l1 l2 btest1"
#a_projects['bluks']="btest1"


# time interval in minutes
# 1440 = 1 tag
declare -A a_interval
# days:hours:minutes
# hours:minutes
# minutes
a_interval['bluks_btest1']=7:14


# successarray
# successful projects listed in this order in file 'successloglines.txt' 
SUCCESSLINE="bluks:l0"
