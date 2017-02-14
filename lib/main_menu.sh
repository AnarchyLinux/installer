#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Main Menu
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

main_menu() {

	op_title="$menu_op_msg"
	menu_item=$(dialog --nocancel --ok-button "$ok" --menu "$menu" 20 60 9 \
		"$menu13" "-" \
		"$menu0"  "-" \
		"$menu1"  "-" \
		"$menu2"  "-" \
		"$menu3"  "-" \
		"$menu4"  "-" \
		"$menu5"  "-" \
		"$menu11" "-" \
		"$menu12" "-" 3>&1 1>&2 2>&3)

	case "$menu_item" in
		"$menu0")	set_locale
		;;
		"$menu1")	set_zone
		;;
		"$menu2")	set_keys
		;;
		"$menu3")	if "$mounted" ; then 
						if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$menu_err_msg3" 10 60); then
							mounted=false ; prepare_drives
						else
							main_menu
						fi
					fi
 					prepare_drives 
		;;
		"$menu4") 	update_mirrors
		;;
		"$menu5")	prepare_base
		;;
		"$menu11") 	reboot_system
		;;
		"$menu12") 	if "$INSTALLED" ; then
						dialog --ok-button "$ok" --msgbox "\n$menu_err_msg4" 10 60
						reset ; exit
					else
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$menu_exit_msg" 10 60) then
							reset ; exit
						else
							main_menu
						fi
					fi
		;;
		"$menu13")	echo -e "alias arch-anywhere=exit ; echo -e '$return_msg'" > /tmp/.zshrc
					clear
					ZDOTDIR=/tmp/ zsh
					rm /tmp/.zshrc
					clear
					main_menu
		;;
	esac

}
