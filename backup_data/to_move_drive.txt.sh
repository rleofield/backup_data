


rsync -avSAXH /mnt/old/rs/project/ /mnt/new/rs/project/ -P -n


copy 
	old_project.conf new_project.conf



change in new_projekt.conf
config_version. 1.2
	old -> new
	snapshot_root.  /mnt/new/..
		/mnt/old/rs/projekt/ -> /mnt/new/rs/projekt/
	logfile./home/rleo/bin/backup_data/aa_new_acer.log
	rsync_long_args.--delete --numeric-ids --relative --delete-excluded   --log-file=/home/rleo/bin/backup_data/rr_red2_acer.log
	exclude_file.   /home/rleo/bin/backup_data/exclude/red2_acer


in folder pre
	cp red2_acer.pre.sh wdg_acer.pre.sh 
  	contents is not changed


in folder exclude
	cp red2_acer wdg_acer
  	contents is not changed


add new drive label to 
	DISKLIST="eluks red2 wdg"	
	in file cfg.target_disk_list


add new drive label and UUID in uuid.txt


add entries for new label and each projekt in new drive to cfg.projects 
a_properties['wdg']="noumount"
a_projects['wdg']="acer testbilder"·
a_interval['wdg_acer']=1:00:00


run ./test.sh


copy all old_projket .> new_projekt in folder retains_count
copy all old_projket .> new_projekt in folder interval_done/
	set merker in copied files, to mark the change in the drive
copy all old_projket .> new_projekt in folder done/




start and check log

