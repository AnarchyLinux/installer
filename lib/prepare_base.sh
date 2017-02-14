#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Prepare base install packages
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

prepare_base() {
	
	op_title="$install_op_msg"
	if "$mounted" ; then	
		install_menu=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$install_type_msg" 14 64 5 \
			"Arch-Linux-Base" 			"$base_msg0" \
			"Arch-Linux-Base-Devel" 	"$base_msg1" \
			"Arch-Linux-GrSec"			"$grsec_msg" \
			"Arch-Linux-LTS-Base" 		"$LTS_msg0" \
			"Arch-Linux-LTS-Base-Devel" "$LTS_msg1" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
				main_menu
			else
				prepare_base
			fi
		fi

		case "$install_menu" in
			"Arch-Linux-Base")
				base_install="linux-headers sudo" kernel="linux"
			;;
			"Arch-Linux-Base-Devel") 
				base_install="base-devel linux-headers" kernel="linux"
			;;
			"Arch-Linux-GrSec")
				base_install="base-devel linux-grsec linux-grsec-headers" kernel="linux-grsec"
			;;
			"Arch-Linux-LTS-Base")
				base_install="linux-lts linux-lts-headers sudo" kernel="linux-lts"
			;;
			"Arch-Linux-LTS-Base-Devel")
				base_install="base-devel linux-lts linux-lts-headers" kernel="linux-lts"
			;;
		esac

		while (true)
		  do
			shell=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$shell_msg" 16 64 6 \
				"bash"  "$shell5" \
				"dash"	"$shell0" \
				"fish"	"$shell1" \
				"mksh"	"$shell2" \
				"tcsh"	"$shell3" \
				"zsh"	"$shell4" 3>&1 1>&2 2>&3)
			if [ "$?" -gt "0" ]; then
				if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
					main_menu
				fi
			else
				case "$shell" in
                                        bash) sh="/bin/bash" shell="bash-completion"
                                        ;;
					fish) 	sh="/bin/bash"
					;;
					zsh) sh="/usr/bin/$shell" shell="zsh zsh-syntax-highlighting"
					;;
					*) sh="/bin/$shell"
					;;
				esac
	
				base_install+=" $shell"
				break
			fi
		done

		while (true)
		  do
			if "$UEFI" ; then
				bootloader=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$loader_type_msg" 13 64 4 \
					"grub"			"$loader_msg" \
					"syslinux"		"$loader_msg1" \
					"systemd-boot"	"$loader_msg2" \
					"$none" "-" 3>&1 1>&2 2>&3)
				ex="$?"
			else
				bootloader=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$loader_type_msg" 12 64 3 \
					"grub"			"$loader_msg" \
					"syslinux"		"$loader_msg1" \
					"$none" "-" 3>&1 1>&2 2>&3)
				ex="$?"
			fi
			
			if [ "$ex" -gt "0" ]; then
				if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
					main_menu
				fi
			elif [ "$bootloader" == "systemd-boot" ]; then
				break
			elif [ "$bootloader" == "syslinux" ]; then
				if ! "$UEFI" ; then
					if (tune2fs -l /dev/"$BOOT" | grep "64bit" &> /dev/null); then
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$syslinux_warn_msg" 11 60) then
							mnt=$(df | grep -w "$BOOT" | awk '{print $6}')
							(umount "$mnt"
							wipefs -a /dev/"$BOOT"
							mkfs.ext4 -O \^64bit /dev/"$BOOT"
							mount /dev/"$BOOT" "$mnt") &> /dev/null &
							pid=$! pri=0.1 msg="\n$boot_load \n\n \Z1> \Z2mkfs.ext4 -O ^64bit /dev/$BOOT\Zn" load
							base_install+=" $bootloader"
							break
						fi
					else
						base_install+=" $bootloader"
						break
					fi
				else
					base_install+=" $bootloader"
					break
				fi
			elif [ "$bootloader" == "grub" ]; then
				base_install+=" $bootloader"
				break
			else
				if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$grub_warn_msg0" 10 60) then
					dialog --ok-button "$ok" --msgbox "\n$grub_warn_msg1" 10 60
					break
				fi
			fi			
		done
	
		while (true)
		  do
			net_util=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$wifi_util_msg" 14 64 3 \
				"netctl"			"$net_util_msg0" \
				"networkmanager" 		"$net_util_msg1" \
				"$none" "-" 3>&1 1>&2 2>&3)
		
			if [ "$?" -gt "0" ]; then
				if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
					main_menu
				fi
			else
				if [ "$net_util" == "netctl" ] || [ "$net_util" == "networkmanager" ]; then
					base_install+=" $net_util dialog" enable_nm=true
				fi
				break
			fi
		done
		
		if "$wifi" ; then
			base_install+=" wireless_tools wpa_supplicant wpa_actiond"
		else
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$wifi_option_msg" 10 60) then
				base_install+=" wireless_tools wpa_supplicant wpa_actiond"
			fi
		fi
		
		if "$bluetooth" ; then
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$bluetooth_msg" 10 60) then
				base_install+=" bluez bluez-utils pulseaudio-bluetooth"
				enable_bt=true
			fi
		fi
		
		if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$pppoe_msg" 10 60) then
			base_install+=" rp-pppoe"
		fi
		
		if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$os_prober_msg" 10 60) then
			base_install+=" os-prober"
		fi
		
		if "$enable_f2fs" ; then
			base_install+=" f2fs-tools"
		fi
	
		if "$UEFI" ; then
			base_install+=" efibootmgr"
		fi

		if "$intel" && ! "$VM"; then
			base_install+=" intel-ucode"
		fi

	elif "$INSTALLED" ; then
		dialog --ok-button "$ok" --msgbox "\n$install_err_msg0" 10 60
		main_menu
	
	else

		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$install_err_msg1" 10 60) then
			prepare_drives
		else
			dialog --ok-button "$ok" --msgbox "\n$install_err_msg2" 10 60
			main_menu
		fi
	fi
	
}
