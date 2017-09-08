#!/bin/bash


# file: mount.sh

. ./log.sh


FILENAME=$(basename "$0" .sh)

label=$1
FILENAME="umount:$label"


if [[ "$label" == *luks ]]
then
	#datelog "${FILENAME}:  is luks"
	#datelog "${FILENAME}:   LUKS: 'umount /mnt/$label'"
	umount /mnt/$label
	RET=$?
	if test $RET -eq 0
	then
		datelog "${FILENAME}:   LUKS: 'cryptsetup luksClose $label'"
		cryptsetup luksClose $label
		RET=$?
		if test $RET -ne 0
		then
			datelog "${FILENAME}:   LUKS: 'cryptsetup luksClose $label' fails"
			exit 1
		fi
	else
		datelog "${FILENAME}:   LUKS: 'umount /mnt/$label' fails"
		exit 1
	fi


	#datelog "${FILENAME}:   LUKS: ok, dismounted"
	exit 0
else
	#datelog "${FILENAME}:  is not luks, umount normal"
	#datelog "${FILENAME}:    'umount /mnt/$label'"
	umount /mnt/$label
	RET=$?
	if test $RET -ne 0
	then
		datelog "${FILENAME}: 'umount /mnt/$label' fails"
		exit 1
	fi
fi


exit 0
