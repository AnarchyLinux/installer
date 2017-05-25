#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
### configure_user.sh
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

add_user() {

	while (true)	# Begin user menu while loop
	  do
		op_title="$user_op_msg"
		## Create main user dialog menu from users in $ARCH/etc/passwd include root user
		user=$(dialog --extra-button --extra-label "$edit" --ok-button "$new_user" --cancel-button "$done_msg" --menu "$user_menu_msg" 13 55 4 \
			$(for i in $(grep "100" "$ARCH"/etc/passwd | cut -d: -f1) ; do
				echo "$i $(grep -w "$i" "$ARCH"/etc/passwd | cut -d: -f7)"
			done) \
			"root" "$(grep -w "root" "$ARCH"/etc/passwd | cut -d: -f7)" 3>&1 1>&2 2>&3)

		## Check exit status of main user dialog menu
		case "$?" in
			1)	## if user selects cancel
				break
			;;
			0)	## if user selects add new user
				while (true)
				  do
					## prompt user for username
					user=$(dialog --cancel-button "$cancel" --ok-button "$ok" --inputbox "\n$user_msg1" 12 55 "" 3>&1 1>&2 2>&3)

					if [ "$?" -gt "0" ]; then
						break
					elif [ -z "$user" ]; then
						dialog --ok-button "$ok" --msgbox "\n$user_err_msg2" 10 60
					elif (grep "^$user:" "$ARCH"/etc/passwd &>/dev/null); then
						dialog --ok-button "$ok" --msgbox "\n$user_err_msg1" 10 60
					elif (<<<"$user" egrep "^[0-9]\|[A-Z\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]" &> /dev/null); then
						dialog --ok-button "$ok" --msgbox "\n$user_err_msg" 10 60
					else
						arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -s "$sh" "$user" &>/dev/null &
						set_password
						echo "$(date -u "+%F %H:%M") : Added user: $user" >> "$log"

						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var" 10 60) then
							(sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
							arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
						fi
						break
					fi
				done
			;;
			*)
				while (true)
				  do
					op_title="$user_op_msg1"
					usr_shell=$(grep -w "$user" "$ARCH"/etc/passwd | cut -d: -f7)
					if (grep -w "$user" "$ARCH"/etc/group | grep "wheel" &>/dev/null); then
						sudo="$yes"
					else
						sudo="$no"
					fi
					source "$lang_file"

					if [ "$user" == "root" ]; then
						user_edit=$(dialog --ok-button "$select" --cancel-button "$back" --menu "$user_edit_var" 12 55 2 \
							"$change_pass" "->" \
							"$change_sh" "->" 3>&1 1>&2 2>&3)
					else
						user_edit=$(dialog --ok-button "$select" --cancel-button "$back" --menu "$user_edit_var" 14 55 4 \
							"$change_pass" "->" \
							"$change_sh" "->" \
							"$change_su" "->" \
							"$del_user" "->" 3>&1 1>&2 2>&3)
					fi

					case "$user_edit" in
						"$change_pass")
							set_password
						;;
						"$change_sh")
							user_sh=$(dialog --ok-button "$select" --cancel-button "$cancel" --menu "$user_shell_var" 12 55 3 \
								$(for i in $(arch-chroot "$ARCH" chsh -l | sed 's!.*/!!' | uniq) ; do
									echo "$i ->"
								done) 3>&1 1>&2 2>&3)
							if [ "$?" -eq "0" ]; then
								case "$user_sh" in
									zsh)
										arch-chroot "$ARCH" chsh "$user" -s /usr/bin/zsh &>/dev/null
									;;
									fish)
										arch-chroot "$ARCH" chsh "$user" -s /bin/bash &>/dev/null
									;;
									*)
										arch-chroot "$ARCH" chsh "$user" -s /bin/"$user_sh" &>/dev/null
									;;

								esac
							fi
						;;
						"$change_su")
							if [ "$sudo" == "$yes" ]; then
								if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var1" 10 60) then
									arch-chroot "$ARCH" gpasswd -d "$user" wheel &>/dev/null
								fi
							else
								if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var" 10 60) then
									arch-chroot "$ARCH" usermod -a -G wheel "$user" &>/dev/null
								fi
							fi
						;;
						"$del_user")
							if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$deluser_var" 10 60) then
								arch-chroot "$ARCH" userdel --remove "$user" &>/dev/null
								break
							fi
						;;
						*)
							break
						;;
					esac
				done
			;;
		esac
	done

}

set_password() {

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
	echo "$(date -u "+%F %H:%M") : Password set: $user" >> "$log"
	op_title="$user_op_msg"

}
