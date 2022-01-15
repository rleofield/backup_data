#!/bin/bash

# file: ping_host
# bk_version 22.01.1


# Copyright (C) 2021 Richard Albrecht
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



. ./src_log.sh
. ./src_ssh.sh

lv_cc_logname="ping"

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
echo "do_ping_host, login: ${sshlogin}, host: ${sshhost}, folder: ${sshtargetfolder} ${p}"
do_ping_host ${sshlogin} ${sshhost} ${sshtargetfolder} ${sshport}
RET=$?
if [ $RET -eq 0 ]
then
	echo "ok"
else
	echo "nok"
fi

# EOF


