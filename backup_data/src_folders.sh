# file: src_folders.sh

# bk_version 26.01.1
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


# 8 folder

# 1. folder for rsnapshot configuration files
readonly bv_conffolder="conf"

# 2. folder for log of done backups
readonly bv_intervaldonefolder="interval_done"

# 3. folder for count if retains
# files to store count of retains for one retain value
# number of lines is used as count
readonly bv_retainscountfolder="retains_count"

# 4. for test messages, send to PC-Desktop, if configured, see 'cfg.ssh_login'
readonly bv_backup_messages_testfolder="backup_messages_test"

# 5. date of last backup per project 'label_projekt'
readonly bv_donefolder="done"

# 6. bv_excludefolder files for rsync/rsnasphot
readonly bv_excludefolder="exclude"

# 7. storage for old daily logfiles, never deleted
readonly bv_oldlogsfolder="oldlogs"

# 8. ssh tests to check, if a remote host is alive and ready for backup
readonly bv_preconditionsfolder="pre"

# list of all folders
# 1. $bv_conffolder 
# 2. $bv_intervaldonefolder 
# 3. $bv_retainscountfolder 
# 4. $bv_backup_messages_testfolder 
# 5. $bv_donefolder 
# 6. $bv_excludefolder 
# 7. $bv_oldlogsfolder 
# 8. $bv_preconditionsfolder

readonly bv_folderlist="\
$bv_conffolder \
$bv_intervaldonefolder \
$bv_retainscountfolder \
$bv_backup_messages_testfolder \
$bv_donefolder \
$bv_excludefolder \
$bv_oldlogsfolder \
$bv_preconditionsfolder"



# EOF
