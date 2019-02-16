#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### configure_user.sh
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

set_user() {

	while (true)	# Begin user menu while loop
	  do
		op_title="$user_op_msg"
		## Create main user dialog menu from users in $tmp_passwd include root user
		user=$(dialog --extra-button --extra-label "$edit" --ok-button "$new_user" --cancel-button "$done_msg" --menu "$user_menu_msg" 13 55 4 \
			$(while IFS= read -r i ; do
				echo "$i $(<"$tmp_passwd" cut -d: -f1,2 | grep -w $i | cut -d: -f2)"
			done <<<"$(sort "$tmp_passwd" | cut -d: -f1)") \
			"root" "$root_sh" 3>&1 1>&2 2>&3)

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
					elif (grep "^$user:" "$tmp_passwd" &>/dev/null); then
						dialog --ok-button "$ok" --msgbox "\n$user_err_msg1" 10 60
					elif (<<<"$user" grep "^[0-9]\|[A-Z\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]" &> /dev/null); then
						dialog --ok-button "$ok" --msgbox "\n$user_err_msg" 10 60
					else
						while (true)
						  do
							full_user=$(dialog --cancel-button "$cancel" --ok-button "$ok" --inputbox "\n$user_msg2" 12 55 3>&1 1>&2 2>&3)
							if [ "$?" != "0" ]; then
								break
							elif (<<<"$full_user" grep "," &> /dev/null) then
								dialog --ok-button "$ok" --msgbox "\n$fulluser_err_msg" 10 60
							elif $(cut -d: -f1,4 <"$tmp_passwd" | grep -w "$user" | cut -d: -f2 | grep -w "$full_user"); then
								dialog --ok-button "$ok" --msgbox "\n$fulluser_err_msg1" 10 60
							else
								set_password
								echo "$(date -u "+%F %H:%M") : Added user: $user" >> "$log"

								if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var" 10 60) then
									sudo_user=yes
								else
									sudo_user=no
								fi

								echo "${user}:${sh}:${sudo_user}:${full_user}:${pass_crypt}" >> "$tmp_passwd"

								if "$menu_enter" ; then
									add_user
								fi
								break
							fi
						done
						break
					fi
				done
			;;
			*)
				while (true)
				  do
					op_title="$user_op_msg1"
					user_sh=$(grep -w "$user" <"$tmp_passwd" | cut -d: -f2)
					full_user=$(grep -w "$user" <"$tmp_passwd" | cut -d: -f4)
					pass_crypt=$(grep -w "$user" <"$tmp_passwd" | cut -d: -f5)
					sudo_user=$(grep -w "$user" <"$tmp_passwd" | cut -d: -f3)
					if (grep -w "$user" <"$tmp_passwd" | cut -d: -f3 | grep "yes" &>/dev/null); then
						sudo="$yes"
					else
						sudo="$no"
					fi
					source "$lang_file"
					paswd=$(<"$tmp_passwd" grep -v "$user")

					if [ "$user" == "root" ]; then
						user_sh="$root_sh"
						sudo="$yes"
						full_user="superuser"
						source "$lang_file"
						user_edit=$(dialog --ok-button "$select" --cancel-button "$back" --menu "$user_edit_var" 15 55 2 \
							"$change_pass" "->" \
							"$change_sh" "->" 3>&1 1>&2 2>&3)
					else
						user_edit=$(dialog --ok-button "$select" --cancel-button "$back" --menu "$user_edit_var" 17 65 5 \
							"$change_pass" "->" \
							"$change_sh" "->" \
							"$change_su" "->" \
							"$change_fn" "->" \
							"$del_user" "->" 3>&1 1>&2 2>&3)
					fi

					case "$user_edit" in
						"$change_pass")
							set_password

							if "$menu_enter" ; then
								input="$(echo "$pass_crypt" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$ssl_key")"
						                (printf "$input\n$input" | arch-chroot "$ARCH" passwd "$user") &> /dev/null &
						                pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2passwd $user\Zn" load
								echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
							elif [ "$user" == "root" ]; then
								root_crypt="${pass_crypt}"
							else
								echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
							fi
						;;
						"$change_sh")
							user_sh=$(dialog --ok-button "$select" --cancel-button "$cancel" --menu "$user_shell_var" 15 55 6 \
								"bash"  "$shell5" \
					                        "dash"  "$shell0" \
					                        "fish"  "$shell1" \
					                        "mksh"  "$shell2" \
					                        "tcsh"  "$shell3" \
					                        "zsh"   "$shell4" 3>&1 1>&2 2>&3)
							if [ "$?" -eq "0" ]; then
								if ! (<<<"$base_install" grep "$user_sh" &>/dev/null); then
									base_install+="$user_sh "
								fi

								case "$user_sh" in
									zsh)	user_sh=/usr/bin/zsh
									;;
									fish)	user_sh=/bin/bash
									;;
									*)	user_sh=/bin/"$user_sh"
									;;

								esac
							fi

							if "$menu_enter" ; then
								arch-chroot "$ARCH" chsh "$user" -s "$user_sh" &>/dev/null

								if [ "$user" != "root" ]; then
									echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
								fi
							elif [ "$user" == "root" ]; then
								root_sh="$user_sh"
							else
								echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
							fi
						;;
						"$change_su")
							if [ "$sudo" == "$yes" ]; then
								if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var1" 10 60) then
									sudo_user=no
								fi
							else
								if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var" 10 60) then
									sudo_user=yes
								fi
							fi

							if "$menu_enter" ; then
								(sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
					                        arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
					                        pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2usermod -a -G wheel $user\Zn" load
							fi

							echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
						;;
						"$change_fn")
							while (true)
							  do
								full_user=$(dialog --cancel-button "$cancel" --ok-button "$ok" --inputbox "\n$user_msg2" 12 55 3>&1 1>&2 2>&3)
								if [ "$?" != "0" ]; then
									break
								elif (<<<"$full_user" grep "," &> /dev/null) then
									dialog --ok-button "$ok" --msgbox "\n$fulluser_err_msg" 10 60
								else
									if "$menu_enter" ; then
										if [ "$full_user" == "" ]; then
											full_user="$user"
										fi
										arch-chroot "$ARCH" chfn -f "$full_user" "$user" &>/dev/null
									fi

									echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
									break
								fi
							done
						;;
						"$del_user")
							if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$deluser_var" 10 60) then
								if "$menu_enter" ; then
									arch-chroot "$ARCH" userdel --remove "$user" &>/dev/null
								fi
								echo -e "${paswd}" > "$tmp_passwd"
								break
							else
								echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
								break
							fi
						;;
						*)	if [ "$user" != "root" ]; then
								echo -e "${paswd}\n${user}:${user_sh}:${sudo_user}:${full_user}:${pass_crypt}" > "$tmp_passwd"
							fi
							break
						;;
					esac
				done
			;;
		esac
	done

}

set_hostname() {

	op_title="$host_op_msg"

        while (true)     ## Begin set hostname loop
           do            ## Prompt user to enter hostname check for starting with numbers or containg special char
                 hostname=$(dialog --ok-button "$ok" --nocancel --inputbox "\n$host_msg" 12 55 "anarchy" 3>&1 1>&2 2>&3 | sed 's/ //g')

                 if (<<<$hostname grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()+=<>~;:/?.,^{}]\|]" &> /dev/null); then
                         dialog --ok-button "$ok" --msgbox "\n$host_err_msg" 10 60
                 else
                         break
                 fi
         done

         user=root
         set_password
         root_sh="$sh"
         root_crypt="$pass_crypt"

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

	pass_crypt="$(echo "$input" | openssl enc -aes-256-cbc -a -salt -pass pass:"$ssl_key")"
	sleep 1 &
	pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2encrypt passwd\Zn" load
	unset input input_chk ; input_chk=default
	op_title="$user_op_msg"

}

add_user() {

	if "$menu_enter" ; then
		if [ "$full_user" == "" ]; then
			arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -s "$sh" "$user" &>/dev/null &
	                pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2useradd $user\Zn" load
	        else
	                arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -c "$full_name" -s "$sh" "$user" &>/dev/null &
	                pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2useradd $user\Zn" load
	        fi

	        input="$(echo "$pass_crypt" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$ssl_key")"
	        (printf "$input\n$input" | arch-chroot "$ARCH" passwd "$user") &> /dev/null &
	        pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2passwd $user\Zn" load
	        unset input
	        echo "$(date -u "+%F %H:%M") : Password set: $user" >> "$log"

	        if [ "$sudo_user" == "yes" ]; then
			(sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
	                arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
			pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2usermod -a -G wheel $user\Zn" load
	        fi
	else
		while IFS= read -r i ; do
	                 if [ "$(<<<"$i" cut -d: -f4)" == "" ]; then
	                         arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -s "$(<<<"$i" cut -d: -f2)" "$(<<<"$i" cut -d: -f1)" &>/dev/null &
	                         pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2useradd $(<<<"$i" cut -d: -f1)\Zn" load
	                 else
	                         arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -c "$(<<<"$i" cut -d: -f4)" -s "$(<<<"$i" cut -d: -f2)" "$(<<<"$i" cut -d: -f1)" &>/dev/null &
	                         pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2useradd $(<<<"$i" cut -d: -f1)\Zn" load
	                 fi

	                 input="$(<<<"$i" cut -d: -f5 | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$ssl_key")"
	                 (printf "$input\n$input" | arch-chroot "$ARCH" passwd "$(<<<"$i" cut -d: -f1)") &> /dev/null &
	                 pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2passwd $(<<<"$i" cut -d: -f1)\Zn" load
	                 unset input
	                 echo "$(date -u "+%F %H:%M") : Password set: $(<<<"$i" cut -d: -f1)" >> "$log"

	                 if [ "$(<<<"$i" cut -d: -f3)" == "yes" ]; then
	                         (sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
	                         arch-chroot "$ARCH" usermod -a -G wheel "$(<<<"$i" cut -d: -f1)") &> /dev/null &
				 pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2usermod -a -G wheel $(<<<"$i" cut -d: -f1)\Zn" load
	                 fi
		done <<<$(sort "$tmp_passwd")
	fi

 }

# vim: ai:ts=8:sw=8:sts=8:noet
