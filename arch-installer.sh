#!/bin/bash

### Arch Linux Anywhere Install Script
##
## Copyright (C) 2015  Dylan Schacht
##
## By: Deadhead (Dylan Schacht)
## Email: deadhead3492@gmail.com
## Webpage: arch-anywhere.tgits.co.uk
##
## Any questions, comments, or bug reports may be sent to abve
## email address. Enjoy, and keep on using Arch.
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either version 2
## of the License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License version 2 for more details.
###################################################################

lang_config() {

	clear
	ILANG=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Select your desired install language:" 15 60 6 \
		"English" "" \
		"German" "Deutsche" \
		"Portuguese" "Português" \
		"Romanian" "Română" 3>&1 1>&2 2>&3)

	case "$ILANG" in
		"English")
			export lang_file=/usr/share/arch-anywhere/arch-installer-english.conf
			export lang_link="https://raw.githubusercontent.com/deadhead420/arch-linux-anywhere/master/lang/arch-installer-english.conf"
		;;
		"German")
			export lang_file=/usr/share/arch-anywhere/arch-installer-german.conf
			export lang_link="https://raw.githubusercontent.com/deadhead420/arch-linux-anywhere/master/lang/arch-installer-german.conf"
		;;
		"Portuguese")
			export lang_file=/usr/share/arch-anywhere/arch-installer-portuguese.conf
			export lang_link="https://raw.githubusercontent.com/deadhead420/arch-linux-anywhere/master/lang/arch-installer-portuguese.conf"
		;;
		"Romanian")
			export lang_file=/usr/share/arch-anywhere/arch-installer-romanian.conf
			export lang_link="https://raw.githubusercontent.com/deadhead420/arch-linux-anywhere/master/lang/arch-installer-romanian.conf"
		;;
	esac

	source /etc/arch-anywhere.conf
	source "$lang_file"
#	setfont "$font"
	check_connection

}

check_connection() {

	if ! (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$intro_msg" 10 60) then
		clear ; exit
	fi
	
	until "$connection"
	  do
		wget --append-output=/tmp/wget.log -O /dev/null "http://speedtest.wdc01.softlayer.com/downloads/test10.zip" &
		pid=$! pri=1 msg="$connection_load" load
    
		if "$err" ; then
    
			if [ -n "$wifi_network" ]; then
    
				if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$wifi_msg0" 10 60) then
					wifi_menu
    
					if [ "$?" -gt "0" ]; then
						whiptail --title "$title" --ok-button "$ok" --msgbox "$wifi_msg0" 10 60
							clear ; echo "$connect_err1" ; exit 1
					else
						err=false
						wifi=true
					fi
				else
					whiptail --title "$title" --ok-button "$ok" --msgbox "$connect_err0" 10 60
					clear ; echo "$connect_err1" ; exit 1
				fi
			else
				whiptail --title "$title" --ok-button "$ok" --msgbox "$connect_err0" 10 60
				clear ; echo "$connect_err1" ;  exit 1
			fi
		else
			export connection_speed=$(tail -n 2 /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $1}')
			export connection_rate=$(tail -n 2 /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $2}')
        
			case "$connection_rate" in
				KB/s)
					down_sec=$((arch_total*1024/connection_speed))
				;;
				MB/s)
					down_sec=$((arch_total/connection_speed))
				;;
				GB/s)
					down_sec="1"
					down_min="1/2"
				;;
			esac
        
			cpu_mhz=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | sed 's/\..*//')
        
			if [ "$?" -gt "0" ]; then
				cpu_mhz=$(lscpu | grep "CPU MHz" | awk '{print $3}' | sed 's/\..*//')
			fi
        
			case "$cpu_mhz" in
				[0-9][0-9][0-9])
					cpu_sleep=4
				;;
				[1][0-9][0-9][0-9])
					cpu_sleep=4
				;;
				[2][0-9][0-9][0-9])
					cpu_sleep=3
				;;
				[3-5][0-9][0-9][0-9])
					cpu_sleep=2
				;;
			esac
        
			export down=$((down_sec/100+cpu_sleep))
			export down_min=$((down*100/60))
			connection=true
		fi
	done
	git_update

}

set_locale() {

	LOCALE=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$locale_msg" 15 60 6 \
	"en_US.UTF-8" "United States" \
	"en_AU.UTF-8" "Australia" \
	"en_CA.UTF-8" "Canada" \
	"de_DE.UTF-8" "German" \
	"en_GB.UTF-8" "Great Britain" \
	"en_MX.UTF-8" "Mexico" \
	"pt_PT.UTF-8" "Portugal" \
	"ro_RO.UTF-8" "Romanian" \
	"ru_RU.UTF-8" "Russian" \
	"$other"       "-"		 3>&1 1>&2 2>&3)

	if [ "$LOCALE" = "$other" ]; then
		LOCALE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$locale_msg" 15 60 6  $localelist 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then 
			set_locale
		fi
	fi

	locale_set=true
	set_zone

}

set_zone() {

	ZONE=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$zone_msg0" 15 60 6 $zonelist 3>&1 1>&2 2>&3)
	check_dir=$(find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE")

		if [ -n "$check_dir" ]; then
			sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
			SUBZONE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$zone_msg1" 15 60 6 $sublist 3>&1 1>&2 2>&3)

			if [ "$?" -gt "0" ]; then 
				set_zone 
			fi
			chk_dir=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE")

			if [ -n "$chk_dir" ]; then
				sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
				SUB_SUBZONE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$zone_msg1" 15 60 6 $sublist 3>&1 1>&2 2>&3)

				if [ "$?" -gt "0" ]; then 
					set_zone 
				fi
			fi
		fi

	zone_set=true
	set_keys

}

set_keys() {
	
	keyboard=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$keys_msg" 15 60 6 \
	"$default" "$default Keymap" \
	"us" "United States" \
	"de" "German" \
	"es" "Spanish" \
	"fr" "French" \
	"pt-latin9" "Portugal" \
	"ro" "Romanian" \
	"ru" "Russian" \
	"uk" "United Kingdom" \
	"$other"       "-"		 3>&1 1>&2 2>&3)
	source "$lang_file"

	if [ "$keyboard" = "$other" ]; then
		keyboard=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$keys_msg" 15 60 6  $key_maps 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			set_keys
		fi
	fi

	keys_set=true 
	prepare_drives

}

prepare_drives() {

	DRIVE=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$drive_msg" 15 60 5 $drive 3>&1 1>&2 2>&3)
	source "$lang_file"
	PART=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$part_msg" 16 62 4 \
	"$method0" "-" \
	"$method1" "-" \
	"$method2"  "-" \
	"$menu_msg" "-" 3>&1 1>&2 2>&3)

	if [ "$?" -gt "0" ]; then
		prepare_drives

	elif [ "$PART" == "$menu_msg" ]; then
		main_menu

	elif [ "$PART" == "$method1" ] || [ "$PART" == "$method0" ]; then

		if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$drive_var" 10 60) then
			sgdisk --zap-all "$DRIVE" &> /dev/null
		else
			prepare_drives
		fi

		FS=$(whiptail --title "$title" --nocancel --menu "$fs_msg" 15 60 6 \
			"ext4"      "$fs0" \
			"ext3"      "$fs1" \
			"ext2"      "$fs2" \
			"btrfs"     "$fs3" \
			"jfs"       "$fs4" \
			"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
			source "$lang_file"

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$swap_msg0" 10 60) then
			drive_bytes=$(fdisk -l | grep -w "$DRIVE" | awk '{print $5}') 
			total_mb=$(echo "$drive_bytes/(2^20)-4096" | bc)
			total_gb=$(echo "$drive_bytes/(2^30)-4" | bc)
			
			while [ "$swapped" != "true" ]
				do
					SWAPSPACE=$(whiptail --inputbox --nocancel "$swap_msg1" 10 60 "512M" 3>&1 1>&2 2>&3)
					unit=$(grep -o ".$" <<< "$SWAPSPACE")
					unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE") 
					
					if [ "$unit" == "M" ]; then 

						if [ "$unit_size" -lt "$total_mb" ]; then 
							SWAP=true 
							swapped=true
						else 
							whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg0" 10 60
						fi

					elif [ "$unit" == "G" ]; then 

						if [ "$unit_size" -lt "$total_gb" ]; then 
							SWAP=true 
							swapped=true
						else 
							whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg0" 10 60
						fi

					else 
						whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg1" 10 60
					fi
				done
		fi

		efivar -l &> /dev/null

		if [ "$?" -eq "0" ]; then

			if [ "$arch" == "x86_64" ]; then

				if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$efi_msg0" 10 60) then
					GPT=true 
					UEFI=true 
					down=$((down+1))
				fi
			fi
		fi

		if [ "$UEFI" == "false" ]; then 

			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$gpt_msg" 10 60) then 
				GPT=true
			fi
		fi

	else
		efivar -l &> /dev/null

		if [ "$?" -eq "0" ]; then

			if [ "$arch" == "x86_64" ]; then

				if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$efi_msg0" 10 60) then
					whiptail --title "$title" --ok-button "$ok" --msgbox "$efi_msg1" 10 60

					if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$efi_msg2" 10 60) then
						UEFI=true 
						down=$((down+1))
					else
						prepare_drives
					fi	
				fi
			fi
		fi

		part_tool=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$part_tool_msg" 15 60 5 \
					"cfdisk"  "$tool0" \
					"fdisk"   "$tool1" \
					"gdisk"   "$tool2" \
					"parted"  "$tool3" 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then prepare_drives ; fi
	fi

	case "$PART" in

		"$method0")

			if "$GPT" ; then

				if "$UEFI" ; then

					if "$SWAP" ; then
						echo -e "n\n\n\n512M\nef00\nn\n3\n\n+512M\n8200\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="$load_var0" load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					else
						echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="$load_var0" load
					fi

					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				else

					if "$SWAP" ; then
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n4\n\n+$SWAPSPACE\n8200\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="$load_var0" load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==5) print substr ($1,3) }')"
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					else
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="$load_var0" load
					fi

					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"	
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
				fi
			else

				if "$SWAP" ; then
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n3\n\n+$SWAPSPACE\nt\n\n82\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="$load_var0" load
					SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"					
					wipefs -a /dev/"$SWAP" &> /dev/null
					mkswap /dev/"$SWAP" &> /dev/null
					swapon /dev/"$SWAP" &> /dev/null
				else
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="$load_var0" load
				fi				

				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
			fi

			wipefs -a /dev/"$BOOT" &> /dev/null
			wipefs -a /dev/"$ROOT" &> /dev/null

			if "$UEFI" ; then
				mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="$efi_load" load
			else
				mkfs -t ext4 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="$boot_load" load
			fi

			if	[ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
				echo -e "y" | mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="$load_var1" load
			else
				mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="$load_var1" load
			fi

			mount /dev/"$ROOT" "$ARCH"

			if [ "$?" -eq "0" ]; then
				mounted=true
			fi

			mkdir $ARCH/boot
			mount /dev/"$BOOT" "$ARCH"/boot
		;;

		"$method1")

			if "$GPT" ; then

				if "$UEFI" ; then
					echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="$load_var0" load
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				else
					echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="$load_var0" load
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				fi
			else
				echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.3 msg="$load_var0" load
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				
			fi

			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$encrypt_var0" 10 60) then
				wipefs -a /dev/"$ROOT" &> /dev/null
				lvm pvcreate /dev/"$ROOT" &> /dev/null
				lvm vgcreate lvm /dev/"$ROOT" &> /dev/null

				if "$SWAP" ; then
					lvm lvcreate -L $SWAPSPACE -n swap lvm &> /dev/null
				fi

				lvm lvcreate -L 500M -n tmp lvm &> /dev/null
				lvm lvcreate -l 100%FREE -n lvroot lvm &> /dev/null

				while [ "$input" != "$input_chk" ]
	            		  do
	            	    		input=$(whiptail --passwordbox --nocancel "$encrypt_var1" 10 78 --title "$title" 3>&1 1>&2 2>&3)
	            	    		input_chk=$(whiptail --passwordbox --nocancel "$encrypt_var2" 9 78 --title "$title" 3>&1 1>&2 2>&3)

	            	        	if [ -z "$input" ]; then
                   			 		whiptail --title "$title" --ok-button "$ok" --msgbox "'$passwd_msg0'" 10 60
                   			 		input_chk=default
                   			 	elif [ "$input" != "$input_chk" ]; then
                      		    	whiptail --title "$title" --ok-button "$ok" --msgbox "'$passwd_msg1'" 10 60
                     		 	fi
	            	 	  done

				printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot - &
				pid=$! pri=0.2 msg="$encrypt_load" load
				printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -
				input=""

				if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
					echo -e "y" | mkfs -t "$FS" /dev/mapper/root &> /dev/null &
					pid=$! pri=1 msg="$load_var1" load
				else
					mkfs -t "$FS" /dev/mapper/root &> /dev/null &
					pid=$! pri=1 msg="$load_var1..." load
				fi

				mount /dev/mapper/root "$ARCH"

				if [ "$?" -eq "0" ]; then
					mounted=true
					crypted=true
				fi

				wipefs -a /dev/"$BOOT" &> /dev/null

				if "$UEFI" ; then
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="$efi_load" load
				else
					mkfs -t ext4 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="$boot_load" load
				fi

				mkdir $ARCH/boot
				mount /dev/"$BOOT" "$ARCH"/boot
			else
				prepare_drives
			fi
		;;

		"$method2")

			$part_tool /dev/"$DRIVE"
			
			if [ "$?" -gt "0" ]; then err=true; fi

			lsblk | egrep "$DRIVE[0-9]" &>/dev/null

			if [ "$?" -gt "0" ]; then err=true; fi

			if "$err" ; then
				whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg" 10 60
				err=false
				prepare_drives
			fi

			partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K" | sed "1d" | cut -c7- | awk '{print $1" "$4}')

			if "$UEFI" ; then
				BOOT=$(whiptail --nocancel --title "$title" --nocancel --menu "$efi_msg3" 15 60 5 $partition 3>&1 1>&2 2>&3)
				i=$(<<<$BOOT cut -c4-)

				if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$efi_msg4" 10 60) then
					echo -e "t\n${i}\nEF00\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="$efi_load" load
					points=$(echo -e "/home   >\n/srv    >\n/usr    >\n/var    >\nSWAP   >")
					mkdir $ARCH/boot
					mount /dev/"$BOOT" "$ARCH"/boot	
				else
					prepare_drives
				fi

				partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K\|$BOOT" | sed "1d" | cut -c7- | awk '{print $1" "$4}')
			fi

			ROOT=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$root_msg" 15 60 5 $partition 3>&1 1>&2 2>&3)

			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$new_fs_msg" 10 60) then
				FS=$(whiptail --title "$title" --nocancel --menu "$fs_msg" 15 60 6 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"btrfs"     "$fs3" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
				source "$lang_file"
				wipefs -a -q /dev/"$ROOT" &> /dev/null

				if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
					echo -e "y" | mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="$load_var1..." load
				else
					mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="$load_var1..." load
				fi

				mount /dev/"$ROOT" "$ARCH"

				if [ "$?" -eq "0" ]; then
					mounted=true
				else
					whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg" 10 60
					prepare_drives
				fi

			else
				prepare_drives
			fi

			until [ "$new_mnt" == "$done_msg" ] 
				do
					partition=$(lsblk | grep "$DRIVE" | grep -v "/\|[SWAP]\|1K" | sed "1d" | cut -c7- | awk '{print $1"     "$4}')
					new_mnt=$(whiptail --title "$title" --nocancel --menu "$part_sel_msg" 15 60 6 $partition "$done_msg" "$continue_msg" 3>&1 1>&2 2>&3)

					if [ "$new_mnt" != "Done" ]; then
						source "$lang_file"
						MNT=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$mnt_var0" 15 60 6 $points 3>&1 1>&2 2>&3)

						if [ "$MNT" == "SWAP" ]; then

							if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$swap_var" 10 60) then
								wipefs -a -q /dev/"$new_mnt"
								mkswap /dev/"$new_mnt" &> /dev/null
								swapon /dev/"$new_mnt" &> /dev/null
							fi

						elif [ -n "$MNT" ]; then
							source "$lang_file"
							
							if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$mnt_var1" 10 60) then
								FS=$(whiptail --title "$title" --nocancel --menu "$fs_msg" 15 60 6 \
									"ext4"      "$fs0" \
									"ext3"      "$fs1" \
									"ext2"      "$fs2" \
									"btrfs"     "$fs3" \
									"jfs"       "$fs4" \
									"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
								source "$lang_file"
								wipefs -a -q /dev/"$new_mnt"
								
								if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
									echo -e "y" | mkfs -t "$FS" /dev/"$new_mnt" &> /dev/null &
									pid=$! pri=1 msg="$load_var1..." load
								else
									mkfs -t "$FS" /dev/"$new_mnt" &> /dev/null &
									pid=$! pri=1 msg="$load_var1..." load
								fi

								mkdir "$ARCH"/"$MNT"
								mount /dev/"$new_mnt" "$ARCH"/"$MNT"
								points=$(echo  "$points" | grep -v "$MNT")
							fi
						fi
					fi
				done
		;;
	esac

	if ! "$mounted" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg" 10 60
		prepare_drives
	fi

	update_mirrors

}

update_mirrors() {

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$mirror_msg0" 10 60) then
		code=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$mirror_msg1" 15 60 6 $countries 3>&1 1>&2 2>&3)
		wget --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak &
		pid=$! pri=0.2 msg="$mirror_load0" load
		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist &
 		pid=$! pri=0.8 msg="$mirror_load1" load
 		mirrors_updated=true
	fi

	install_base

}

install_base() {

	if ! "$INSTALLED" && "$mounted" ; then	

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$install_var" 10 60) then

			if "$wifi" ; then
				pacstrap "$ARCH" base base-devel libnewt wireless_tools wpa_supplicant wpa_actiond netctl dialog &> /dev/null &
				pid=$! pri="$down" msg="$install_load" load
			else

				if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$wifi_option_msg" 11 60) then
					pacstrap "$ARCH" base base-devel libnewt wireless_tools wpa_supplicant wpa_actiond netctl dialog &> /dev/null &
					pid=$! pri="$down" msg="$install_load" load
				else
					pacstrap "$ARCH" base base-devel libnewt &> /dev/null &
					pid=$! pri="$down" msg="$install_load" load
				fi
			fi
			
			genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab
			INSTALLED=true

			while [ ! -n "$loader" ]
				do

					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$grub_msg0" 10 60) then

						if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$os_prober_msg" 10 60) then
							pacstrap "$ARCH" os-prober &> /dev/null &
							pid=$! pri=0.5 msg="$os_prober_load" load
						fi

						pacstrap "$ARCH" grub &> /dev/null &
						pid=$! pri=0.5 msg="$grub_load0" load

						if "$crypted" ; then
							sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
						else
							sed -i 's/quiet//' "$ARCH"/etc/default/grub
						fi

						if "$UEFI" ; then
							pacstrap "$ARCH" efibootmgr &> /dev/null &
							pid=$! pri=0.5 msg="Installing efibootmgr..." load
							arch-chroot "$ARCH" grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot &> /dev/null &
							pid=$! pri=0.5 msg="$grub_load1" load
							mv "$ARCH"/boot/EFI/boot/grubx64.efi "$ARCH"/boot/EFI/boot/bootx64.efi
							
							if ! "$crypted" ; then
								arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
								pid=$! pri=1 msg="$uefi_config_load" load
							fi
						else
							arch-chroot "$ARCH" grub-install /dev/"$DRIVE" &> /dev/null &
							pid=$! pri=0.5 msg="$grub_load1" load
						fi

						arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
						pid=$! pri=0.2 msg="$grub_load2" load

						loader=true
						bootloader=true

					else

						if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$grub_warn_msg0" 10 60) then
							whiptail --title "$title" --ok-button "$ok" --msgbox "$grub_warn_msg1" 10 60
							loader=true
						fi
					fi
				done

			configure_system

		else

			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$exit_msg" 10 60) then
				main_menu
			else
				install_base
			fi
		fi

	elif "$INSTALLED" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$install_err_msg0" 10 60
		main_menu

	else

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$install_err_msg1" 10 60) then
			prepare_drives
		else
			whiptail --title "$title" --ok-button "$ok" --msgbox "$install_err_msg2" 10 60
			main_menu
		fi
	fi

}

configure_system() {

	if "$system_configured" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$config_err_msg" 10 60
		main_menu
	fi

	if "$crypted" ; then

		if "$UEFI" ; then 
			echo "/dev/$BOOT              /boot           vfat         rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro        0       2" > "$ARCH"/etc/fstab
		else 
			echo "/dev/$BOOT              /boot           ext4         defaults        0       2" > "$ARCH"/etc/fstab
		fi

		echo "/dev/mapper/root        /               $FS         defaults        0       1" >> "$ARCH"/etc/fstab
		echo "/dev/mapper/tmp         /tmp            tmpfs        defaults        0       0" >> "$ARCH"/etc/fstab
		echo "tmp	       /dev/lvm/tmp	       /dev/urandom	tmp,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab

		if "$SWAP" ; then
			echo "/dev/mapper/swap     none            swap          sw                    0       0" >> "$ARCH"/etc/fstab
			echo "swap	/dev/lvm/swap	/dev/urandom	swap,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab
		fi

		sed -i 's/k filesystems k/k lvm2 encrypt filesystems k/' "$ARCH"/etc/mkinitcpio.conf
		arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
		pid=$! pri=1 msg="$encrypt_load1" load
	fi

	sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
	echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
	arch-chroot "$ARCH" locale-gen &> /dev/null &
	pid=$! pri=0.2 msg="$locale_load_var" load
	
	if [ "$keyboard" != "$default" ]; then
		echo "KEYMAP=$keyboard" > "$ARCH"/etc/vconsole.conf
	fi

	if [ -n "$SUB_SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE"/"$SUB_SUBZONE" /etc/localtime &
		pid=$! pri=0.2 msg="$zone_load_var0" load

	elif [ -n "$SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" /etc/localtime &
		pid=$! pri=0.2 msg="$zone_load_var1" load

	elif [ -n "$ZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE" /etc/localtime &
		pid=$! pri=0.2 msg="$zone_load_var2" load	
	fi

	if [ "$arch" == "x86_64" ]; then
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$multilib_msg" 10 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
		fi
	fi

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$dhcp_msg" 10 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.2 msg="$dhcp_load" load
	fi

	system_configured=true
	set_hostname

}

set_hostname() {

	hostname=$(whiptail --nocancel --inputbox "$host_msg" 10 40 "arch" 3>&1 1>&2 2>&3)
	echo "$hostname" > "$ARCH"/etc/hostname
	echo -e 'input=default
		while [ "$input" != "$input_chk" ]
            		do
                   			 input=$(whiptail --passwordbox --nocancel "'$root_passwd_msg0'" 10 78 --title "'$title'" 3>&1 1>&2 2>&3)
            		         input_chk=$(whiptail --passwordbox --nocancel "'$root_passwd_msg1'" 9 78 --title "'$title'" 3>&1 1>&2 2>&3)
                   			 if [ -z "$input" ]; then
                   			 	whiptail --title "$title" --ok-button "$ok" --msgbox "'$passwd_msg0'" 10 60
                   			 	input_chk=default
                   			 elif [ "$input" != "$input_chk" ]; then
                      		      whiptail --title "$title" --ok-button "$ok" --msgbox "'$passwd_msg1'" 10 60
                     		 fi
         		        done
    			echo -e "$input\n$input\n" | passwd &> /dev/null' > /mnt/root/set.sh
	chmod +x "$ARCH"/root/set.sh
	arch-chroot "$ARCH" ./root/set.sh
	rm "$ARCH"/root/set.sh

	hostname_set=true
	add_user

}

add_user() {

	if "$user_added" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$user_exists_msg" 10 60
		main_menu
	fi

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$user_msg0" 10 60) then
		user=$(whiptail --nocancel --inputbox "$user_msg1" 10 60 "" 3>&1 1>&2 2>&3)
		
		if [ -z "$user" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg" 10 60
			add_user
		fi

		user=$(<<<$user sed 's/ //g')
		user_check=$(<<<$user grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]")
		
		if [ -n "$user_check" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg" 10 60
			add_user
		fi

	else
		graphics
	fi

	source "$lang_file"
	arch-chroot "$ARCH" useradd -m -g users -G wheel,audio,network,power,storage,optical -s /bin/bash "$user"
	echo -e 'user='$user'
			   input=default
			           while [ "$input" != "$input_chk" ]
            				do
                   					 input=$(whiptail --passwordbox --nocancel "'$user_var0'" 9 78 --title "'$title'" 3>&1 1>&2 2>&3)
            				         input_chk=$(whiptail --passwordbox --nocancel "'$user_var1'" 9 78 --title "'$title'" 3>&1 1>&2 2>&3)
                   					 if [ -z "$input" ]; then
                   			 			whiptail --title "$title" --ok-button "$ok" --msgbox "'$passwd_msg0'" 10 60
                   			 			input_chk=default
                   			 		 elif [ "$input" != "$input_chk" ]; then
                      		    		whiptail --title "$title" --ok-button "$ok" --msgbox "'$passwd_msg1'" 10 60
                     		 		fi
         				        done
    					echo -e "$input\n$input\n" | passwd "$user" &> /dev/null' > /mnt/root/set.sh
	chmod +x "$ARCH"/root/set.sh
	arch-chroot "$ARCH" ./root/set.sh
	rm "$ARCH"/root/set.sh

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$sudo_var" 10 60) then
		sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
	fi

	export "$user"
	export user_added=true 
	graphics

}
	
graphics() {

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$xorg_msg" 10 60) then
		GPU=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 17 60 6 \
		"$default"			"$g0" \
		"mesa-libgl"        "$g1" \
		"Nvidia"            "$g2" \
		"Vbox-Guest-Utils"  "$g3" \
		"xf86-video-ati"    "$g4" \
		"xf86-video-intel"  "$g5" 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then
			graphics
		fi
	else
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$xorg_cancel_msg" 10 60) then
			install_software
		else
			graphics
		fi
	fi

	if [ "$GPU" == "Nvidia" ]; then
		GPU=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$nvidia_msg" 15 60 4 \
		"nvidia"       "$g6" \
		"nvidia-340xx" "$g7" \
		"nvidia-304xx" "$g8" 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then
			graphics
		fi 

		GPU="$GPU ${GPU}-libgl"

	elif [ "$GPU" == "Vbox-Guest-Utils" ]; then
		GPU="virtualbox-guest-utils mesa-libgl"
		echo -e "vboxguest\nvboxsf\nvboxvideo" > "$ARCH"/etc/modules-load.d/virtualbox.conf

	elif [ "$GPU" == "Default" ]; then
		GPU=""
	fi

	if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$touchpad_msg" 10 60) then
		GPU="$GPU xf86-input-synaptics"
	fi

	pacstrap "$ARCH" xorg-server xorg-server-utils xorg-xinit xterm $(echo "$GPU") &> /dev/null &
	pid=$! pri=2 msg="$xorg_load" load
	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_msg" 10 60) then
		until [ "$DE" == "set" ]
			do
				i=false
				DE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$enviornment_msg" 15 60 6 \
				"xfce4"         "$de0" \
				"mate"          "$de1" \
				"lxde"          "$de2" \
				"lxqt"          "$de3" \
				"gnome"         "$de4" \
				"cinnamon"      "$de5" \
				"KDE plasma"    "$de6" \
				"enlightenment" "$de7" \
				"openbox"       "$de8" \
				"awesome"       "$de9" \
				"i3"            "$de10" \
				"fluxbox"       "$de11" \
				"dwm"           "$de12" 3>&1 1>&2 2>&3)
				
				if [ "$?" -gt "0" ]; then 
					DE=set
				else
					i=true

					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$lightdm_msg" 10 60) then
						pacstrap "$ARCH" lightdm lightdm-gtk-greeter &> /dev/null &
						pid=$! pri="1" msg="$lightdm_load" load
						arch-chroot "$ARCH" systemctl enable lightdm.service &> /dev/null
					else
						whiptail --title "$title" --ok-button "$ok" --msgbox "$startx_msg" 10 60
					fi
				fi

				case "$DE" in

					"xfce4") start_term="exec startxfce4" 

							if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg0" 10 60) then
								DE_EXTRA="xfce4-goodies"
							fi
					;;

					"gnome") start_term="exec gnome-session"

						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg1" 10 60) then
							DE_EXTRA="gnome-extra" de_down=$((down+4))
						fi 
					;;

					"mate") start_term="exec mate-session"

						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg2" 10 60) then
							DE_EXTRA="mate-extra" de_down=$((down+2))
						fi
					;;

					"KDE plasma") start_term="exec startkde" DE="kde-applications"

						if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$extra_msg3" 10 60) then
							DE_EXTRA="plasma-desktop" de_down=$((down+4))
						else
							DE_EXTRA="plasma" de_down=$((down+5))
						fi
					;;

					"cinnamon") 
						start_term="exec cinnamon-session"
					;;
					
					"lxde") 
						start_term="exec startlxde"
					;;
					
					"lxqt") 
						start_term="exec startlxqt" 
						DE="lxqt oxygen-icons"
					;;
					
					"enlightenment") 
						start_term="exec enlightenment_start"
						DE="enlightenment terminology"
					;;
					
					"fluxbox") 
						start_term="exec startfluxbox"
					;;
					
					"openbox") 
						start_term="exec openbox-session"
					;;
					
					"awesome") 
						start_term="exec awesome"
					;;
					
					"dwm") 
						start_term="exec dwm"
					;;
					
					"i3") 
						start_term="exec i3"
					;;
				esac

				if [ -z "$de_down" ]; then
					de_down=$((down-1))
				fi

				if "$i" ; then
					pacstrap "$ARCH" $(echo "$DE $DE_EXTRA") &> /dev/null &
					pid=$! pri="$de_down" msg="$desktop_load" load

					if "$user_added" ; then
						echo "$start_term" > "$ARCH"/home/"$user"/.xinitrc
					else
						echo "$start_term" > "$ARCH"/root/.xinitrc
					fi

					DE=set
				fi
			done
	fi

	install_software

}

install_software() {

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$software_msg0" 10 60) then
		software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 60 10 \
		"arch-wiki"            "$m0" ON \
		"openssh"     	       "$m1" ON \
		"pulseaudio"  	       "$m2" ON \
		"screenfetch"          "$m3" ON \
		"vim"         	       "$m4" ON \
		"wget"        	       "$m5" ON \
		"apache"  	  	       "$m6" OFF \
		"audacity"             "$m7" OFF \
		"chromium"    	       "$m8" OFF \
		"cmus"        	       "$m9" OFF \
		"conky"       	       "$m10" OFF \
		"dropbox"              "$m11" OFF \
		"emacs"                "$m12" OFF \
		"firefox"     	       "$m13" OFF \
		"gimp"        	       "$m14 " OFF \
		"git"                  "$m15" OFF \
		"gparted"     	       "$m16" OFF \
		"htop"        	       "$m17" OFF \
		"libreoffice" 	       "$m18 " OFF \
		"lmms"                 "$m19" OFF \
		"lynx"        	       "$m20" OFF \
		"mpd"         	       "$m21" OFF \
		"mplayer"     	       "$m22" OFF \
		"ncmpcpp"     	       "$m23" OFF \
		"nmap"                 "$m24" OFF \
		"pitivi"               "$m25" OFF \
		"projectm"             "$m26" OFF \
		"screen"  	  	       "$m27" OFF \
		"simplescreenrecorder" "$m28" OFF \
		"steam"                "$m29" OFF \
		"tmux"    	  	   	   "$m30" OFF \
		"transmission-cli" 	   "$m31" OFF \
		"transmission-gtk"     "$m32" OFF \
		"virtualbox"  	       "$m33" OFF \
		"vlc"         	   	   "$m34" OFF \
		"ufw"         	       "$m35" OFF \
		"wget"                 "Wget cli downloader" ON \
		"zsh"                  "$m36" OFF 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then
			reboot_system
		fi

		download=$(echo "$software" | sed 's/\"//g')
		wiki=$(<<<$download grep "arch-wiki")

		if [ -n "$wiki" ]; then
			cp /usr/bin/arch-wiki "$ARCH"/usr/bin
			download=$(<<<$download sed 's/arch-wiki/lynx/')
		fi

	    	pacstrap "$ARCH" ${download} &> /dev/null &
	    	pid=$! pri=1 msg="$software_load" load
	fi

	if [ -f "$ARCH"/var/lib/pacman/db.lck ]; then
		rm "$ARCH"/var/lib/pacman/db.lck
	fi

	arch-chroot "$ARCH" pacman -Syyy &> /dev/null &
	pid=$! pri=1 msg="$pacman_load" load

	reboot_system

}

reboot_system() {

	if "$INSTALLED" ; then

		if ! "$bootloader" ; then

			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$complete_no_boot_msg" 10 60) then
				clear ; exit
			fi
		fi

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$complete_msg0" 10 60) then
			umount -R $ARCH
			clear ; reboot ; exit
		else

			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$complete_msg1" 10 60) then
				umount -R "$ARCH"
				clear ; exit
			else
				clear ; exit
			fi
		fi

	else

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$not_complete_msg" 10 60) then
			umount -R $ARCH
			clear ; reboot ; exit
		else
			main_menu
		fi
	fi

}

load() {

	{	int="1"
        	while (true)
    	    	do
    	            proc=$(ps | grep "$pid")
    	            if [ "$?" -gt "0" ]; then err=true break; fi
    	            sleep $pri
    	            echo $int
    	            int=$((int+1))
    	        done
            echo 100
            sleep 1
	} | whiptail --title "$title" --gauge "$msg" 8 78 0

}

main_menu() {

	menu_item=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$menu" 15 60 6 \
		"$menu0"            "-" \
		"$menu1"          "-" \
		"$menu2"            "-" \
		"$menu3"       "-" \
		"$menu4"        "-" \
		"$menu5"   "-" \
		"$menu6"      "-" \
		"$menu7"          "-" \
		"$menu8"              "-" \
		"$menu9"      "-" \
		"$menu10"      "-" \
		"$menu11"         "-" \
		"$menu12"        "-" 3>&1 1>&2 2>&3)

	case "$menu_item" in

		"$menu0") 

			if "$locale_set" ; then 
				whiptail --title "$title" --ok-button "$ok" --msgbox "$menu_err_msg0" 10 60
				main_menu
			fi
			set_locale 
		;;

		"$menu1")

			if "$zone_set" ; then 
				whiptail --title "$title" --ok-button "$ok" --msgbox "$menu_err_msg1" 10 60
				main_menu
			fi
			set_zone 
		;;

		"$menu2")

			if "$keys_set" ; then
				whiptail --title "$title" --ok-button "$ok" --msgbox "$menu_err_msg2" 10 60
				main_menu
			fi
			set_keys
		;;

		"$menu3")

			if "$mounted" ; then 
				whiptail --title "$title" --ok-button "$ok" --msgbox "$menu_err_msg3" 10 60 ; 
				main_menu
			fi
 			prepare_drives 
		;;

		"$menu4") 
			update_mirrors
		;;

		"$menu5")
			install_base
		;;

		"$menu6")
			
			if "$INSTALLED" ; then 
				configure_system
			fi

			whiptail --title "$title" --ok-button "$ok" --msgbox "$return_msg" 10 60
		;;
		
		"$menu7")
			
			if "$INSTALLED" ; then 
				set_hostname
			fi

			whiptail --title "$title" --ok-button "$ok" --msgbox "$return_msg" 10 60
		;;
		
		"$menu8")
			
			if "$INSTALLED" ; then 
				add_user
			fi

			whiptail --title "$title" --ok-button "$ok" --msgbox "$return_msg" 10 60
		;;
		
		"$menu9")
			
			if "$INSTALLED" ; then 
				graphics
			fi

			whiptail --title "$title" --ok-button "$ok" --msgbox "$return_msg" 10 60
		;;
		
		"$menu10")
			
			if "$INSTALLED" ; then
				install_software
			fi

			whiptail --title "$title" --ok-button "$ok" --msgbox "$return_msg" 10 60
		;;
		
		"$menu11") 
			reboot_system
		;;
		
		"$menu12") 

			if "$INSTALLED" ; then
				whiptail --title "$title" --ok-button "$ok" --msgbox "$menu_err_msg4" 10 60
				clear ; exit
			else

				if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$menu_exit_msg" 10 60) then
					clear ; exit
				else
					main_menu
				fi
			fi
		;;
	esac

	main_menu

}

git_update() {

	echo "$lang_link" >> /usr/share/arch-anywhere/git-update.link
	cd /tmp
	wget -i /usr/share/arch-anywhere/git-update.link &> /dev/null &
	pid="$!" pri=0.5 msg="Initializing installer..." load
	mv /tmp/arch-installer.sh /usr/bin/arch-anywhere-latest
	sed -i '25,135d' /usr/bin/arch-anywhere-latest
	sed -i 's!lang_config!source /etc/arch-anywhere.conf ; source "$lang_file" ; export reload=true ; set_locale!' /usr/bin/arch-anywhere-latest
	mv /tmp/arch-anywhere.conf /etc
	mv /tmp/* /usr/share/arch-anywhere/
	bash /usr/bin/arch-anywhere-latest

}

lang_config
