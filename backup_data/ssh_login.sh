# ssh login for notify message
readonly sshhost="kvm"
readonly sshlogin="richard"
readonly sshtargetfolder="/home/$sshlogin/Desktop/backup_messages/"
readonly notifytargetsend="$sshlogin@$sshhost:$sshtargetfolder"
readonly notifytargetremovestring="ssh $sshlogin@$sshhost"
