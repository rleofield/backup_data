# ssh login for notify message
readonly sshhost="server"
readonly sshlogin="rleofield"
readonly sshtargetfolder="/home/$sshlogin/Desktop/backup_messages/"
readonly notifytargetsend="$sshlogin@$sshhost:$sshtargetfolder"
readonly notifytargetremovestring="ssh $sshlogin@$sshhost"
