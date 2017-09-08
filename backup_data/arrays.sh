# arrays.sh



# keys for control a disk
# umount = disk is unmounted, for external USB
# xumount = disk stays at system, for internal disks
declare -A a_properties
a_properties['cluks']="xumount"


# sub projects per disk
declare -A a_projects
a_projects['cluks']="l0 l1 l2"
a_projects['bluks']="l0 l1 l2 btest1"
#a_projects['bluks']="btest1"


# time interval in minutes
# 1440 = 1 tag
declare -A a_interval
# days:hours:minutes
# hours:minutes
# minutes
a_interval['cluks_l0']=1:17
a_interval['cluks_l1']=2:16
a_interval['cluks_l2']=3:13
a_interval['bluks_l0']=4:18
a_interval['bluks_l1']=5:12
a_interval['bluks_l2']=6:13
a_interval['bluks_btest1']=7:14


# successarray
# successful projects listed in this order in file 'successloglines.txt' 
SUCCESSLINE="bluks:l0 bluks:l1 bluks:l2 bluks:btest1 cluks:l0 cluks:l1 cluks:l2"
