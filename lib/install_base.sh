#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Install base system
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

install_base() {

	op_title="$install_op_msg"
	pacman -Sy --print-format='%s' $(echo "$base_install") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
	pid=$! pri=0.1 msg="\n$pacman_load \n\n \Z1> \Z2pacman -Sy --print-format\Zn" load
	download_size=$(</tmp/size) ; rm /tmp/size
	export software_size="$download_size Mib"
	cal_rate
	
	if (dialog --yes-button "$install" --no-button "$cancel" --yesno "\n$install_var" "$x" 65); then
		tmpfile=$(mktemp)
		
		(pacman-key --init
		pacman-key --populate archlinux) &> /dev/null &
		pid=$! pri=1 msg="\n$keys_load\n\n \Z1> \Z2pacman-key --init ; pacman-key --populate archlinux\Zn" load

		if [ "$kernel" == "linux" ]; then
			base_install="$(pacman -Sqg base) $base_install"
			(pacstrap "$ARCH" --force $(echo "$base_install") ; echo "$?" > /tmp/ex_status) &> "$tmpfile" &
			pid=$! pri=$(echo "$down" | sed 's/\..*$//') msg="\n$install_load_var" load_log
		else
			base_install="$(pacman -Sqg base | sed 's/^linux//') $base_install"
			(pacstrap "$ARCH" --force $(echo "$base_install") ; echo "$?" > /tmp/ex_status) &> "$tmpfile" &
			pid=$! pri=$(echo "$down" | sed 's/\..*$//') msg="\n$install_load_var" load_log
		fi

		genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab

		if [ $(</tmp/ex_status) -eq "0" ]; then
			INSTALLED=true
		else
			mv "$tmpfile" /tmp/arch-anywhere.log
			dialog --ok-button "$ok" --msgbox "\n$failed_msg" 10 60
			reset ; tail /tmp/arch-anywhere.log ; exit 1
		fi					
	else
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
			main_menu
		else
			install_base
		fi
	fi

}
