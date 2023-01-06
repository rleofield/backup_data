#!/bin/bash - 

# file: get_sha256.sh
# bk_version 23.01.1

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




#===============================================================================
#

set -o nounset                              # Treat unset variables as an error

LIST="
bk_archive.sh
bk_disks.sh
bk_loop.sh
bk_main.sh
bk_project.sh
bk_rsnapshot.sh
src_exitcodes.sh
src_filenames.sh
src_folders.sh
src_global_strings.sh
src_log.sh
"

SHAFILE="sha256sum.txt"
touch $SHAFILE
truncate -s 0 $SHAFILE



for _L in $LIST
do
	sha256sum  $_L >> $SHAFILE
done


