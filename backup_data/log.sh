# log.sh



ERRORLOG="error.log"
LOGFILE="llog.log"



function log {
   local msg=$1
   #echo "$msg" | tee -a $LOGFILE
   echo -e "$msg" >> $LOGFILE
}



function datelog {
        local _TODAY=`date +%Y%m%d-%H%M`
        log "$_TODAY ==>  $1"
}

function errorlog {
	local _TODAY=`date +%Y%m%d-%H%M`
	msg=$( echo "$_TODAY err ==> '$1'" )
	echo -e "$msg" >> $ERRORLOG
}



# EOF
