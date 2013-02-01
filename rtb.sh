#! /bin/bash

# Some requirements
## Screen
## inotify (inotifywait)

######################CONFIG SECTION###########################################
#
##Path to the FTB jar file with no trailing slash /
server_path="/home/minecraft"
## FTB Server start command. (you can grab this from the .bat files)
server_start="java -Xms512M -Xmx2G -jar ${server_path}/ftbserver.jar"
##############Backup Options###################################################
## Time to wait between backups. (In seconds)
## Default is 14400 seconds (every 4 hours)
backup_interval=43200 # twice daily
## Backup location. No trailing slash /
## Set to something OUTSIDE the server path or it'll recursively backup your backups.
backup_location="/home/mcbackup"
## Backup Retention in DAYS
backup_retention=7
####################Extended Backup Options####################################
use_extended_options=0 # 0=false, 1=true  ##NOT implemented yet
keep_daily_backup=0 # Keep at least one backup from each day.
keep_weekly_backup=0 # Same for weekly backup.
keep_monthly_backup=0 # monthly
backup_time=00:00:00 # Timestamp for when backups should be made (roughly) HH:MM:SS
restart_after_backup=0 # restart server after performing a scheduled backup at the time above.
###############################################################################
function ftbmon() {
  kill $(ps faux | grep "${server_start}" | grep -i screen | awk '{print $2}')
  kill $(ps faux | grep inotifywait | grep $server_path | awk '{print $2}')
  sleep 55
  crashlog="$server_path/detected_crashes.txt"
  inotifywait -m -r --format '%:e %f' -e modify -e create $server_path/crash-reports/ > $crashlog &
  while [[ 1 ]]
   do
    server_check
    sleep 5
    epoch_time=$(date +%s)
    last_backup="$(stat -c %X $(find ${backup_location} -type f -mtime -1 -iname "backup*.zip"|grep $(date +%b)|sort|tail -n 1) 2>/dev/null)"
    [[ -z $last_backup ]] && last_backup=1 ## 1 second epoch time to force a backup if none exists.
    backup_time_diff=$(($epoch_time - $last_backup))
    if [[ $backup_time_diff -gt $backup_interval ]]
    then
      [[ ! -d $backup_location ]] && mkdir -p $backup_location
      echo -e "$(date) -- \e[1;32mCreating a server backup:\e[0;32m Time since last backup: $backup_time_diff seconds ($(($backup_time_diff/60)) minutes) ($(($backup_time_diff/60/60)) hours)\e[0m"
      backup_file="${backup_location}/backup-$(date +%H-%M-%S_%d-%b-%Y).zip"
      zip -r "${backup_file}" "${server_path}" &> /dev/null
      echo -e "$(date) -- \e[0;32mBacked Up Server files to\e[1;32m ${backup_file} \e[0m"
      find ${backup_location} -type f -name "backup-*.zip" -mtime +${backup_retention} -exec rm -fv "{}" \;
    fi
    if [[ $use_extended_options = 1 ]]
     then extended_backup
    fi
  done
}

function server_check() {
  if [[ "$(ps faux | grep "${server_start}" | grep -i screen)" == "" ]]
   then echo -e "$(date) -- \e[0;31mServer NOT running...\e[0m  \e[0;33mAttempting to start.\e[0m"
    kill $(ps faux | grep "${server_start}" | grep -i screen | awk '{print $2}')
    sleep 5
    screen -S "FTB-Server" -d -m -c /dev/null -- bash -c "$server_start;exec $SHELL"
    sleep 55
  elif [[ $(tail -n1 $crashlog | grep CREATE) ]]
   then echo -e "$(date) -- \e[0;31mServer crash detected...\e[0m  \e[0;33mAttempting to restart.\e[0m"
    kill $(ps faux | grep "${server_start}" | grep -i screen | awk '{print $2}')
    sleep 5
    screen -S "FTB-Server" -d -m -c /dev/null -- bash -c "$server_start;exec $SHELL"
    echo "" > $crashlog
    sleep 55
  fi
}

function extended_backup() {
  sleep 1 # Doesn't do anything yet. 
}

ftbmon &
screen -S "FTB-Server" -d -m -c /dev/null -- bash -c "$server_start;exec $SHELL"
