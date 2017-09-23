# included with 'source'

# file: ssh_login.sh


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


# ssh login for notify message
readonly sshhost="server"
readonly sshlogin="rleofield"
readonly sshtargetfolder="/home/$sshlogin/Desktop/backup_messages/"
readonly notifytargetsend="$sshlogin@$sshhost:$sshtargetfolder"
readonly notifytargetremovestring="ssh $sshlogin@$sshhost"
