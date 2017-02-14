#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Cleanup and reboot system
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

reboot_system() {

	op_title="$complete_op_msg"
	if "$INSTALLED" ; then
		if [ "$bootloader" == "$none" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$complete_no_boot_msg" 10 60) then
				reset ; exit
			fi
		fi

		reboot_menu=$(dialog --nocancel --ok-button "$ok" --menu "$complete_msg" 15 60 6 \
			"$reboot0" "-" \
			"$reboot6" "-" \
			"$reboot2" "-" \
			"$reboot1" "-" \
			"$reboot3" "-" \
			"$reboot5" "-" 3>&1 1>&2 2>&3)
		
		case "$reboot_menu" in
			"$reboot0")		umount -R "$ARCH"
							reset ; reboot ; exit
			;;
			"$reboot6")		umount -R "$ARCH"
							reset ; poweroff ; exit
			;;
			"$reboot1")		umount -R "$ARCH"
							reset ; exit
			;;
			"$reboot2")		clear
							echo -e "$arch_chroot_msg" 
							echo "/root" > /tmp/chroot_dir.var
							arch_anywhere_chroot
							clear
			;;
			"$reboot3")		if (dialog --yes-button "$yes" --no-button "$no" --yesno "$user_exists_msg" 10 60); then
								menu_enter=true
								add_user	
							else
								reboot_system
							fi
			;;
			"$reboot5")		install_software
			;;
		esac

	else

		if (dialog --yes-button "$yes" --no-button "$no" --yesno "$not_complete_msg" 10 60) then
			umount -R $ARCH
			reset ; reboot ; exit
		else
			main_menu
		fi
	fi

}
