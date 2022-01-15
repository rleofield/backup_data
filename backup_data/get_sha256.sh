#!/bin/bash - 
#===============================================================================
#
#          FILE: create_sha256.sh
# 
#         USAGE: ./create_sha256.sh 
# 
#   DESCRIPTION: creates sha256sum of all files 
# 
#       CREATED: 20.09.2021 11:23:42
#      REVISION: 22.01.1
#===============================================================================

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
src_ssh.sh
"

SHAFILE="sha256sum.txt.sh"
touch $SHAFILE
truncate -s 0 $SHAFILE



for _L in $LIST
do
	sha256sum  $_L >> $SHAFILE
done


