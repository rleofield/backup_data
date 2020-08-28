#!/bin/bash

# no test for local host, demo only
exit  0

# adapt for remote backup
HOST="host"
USER="root"


ping -c1 $HOST &> /dev/null
if test $? -eq 0
then
        ssh $USER@$HOST -p 22 'x=99; y=88; if test  -d ~/marker; then  exit $x; else exit $y; fi' &> /dev/null
        RET=$?
        if test  $RET -eq 99; then
                # host exists
                exit 0
        fi
fi

exit 1



