#!/bin/bash


# file: mount.sh

. ./log.sh


FILENAME=$(basename "$0" .sh)


# call: ./mount.sh $LABEL $MOUNTDIR $MARKERDIR


label=$1
FILENAME="mount:$label"
mountdir=/mnt/$label

if [[ "$label" == *luks ]]
then
#	datelog "${FILENAME}:  is luks"
	LUKSKEYFILE=/root/luks1_keyfile

	UUID=`grep -w ${label} uuid.txt | awk '{print $2}'`
	DEVICE="/dev/disk/by-uuid/${UUID}"
	datelog "${FILENAME}:   LUKS device: $DEVICE"

	# test, if LUKS Device is open
	# test against block device
	if test ! -b /dev/mapper/$label
	then
 #       	datelog "${FILENAME}:   LUKS:  cryptsetup luksOpen --key-file $LUKSKEYFILE $DEVICE $label"
	        cryptsetup luksOpen --key-file $LUKSKEYFILE $DEVICE $label
#       RETURN CODES
#              Cryptsetup returns 0 on success and a non-zero value on error.
#              Error codes are: 
#                1 wrong parameters, 
#                2 no permission (bad passphrase), 
#                3 out of memory, 
#                4 wrong device specified, 
#                5 device already exists or device is busy.

        	RET=$?
        	if test $RET -ne 0
        	then
        		datelog "${FILENAME}:   LUKS Device couldn't be opened"
                	exit 1
        	fi
	else
        	datelog "${FILENAME}:   LUKS Device /dev/mapper/$label is already open"
	fi

#	datelog "${FILENAME}:   LUKS: command: 'mount /dev/mapper/$label $mountdir'"
	mount /dev/mapper/$label $mountdir
	RET=$?
        if test $RET -ne 0
        then
        	datelog "${FILENAME}:   LUKS Device couldn't be mounted"
		exit 1
	fi
	

else
#	datelog "${FILENAME}:  is no luks device, mount normal"
#	datelog "${FILENAME}:    'mount -L $label $mountdir'"
	mount -L $label $mountdir
	RET=$?
        if test $RET -ne 0
        then
		exit 1
	fi
fi


exit 0
