#!/bin/bash


# file: show_times_disk.sh

# bk_version 21.11.1


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



TODAY=`date +%Y-%m-%dT%H:%M`
readonly LABEL=$1

. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.projects

. ./src_exitcodes.sh
. ./src_filenames.sh
. ./src_folders.sh

readonly maxLASTDATE="2021-03-01T00:00"

if [ -z $LABEL  ]
then
	echo 	"Usage: show_times_disk.sh disklabel "
	exit 1
fi



function log {
   local msg=$1
   #echo -e "$msg" >> $SHOWTIMES_LOGFILE
   echo -e "$msg" 
}



function stdatelog {
        local _TODAY=`date +%Y%m%d-%H%M`
        log "$_TODAY ==>  $1"
}

function errorlog {
        local _TODAY=`date +%Y%m%d-%H%M`
        msg=$( echo "$_TODAY err ==> '$1'" )
        echo -e "$msg" >> $ERRORLOG
}


# use media mount instead of /mnt
# 0 = use
# 1 = don't use, use /mnt
readonly use_mediamount=0

arrays_ok=0

if test ${#a_properties[@]} -eq 0 
then
	stdatelog "Array 'a_properties' doesn't exist"
	arrays_ok=1
fi
if test ${#a_projects[@]} -eq 0 
then
	stdatelog "Array 'a_projects' doesn't exist"
	arrays_ok=1
fi
if test ${#a_interval[@]} -eq 0 
then
	stdatelog "Array 'a_interval' doesn't exist"
	arrays_ok=1
fi
if test "$arrays_ok" -eq "1" 
then
	exit $ARRAYSNOK
fi

# changed later, if use_mediamount=0
MOUNTDIR=/mnt/$LABEL
MARKERDIR=$MOUNTDIR/marker

readonly FILENAME="disk:$LABEL"


# diff = old - new 
# h = 60, d = 1440, w=10080, m=43800,y=525600
function time_diff_minutes() {
        local old=$1
        local new=$2
        # convert the date "1970-01-01 hour:min:00" in seconds from Unix Date Stamp
        # "1980-01-01 00:00"
        local sec_old=$(date +%s -d $old)
        local sec_new=$(date +%s -d $new)
        echo "$(( (sec_new - sec_old) / 60 ))"
}



function check_disk_label {
        local _LABEL=$1

        # 0 = success
        # 1 = error
        local goodlink=1
	local uuid=$( cat "uuid.txt" | grep -w $_LABEL | awk '{print $2}' )
	#local uuid=$( gawk -v pattern="$_LABEL" '$1 ~ pattern  {print $NF}' $WORKINGFOLDER/uuid.txt )

        #disklink="/dev/disk/by-label/$_LABEL"
        local disklink="/dev/disk/by-uuid/$uuid"
        # test, if symbolic link
        if test -L ${disklink} 
        then
                # test, if exists
                #if [ -e ${disklink} ]
                #then
                        goodlink=0
                #fi
        fi
        return $goodlink
}


function decode_diff_local {
	local v=$1
	local oldifs=$IFS
	IFS=':' 

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
function decode_pdiff {
	local _k=$1
        local _r2=$( decode_diff_local ${a_interval[${_k}]} )
        echo $_r2
}



function encode_diff {

        local hour=60
        local day=$(( hour * 24 ))
        local testday=$1
	local ret=""
	local negativ="false"
	if test $testday -lt 0
	then
		testday=$(( $testday * (-1) ))
		negativ="true"
	fi

	local days=$(( testday/day  ))
        local remainder=$(( testday - days*day   ))
	local hours=$(( remainder/hour   ))
        local minutes=$(( remainder - hours*hour  ))

        if test $days -eq 0
	then
    	  	if test $hours -eq 0
        	then
                        ret=$minutes
		else
                	phours=$( printf "%02d\n"  $hours )
                       	pminutes=$( printf "%02d\n"  $minutes )
                       	ret="$phours:$pminutes"
		fi
	else
               	pdays=$( printf "%02d\n"  $days )
	        phours=$( printf "%02d\n"  $hours )
	        pminutes=$( printf "%02d\n"  $minutes )
	       	ret="$pdays:$phours:$pminutes"	
	fi

	# add minus sign, if negative 
	if test "$negativ" = "true" 
	then
		ret="-$ret"
	fi	

        echo "$ret"
}


# parameter
# $1 = Disklabel
# $2 = Projekt
# return 0, 1 
function check_disk_done {
        local _label=$1
        local _p=$2
	local _key=${_label}_${_p}

        local _LASTLINE=""
        local _current=`date +%Y-%m-%dT%H:%M`

        # 0 = success
        # 1 = error
        local _DONEINTERVAL=1
        local _DONEFILE="./${donefolder}/${_key}_done.log"
        #stdatelog "DONEFILE: '$_DONEFILE'"
        local _LASTLINE=""
        #echo "in function check_disk_done "
        _LASTLINE="$maxLASTDATE"

        if test -f $_DONEFILE
        then
                # last line in done file
		_LASTLINE=$(awk NF  $_DONEFILE | awk  'END {print }' -)

        fi
        local _DIFF=$(time_diff_minutes  $_LASTLINE  $_current  )
        #local _pdiff=${a_interval[${_key}]}
	local _pdiff=$( decode_pdiff ${_key} )
	#echo "if test $_DIFF -ge $_pdiff"
	if test $_DIFF -ge $_pdiff
        then
#        	echo "diff was greater then reference, take as success"
                _DONEINTERVAL=0
        fi

        echo $_DONEINTERVAL
}


function check_pre_host {

	local _LABEL=$1
	local _p=$2

        local _precondition=pre/${_LABEL}_${_p}.pre.sh

	#stdatelog "pre: $_LABEL $_p"
	#stdatelog "cpre: $_precondition"

        if [[  -f $_precondition ]]
        then
                ($_precondition)
                _RET=$?
                if [ $_RET -ne 0 ]
                then
                        return 1
                else
                        return 0
                fi
	fi
        return 1
}



check_disk_label $LABEL
goodlink=$?

stdatelog ""
stdatelog "${FILENAME}: test disk ========== '$LABEL' =========="
if test $goodlink -ne 0
then
	# disk label/uuid not found, write label file
	stdatelog "${FILENAME}: disk '$LABEL' wasn't found in '/dev/disk/by-uuid'"
fi


PROJEKTLABELS=${a_projects[$LABEL]}

DONE_REACHED=0
DONE_NOT_REACHED=1
ispre=1
mindiff=100000
minexpected=10000
declare -A nextprojects
nextprojekt=""
#DONE=$donefolder
#stdatelog "DONE: '$DONE'"

# find projects in time		
stdatelog "                             dd:hh:mm               dd:hh:mm               dd:hh:mm"
for p in $PROJEKTLABELS
do
        lpkey=${LABEL}_${p}
	
#stdatelog "key: $lpkey"

        tcurrent=`date +%Y-%m-%dT%H:%M`
        DONE_FILE="$WORKINGFOLDER/${donefolder}/${lpkey}_done.log"
        LASTLINE=$maxLASTDATE
        if [ -f $DONE_FILE  ]
        then
                # last line in done file
		LASTLINE=$(awk NF  $DONE_FILE | awk  'END {print }' -)

        fi
        pdiff=$(  decode_pdiff ${lpkey} )
        done_diff_minutes=$(   time_diff_minutes  "$LASTLINE"  "$tcurrent"  )
        deltadiff=$(( pdiff - done_diff_minutes ))
        
        # ret , 0 = do backup, 1 = interval not reached, 2 = daytime not reached
        DISKDONE=$(check_disk_done $LABEL $p )

        txt=$( printf "%-14s\n"  $( echo "${p}," ) )
        n0=$( printf "%5s\n"  $done_diff_minutes )
        pdiff_print=$( printf "%5s\n"  $pdiff )
        ndelta=$( printf "%6s\n"  $deltadiff )

        fndelta=$( encode_diff $ndelta )
        fndelta=$( printf "%8s\n"  $fndelta )
        fn0=$( encode_diff  $n0 )
        fn0=$( printf "%8s"  $fn0 )
        pdiff_minutes_print=$( encode_diff  $pdiff_print )
        pdiff_minutes_print=$( printf "%8s"  $pdiff_minutes_print )

        if test "$DISKDONE" -eq $DONE_REACHED
        then
                diskdonetext="ok"
#               stdatelog "check_pre_host $LABEL $p "
                check_pre_host $LABEL $p 
		ispre=$?
                if test $ispre -eq 0
                then
                        # all is ok,  do backup
                        stdatelog "${FILENAME}: $txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  reached, source is ok"
                        nextprojects["$p"]=$p
                #       isdone=true

                else
                        stdatelog "${FILENAME}: $txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  reached, source not available"
                fi
        fi

        if test "$DISKDONE" -eq $DONE_NOT_REACHED
        then
                diskdonetext="not"
                stdatelog "${FILENAME}: $txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  do nothing"
        fi

done


exit 0

# EOF


