#!/bin/bash


exit 0;

# exaples for backup of a remote host
# test, if remote host is reachable by ssh

. ./cfg.exit_codes



HOST="sourcehost"
USER="root"


ping -c1 $HOST &> /dev/null
if test $? -eq 0
then
	# in remote host folder '/root/marker' must exist, for check only
#        echo "ssh $USER@$HOST 'x=99; y=88; if test  -d ~/marker; then  exit $x; else exit $y; fi' "
        ssh $USER@$HOST 'x=99; y=88; if test  -d ~/marker; then  exit $x; else exit $y; fi' &> /dev/null
        RET=$?
        if test  $RET -eq 99; then
                # host exists
                exit 0
        fi
fi

exit $PRE_WAS_NOK



