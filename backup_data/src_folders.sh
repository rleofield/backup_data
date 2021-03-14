# file: folders.sh
# bk_version 21.05.1
# included with 'source'

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


# 10 folders

# folder for rsnapshot configuration files
readonly CONFFOLDER="conf"

# folder for log of done backups
readonly intervaldonefolder="interval_done"

# folder for count if retains
# files to store count of retains for one retain value
# number of lines is used as count
readonly retainscountfolder="retains_count"


# folder for own rsnapshot logs
readonly rsynclogfolder="rsynclog"

# for test messages, send to PC-Desktop, if configured, see 'cfg.ssh_login'
readonly backup_messages_test="backup_messages_test"

# date of last backup per project 'label_projekt'
readonly done="done"
readonly donefolder="done"

# exclude files for rsync/rsnasphot
readonly exclude="exclude"

# storage for old daily logfiles, never deleted
readonly oldlogs="oldlogs"

# ssh tests to chcke if a remote host is alive and ready for backup
readonly pre="pre"

# files to store count of retains for one retain value
# number of lines is used as count
#readonly retains_count="retain_scount"



# EOF
