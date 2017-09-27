#!/bin/bash


. ./cfg.exit_codes



HOST="vdserver"
USER="root"


ping -c1 $HOST &> /dev/null
if test $? -eq 0
then
#        echo "ssh $USER@$HOST 'x=99; y=88; if test  -d ~/marker; then  exit $x; else exit $y; fi' "
        ssh $USER@$HOST 'x=99; y=88; if test  -d ~/marker; then  exit $x; else exit $y; fi' &> /dev/null
        RET=$?
        if test  $RET -eq 99; then
                # host exists
                exit 0
        fi
fi

exit $PRE_WAS_NOK



