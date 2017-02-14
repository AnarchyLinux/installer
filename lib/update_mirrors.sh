#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Update mirrorlists
###
### Copyright (C) 2017  Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: http://arch-anywhere.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0

update_mirrors() {

	op_title="$welcome_op_msg"
	if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$intro_msg" 10 60) then
		reset ; exit
	fi

	if ! (</etc/pacman.d/mirrorlist grep "rankmirrors" &>/dev/null) then
		op_title="$mirror_op_msg"
		code=$(dialog --nocancel --ok-button "$ok" --menu "$mirror_msg1" 17 60 10 $countries 3>&1 1>&2 2>&3)
		if [ "$code" == "AL" ]; then
			(wget -4 --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/all/" -O /etc/pacman.d/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/all\Zn" load
		elif [ "$code" == "AS" ]; then
			(wget -4 --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/all/https/" -O /etc/pacman.d/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/all/https\Zn" load
		else
			(wget -4 --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/?country=$code\Zn" load
		fi
		
		while [ "$(</tmp/ex_status.var)" -gt "0" ]
		  do
			if [ -n "$wifi_network" ]; then
				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$wifi_msg0" 10 60) then
					wifi-menu
					if [ "$?" -gt "0" ]; then
						dialog --ok-button "$ok" --msgbox "\n$wifi_msg1" 10 60
						setterm -background black -store ; reset ; echo "$connect_err1" | sed 's/\\Z1//;s/\\Zn//' ; exit 1
					else
						echo "0" > /tmp/ex_status.var
					fi
				else
					unset wifi_network
				fi
			else
				dialog --ok-button "$ok" --msgbox "\n$connect_err0" 10 60
				setterm -background black -store ; reset ; echo -e "$connect_err1" | sed 's/\\Z1//;s/\\Zn//' ;  exit 1
			fi
		done

		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist &
	 	pid=$! pri=0.8 msg="\n$mirror_load1 \n\n \Z1> \Z2rankmirrors -n 6 /etc/pacman.d/mirrorlist\Zn" load
	fi

}
