#!/bin/bash

# file: ping_host
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



. ./cfg.ssh_login
. ./src_log.sh
#. ./src_ssh.sh

lv_cc_logname="ping"

function do_ping_host {

	local _USER=$1
	local _HOST=$2
        local _FOLDER=$3
        local _PORT=$4

        if [ -z $_PORT ]
        then
                _PORT=22
        fi
#	dlog "in ping, host: $_HOST"

        ping -c1 $_HOST &> /dev/null
        if test $? -eq 0
        then
#		dlog "ping ok  ping -c1 $_HOST "
                sshstr="x=99; y=88; if test  -d $sshtargetfolder; then  exit 99; else exit 88; fi"
                sshstr2="ssh -p $_PORT $_USER@$_HOST '${sshstr}'"
#		dlog "in ping sshstr2: $sshstr2"
                eval ${sshstr2}  &> /dev/null
                local _RET=$?
#		dlog "ping ret: $_RET"
                if test  $_RET -eq 99; then
                        # host exists
                        return 0
                fi
        fi
        return 1
}


function func_sshport {
        local p="22"
        if [[ -n $sshport ]]
        then
                p=$sshport
        fi
        echo $p
}

if [ ${sshhost} = "localhost" ]
then
	echo "is localhost"
	exit
fi
if [ ${sshhost} = "127.0.0.1" ]
then
	echo "is 127.0.0.1"
	exit
fi

p=$( func_sshport )
#echo "do_ping_host, login: ${sshlogin}, host: ${sshhost}, folder: ${sshtargetfolder} ${p}"
do_ping_host ${sshlogin} ${sshhost} ${sshtargetfolder} ${sshport}
RET=$?
if [ $RET -eq 0 ]
then
	echo "ok"
else
	echo "nok"
fi

# EOF


