#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### menus.sh
###
### Copyright (C) 2017 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: https://anarchylinux.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0
###############################################################

reboot_system() {

	op_title="$complete_op_msg"
	## Check if system is installed
	if "$INSTALLED" ; then
		## Check if user has installed bootloader, if no promtp to exit to commandline
		if [ "$bootloader" == "$none" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$complete_no_boot_msg" 10 60) then
				reset ; exit
			fi
		fi

		## Begin reboot menu loop
		while (true)
		  do
			## Prompt for user input
			reboot_menu=$(dialog --nocancel --ok-button "$ok" --menu "$complete_msg" 16 60 7 \
				"$reboot0" "-" \
				"$reboot6" "-" \
				"$reboot2" "-" \
				"$reboot1" "-" \
				"$reboot4" "-" \
				"$reboot3" "-" \
				"$reboot5" "-" 3>&1 1>&2 2>&3)

			## Execute user input
			case "$reboot_menu" in
				"$reboot0")	## Reboot system
						umount -R "$ARCH"
						reset ; reboot ; exit
				;;
				"$reboot6")	## Poweroff system
						umount -R "$ARCH"
						reset ; poweroff ; exit
				;;
				"$reboot1")	## Unmount system and exit to command line
						umount -R "$ARCH"
						reset ; exit
				;;
				"$reboot2")	## Anarchy Chroot function
						clear
						echo -e "$arch_chroot_msg"
						echo "/root" > /tmp/chroot_dir.var
						anarchy_chroot
						clear
				;;
				"$reboot3")	## Edit users
						menu_enter=true
						set_user
				;;
				"$reboot5")	## Software menu
						menu_enter=true
						add_software
				;;
				"$reboot4")	## Show install log
						clear ; less "$log" clear
				;;
			esac
		done
	else
		## Warn user install not complete, prompt for reboot
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "$not_complete_msg" 10 60) then
			umount -R "$ARCH"
			reset ; reboot ; exit
		fi
	fi

}

main_menu() {

	op_title="$menu_op_msg"
	while (true)
	  do
		menu_item=$(dialog --nocancel --ok-button "$ok" --menu "$menu" 19 60 8 \
			"$menu13" "-" \
			"$menu0"  "-" \
			"$menu1"  "-" \
			"$menu2"  "-" \
			"$menu3"  "-" \
			"$menu5"  "-" \
			"$menu11" "-" \
			"$menu12" "-" 3>&1 1>&2 2>&3)

		case "$menu_item" in
			"$menu0")	## Set system locale
					set_locale
			;;
			"$menu1")	## Set system timezone
					set_zone
			;;
			"$menu2")	## Set system keymap
					set_keys
			;;
			"$menu3")	## Prepare drives check if mounted
					if "$mounted" ; then
						if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$menu_err_msg3" 10 60); then
							mounted=false ; prepare_drives
						fi
					else
						prepare_drives
					fi
			;;
			"$menu5")	## Begin base install
					if "$mounted" ; then
						install_options
						set_hostname
						set_user
						add_software
						install_base
						configure_system
						add_user
						reboot_system
					elif (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$install_err_msg1" 10 60) then
						prepare_drives
					fi
			;;
			"$menu11") 	## Reboot system function
					reboot_system
			;;
			"$menu12") 	## Exit installer
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$menu_exit_msg" 10 60) then
						reset ; exit
					fi
			;;
			"$menu13")	## Start command line session
					echo -e "alias anarchy=exit ; echo -e '$return_msg'" > /tmp/.zshrc
					clear
					ZDOTDIR=/tmp/ zsh
					rm /tmp/.zshrc
					clear
			;;
		esac
	## End main menu loop
	done

}

# vim: ai:ts=8:sw=8:sts=8:noet
