# file: ssh.sh
# version 20.08.1
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

#pwd
. ./cfg.ssh_login


# ssh functions for notify message
#	echo "pport $sshport" 

function sshport {
	local p="22"
	if [[ -n $sshport ]]
	then
		p=$sshport
	fi
  	echo $p
}

function do_ping_host {

        local _USER=$1
        local _HOST=$2
        local _FOLDER=$3
	local _PORT=$4
	
	if [ -z $_PORT ]
	then
		_PORT=22
	fi
#	dlog "in ping"
        ping -c1 $_HOST &> /dev/null
        if test $? -eq 0
        then
#		dlog "ping ok  ping -c1 $_HOST "
	 	sshstr="x=99; y=88; if test  -d $sshtargetfolder; then  exit 99; else exit 88; fi"	
		sshstr2="ssh -p $_PORT $_USER@$_HOST '${sshstr}'"
#		dlog "in ping sshstr2: $sshstr2"
                eval ${sshstr2}  &> /dev/null
                local _RET=$?
                if test  $_RET -eq 99; then
                        # host exists
                        return 0
                fi
        fi
        return 1


}

function do_sshnotifysend {
	local _temp=$1
	local p=$( sshport )
	local _temp2="rsync $_temp -e 'ssh -p $p' $sshlogin@$sshhost:$sshtargetfolder"
	eval ${_temp2}
	local _RET=$?
	return $_RET

}


function do_rm_notify_file_for_disk {
	local _f=$1
	local p=$( sshport )
        local _temp="ssh -p $p $sshlogin@${sshhost} 'rm ${sshtargetfolder}${_f}_*'"
	# ssh -p 4194 xxxxxx@hhhh 'rm /home/xxxxx/Desktop/backup_messages/Backup-HD_dluks_*'
        eval $_temp
        local _RET=$?
	return $_RET
}


