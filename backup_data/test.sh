#!/bin/bash


echo "test conf files"
echo "rsnapshot -c conf/cluks_l0.conf configtest"
rsnapshot -c conf/cluks_l0.conf configtest
echo "rsnapshot -c conf/cluks_l1.conf configtest"
rsnapshot -c conf/cluks_l1.conf configtest
echo "rsnapshot -c conf/cluks_l2.conf configtest"
rsnapshot -c conf/cluks_l2.conf configtest

echo "rsnapshot -c conf/bluks_l0.conf configtest"
rsnapshot -c conf/bluks_l0.conf configtest
echo "rsnapshot -c conf/bluks_l1.conf configtest"
rsnapshot -c conf/bluks_l1.conf configtest
echo "rsnapshot -c conf/bluks_l2.conf configtest"
rsnapshot -c conf/bluks_l2.conf configtest
echo "rsnapshot -c conf/bluks_btest1.conf configtest"
rsnapshot -c conf/bluks_btest1.conf configtest



echo "test pre check "
echo "pre/cluks_l0.pre.sh" 
RET=$( pre/cluks_l0.pre.sh )
echo $?

echo "pre/cluks_l1.pre.sh" 
RET=$( pre/cluks_l1.pre.sh )
echo $?

echo "pre/cluks_l2.pre.sh" 
RET=$( pre/cluks_l2.pre.sh )
echo $?








