#!/bin/bash

# file: show_config.sh
# bk_version 21.09.1


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

# 

. ./cfg.working_folder
. ./cfg.target_disk_list
. ./cfg.projects


cd $WORKINGFOLDER
if [ ! -d $WORKINGFOLDER ] && [ ! $( pwd ) = $WORKINGFOLDER ]
then
	echo "WD '$WORKINGFOLDER'"
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

#projects=""

function do_label {
	local _disk=$1
#	echo "disk: $_disk"
	local PROJEKTLABELS=${a_projects[$_disk]}
	for p in $PROJEKTLABELS
	do
#		echo "p: ${_disk}_$p"
		projects+=(${_disk}_$p)

	done

}


WORKINGDIR=$WORKINGFOLDER

cd  ${WORKINGDIR}
 
CONFFOLDER="${WORKINGDIR}/conf"


for _disk in $DISKLIST
do
#	echo "disk: $_disk"
	do_label $_disk
done

echo "${projects[@]}"


dlog(){
	echo "$RSNAPSHOT -->  $1"
}

for RSNAPSHOT in ${projects[@]}
do



#	echo "retainslist= cat ${CONFFOLDER}/${RSNAPSHOT}.conf "
	if [ -f ${CONFFOLDER}/${RSNAPSHOT}.conf ]
	then
		retainslist=$( cat ${CONFFOLDER}/${RSNAPSHOT}.conf | grep ^retain )
		backupslist=$( cat ${CONFFOLDER}/${RSNAPSHOT}.conf | grep ^backup )
		#echo "$retainslist"
		OIFS=$IFS
IFS='
'
		lines=($retainslist)
		backups=($backupslist)
		declare -A retainscount
		declare -A retains


		echo ""
		echo ""
		dlog "Project: == $RSNAPSHOT =="
		cfg="$CONFFOLDER/${RSNAPSHOT}.conf"
		#RSNAPSHOT_ROOT=$(cat ${cfg} | grep ^snapshot_root | awk '{print $2}')
		RSNAPSHOT_ROOT=$(awk  '/^snapshot_root/&&!/^'#'/  {print $2}' ${cfg})


		dlog "root folder: $RSNAPSHOT_ROOT"
		# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
		n=0
		IFS=$OIFS
		ncount=0
		for i in "${lines[@]}"
		do
			# split to array with ()
			_line=($i)
			# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
			retainscount[$n]=${_line[2]}
			retains[$n]=${_line[1]}
			(( n++ ))
		done
#		echo "n: $n"
		#if [ $n -ne 4 ]
		#then
	#		exit 1
	#	fi
		dlog "-----------------"
		pdiff=$( decode_pdiff ${RSNAPSHOT})
		ncount=$(( retainscount[0] )) 


		t=$( printf "%3d"  $ncount )
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

#exit


echo ""
echo "all disks"
cat cfg.target_disk_list | grep -v '#' | grep DISKLIST
echo ""
echo "all Projects"
cat cfg.projects | grep -v declare | grep a_projects
echo ""
echo "all intervals"
cat cfg.projects | grep -v declare | grep -v pdiff | grep a_interval
echo ""
echo "all wait times"
cat cfg.projects | grep -v declare | grep -v pdiff | grep a_waittime
	

# EOF


