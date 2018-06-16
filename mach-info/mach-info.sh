#!/bin/bash
ndate=$(date +%F)
ntime=$(date +%T)
function printing {
wholespace=$(df -h /home | grep -E "\/home$" | awk '{print $2}')
freespace=$(df -h /home | grep -E "\/home$" | awk '{print  $4}')
title_style=$1
text_style=$2
reset_style=$3
delimiter="=========================================="
printf "\n$title_style$delimiter$reset_style\n$title_style%s$reset_style\n$title_style$delimiter$reset_style\n" "Some information about the current system:"
format_string=$text_style"%17.17s\t%s"$reset_style"\n"
username=$(id -nu)
printf $format_string "Machine:" $MACHTYPE 
printf $format_string "OS:" $OSTYPE
printf $format_string "Hostname:" $HOSTNAME
printf $format_string "Username:" $username
if (($UID == 0)); then
	printf $format_string $username":" "superuser"
else
	printf $format_string $username":" "usual user"
fi
printf $format_string "Memory:" $freespace"/"$wholespace" free"
printf $format_string "Bluetooth:" $(cat /proc/acpi/ibm/bluetooth | grep -i "status" | cut -d ":" -f 2)
printf $format_string "Battery charge:" $(acpi -bi | grep -i -m 1 "Battery 0" | cut -d ',' -f 2)
printf $format_string "Battery capacity:" $(acpi -bi | grep -i "capacity" | awk {'print $10'})" mAh"
printf $format_string "Date:" $ndate
printf $format_string "Time:" $ntime
}
logflag=false;
while getopts :l option; do
		case $option in
			l)logflag=true;;
			?)echo -e "There is no $OPTARG option\n";;
		esac
done
printing "\033[1;33;44m" "\033[0;33m" "\033[0m"
echo -e "\nPress any key to finish..."
while true; do
	read -t 0.01 -n 1 anykey;
	if (($? == 0)); then
		if [ "$logflag" == true ]; then
			cat <<- EOF > logs/mach-info_"$ndate"_"$ntime"_report.log
			This report was generated automatically.
			The report contains some information about machine, system and user.
		EOF
		printing >> logs/mach-info_"$ndate"_"$ntime"_report.log
		echo -e "The \"logs\mach-info_"$ndate"_"$ntime"_report.log\" was successfully created.\n"
		fi
		exit 0
	fi
done

