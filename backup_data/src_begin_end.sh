# file: src_begin_end.sh

# bk_version  26.01.1
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


# ./bk_main.sh  
#	./bk_disks.sh, all disks
#		./bk_loop.sh.   all projects in disk
#			./bk_project.sh, one project with 1-n folder trees
#				./bk_rsnapshot.sh,  do rsnapshot
#				./bk_archive, no snapshot, rsync only, files accumulated

# prefixes of variables in backup:
# bv_*  - global vars, alle files
# lv_*  - local vars, global in file
# lc_*  - local constants, global in file
# _*    - local in functions or loops
# BK_*  - exitcodes, upper case, BK_



# BK_PROJECT_BEGIN_FAILED=19
# BK_PROJECT_END_FAILED=20
# BK_DISK_BEGIN_FAILED=21
# BK_DISK_END_FAILED=22
# BK_MAIN_BEGIN_FAILED=23
# BK_MAIN_END_FAILED=24


# sourced after: src_folders.sh


function execute_begin_end {

	# in conf folder
	# shell script, executed at start  of main loop
	local script="$1"
	startendtestlog "script is: '$script'"
#	exists, not null, size > 0, is file, readable 
	if  test_normal_file "$script"
	then
		#  is file,readable, executable
		if  test_is_executable "$script"
		then
			dlog "'$script' found"
			eval ./$script
			local RET=$?
			sync
			#dlog "RET $RET"
			return $RET
		fi
		dlog "ERROR: '$script' is not executable"
		return 1
	fi
	startendtestlog "'$script' not found"
	# script is missing, is not an error
	return 0
}

# used in bk_disk.sh
function execute_main_end {
	# in conf folder
	# shell script, executed at end of main loop
	execute_begin_end  "$bv_conffolder/main_end.sh"
	return $?
}

# used in bk_main.sh
function execute_main_begin {
	# in conf folder
	# shell script, executed at start  of main loop
	execute_begin_end "$bv_conffolder/main_begin.sh" 
	return $?
}


# used in bk_loop.sh line 1132
function execute_project_begin  {
	local lpkey=$1
	execute_begin_end "$bv_conffolder/${lpkey}_begin.sh"
	return $?
}

# line 1292
function execute_project_end  {
	local lpkey=$1
	execute_begin_end "$bv_conffolder/${lpkey}_end.sh"
	return $?
}

# line  1313
function execute_disk_begin  {
	local disklabel=$1
	execute_begin_end "$bv_conffolder/${disklabel}_begin.sh" 
	return $?
}

# line 1361
function execute_disk_end  {
	local disklabel=$1
	execute_begin_end "$bv_conffolder/${disklabel}_end.sh" 
	return $?
}



# EOF

