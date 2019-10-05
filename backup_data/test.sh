#/bin/bash

# file: test.sh
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


. ./cfg.working_folder
. ./cfg.loop_time_duration
. ./cfg.target_disk_list
. ./cfg.projects

errlog="test_errors.log"
  
# cd xxxx 2> "$errlog" || exit 1 
if [ ! -d $WORKINGFOLDER ] 
then
	echo "WD doesn#t exist"
fi

cd $WORKINGFOLDER 2> "$errlog"  || exit
if [ ! -d $WORKINGFOLDER ] && [ ! "$( pwd )" = $WORKINGFOLDER ]
then
	echo "WD '$WORKINGFOLDER'"
	echo "WD is wrong"
	echo "XXXWD is wrong"
	exit 1
fi


#n=5
#b=$(($n+2))
#echo "$b"


function datelog {

	local _TODAY
	_TODAY=$(date +%Y%m%d-%H%M)
        local _msg="$_TODAY --» $1"
        echo -e "count $# ,    $_msg" 
}

function ff {
	local a=$1
	echo "N: $#"
	echo "A: $a"

}



# loop disk list
echo "loop disk list"
for _disk in $DISKLIST
do
	PROJEKTLABELS=${a_projects[$_disk]}
	for p in $PROJEKTLABELS
	do
        	lpkey=${_disk}_${p}
		echo "rsnapshot -c conf/$lpkey.conf configtest"
		RSNAPSHOT_CONFIG=${lpkey}.conf
		DO_RSYNC=$(cat ./conf/${RSNAPSHOT_CONFIG} | grep ^rsync_root | grep -v '#' | wc -l)

		if [ $DO_RSYNC -eq 0 ]
		then
			rsnapshot -c conf/${lpkey}.conf configtest
		fi
		echo ""
		echo "pre/$lpkey.pre.sh" 
		pre/${lpkey}.pre.sh
		RET=$?
		if [ $RET -eq 0 ]; then echo "ok"; else echo "not reached"; fi
		echo "--------"
	done
done

echo "==================="


exit


#------------------------------------------------------------------------------

do_test5=0
if [ $do_test5 -eq 1 ]
then

	declare -A my_array
	#my_array=(foo bar)
	my_array["bb"]="bb"
	my_array["cc"]=cc
	my_array["dd"]=dd
	my_array["ee"]=ee
	my_array["ff"]=ff
	echo "with @ non quoted"
	echo ${my_array[@]}
	echo "with @ quoted"
	echo "mmm  ${my_array[@]}"
	echo "with datelog"
	datelog "${my_array[@]}"
	echo "with *"
	echo "non quoted"
	echo ${my_array[*]}
	echo "quoted"
	echo "${my_array[*]}"
	echo "with datelog quoted"
	datelog "${my_array[*]}"
	inarray=$(echo ${my_array[*]} | grep -w  "vff" | wc -l )
	echo "inarray: $inarray"
	exit
	echo "call ff non quoted@"
	ff ${my_array[@]}
	echo "call ff quoted @"
	ff "${my_array[@]}"

	
	echo "call ff quoted *"
	ff "${my_array[*]}"
	echo "call ff no quoted *"
	ff ${my_array[*]}
	echo "indexes"
	echo "${!my_array[@]}"
	for index in "${!my_array[@]}"; do echo "$index"; done
	exit

	for i in "${my_array[@]}"; do echo "$i"; done
	echo "next"
	for i in "${my_array[*]}"; do echo "$i"; done


	my_array=(foo bar baz)
	echo "the array contains ${#my_array[@]} elements"
	exit

	HDA="-hda eserver.ovl"
	RAM="4096"
	NETNIC0="-net nic,vlan=0,macaddr=52:54:00:EF:E0:05,model=virtio"
	NETTAP0="-net tap,vlan=0,ifname=tap4,script=/etc/network/qemu-ifupbr0,downscript=/etc/network/qemu-ifdownbr0"
	VGA="cirrus"
	SMP="4"
	RTC=""
	VNCOPTIONS="-vnc :35"
	SDLOPTIONS=""
	USB=""


        KVM_COMMAND="kvm -enable-kvm $VGA $RTC $SMP $USB $NETNIC0 $NETTAP0 -usbdevice tablet -m $RAM $HDA $VNCOPTIONS $SDLOPTIONS $@"

	echo "KVM_COMMAND: $KVM_COMMAND" 
	ff $KVM_COMMAND


	exit
fi

do_test=0
if [ $do_test -eq 1 ]
then
	name="bk_main.sh"
	files=( * )
	echo foo
	echo "${name}${#files[@]}"
	echo foo
	exit

	echo "w: $waittimeinterval"

	donone=$waittimeinterval
        oldifs=$IFS
        IFS='-'

        a=($donone)	
	startdonone="09"
	enddonone=$startdonone



	l=${#a[@]}
	if [ $l = 2 ]
	then
		startdonone=${a[0]}
		enddonone=${a[1]}
	fi
	echo "array alle Daten: ${a[@]} "
	echo "array 0: $startdonone "
	echo "array 1: $enddonone "


        days=5
        hours=3
        minutes=6

        
        tdays=$( printf "%02d:%02d:%02d"  $days $hours $minutes )
        pdays=$( printf "%02d"  $days   )
        phours=$( printf "%02d"  $hours )
        pminutes=$( printf "%02d"  $minutes )
        ret="$pdays:$phours:$pminutes"
	echo "via printf  tdays  $tdays"
	echo "via strings ret    $ret"
	echo "via printf days pdays   $pdays"
	exit	
fi

do_test1=0
if [ $do_test1 -eq 1 ]
then

	declare -A abc
	abc[eins]="y,xx"

	# -v varname
	#    True if the shell variable varname is set (has been assigned a value).

	# test, if element is set ( -v )
	if [[ -v ${abc[zwei]} ]]
	then
		echo "ok"
	else
		echo "nok"
	fi
	p=${abc[eins]}
	echo "abc eins: ${p}"
	oldifs=$IFS
	IFS=','
	parray=($p)
	IFS=$oldifs

	l=${#parray[@]}
	echo "$l"
	echo "check y"
	inarray=$(echo "${parray[*]}" | grep -w -o "y" | wc -l )
	echo "inarray: $inarray"

	# array is expanded
	echo -e "print array: ${parray[*]}" 
	echo "${parray[@]}" 
	abc1="${parray[*]}" 
	echo  "${abc1}" 

	# array is expanded with echo 
	datelog  "print array: ${parray[*]}" 


	exit
fi



echo ""



