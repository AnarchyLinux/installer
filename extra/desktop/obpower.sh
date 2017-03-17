#!/bin/bash
###############################################################
### Arch Linux Anywhere Script
### obpower
###
### Copyright (C) 2017 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: http://arch-anywhere.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0
###############################################################

if (pgrep Xorg &>/dev/null) && (which gxmessage &>/dev/null); then
	gxmessage "What would you like to do?" -center \
		-title "Power Options" -font "Sans bold 10" \
		-default "Cancel" -buttons \
		"_Cancel":1,"_Log out":2,"_Reboot":3,"_Shut down":4,"_Suspend":5 >/dev/null
else
	echo "<| Power Options |>"
	echo "1.) Cancel / Exit"
	echo "2.) Logout"
	echo "3.) Reboot"
	echo "4.) Shutdown"
	echo "5.) Suspend"
	echo -n "Select an option: "
	read input 
	return "$input"
fi

case $? in
	1)	echo "Exit"
	;;
	2)	openbox --exit
	;;
	3)	shutdown -r now
	;;
	4)	shutdown -h now
	;;
	5)	systemctl suspend
	;;
esac
