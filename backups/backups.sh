#!/bin/bash
#_________________________TITLE_______________________
function head {
local OLD_IFS=$IFS
IFS=$'\n'
clear
local x=$(tput cols)
if [ $x -lt 80 ];then
	echo -ne "\033[8;24;90t";
	x=80
fi
title_style=$1
reset_style=$2
local delimiter=""
for ((i=0; i<x; i++))
do
	delimiter=$delimiter"="
done
local header=$3
local y=$(($x/2+${#3}/2))
local whitestr=""
for ((i=0; i<(($x-$y));i++))
do
	whitestr=$whitestr" "
done
printf "\n$title_style$delimiter\n%${y}s$whitestr\n$delimiter$reset_style\n" $header
IFS=$OLD_IFS
}
#_________________________FLAGS_______________________
while getopts :chfd option; do
		case $option in
			c)head "\033[1;33;44m" "\033[0m" "Backup Configuration"				
#			sudo echo -e "#!/bin/sh\n### BEGIN INIT INFO\n# Provides:          backup\n# Required-Start:\n# Required-Stop:\n# Default-Start:\n# Default-Stop:	6\n# X-Interactive:     true\n# Short-Description: make and upload backup-files\n# Description:       make and upload backup-files\n### END INIT INFO\ncase \""'$1'"\" in\nstart)\necho \"START\"\n;;\nstop)\nbash $DIRSTACK/$0\necho \"STOP\"\n;;\nesac" > /etc/init.d/backup
#			sudo chmod +x /etc/init.d/backup
#			sudo update-rc.d backup stop 1 6 .
			exit 0;;
			d);;
			f)target=monthly
			srcs="/home /etc"
			excludi=xtra/backup_exclusions3.txt;;
			h)echo -e "\033[1mNAME\033[0m\n\tbackups.sh - make a backup of system and upload tp Yandex.Disk\n"
			echo -e "\033[1mSYNOPSIS\n\tbackups.sh \033[0m[OPTION]\n"
			echo -e "\033[1mDESCRIPTION\n\t-d\033[0m\n\t\tMake backup-file of \"daily\"-info and upload it to Yandex.Disk\n\t\033[1m-c\033[0m\n\t\tConfigure backup settings (namely how often to do and so on)\n\t\033[1m-h\033[0m\n\t\tshow this helpdesk and exit\n\t\033[1m-f\033[0m\n\t\tMake a backup-file of \"monthly\"-info and upload to Yandex.Disk"
			echo -e "\033[1mAUTHORS\033[0m\n\tRoman Kenig, kenromka@yandex.ru\n"
			exit 0;;
			?)echo -e "There is no $OPTARG option\nInput with flag \033[1m-h\033[0m to see helpdesk"
			exit 0;;
		esac
done
#______________________________________________________
#____________________USER_SETTINGS_____________________
if [ $# -eq 1 ]; then
	if [ $1 != "-f" ]; then
		target=daily
		srcs="/home/"
		excludi=xtra/backup_exclusions1.txt
	fi
else
	target=daily
	srcs="/home/"
	excludi=xtra/backup_exclusions1.txt
	echo $excludi
fi
backup_dir="/home/backup"
[ -d "$backup_dir" ] || mkdir -p $backup_dir
bu_num=30 
cur_date=$(date +%F-%T)
oauth_token=ABCDEFGHIJKLMONPQRS-JSJSJSJSJSJSJJSJS
report=$target"_backup_report.log"
myEmail=my@email.ru
output="$(date +%F-%T)".tar.gz
#[ -f "$report" ] || touch $report
#______________________________________________________
function mailto
{
	echo -e "subject:"$2"\nfrom:backup@kenromka.info\n"$1"_____"$target | /usr/sbin/sendmail $myEmail
#	echo "$2" | sendmail -s "$1" $myEmail > /dev/null
}

function logger
{
    echo "["$(date "+%F_%T")"] File $backup_dir: $1" >> $backup_dir/$report
}

function parse
{
    local output
    regex="(\"$1\":[\"]?)([^\",\}]+)([\"]?)"
    [[ $2 =~ $regex ]] && output=${BASH_REMATCH[2]}
    echo $output
}

function checkError
{
    echo $(parse 'error' "$1")
}

function getUploadUrl
{
    out=$(curl -s -H "Authorization: OAuth $oauth_token" https://cloud-api.yandex.net:443/v1/disk/resources/upload/?path=app:/$backupName&overwrite=true)
    error=$(checkError "$out")
    if [[ $error != '' ]];then
        logger $SECONDS": backup - Yandex.Disk error: $error"
        mailto "backup - Yandex.Disk backup error" "ERROR copy file $backupName. Yandex.Disk error: $error"
    	echo ''
    else
        output=$(parse 'href' $out)
        echo $output
    fi
}

function uploadFile {
    local out
    local uploadUrl
    local error
    uploadUrl=$(getUploadUrl)
    if [[ $uploadUrl != '' ]];then
    	echo $uploadUrl
        out=$(curl -s -T $1 -H "Authorization: OAuth $oauth_token" $uploadUrl)
        error=$(checkError "$out")
    	if [[ $error != '' ]];then
        	logger $SECONDS": ""backup - Yandex.Disk error: $error"
        	mailto "backup - Yandex.Disk backup error" "ERROR copy file $backupName. Yandex.Disk error: $error"

    	else
        	logger $SECONDS": ""backup - Copying file to Yandex.Disk success"
        	mailto "backup - Yandex.Disk backup success" "SUCCESS copy file $backupName"

    	fi
    else
    	echo 'Some errors occured. Check log file for detail'
    fi
}

function backups_list {
    curl -s -H "Authorization: OAuth $oauth_token" "https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/&sort=created&limit=100" | tr "{},[]" "\n" | grep "name[[:graph:]]*.tar.gz" | cut -d: -f 2 | tr -d '"'
}

function backups_count {
    local bkps=$(backups_list | wc -l)
    expr $bkps/2
}

function rm_old_backups {
    bkps=$(backups_count)
    old_bkps=$((bkps - bu_num))
    if [ "$old_bkps" -gt "0" ];then
        logger $SECONDS": Delete old backup-files from Yandex.Disk"
        for i in $(eval echo {1..$((old_bkps * 2))}); do
            curl -X DELETE -s -H "Authorization: OAuth $oauth_token" "https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/$(backups_list | awk '(NR == 1)')&permanently=true"
        done
    fi
}
logger "---------------------------------------"
logger "--- $PROJECT START BACKUP $cur_date ---"
logger "---------------------------------------"

logger $SECONDS": Create $backup_dir/$cur_date-files-backup.tar.gz"
tar -cvzf $backup_dir/$cur_date-files-backup.tar.gz --exclude-from=$excludi $srcs

logger $SECONDS": Uploading $backup_dir/$cur_date-files-backup.tar.gz to Yandex.Disk..."
backupName=$cur_date-files-backup.tar.gz
uploadFile $backup_dir/$cur_date-files-backup.tar.gz

logger $SECONDS": Delete local backup-file"
find $backup_dir -type f -name "*.gz" -exec rm '{}' \;

if [ "$bu_num" > "0" ];then 
	rm_old_backups
fi
logger $SECONDS": Backup finished"
#to have no more 300 strings in log-files
tail -n 300  $backup_dir/$report >$backup_dir/forchange.tmp
mv -f $backup_dir/forchange.tmp $backup_dir/$report
exit 0
