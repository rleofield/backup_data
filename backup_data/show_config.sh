#!/bin/bash

# file: show_config.sh
# bk_version 23.12.2


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

# 

. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.projects


cd $bv_workingfolder
if [ ! -d $bv_workingfolder ] && [ ! $( pwd ) = $bv_workingfolder ]
then
	echo "WD '$bv_workingfolder'"
	echo "WD is wrong"
	exit 1
fi


###### some functions ############
function decode_pdiff_local {
	local v=$1
	local oldifs=$IFS
	IFS=':'·

	local a=($v)
	local l=${#a[@]}

	# mm only
	local r_=${a[0]}
	if test $l -eq 2
	then
		# hh:mm
		r_=$(( ( ${a[0]} * 60 ) + ${a[1]} ))
	fi
	if test $l -eq 3
	then
		# dd:hh:mm
		r_=$(( ( ( ${a[0]} * 24 )  * 60 + ${a[1]} * 60  ) + ${a[2]} ))
	fi

	IFS=$oldifs
	echo $r_

}

# parameter is key in a_interval array
# return projekt interval in minutes·
function decode_pdiff {
	local _k=$1
	local _interval=${a_interval[${_k}]}
        local _r2=$( decode_pdiff_local ${a_interval[${_k}]} )
        echo $_r2
}

function encode_diff {

        # testday is in minutes
        local testday=$1
        local ret=""
        local negativ="false"


        #dlog " encode_diff, testday: $testday"
        if test $testday -lt 0
        then
                #dlog "is negative '$testday'"
                testday=$(( $testday * (-1) ))
                negativ="true"
        fi

        local hour=60
        local day=$(( hour * 24 ))
        local days=$(( testday/day  ))
        local remainder=$(( testday - days*day   ))
        local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq 0
        then
                if test $hours -eq 0
                then
                        ret=$( printf "%2d:%02d:%02d"  0 0 $minutes )
                else
                        ret=$( printf "%2d:%02d:%02d"  0 $hours $minutes )
                fi
        else
                ret=$( printf "%02d:%02d:%02d"  $days $hours $minutes )
        fi

        # add minus sign, if negative
        if test "$negativ" = "true"
        then
                ret="-$ret"
        fi
        echo "$ret"
}

function do_label {
	local _disk=$1
	# a_projects is in 'cfg.projects'
	local _project_list=${a_projects[$_disk]}
	for _project in $_project_list
	do
		projects+=(${_disk}_$_project)
	done

}



readonly lv_conffolder="${bv_workingfolder}/conf"
readonly bv_disklist=$DISKLIST

#  collect complete projectnames, label_project, for all disks
for _disk in $bv_disklist
do
#	echo "disk: $_disk"
	do_label $_disk
done

echo "found projects"
echo "${projects[@]}"


dlog(){
	echo "$RSNAPSHOT -->  $1"
}

for _project in ${projects[@]}
do

	_projekt_conf=${lv_conffolder}/${_project}.conf
	RSNAPSHOT=$_project


	if [ -f ${_projekt_conf} ]
	then
		retainslist=$( cat ${_projekt_conf} | grep ^retain )
		backupslist=$( cat ${_projekt_conf} | grep ^backup )
		#echo "$retainslist"
		_oldifs=$IFS
IFS='
'
		lines=($retainslist)
		backups=($backupslist)


		echo ""
		echo ""
		dlog "Project: == $_project =="
#		cfg="${_projekt_conf}"

		# lookup for backup disk root folder
		_backup_root=$(awk  '/^snapshot_root/&&!/^'\#'/  {print $2}' ${_projekt_conf})
		echo ""
		dlog ""

		dlog "root folder: $_backup_root"
		# retainpositions in line:
		# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
		n=0
		IFS=$_oldifs
		ncount=0
		
		declare -A retainscount
		declare -A retains

		for i in "${lines[@]}"
		do
			#echo "i: ${i}"
			# split to array with ()
			_line=($i)
			# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
			retainscount[$n]=${_line[2]}
			retains[$n]=${_line[1]}
			#echo "line: ${_line[2]}"
			(( n++ ))
		done

		dlog "-----------------"
		pdiff=$( decode_pdiff ${_project})
		ncount=$(( retainscount[0] ))


		#t=$( printf "%3d"  $ncount )
		dlog "retain 0 = ${retainscount[0]} times, every $(encode_diff $pdiff), total $( printf "%3d"  $ncount )"
		rr=$(( pdiff * retainscount[0] ))
		ncount=$(( ncount * retainscount[1] )) 
		dlog "retain 1 = ${retainscount[1]} times, every $( encode_diff $rr), total $( printf "%3d"  $ncount )"
		rr=$(( rr * retainscount[1] ))
		ncount=$(( ncount * retainscount[2] )) 
		dlog "retain 2 = ${retainscount[2]} times, every $( encode_diff $rr), total $( printf "%3d"  $ncount )"
		rr=$(( rr * retainscount[2] ))
		ncount=$(( ncount * retainscount[3] )) 
		dlog "retain 3 = ${retainscount[3]} times, every $( encode_diff $rr), total $( printf "%3d"  $ncount )"
		rr=$(( rr * retainscount[3] ))
		dlog "         last copy after: $( encode_diff $rr)"
		dlog "-----------------"

#		retainslist=$( cat ${cfg} | grep ^retain )
#		lines=($retainslist)
		for i in "${lines[@]}"
		do
			dlog "$i"
		done
		cfg="${_projekt_conf}"
		dlog "$( cat ${cfg} | grep ^logfile )" 
		dlog "$( cat ${cfg} | grep ^rsync_short_args )"
		dlog "$( cat ${cfg} | grep ^rsync_long_args )"
		dlog "$( cat ${cfg} | grep ^exclude_file )"
		dlog "$( cat ${cfg} | grep ^ssh_args )"
		for i in "${backups[@]}"
		do
			dlog "$i"
		done
		dlog "======"
	else
		dlog ""
		dlog "======"
		dlog "Project: $RSNAPSHOT"
		dlog "${RSNAPSHOT}.conf does not exist, is archive?"
		dlog "======"

	fi

done




echo ""
echo "all disks"
cat cfg.projects | grep -v '#' | grep bv_disklist
echo ""
echo "all Projects"
cat cfg.projects | grep -v declare | grep -v '#' | grep a_projects
echo ""
echo "all intervals"
cat cfg.projects | grep -v declare | grep -v '#'| grep -v pdiff | grep a_interval
echo ""
echo "all wait times"
cat cfg.projects | grep -v declare | grep -v '#' | grep -v pdiff | grep a_waittime
	

# EOF


