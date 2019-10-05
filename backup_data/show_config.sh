#!/bin/bash

# file: show_config.sh
# version 19.04.1


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
                #datelog "${FILENAME}: is negative '$testday'"
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

RSNAPSHOTS="${!a_interval[*]}"
echo "$RSNAPSHOTS"

WORKINGDIR=$WORKINGFOLDER

cd  ${WORKINGDIR}
 
CONFFOLDER="${WORKINGDIR}/conf"


for RSNAPSHOT in ${RSNAPSHOTS}
do

	#echo "retainslist= cat ${CONFFOLDER}/${RSNAPSHOT}.conf "
	retainslist=$( cat ${CONFFOLDER}/${RSNAPSHOT}.conf | grep ^retain )
	#echo "$retainslist"
	OIFS=$IFS
IFS='
'
	lines=($retainslist)
	declare -A retainscount
	declare -A retains


	echo ""
	echo "======"
	echo "Project: $RSNAPSHOT"
	cfg="$CONFFOLDER/${RSNAPSHOT}.conf"
	RSNAPSHOT_ROOT=$(cat ${cfg} | grep ^snapshot_root | awk '{print $2}')
	echo "root folder: $RSNAPSHOT_ROOT"
	# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
	n=0
	IFS=$OIFS
	for i in "${lines[@]}"
	do
		# split to array with ()
		_line=($i)
		# 0 = keyword 'retain', 1 = level= e.g. eins,zwei,drei, 2 = count
		retainscount[$n]=${_line[2]}
		retains[$n]=${_line[1]}
		(( n++ ))
	done
	echo "-----------------"
	pdiff=$( decode_pdiff ${RSNAPSHOT})
	echo "retain 0 (${retains[0]}), ${retainscount[0]} mal alle dd:hh:mm: $(encode_diff $pdiff)"
	rr=$(( pdiff * retainscount[0] ))
	echo "retain 1 (${retains[1]}), ${retainscount[1]} mal alle dd:hh:mm: $( encode_diff $rr)"
	rr=$(( rr * retainscount[1] ))
	echo "retain 2 (${retains[2]}), ${retainscount[2]} mal alle dd:hh:mm: $( encode_diff $rr)"
	rr=$(( rr * retainscount[2] ))
	echo "retain 3 (${retains[3]}), ${retainscount[3]} mal alle dd:hh:mm: $( encode_diff $rr)"
	rr=$(( rr * retainscount[3] ))
	echo "letzte kopie nach:        dd:hh:mm         $( encode_diff $rr)"
	echo "-----------------"

	cat ${cfg} | grep ^retain 
	cat ${cfg} | grep ^logfile 
	cat ${cfg} | grep ^rsync_short_args 
	cat ${cfg} | grep ^rsync_long_args 
	cat ${cfg} | grep ^exclude_file 
	cat ${cfg} | grep ^ssh_args 
	cat ${cfg} | grep ^backup 
	echo "======"
		
done

#exit

echo ""
echo "DISKLIST"
cat cfg.target_disk_list | grep -v '#' | grep DISKLIST
echo "a_projects"
cat cfg.projects | grep -v declare | grep a_projects
echo "a_interval"
cat cfg.projects | grep -v declare | grep -v pdiff | grep a_interval

	



