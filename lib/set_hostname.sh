#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Set hostname / Password / User
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

set_hostname() {

	op_title="$host_op_msg"
	hostname=$(dialog --ok-button "$ok" --nocancel --inputbox "\n$host_msg" 12 55 "arch-anywhere" 3>&1 1>&2 2>&3 | sed 's/ //g')
	
	if (<<<$hostname grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()+=<>~;:/?.,^{}]\|]" &> /dev/null); then
		dialog --ok-button "$ok" --msgbox "\n$host_err_msg" 10 60
		set_hostname
	fi
	
	echo "$hostname" > "$ARCH"/etc/hostname
	op_title="$passwd_op_msg"
	
	while [ "$input" != "$input_chk" ]
	  do
		input=$(dialog --nocancel --clear --insecure --passwordbox "$root_passwd_msg0" 11 55 --stdout)
    	input_chk=$(dialog --nocancel --clear --insecure --passwordbox "$root_passwd_msg1" 11 55 --stdout)
	 	
	 	if [ -z "$input" ]; then
	 		dialog --ok-button "$ok" --msgbox "\n$passwd_msg0" 10 55
	 		input_chk=default
	 	
	 	elif [ "$input" != "$input_chk" ]; then
	 	     dialog --ok-button "$ok" --msgbox "\n$passwd_msg1" 10 55
	 	fi
	done

	(printf "$input\n$input" | arch-chroot "$ARCH" passwd ; arch-chroot "$ARCH" chsh -s "$sh") &> /dev/null &
	pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2passwd root\Zn" load
	unset input input_chk ; input_chk=default

}

add_user() {

	op_title="$user_op_msg"
	if ! "$menu_enter" ; then
		if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$user_msg0" 10 60) then
			install_software
		fi
	fi

	user=$(dialog --nocancel --inputbox "\n$user_msg1" 12 55 "" 3>&1 1>&2 2>&3 | sed 's/ //g')
	if [ -z "$user" ]; then
		dialog --ok-button "$ok" --msgbox "\n$user_err_msg" 10 60
		add_user
	elif (<<<$user grep "^[0-9]\|[ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]" &> /dev/null); then
		dialog --ok-button "$ok" --msgbox "\n$user_err_msg" 10 60
		add_user
	fi

	arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -s "$sh" "$user" &>/dev/null &
	pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2useradd -m -g users -G ... -s $sh $user\Zn" load

	source "$lang_file"
	op_title="$passwd_op_msg"
	while [ "$input" != "$input_chk" ]
	  do
		input=$(dialog --nocancel --clear --insecure --passwordbox "$user_var0" 11 55 --stdout)
    	input_chk=$(dialog --nocancel --clear --insecure --passwordbox "$user_var1" 11 55 --stdout)
		 
		if [ -z "$input" ]; then
			dialog --ok-button "$ok" --msgbox "\n$passwd_msg0" 10 55
			input_chk=default
		elif [ "$input" != "$input_chk" ]; then
			dialog --ok-button "$ok" --msgbox "\n$passwd_msg1" 10 55
		fi
	done

	(printf "$input\n$input" | arch-chroot "$ARCH" passwd "$user") &> /dev/null &
	pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2passwd $user\Zn" load
	unset input input_chk ; input_chk=default
	op_title="$user_op_msg"
	
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var" 10 60) then
		(sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
		arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
		pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2usermod -a -G wheel $user\Zn" load
	fi

	if "$menu_enter" ; then
		reboot_system
	fi

}
