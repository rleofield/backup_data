#!/bin/bash


# file: disk.sh
# version 18.08.1

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



# delete 
#   rm retains_count/*
#   rm done/*
# before first use

TODAY=`date +%Y-%m-%dT%H:%M`
readonly LABEL=$1

# used at
# disk.sh:671:                    duration=$DURATIONx
# disk.sh:700:duration=$DURATIONx
. ./cfg.loop_time_duration
. ./cfg.exit_codes
. ./cfg.filenames
. ./lib.logger
. ./cfg.ssh_login
. ./cfg.projects



# use media mount instead of /mnt
# 0 = use
# 1 = don't use, use /mnt
readonly use_mediamount=0

arrays_ok=0

if test ${#a_properties[@]} -eq 0 
then
	datelog "Array 'a_properties' doesn't exist"
	arrays_ok=1
fi
if test ${#a_projects[@]} -eq 0 
then
	datelog "Array 'a_projects' doesn't exist"
	arrays_ok=1
fi
if test ${#a_interval[@]} -eq 0 
then
	datelog "Array 'a_interval' doesn't exist"
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


readonly properties=${a_properties[$LABEL]}

datelog ""
datelog "${FILENAME}: == process disk, label: '$LABEL'"

readonly NOTIFYSENDLOG="notifysend.log"
readonly notifybasefile="Backup-HD"

readonly successlogtxt="successlog.txt"
readonly maxLASTDATE="2018-02-01 00:00"

	



function sendlogclear {
        if test -f $NOTIFYSENDLOG
        then
                rm $NOTIFYSENDLOG
        fi
        #touch $NOTIFYSENDLOG
}
function sendlog {
        local msg=$1
        echo -e "$_TODAY  == Notiz: $msg" >> $NOTIFYSENDLOG
}


function sshnotifysend {
        local _disk=$1
        local _ok=$2

        local _TODAY=`date +%Y%m%d-%H%M`
        local temp="${notifybasefile}_${_disk}_${_TODAY}_${_ok}.log"
#        datelog "     send message; '$_disk'"
        datelog " temp =     ${notifybasefile}_${_disk}_${_TODAY}_${_ok}.log"
        $( cat $NOTIFYSENDLOG > $temp )
        local _llog=$(cat $temp )
        datelog "$_llog"

        ## remove comment to activate
        #datelog "rsync $temp $notifytargetsend"
        rsync $temp $notifytargetsend
        rm $temp
        sendlogclear

}

function rm_notify_file {
        local _disk=$1

        local f=${notifybasefile}_${_disk}_*
        local folder=$sshtargetfolder


        #ssh $USER@$target "rm /home/$USER/Desktop/$f" 
        local temp=$( echo "$notifytargetremovestring 'rm ${sshtargetfolder}${f}'" )
	if test "$notifytargetremovestring" = "" 
	then
        	temp=$( echo "rm ${sshtargetfolder}${f}" )
	fi

        ## remove comment to activate
        #ssh $USER@$target "rm ${folder}${f}"

        #datelog "${FILENAME}:  rm notify file"
        datelog "${FILENAME}: rm notify:      $temp"
        eval $temp
}



# par1 = old
# par2 = new
# diff = new - old  
# h = 60, d = 1440, w=10080, m=43800, y=525600
# parameter: dateold, datenew in date format
function time_diff_minutes() {
        local old=$1
        local new=$2
	#datelog "tdiff old: $old"
	#datelog "tdiff new: $new"
        # convert the date "1970-01-01 hour:min:00" in seconds from Unix Date Stamp to seconds
        # "1980-01-01 00:00"
        local sec_old=$(date +%s -d $old)
        local sec_new=$(date +%s -d $new)
	ret=$(( (sec_new - sec_old) / 60 ))
	#datelog "1: done diff minutes = $ret"
	if test $ret -lt 0 
	then
		datelog "done diff ist lower then zero !!!!!!!!!!!!!!!!!!!!!!!!"
	fi
        echo "$ret"
}


# parameter: disklabel
function check_disk_label {
        local _LABEL=$1

        # 0 = success
        # 1 = error
        local goodlink=1
	local uuid=$( cat "uuid.txt" | grep -w $_LABEL | awk '{print $2}' )
	datelog "uuid.txt | grep -w $_LABEL | awk '{print $2}'"
	local label=$( cat "uuid.txt" | grep $_LABEL | awk '{print $1}' )
        #disklink="/dev/disk/by-label/$_LABEL"
        local disklink="/dev/disk/by-uuid/$uuid"
        # test, if symbolic link
	datelog "disklink: '${disklink}'"
        if test -L ${disklink} 
        then
                # test, if exists
                #if [ -e ${disklink} ]
                #then
                        goodlink=0
                #fi
        fi
        echo $goodlink
}

# parameter: string with time value, dd:hh:mm 
function decode_pdiff_local {
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
# return projekt interval in minutes 
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


	#datelog "${FILENAME}:  encode_diff, testday: $testday"
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
                        ret=$minutes
		else
                	#phours=$( printf "%02d\n"  $hours )
                       	#pminutes=$( printf "%02d\n"  $minutes )
			ret=$( printf "%02d:%02d"  $hours $minutes )
                       	#ret="$phours:$pminutes"
		fi
	else
               	#pdays=$( printf "%02d\n"  $days )
	        #phours=$( printf "%02d\n"  $hours )
	        #pminutes=$( printf "%02d\n"  $minutes )
		ret=$( printf "%02d:%02d:%02d"  $days $hours $minutes )
	       	#ret="$pdays:$phours:$pminutes"	
	fi

	# add minus sign, if negative 
	if test "$negativ" = "true" 
	then
		#datelog "${FILENAME}: is negative, correct minus sign"
		ret="-$ret"
	fi	
	#datelog "${FILENAME}:  encode_diff, ret: $ret"

        echo "$ret"
}

# parameter
# $1 = Disklabel
# $2 = Projekt
# return 0, 1, 2, 3  

DONE_REACHED=0
DONE_NOT_REACHED=1
DIFF_REPLACEMENT="600"

function check_disk_done_last_done {
        local _label=$1
        local _p=$2
	local _key=${_label}_${_p}

        local _LASTLINE=""
        local _current=`date +%Y-%m-%dT%H:%M`

        # 0 = success, backup was done
        # 1 = error
        local _DONEINTERVAL=$DONE_NOT_REACHED
        local _DONEFILE="./done/${_key}_done.log"
        #datelog "DONEFILE: '$_DONEFILE'"
        local _LASTLINE=""
        #echo "in function check_disk_done "
        _LASTLINE="$maxLASTDATE"

        if test -f $_DONEFILE
        then
                _LASTLINE=$(cat $_DONEFILE | awk  'END {print }')
        fi
        local _DIFF=$(time_diff_minutes  $_LASTLINE  $_current  )
	local _pdiff=$( decode_pdiff ${_key} )

	if test $_DIFF -ge $_pdiff
        then
        	# diff was greater then reference, take as success
                _DONEINTERVAL=$DONE_REACHED
        fi

        echo $_DONEINTERVAL
}


# 0 = success, no daytime
# 1 = error
# 2 = daytime not reached
# 3 = reached, but daytime
function check_disk_done {
        local _label=$1
        local _p=$2
	local _key=${_label}_${_p}

        # 0 = success
        # 1 = error
        local _DONEINTERVAL=$DONE_NOT_REACHED

	# check, if daytime is reached

	#DONE_REACHED=0
	#DONE_NOT_REACHED=1
	_DONEINTERVAL=$( check_disk_done_last_done ${_label} ${_p} )
        echo $_DONEINTERVAL
}




function check_pre_host {

	local _LABEL=$1
	local _p=$2

        local _precondition=pre/${_LABEL}_${_p}.pre.sh
	local _ispre=$SUCCESS
	local _RET=0

	#datelog "pre: $_LABEL $_p"
	#datelog "cpre: $_precondition"

        if [[  -f $_precondition ]]
        then
                ($_precondition)
                _RET=$?
                if [ "$_RET"  != 0 ]
                then
	#		datelog "pre was not ok"
                        _ispre=$PRE_WAS_NOK
                else
	#		datelog "pre was ok"
                        _ispre=$SUCCESS
                fi
        else
	#	datelog "pre was not ok"
                _ispre=$PRE_WAS_NOK
        fi
	echo $_ispre
}

if test -f $successarraytxt
then
	rm $successarraytxt
fi
if test -f $unsuccessarraytxt
then
	rm $unsuccessarraytxt
fi

sendlogclear 

datelog "${FILENAME}:  check by UUID, if HD '$LABEL' is connected to the PC" 
goodlink=$(check_disk_label $LABEL)

LABELFILE="./label/${LABEL}_label_not_present.txt"
if test $goodlink -ne 0
then
	# disk label/uuid not found, write label file
	datelog "${FILENAME}: disk '$LABEL' wasn't found in '/dev/disk/by-uuid'"
	current=`date +%Y-%m-%dT%H:%M`
        echo "$current : disk $LABEL not present" > $LABELFILE
        exit $DISKLABELNOTFOUND
else
	# label/uuid found, remove label file
	if test -f $LABELFILE
	then
		rm $LABELFILE
	fi
fi


PROJEKTLABELS=${a_projects[$LABEL]}

datelog "${FILENAME}: -- disk '$LABEL', check projects: '$PROJEKTLABELS'"

# start of disk, disk is unmounted

# find, if interval is reached, if not exit

#isdone=false
ispre=1
#mindiff=100000
#minexpected=10000
declare -A nextprojects
#nextprojekt=""



datelog "                            dd:hh:mm                 dd:hh:mm               dd:hh:mm"
for p in $PROJEKTLABELS
do
	lpkey=${LABEL}_${p}
	#datelog "${FILENAME}:  do disk $LABEL, projekt $p"
	
	tcurrent=`date +%Y-%m-%dT%H:%M`
	DONE_FILE="./done/${lpkey}_done.log"
	LASTLINE=$maxLASTDATE
	if test -f $DONE_FILE 
	then
		# last line in done file
		LASTLINE=$(cat $DONE_FILE | awk  'END {print }')  	
	fi

	pdiff=$(  decode_pdiff ${lpkey} )
	done_diff_minutes=$(   time_diff_minutes  $LASTLINE  $tcurrent  )
	deltadiff=$(( pdiff - done_diff_minutes ))
        
	# ret , 0 = do backup, 1 = interval not reached, 2 = daytime not reached
	DISKDONE=$(check_disk_done $LABEL $p )

	txt=$( printf "%-12s\n"  $( echo "${p}," ) )
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
		ispre=$( check_pre_host $LABEL $p )
		if test "$ispre" -eq 0
		then
			# all is ok,  do backup	
			datelog "${FILENAME}: $txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  reached, source is ok"
			nextprojects["$p"]=$p
		#	isdone=true

		else
			datelog "${FILENAME}: $txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  source not available"
		fi
	fi
	
	if test "$DISKDONE" -eq $DONE_NOT_REACHED
	then
		diskdonetext="not"
		datelog "${FILENAME}: $txt   $fn0 last, next in $fndelta,  programmed  $pdiff_minutes_print,  do nothing"
	fi

done

#datelog "mindiff: $mindiff"
#mindiff=$( encode_diff $mindiff )
# in 'nextprojects' are all projects where we need a backup
lnextprojects=${#nextprojects[@]}
#datelog "l nextprojects: $lnextprojects"

if test $lnextprojects -eq 0
then
	datelog "${FILENAME}: == end disk '$LABEL', nothing to do =="
	datelog ""
        exit $TIMELIMITNOTREACHED
fi
# start of backup
# - mount disk
# - do rsnapshot with projekt.sh ans rs.sh
# - umount, if programmmed or no /media/user disk 
# 

rm_notify_file $LABEL

#datelog "${FILENAME}:  next projects: ${nextprojects[*]}"
datelog "${FILENAME}:  time limit for at least one project is reached, projects: ${nextprojects[*]}"
datelog "${FILENAME}:  continue with test of mount state of disk: '$LABEL'"
datelog ""

# check mountdir at /mnt

# first, check mount at /media/user
MEDIAMOUNT=$(df  | grep media | grep $LABEL  | awk '{ print $6 }')
if test  "$MEDIAMOUNT" != ""  
then
	# use media mount instead of /mnt
	# 0 = use
	# 1 = don't use, use /mnt
	if test $use_mediamount -gt 0  
	then
		if test -d $MEDIAMOUNT 
		then
        		datelog "${FILENAME}: umount media mount  at: '$MEDIAMOUNT'" 
			umount $MEDIAMOUNT
			MEDIAMOUNT=$(df  | grep media | grep $LABEL  | awk '{ print $6 }')
			if test  "$MEDIAMOUNT" != ""
			then 
			       datelog "${FILENAME}: media mount couldn't be unmounted: '$MEDIAMOUNT'"
			       exit $MEDIAMOUNTcouldn_t_unmounted
			fi	
		fi
	else
		datelog "media mount '$MEDIAMOUNT' exists"
		MOUNTDIR=$MEDIAMOUNT
		MARKERDIR=$MOUNTDIR/marker
	fi
fi


datelog "${FILENAME}: mount folder   '$MOUNTDIR'" 

if test ! -d $MOUNTDIR 
then
       	datelog "${FILENAME}: mount folder   '$MOUNTDIR' doesn't exist" 
        exit $MOUNTDIRTNOTEXIST
fi

# mount HD
if test -d $MARKERDIR 
then
        datelog "${FILENAME}: HD '$LABEL' is mounted at '$MOUNTDIR'"
else
        datelog "${FILENAME}: marker folder '$MARKERDIR' doesn't exist, try mount" 
	./mount.sh $LABEL 
        RET=$?
	if test $RET -ne 0
	then
                datelog "${FILENAME}: == end, couldn't mount disk '$LABEL' to  '$MOUNTDIR' =="
	fi	
        if test ! -d $MARKERDIR 
        then
                datelog "${FILENAME}: mount,  markerdir '$MARKERDIR' not found"
                datelog "${FILENAME}: == end, couldn't mount disk '$LABEL' to  '$MOUNTDIR' =="
                exit $DISKNOTMOUNTED
        fi
fi

datelog "${FILENAME}: disk '$LABEL' is mounted, marker folder exists"    

# done to false
done=false
#echo "in disk, vor project.sh call, no project given: ./project.sh $LABEL"

datelog "${FILENAME}: execute projects in time and with valid pre check"

#sendlog "HD '$LABEL' nächstes Backup, mind. eines der Projekte auf der HD hat das Zeitlimit erreicht"
#sendlog "Projekte, die gesichert werden: ${nextprojects[*]}"

declare -A projecterrors
declare -a successlist
declare -a unsuccesslist


sucesstxt=""

#for p in $PROJEKTLABELS
# in 'nextprojects' are all projects where we need a backup
for p in "${nextprojects[@]}"
do

	datelog "${FILENAME}: execute project: $p"
	lpkey=${LABEL}_${p}
	# second check, first was in first loop
	# is already checked, see above
	DISKDONE=0 # $(check_disk_done $LABEL $p )
	ispre=0   # $( check_pre_host $LABEL $p )

	pdiff=$( decode_pdiff ${lpkey} )

	# check current time
	tcurrent=`date +%Y-%m-%dT%H:%M`
	# set lastline to 01.01.1980
        LASTLINE=$maxLASTDATE
	DONE_FILE="./done/${lpkey}_done.log"
	# read last line fron done file
        if test -f $DONE_FILE
        then
                LASTLINE=$(cat $DONE_FILE | awk  'END {print }')
        fi
	# get delta from lastline and current time
	DIFF=$(time_diff_minutes  $LASTLINE  $tcurrent  )

        if test "$DISKDONE" -eq 0
        then
		if test "$ispre" -eq 0
		then

			datelog "${FILENAME}: === disk: '$LABEL', start of project '$p' ==="
			# calls project.sh ###############################
			./project.sh $LABEL $p
			# ################################################
			RET=$?
			if test $RET -eq $RSYNCFAILS
			then
				projecterrors[${p}]="rsync Fehler, pruefe Konfiguration"
				datelog "${FILENAME}:  !! rsync error, check configuration !!"
			fi

			done=true
			if test $RET -ne 0
			then
				done=false
			fi
			current=`date +%Y-%m-%dT%H:%M`
			__TODAY=`date +%Y%m%d-%H%M`
			if test "$done" = true
			then
		        	# set current at last line to done file
				# done entry is written in project.sh, 131
			        datelog "${FILENAME}:  all ok, disk: '$LABEL', project '$p'"
				sendlog "HD: '$LABEL' mit Projekt '$p' gelaufen, keine Fehler"
				# write success to a single file 
				echo "$__TODAY ==> '$LABEL' mit '$p' ok" >> $successlogtxt

				# collect success for report at end of main loop
				var="${LABEL}:$p"
				successlist=( "${successlist[@]}" "$var" )
				datelog "${FILENAME}: successlist: $( echo ${successlist[@]} )"

			        #echo "$__TODAY" > ./done/${LABEL}_${p}_done.log
			        #datelog "${FILENAME}: write last date: ./done/${LABEL}_${p}_done.log"

			else
			        datelog "${FILENAME}:  error: '$LABEL', project '$p'"
				sendlog "HD: $LABEL mit Projekt  $p hatte Fehler"
				errorlog "HD: $LABEL mit Projekt  $p hatte Fehler" 
				# write unsuccess to a single file 
				echo "$__TODAY ==> '$LABEL' mit '$p' not ok" >> $successlogtxt
				
				# collect unsuccess for report at end of main loop
				var="${LABEL}:$p"
				unsuccesslist=( "${unsuccesslist[@]}" "$var" )
				datelog "${FILENAME}: unsuccesslist: $( echo ${unsuccesslist[@]} )"
			fi
		else
			datelog "${FILENAME}: pre check disk: '${LABEL}_${p}.pre.sh' was wrong"
		fi
	#else
        #        datelog "${FILENAME}: current  diff:  $DIFF , expected:    $pdiff , $LABEL $p: done interval ist not reached"
	fi
done
# end of disk

# find min diff after backup ist done, done file exists here
mindiff=10000
minp=""
for p in $PROJEKTLABELS
do
	lpkey=${LABEL}_${p}
        tcurrent=`date +%Y-%m-%dT%H:%M`
        DONE_FILE="./done/${lpkey}_done.log"
	#datelog "donefile: $DONE_FILE"
        LASTLINE=$maxLASTDATE
        if test -f $DONE_FILE
        then
                LASTLINE=$(cat $DONE_FILE | awk  'END {print }')
        fi

        #pdiff=${a_interval[${done_key}]}
	# get project delta time
	pdiff=$(decode_pdiff ${lpkey} )
	# get current delta after last done
        DIFF=$(time_diff_minutes  $LASTLINE  $tcurrent  )
        deltadiff=$(( pdiff - DIFF ))
	#datelog "after b configured value $pdiff"
	#datelog "after b lastline   value $DIFF"
	#datelog "after b delta $deltadiff, mindiff: $mindiff"
        if ((deltadiff < mindiff ))
        then
                mindiff=$deltadiff
		minp=$p
        fi
	#datelog "after b delta $deltadiff, mindiff: $mindiff"
	#datelog "programmed diff: $pdiff, lastDIFF: $DIFF, mindiff: $mindiff, delta: $deltadiff"
done



# clean up
notifyfilepostfix="keine_Fehler_alles_ok"

if test -d $MARKERDIR 
then
	RET=1
        if test "$properties" = "umount"  
	then
		datelog "${FILENAME}: umount  $MOUNTDIR"
		./umount.sh  $LABEL
		RET=$?
		if test $RET -ne 0
		then
			msg="HD '$LABEL' wurde nicht korrekt getrennt, bitte nicht entfernen"
			datelog $msg
			sendlog $msg
			notifyfilepostfix="Fehler_HD_nicht_getrennt"
		else
			#rmdir  $MOUNTDIR
	  		datelog "${FILENAME}: '$LABEL' all is ok"
			sendlog "HD '$LABEL': alles ist ok"
			duration=$DURATIONx

			nextdiff=$duration
			if ((nextdiff < mindiff ))
			then
			        nextdiff=$mindiff
			fi
			_nextdiff=$( encode_diff $nextdiff )
			sendlog "HD mit Label '$LABEL' kann in den nächsten '${_nextdiff}' Minuten vom Server entfernt werden "
		fi
		if [ -d $MARKERDIR ]
		then
        		datelog "${FILENAME}: disk is still mounted: '$LABEL', at: '$MOUNTDIR' "
        		datelog ""
	  		datelog "${FILENAME}: '$LABEL' ist noch verbunden, umount error"

                        sendlog "HD mit Label: '$LABEL' konnte nicht ausgehängt werden, bitte nicht entfernen"
                        TODAY=`date +%Y%m%d-%H%M`
                        sendlog "=======  $TODAY  ======="
			notifyfilepostfix="HD_konnte_nicht_getrennt_werden_Fehler"
		
		fi
	else
		datelog "${FILENAME}: no umount configured, maybe fixed disk  at $MOUNTDIR"
		datelog "${FILENAME}: next run of '$minp' in '${mindiff}' minutes"
		sendlog "'umount' wurde nicht konfiguriert, HD '$LABEL' ist noch verbunden, at $MOUNTDIR"
	fi
fi

duration=$DURATIONx


datelog "${FILENAME}: == end disk with '$LABEL' =="
datelog ""
#msg="HD mit Label '$LABEL' erfolgreich beendet, nächster Test dieser HD ist in '${duration}' Minuten"
#datelog "$msg"
#sendlog "$msg"

_mind=$( encode_diff $mindiff )
msg="HD mit Label '$LABEL', nächster Lauf eines Projektes ('$minp')  auf dieser HD ist in '${_mind}' Tagen:Stunden:Minuten"
datelog "${FILENAME}: $msg"
sendlog "$msg"
TODAY=`date +%Y%m%d-%H%M`
sendlog "=======  $TODAY  ======="
#sshok=""

if test ${#projecterrors[@]} -gt 0 
then
	notifyfilepostfix="Fehler_in_Projekten"
	sendlog "${#projecterrors[@]}  Fehler in Projekten:"
	for i in "${!projecterrors[@]}"
	do
		sendlog "Projekt: '$i'  Nachricht: ${projecterrors[$i]}"
	done
	sendlog "---"
fi

sshnotifysend $LABEL $notifyfilepostfix 

# write collected success labels to disk
echo ${successlist[@]} > $successarraytxt
#datelog "${unsuccesslist[@]}  $unsuccessarraytxt "
echo ${unsuccesslist[@]} > $unsuccessarraytxt

exit $SUCCESS


