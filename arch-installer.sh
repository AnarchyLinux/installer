#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###
### Copyright (C) 2016  Dylan Schacht
###
### By: Deadhead (Dylan Schacht)
### Email: deadhead3492@gmail.com
### Webpage: http://arch-anywhere.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0
###
### This program is free software; you can redistribute it and/or
### modify it under the terms of the GNU General Public License
### as published by the Free Software Foundation; either version 2
### of the License, or (at your option) any later version.
###
### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License version 2 for more details.
###############################################################

### the initial function is responsible for setting install language
### also responsible for reading configuration file

init() {

### First we set the desired install language
	clear
	ILANG=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "\nArch Anywhere Installer\n\n * Select your install language:" 19 60 8 \
		"English" "-" \
		"French" "Français" \
		"German" "Deutsch" \
		"Portuguese" "Português" \
		"Romanian" "Română" \
		"Russian" "Русский" \
		"Spanish" "Español" \
		"Swedish" "Svenska" 3>&1 1>&2 2>&3)

	case "$ILANG" in
		"English") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-english.conf ;;
		"French") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-french.conf ;;
		"German") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-german.conf ;;
		"Portuguese") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-portuguese.conf ;;
		"Romanian") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-romanian.conf ;;
		"Russian") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-russian.conf ;;
		"Spanish") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-spanish.conf ;;
		"Swedish") export lang_file=/usr/share/arch-anywhere/lang/arch-installer-swedish.conf ;;
	esac

### Source configuration and language files
	source /etc/arch-anywhere.conf
	source "$lang_file"
	export reload=true
	check_connection

}

### This is the check connection function
### this function is responisble for checking the connection speed
### also responsible for checking max cpu frequency

check_connection() {

### Display into message
	
	if ! (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$intro_msg" 10 60) then
		clear ; exit
	fi
	
### Test connection speed with 10mb file output into /dev/null
	(wget --append-output=/tmp/wget.log -O /dev/null "http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
	echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
	pid=$! pri=1 msg="\n$connection_load" load
	sed -i 's/\,/\./' /tmp/wget.log

### Begin connection test and error check
	while [ "$(</tmp/ex_status.var)" -gt "0" ]
	  do
    	
	### If connection error check for wifi network
		if [ -n "$wifi_network" ]; then
    		
		### If wifi network found prompt user to attempt connection with 'wifi-menu' command
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$wifi_msg0" 10 60) then
				wifi-menu "$wifi_network"
    			
			### If wifi-menu returns error print error message and exit
				if [ "$?" -gt "0" ]; then
					whiptail --title "$title" --ok-button "$ok" --msgbox "$wifi_msg1" 10 60
					clear ; echo "$connect_err1" ; exit 1
				
			### Else set wifi to true and error to false
				else
					wifi=true
					echo "0" > /tmp/ex_status.var
				fi
			
			### Else if user would not like to connect unset wifi network	
				else
					unset wifi_network
				fi
		
	### Else if connection error and no wifi network found print error message and exit
		else
			whiptail --title "$title" --ok-button "$ok" --msgbox "$connect_err0" 10 60
			clear ; echo -e "$connect_err1" ;  exit 1
		fi
	done
		
### Define network connection speed variables from data in wget.log
	connection_speed=$(tail /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $1}')
	connection_rate=$(tail /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $2}')

### Define cpu frequency variables
    cpu_mhz=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | sed 's/\..*//')

	if [ "$?" -gt "0" ]; then
		cpu_mhz=$(lscpu | grep "CPU MHz" | awk '{print $3}' | sed 's/\..*//')
	fi
        
 ### Define cpu sleep variable based on total cpu frequency
	case "$cpu_mhz" in
		[0-9][0-9][0-9]) 
			cpu_sleep=4
		;;
		[1][0-9][0-9][0-9])
			cpu_sleep=3.5
		;;
		[2][0-9][0-9][0-9])
			cpu_sleep=2.5
		;;
		*)
			cpu_sleep=1.5
		;;
	esac
        		
	export connection_speed connection_rate cpu_sleep
	rm /tmp/{ex_status.var} &> /dev/null
	set_locale

}

### This function is responsible for setting the locale

set_locale() {

### Prompt user to set LOCALE variable
	LOCALE=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$locale_msg" 18 60 10 \
	"en_US.UTF-8" "United States" \
	"en_AU.UTF-8" "Australia" \
	"en_CA.UTF-8" "Canada" \
	"es_ES.UTF-8" "Spanish" \
	"fr_FR.UTF-8" "French" \
	"de_DE.UTF-8" "German" \
	"en_GB.UTF-8" "Great Britain" \
	"en_MX.UTF-8" "Mexico" \
	"pt_PT.UTF-8" "Portugal" \
	"ro_RO.UTF-8" "Romanian" \
	"ru_RU.UTF-8" "Russian" \
	"sv_SE.UTF-8" "Swedish" \
	"$other"       "$other-locale"		 3>&1 1>&2 2>&3)

### If user selects 'other' locale display full list
	if [ "$LOCALE" = "$other" ]; then
		LOCALE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$locale_msg" 15 60 6 $localelist 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then 
			set_locale
		fi
	fi

	set_zone

}

### This function is responsible for setting the timezone

set_zone() {

### Prompt user to set timezone variable
	ZONE=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$zone_msg0" 18 60 10 $zonelist 3>&1 1>&2 2>&3)

	### If selected zone is a directory set with subzone inside selected directory
		if (find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE" &> /dev/null); then
			sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
			SUBZONE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$zone_msg1" 18 60 10 $sublist 3>&1 1>&2 2>&3)

			if [ "$?" -gt "0" ]; then 
				set_zone 
			fi

		### If subzone is a directory set again inside selected directory
			if (find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE" &> /dev/null); then
				sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
				SUB_SUBZONE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$zone_msg1" 15 60 6 $sublist 3>&1 1>&2 2>&3)

				if [ "$?" -gt "0" ]; then 
					set_zone 
				fi
			fi
		fi

	set_keys

}

### This function is responsible for setting the keymap

set_keys() {
	
### Prompt user to set keymap
	keyboard=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$keys_msg" 18 60 10 \
	"$default" "$default Keymap" \
	"us" "United States" \
	"de" "German" \
	"es" "Spanish" \
	"fr" "French" \
	"pt-latin9" "Portugal" \
	"ro" "Romanian" \
	"ru" "Russian" \
	"uk" "United Kingdom" \
	"$other"       "$other-keymaps"		 3>&1 1>&2 2>&3)
	source "$lang_file"

### If user selects 'other' display full list of keymaps
	if [ "$keyboard" = "$other" ]; then
		keyboard=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$keys_msg" 19 60 10  $key_maps 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			set_keys
		fi
	fi

	prepare_drives

}

### This function is responsible for, amoung other things partitioning
### Also responsible for creating filesystems and mounting
### This is probably one of the more complex functions in this program

prepare_drives() {

### First check is any drive is mounted or swap turned on
	lsblk | grep "/mnt\|SWAP" &> /dev/null
	
### If drive is mounted or swap turned on then unmount and turn off swap
	if [ "$?" -eq "0" ]; then
		umount -R "$ARCH" &> /dev/null &
		pid=$! pri=0.1 msg="$wait_load" load
		swapoff -a &> /dev/null &
	fi
	
### Prompt user to select their desired method of partitioning
### method0=Auto Partition ; method1=Auto Partition Encrypted ; method2=Manual Partition
	PART=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$part_msg" 17 64 4 \
	"$method0" "-" \
	"$method1" "-" \
	"$method2"  "-" \
	"$menu_msg" "-" 3>&1 1>&2 2>&3)

	if [ "$?" -gt "0" ] || [ "$PART" == "$menu_msg" ]; then
		main_menu
	
### If manual partition NOT selected begin setting drive configuration
	elif [ "$PART" != "$method2" ]; then
	
	### Use cat to generate a drive selection menu script
	### create the file '/tmp/part.sh' containing the command for the properly formatted menu
	### I then set the variable 'DRIVE' to the output of running the generated script and clean-up
		cat <<-EOF > /tmp/part.sh
				#!/bin/bash
				# simple script used to generate block device menu
				whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$drive_msg" 15 60 4 \\
				$(lsblk | grep "disk" | awk '{print "\""$1"\"""    ""\"""Type: "$6"    ""'$size': "$4"\""" \\"}' |
				sed "s/\.[0-9]*//;s/\,[0-9]*//;s/ [0-9][G,M]/&   /;s/ [0-9][0-9][G,M]/&  /;s/ [0-9][0-9][0-9][G,M]/& /")
				3>&1 1>&2 2>&3
			EOF
		
		DRIVE=$(bash /tmp/part.sh)
		rm /tmp/part.sh
		
	### If drive variable is not set user selected cancel
	### return to beginning of prepare drives function
		if [ -z "$DRIVE" ]; then
			prepare_drives
		fi
		
	### Read total gigabytes of selected drive and source language file variables
		drive_gigs=$(lsblk | grep -w "$DRIVE" | awk '{print $4}' | grep -o '[0-9]*' | awk 'NR==1') 

	### Prompt user to select new filesystem type
		FS=$(whiptail --title "$title" --nocancel --menu "$fs_msg" 16 65 6 \
			"ext4"      "$fs0" \
			"ext3"      "$fs1" \
			"ext2"      "$fs2" \
			"btrfs"     "$fs3" \
			"jfs"       "$fs4" \
			"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)

	### Prompt user to create new swap space
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$swap_msg0" 10 60) then
			
		### While swapped variable NOT true - Beginning of swap loop
			while ! "$swapped" 
			  do
				
			### Prompt user to set size for new swapspace default is '512M'
				SWAPSPACE=$(whiptail --inputbox --ok-button "$ok" --cancel-button "$cancel" "$swap_msg1" 10 55 "512M" 3>&1 1>&2 2>&3)
					
			### If user selects 'cancel' escape from while loop and set SWAP to false
				if [ "$?" -gt "0" ]; then
					SWAP=false
					swapped=true
				
			### Else error checking on swapspace variable
				else
					
				### If selected unit is set to 'M' MiB
					if [ "$(grep -o ".$" <<< "$SWAPSPACE")" == "M" ]; then 
						
					### If swapsize exceeded the total volume of the drive in MiB taking into account 4 GiB for install space
						if [ "$(grep -o '[0-9]*' <<< "$SWAPSPACE")" -lt "$(echo "$drive_gigs*1000-4096" | bc)" ]; then 
							SWAP=true 
							swapped=true
						
					### Else selected swap size exceedes total volume of drive print error message
						else 
							whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg0" 10 60
						fi

				### Else if selected unit is set to 'G' GiB
					elif [ "$(grep -o ".$" <<< "$SWAPSPACE")" == "G" ]; then 

				### If swapsize exceeded the total volume of the drive in GiB taking into account 4 GiB for install space
						if [ "$(grep -o '[0-9]*' <<< "$SWAPSPACE")" -lt "$(echo "$drive_gigs-4" | bc)" ]; then 
							SWAP=true 
							swapped=true
							
					### Else selected swap size exceedes total volume of drive print error message
						else 
							whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg0" 10 60
						fi

				### Else size unit not set to 'G' for GiB or 'M' for MiB print error
					else
						whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg1" 10 60
					fi
				fi
				
		### End of swap loop	
			done
			
		### End of setting swap
		fi
			
	### Run efivar to check if efi support is enabled
		efivar -l &> /dev/null

		if [ "$?" -eq "0" ]; then

		### If no error is returned prompt user to install with efi
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$efi_msg0" 10 60) then
					GPT=true 
					UEFI=true 
			fi
		fi

	### If uefi boot is not set to true prompt user if they would like to use GUID Partition Table
		if ! "$UEFI" ; then 

			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$gpt_msg" 11 60) then 
				GPT=true
			fi
		fi

		source "$lang_file"

		if "$SWAP" ; then
			drive_var="$drive_var1"
			height=15

			if "$UEFI" ; then
				drive_var="$drive_var2"
				height=16
			fi
		elif "$UEFI" ; then
			drive_var="$drive_var3"
			height=15
		else
			height=13
		fi
	
	### Prompt user to format selected drive
		if (whiptail --title "$title" --defaultno --yes-button "$write" --no-button "$cancel" --yesno "$drive_var" "$height" 60) then
			sgdisk --zap-all /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.1 msg="\n$frmt_load" load
	
	### Else reset back to beginning of prepare drives function
		else
			prepare_drives
		fi
### End setting drive configuration
	fi
	
### Begin drive configuration
	case "$PART" in
		
	### Auto partition drive
		"$method0")

		### If GPT partitioning is true
			if "$GPT" ; then

			### If UEFI boot is true
				if "$UEFI" ; then

				### If swapspace is true
					if "$SWAP" ; then
						
					### If swap is set with efi and gpt enabled echo partition commands into 'gdisk'
					### create new partition size 512M type of ef00 this is efi boot partition
					### create new partition size set to SWAPSPACE variable type set to 8200 'Linux SWAP'
					### use remaining space for root partition
						echo -e "n\n\n\n512M\nef00\nn\n3\n\n+$SWAPSPACE\n8200\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.1 msg="\n$load_var0" load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
						
					### Wipe swap filesystem create and enable new swapspace
						(wipefs -a /dev/"$SWAP"
						mkswap /dev/"$SWAP"
						swapon /dev/"$SWAP") &> /dev/null &
						pid=$! pri=0.1 msg="\n$swap_load" load
					
				### Else swapspace false
					else
						
					### If efi and gpt set but swap set to false echo partition commands into 'gdisk'
					### create boot 512M type of ef00 and use remaining space for root
						echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.1 msg="\n$load_var0" load
					fi

				### Set boot and root partition variables
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				
			### Else UEFI boot false
				else

				### If swapspace is true
					if "$SWAP" ; then
						
					### If uefi boot is false but gpt partitioning true echo commands into 'gdisk'
					### this gets confusing I couldn't recreate this command if I tried
					### creates a new 100M boot partition then creates a 1M Protected MBR boot partition type of EF02
					### Next creates swapspace and uses remaining space for root partition
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n4\n\n+$SWAPSPACE\n8200\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.1 msg="\n$load_var0" load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==5) print substr ($1,3) }')"
						(wipefs -a /dev/"$SWAP"
						mkswap /dev/"$SWAP"
						swapon /dev/"$SWAP") &> /dev/null &
						pid=$! pri=0.1 msg="\n$swap_load" load

					
				### Else swapspace is false
					else
						
					### If uefi boot false but gpt is true echo commands into 'gdisk'
					### Create boot and protected MBR use remaining space for root
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.1 msg="\n$load_var0" load
					fi
				
				### Set boot and root partition variables 	
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"	
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
				fi
			
		### Else GPT partitioning is false
			else

				if "$SWAP" ; then
					
				### If swap is true echo partition commands into 'fdisk'
				### create new partition size of 100M this is the boot partition
				### create new partition size of swapspace variable use remaining space for root partition
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n3\n\n+$SWAPSPACE\nt\n\n82\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.1 msg="\n$load_var0" load
					SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"					
					(wipefs -a /dev/"$SWAP"
					mkswap /dev/"$SWAP"
					swapon /dev/"$SWAP") &> /dev/null &
					pid=$! pri=0.1 msg="\n$swap_load" load

				else
					
				### If swap is false echo commands into 'fdisk'
				### create 100M boot partition and use remaining space for root partition
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.1 msg="\n$load_var0" load
				fi				

			### define boot and root partition variables
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
		
		### End partitioning
			fi

		### If uefi boot is set to true create new boot filesystem type of 'vfat'
			if "$UEFI" ; then
				(wipefs -a /dev/"$BOOT"
				mkfs.vfat -F32 /dev/"$BOOT") &> /dev/null &
				pid=$! pri=0.1 msg="\n$efi_load1" load
			
		### Else create new boot filesystem using selected filesystem type
			else
				(wipefs -a /dev/"$BOOT"
				mkfs -F -t "$FS" /dev/"$BOOT") &> /dev/null &
				pid=$! pri=0.1 msg="\n$boot_load" load
			fi

		### Create root filesystem using desired filesystem type
			(wipefs -a /dev/"$ROOT"
			mkfs -F -t "$FS" /dev/"$ROOT") &> /dev/null &
			pid=$! pri=1 msg="\n$load_var1" load

		### Mount root partition at arch mountpoint
			(mount /dev/"$ROOT" "$ARCH"
			echo "$?" > /tmp/ex_status.var
			mkdir $ARCH/boot
			mount /dev/"$BOOT" "$ARCH"/boot) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mnt_load" load

			if [ "$(</tmp/ex_status.var)" -eq "0" ]; then
				mounted=true
			fi

			rm /tmp/ex_status.var
		;;

	### Auto partition encrypted LVM
		"$method1")

		### Warn user of encrypting drive
			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$encrypt_var0" 10 60) then
				
			### While input not equal to input check password check loop
				while [ "$input" != "$input_chk" ]
	        	  do
	        		
	        	### Set password for drive encryption and check if it matches
	        		input=$(whiptail --passwordbox --nocancel "$encrypt_var1" 11 55 --title "$title" 3>&1 1>&2 2>&3)
	        	    input_chk=$(whiptail --passwordbox --nocancel "$encrypt_var2" 11 55 --title "$title" 3>&1 1>&2 2>&3)

	        	### If no password entered display error message and try again
	        	    if [ -z "$input" ]; then
               			whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg0" 10 60
        		 		input_chk=default
       			 	
       			### Else if passwords not equal display error and try again
       			 	elif [ "$input" != "$input_chk" ]; then
                  		whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg1" 10 60
                 	fi
	        	 
	        ### End password check loop
	        	 done
			
		### if user would not like to encrypt drive return to beginning of prepare drives function
			else
				prepare_drives
			fi

			
		### If GPT set to true echo partitioning commands into 'gdisk'
			if "$GPT" ; then

			### If uefi set to true echo commands to create efi boot partition
				if "$UEFI" ; then
					echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.1 msg="\n$load_var0" load
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				
			### Else echo commands to create gpt partion scheme with protected mbr boot
				else
					echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.1 msg="\n$load_var0" load
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				fi
			
		### Else echo partitioning commands into  fdisk
			else
				echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.1 msg="\n$load_var0" load
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
			fi

		### Wipe filesystem on root partition
			(wipefs -a /dev/"$ROOT"
			wipefs -a /dev/"$BOOT") &> /dev/null &
			pid=$! pri=0.1 msg="\n$frmt_load" load

		### Create new physical volume and volume group on root partition using LVM
			(lvm pvcreate /dev/"$ROOT"
			lvm vgcreate lvm /dev/"$ROOT") &> /dev/null &
			pid=$! pri=0.1 msg="\n$pv_load" load

		### If swap is set to true create new swap logical volume set to size of swapspace
			if "$SWAP" ; then
				lvm lvcreate -L "$SWAPSPACE" -n swap lvm &> /dev/null &
				pid=$! pri=0.1 msg="\n$swap_load" load
			fi

		### Create new locical volume for tmp and root filesystems 'tmp' and 'lvroot'
			(lvm lvcreate -L 500M -n tmp lvm
			lvm lvcreate -l 100%FREE -n lvroot lvm) &> /dev/null &
			pid=$! pri=0.1 msg="\n$lv_load" load

		### Encrypt root logical volume using cryptsetup lukas format
			(printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot -
			printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -) &> /dev/null &
			pid=$! pri=0.2 msg="\n$encrypt_load" load
			unset input ; input_chk=default

		### Create and mount root filesystem on new encrypted volume
			mkfs -F -t "$FS" /dev/mapper/root &> /dev/null &
			pid=$! pri=1 msg="\n$load_var1" load
			
		### If efi is true create new boot filesystem using 'vfat'
			if "$UEFI" ; then
				mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="\n$efi_load1" load
			
		### Else create new boot filesystem using selected filesystem type
			else
				mkfs -F -t "$FS" /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="\n$boot_load" load
			fi

			(mount /dev/mapper/root "$ARCH"
			echo "$?" > /tmp/ex_status.var
			mkdir $ARCH/boot
			mount /dev/"$BOOT" "$ARCH"/boot) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mnt_load" load

			if [ $(</tmp/ex_status.var) -eq "0" ]; then
				mounted=true
				crypted=true
			fi

			rm /tmp/ex_status.var

		;;

	### Manual partitioning selected
		"$method2")
		
		### Set mountpoints variable and move into manual partition function
			points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
			manual_partition
		;;
	esac

### If no root partition is mounted display error message and return to beginning of prepare drives function
	if ! "$mounted" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg" 10 60
		prepare_drives
	
### Else continue into update mirrors function
	else
		update_mirrors
	fi

}

### This next function takes care of guided manual partitioning
### also one of the more complex functions in this program

manual_partition() {

### Reset variables
	unset manual_part
	part_count=$(lsblk | grep "sd." | wc -l)
	
### Set menu height variable based on the number of listed partitions
	if [ "$part_count" -lt "6" ]; then
		height=16
		menu_height=5
	elif [ "$part_count" -lt "16" ]; then
		height=21
		menu_height=10
	else
		height=25
		menu_height=14
	fi
	
### Prompt user to select a drive or partition to edit
### due to the formatting of the partition menu I was forced to cat this menu into its own script
### cat creates the file '/tmp/part.sh containing the command used create the partition menu
### I then set the variable 'manual_part' to the output of running the generated script and clean-up
	cat <<-EOF > /tmp/part.sh
			#!/bin/bash
			# simple script used to generate block device menu
			whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$manual_part_msg" "$height" 70 "$menu_height" \\
			$(lsblk | grep -v "K" | grep "sd." | sed 's/\/mnt/\//;s/\/\//\//' | awk '{print "\""$1"\"""   ""\"""Type: "$6"   '$size': "$4"   '$mountpoint': "$7"\""" \\"}' |
			sed "s/\.[0-9]*//;s/\,[0-9]*//;s/ [0-9][G,M]/&   /;s/ [0-9][0-9][G,M]/&  /;s/ [0-9][0-9][0-9][G,M]/& /;s/\(^\"sd.*$size:......\).*/\1\" \\\/")
			"$done_msg" "$write>" 3>&1 1>&2 2>&3
		EOF

	manual_part=$(bash /tmp/part.sh)
	rm /tmp/part.sh
	clear
	
### If manual_part is not defined this means the user selected cancel
### return to prepare drives function
	if [ -z "$manual_part" ]; then
		prepare_drives
	
### Else if the manual_part variable contains a number 0-9 this means it is a partition
	elif (<<<$manual_part grep "[0-9]" &> /dev/null); then

	### Remove the line output so you're left with only device location eg 'sda1'
	### set the size of the selected partition
	### specify the existing mountpoint (if any)
		part=$(<<<$manual_part sed 's/├─//;s/└─//')
		part_size=$(lsblk | grep "$part" | awk '{print $4}' | sed 's/\,/\./')
		part_mount=$(lsblk | grep "$part" | awk '{print $7}' | sed 's/\/mnt/\//;s/\/\//\//')
		source "$lang_file"

	### If no partitions are mounted user must create root partition first
		if ! (lsblk | grep "part" | grep "/" &> /dev/null); then
	
		### Check the size of the selected partition
		### Root partition can't be smaller than 4 Gib
			case "$part_size" in
				[4-9]G|[0-9][0-9]*G|[4-9].*G|T)
				
				### If partition is in the correct size range prompt user to create new root partition
					if (whiptail --title "$title" --yes-button "$yes" --no-button "$cancel" --defaultno --yesno "$root_var" 13 60) then
						
					### Prompt user for new root partition filesystem type
						FS=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$fs_msg" 16 65 6 \
							"ext4"      "$fs0" \
							"ext3"      "$fs1" \
							"ext2"      "$fs2" \
							"btrfs"     "$fs3" \
							"jfs"       "$fs4" \
							"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)

					### If exit status greater than '0' user selected cancel
					### return to beginning for manual partition function
						if [ "$?" -gt "0" ]; then
							manual_partition
						fi

						source "$lang_file"

					### Prompt user to confirm creating new root mountpoint on partition
					### displays partition location partition size new mountpoint filesystem type
						if (whiptail --title "$title" --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$root_confirm_var" 14 50) then
						
						### Wipe root filesystem on selected partition
							wipefs -a -q /dev/"$part" &> /dev/null &
							pid=$! pri=0.1 msg="\n$frmt_load" load

						### Create new filesystem on root partition
							mkfs -F -t "$FS" /dev/"$part" &> /dev/null &
							pid=$! pri=1 msg="\n$load_var1" load

						### Mount new root partition at arch mountpoint
							(mount /dev/"$part" "$ARCH"
							echo "$?" > /tmp/ex_status.var) &> /dev/null &
							pid=$! pri=0.1 msg="\n$mnt_load" load

						### If exit status is equal to '0' set mounted, root, and drive variables
							if [ $(</tmp/ex_status.var) -eq "0" ]; then
								mounted=true
								ROOT="$part"
								DRIVE=$(<<<$part sed 's/[0-9]//')

						### Else mount command failed
						### display error message and return to prepare drives function
							else
								whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg1" 10 60
								prepare_drives
							fi
						fi
					fi
				;;
			### Size of selected partition is less than 4GB and root partition has not been selected
				*)
				### Partition too small to be root partition display error and prompt user to select another partition to be root
					whiptail --title "$title" --ok-button "$ok" --msgbox "$root_err_msg" 10 60
				;;
			esac

	### Else if partition is already mounted
		elif [ -n "$part_mount" ]; then
			
		### Display mounted message with partition info and mountpoint with edit and back buttons
			if (whiptail --title "$title" --yes-button "$edit" --no-button "$back" --defaultno --yesno "$manual_part_var0" 13 60) then
			
			### If user selects to edit existing mountpoint check if it is the root partition
			### if existing mountpoint is root warn user
				if [ "$part" == "$ROOT" ]; then
					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$manual_part_var2" 11 60) then
						
					### If user decides to change mountpoint on root partition set mounted to false
					### unset variables and unmount recursive root partition
						mounted=false
						unset ROOT DRIVE
						umount -R "$ARCH" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load" load
					fi
				
			### Else if user selected to edit existing mountpoint and is not root partition
				else
			
				### Check if mountpoint is swap partition
				### if mountpoint is swap and user would like to edit mountpoint turn off swap
					if [ "$part_mount" == "[SWAP]" ]; then
						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$manual_swap_var" 10 60) then
							swapoff /dev/"$part" &> /dev/null &
							pid=$! pri=0.1 msg="$wait_load" load
						fi
					
				### Else if mountpoint is not swap prompt user if they would like to change mountpoint
				### if user selects yes unmount the partition remove the created mountpoint and echo the mountpoint back into the points menu
					elif (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$manual_part_var1" 10 60) then
						umount  "$ARCH"/"$part_mount" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load" load
						rm -r "$ARCH"/"$part_mount"
						points=$(echo -e "$part_mount   mountpoint>\n$points")
					fi
				fi
			fi

	### Else if root partition has already been mounted and selected partition is not already mounted
	### prompt user to create a new mountpoint on selected partition
		elif (whiptail --title "$title" --yes-button "$edit" --no-button "$cancel" --yesno "$manual_new_part_var" 12 60) then
			
		### set the variable mnt to the location of new mountpoint
			mnt=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$mnt_var0" 15 60 6 $points 3>&1 1>&2 2>&3)
				
		### If exit status is greater than '0' user selected cancel
		### return to beginning of manual partition function
			if [ "$?" -gt "0" ]; then
				manual_partition
			fi

		### if user selected a custom mountpoint set err variable to true
			if [ "$mnt" == "$custom" ]; then
				err=true

			### begin custom mountpoint menu loop
			### until err is set to false prompt user to input custom mountpoint
				until ! "$err"
				  do
					mnt=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --inputbox "$custom_msg" 10 50 "/" 3>&1 1>&2 2>&3)
					
				### If exit status is greater than '0' user selected cancel
				### return to beginning of manual partition function
					if [ "$?" -gt "0" ]; then
						err=false
						manual_partition
					
				### Else if custom mountpoint contains special characters display error message and return to beginning of custom mountpoint loop
					elif (<<<$mnt grep "[\[\$\!\'\"\`\\|%&#@()+=<>~;:?.,^{}]\|]" &> /dev/null); then
						whiptail --title "$title" --ok-button "$ok" --msgbox "$custom_err_msg0" 10 60

				### Else if custom mountpoint is set to root '/' display error message and return to beginning of custom mountpoint loop
					elif (<<<$mnt grep "^[/]$" &> /dev/null); then
						whiptail --title "$title" --ok-button "$ok" --msgbox "$custom_err_msg1" 10 60
					
				### Else custom mountpoint is valid set err variable to false
					else
						err=false
					fi
				
			### End custom mountpoint loop
				done
			fi

					
		### Else prompt user to select filesystem type for selected partition
			if [ "$mnt" != "SWAP" ]; then
				FS=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$fs_msg" 16 65 6 \
					"ext4"      "$fs0" \
					"ext3"      "$fs1" \
					"ext2"      "$fs2" \
					"btrfs"     "$fs3" \
					"jfs"       "$fs4" \
					"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
					
				if [ "$?" -gt "0" ]; then
					manual_partition
				fi
			else
				FS="SWAP"
			fi

			source "$lang_file"
		
		### Confirm creating new mountpoint on partition
			if (whiptail --title "$title" --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$part_confirm_var" 14 50) then
				
			### If user set  mountpoint to swap
			### wipe filesystem on selected partition
			### create new swapspace on partition and turn swap on
				if [ "$mnt" == "SWAP" ]; then
					(wipefs -a -q /dev/"$part"
					mkswap /dev/"$part"
					swapon /dev/"$part") &> /dev/null &
					pid=$! pri=0.1 msg="\n$swap_load" load
				
			### Else if mount is not equal to swap
				else
					points=$(echo  "$points" | grep -v "$mnt")
				
				### Wipe filesystem on selected partition
					wipefs -a -q /dev/"$part" &> /dev/null &
					pid=$! pri=0.1 msg="\n$frmt_load" load
				
				### Create new filesystem on selected partition
					mkfs -F -t "$FS" /dev/"$part" &> /dev/null &
					pid=$! pri=1 msg="\n$load_var1" load
				
				### Create new mountpoint and mount selected partition
					(mkdir -p "$ARCH"/"$mnt"
					mount /dev/"$part" "$ARCH"/"$mnt") &> /dev/null &
					pid=$! pri=0.1 msg="\n$mnt_load" load
				fi
			fi
		fi

		manual_partition

### Else if manual part variable is set to 'done'
	elif [ "$manual_part" == "$done_msg" ]; then
	
	### If no partition is mounted display error message to user and return to beginning of manual partition function
		if ! "$mounted" ; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$root_err_msg1" 10 60
			manual_partition
		
	### Else partition is mounted, create a list and count of final partitions
		else
			final_part=$(lsblk | grep "/\|[SWAP]" | grep "part" | awk '{print $1"      "$4"       "$7}' | sed 's/\/mnt/\//;s/\/\//\//;1i'$partition': '$size':       '$mountpoint': ' | sed "s/\,/\./;s/\.[0-9]*//;s/ [0-9][G,M]/&   /;s/ [0-9][0-9][G,M]/&  /;s/ [0-9][0-9][0-9][G,M]/& /")
			final_count=$(lsblk | grep "/\|[SWAP]" | grep "part"  | wc -l)

			
		### Set the height of the write confirm menu based on the number of partitions to be added
			if [ "$final_count" -lt "7" ]; then
				height=17
			elif [ "$final_count" -lt "13" ]; then
				height=23
			elif [ "$final_count" -lt "17" ]; then
				height=26
			else
				height=30
			fi

		### Confirm writing changes to partition table and continue with install
			if (whiptail --title "$title" --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$write_confirm_msg \n\n $final_part \n\n $write_confirm" "$height" 50) then
				update_mirrors
			else
				manual_partition
			fi
		fi
	
### Else user selected a root block device 
### Prompt user to edit partition scheme
	else
		
	### Set the size of selected block device
		part_size=$(lsblk | grep "$manual_part" | awk 'NR==1 {print $4}')
		source "$lang_file"

	### Check if block device contains mounted partitions
		if (lsblk | grep "$manual_part" | grep "$ARCH" &> /dev/null); then	
			
		### If partitions are mounted display warning to user
			if (whiptail --title "$title" --yes-button "$edit" --no-button "$cancel" --defaultno --yesno "$mount_warn_var" 10 60) then
				
			### If user selects to edit partition scheme anyway unmount all partitions turn off any swap and edit with cfdisk
				points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
				(umount -R "$ARCH"
				swapoff -a) &> /dev/null &
				pid=$! pri=0.1 msg="$wait_load" load
				mounted=false
				unset DRIVE
				cfdisk /dev/"$manual_part"
			fi
		
	### Else block device does not contain any mounted partitions prompt user to edit partition scheme with cfdisk
		elif (whiptail --title "$title" --yes-button "$edit" --no-button "$cancel" --yesno "$manual_part_var3" 12 60) then
			cfdisk /dev/"$manual_part"
		fi

		manual_partition
	fi

}

update_mirrors() {

### Prompt user to update pacman mirrorlist
	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$mirror_msg0" 10 60) then
		
	### Display full list of mirrorlist country codes to user
	### use wget to fetch mirrorlist
		code=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$mirror_msg1" 18 60 10 $countries 3>&1 1>&2 2>&3)
		wget --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak &
		pid=$! pri=0.2 msg="\n$mirror_load0" load
		
	### Use sed to remove comments from mirrorlist and rank the top 6 mirrors into /etc/pacman.d/mirrorlist
		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist &
 		pid=$! pri=0.8 msg="\n$mirror_load1" load
 		mirrors_updated=true
	fi

	install_base

}

install_base() {

	
### Check if system is installed and drive is mounted
### if system is not installed but drive is mounted begin install process
	if "$mounted" ; then	

	### Display install menu prompting user to install base, base-devel, or linuxLTS
		install_menu=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$install_type_msg" 14 64 4 \
			"Arch-Linux-Base" 			"$base_msg0" \
			"Arch-Linux-Base-Devel" 	"$base_msg1" \
			"Arch-Linux-LTS-Base" 		"$LTS_msg0" \
			"Arch-Linux-LTS-Base-Devel" "$LTS_msg1" 3>&1 1>&2 2>&3)
		
	### If user selects cancel display exit message
		if [ "$?" -gt "0" ]; then
			
		### If user decides to exit return to main menu function
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$exit_msg" 10 60) then
				main_menu
			else
				install_base
			fi
		fi

	### Begin setting base install variable based on the users install type selection
		case "$install_menu" in
			"Arch-Linux-Base")
				base_install="base sudo"
			;;
			"Arch-Linux-Base-Devel") 
				base_install="base base-devel"
			;;
			"Arch-Linux-LTS-Base")
				base_install="base linux-lts sudo"
			;;
			"Arch-Linux-LTS-Base-Devel")
				base_install="base base-devel linux-lts"
			;;
		esac

		### Prompt user to install grub bootloader and add to base install variable
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$grub_msg0" 10 60) then	
			base_install="$base_install grub"
			bootloader=true
		else
				
			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$grub_warn_msg0" 10 60) then
				whiptail --title "$title" --ok-button "$ok" --msgbox "$grub_warn_msg1" 10 60
			else
				base_install="$base_install grub"
				bootloader=true
			fi
		fi

	
	### If user is using wifi or selected to install wifi tools add to base install variable
	### If user is not using wifi prompt to install netctl wireless tools and wpa supplicant
		if ! "$wifi" ; then
			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$wifi_option_msg" 11 60) then
				base_install="$base_install wireless_tools wpa_supplicant wpa_actiond netctl dialog"
			fi
		else
			base_install="$base_install wireless_tools wpa_supplicant wpa_actiond netctl dialog"
		fi

	### Prompt user to install os-prober and add to install variable
		if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$os_prober_msg" 10 60) then
			base_install="$base_install os-prober"
		fi

	### Use pacstrap to print the total size of all packages selected in the base install variable
		pacstrap "$ARCH" --print-format='%s' $(echo "$base_install") | sed '1,6d' | awk '{s+=$1} END {print s/1024/1024}' &> /tmp/size.var &
		pid=$! pri=1 msg="\n$pacman_load" load
		download_size=$(</tmp/size.var)

	### export the software size variable to display in menu to user then load the cal rate function to estimate download speed
		export software_size=$(echo "$download_size Mib")
		cal_rate

	### Prompt user to confirm installing Arch Linux
	### display packages to add size connection speed and estimated install time
		if (whiptail --title "$title" --yes-button "$install" --no-button "$cancel" --yesno "\n$install_var" 16 60) then
			
		### Begin installing arch linux to mountpoint with packages from the base install variable
			(pacstrap "$ARCH" $(echo "$base_install")
			genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab
			echo "$?" > /tmp/ex_status.var) &> /dev/null &
			pid=$! pri="$down" msg="$install_load" load
			
			if [ $(</tmp/ex_status.var) -eq "0" ]; then
				INSTALLED=true
			fi
			
			rm /tmp/ex_status.var

		### Check if bootloader was installed
			if "$bootloader" ; then
						
			### If encrypted configure grub with cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root replacing quiet boot
				if "$crypted" ; then
					sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
				
			### Else remove quiet boot from grub ---------------------------------------------------------
			### True linux should always have the init of the system scrolling by on the screen super fast
			### You can always tell a true linux badass by their screen at bootup
				else
					sed -i 's/quiet//' "$ARCH"/etc/default/grub
				fi

			### If user selected efi boot
				if "$UEFI" ; then
					
				pacstrap "$ARCH" efibootmgr &> /dev/null &
				pid=$! pri=1 msg="\n$efi_load" load

				### Chroot into system and install grub with efi options enabled
				### Rename the grubx64.efi boot file
					arch-chroot "$ARCH" grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot &> /dev/null &
					pid=$! pri=0.5 msg="\n$grub_load1" load
					mv "$ARCH"/boot/EFI/boot/grubx64.efi "$ARCH"/boot/EFI/boot/bootx64.efi
							
				### If not encrypted but efi is enabled reconfigure kernel after grub is installed
					if ! "$crypted" ; then
						arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
						pid=$! pri=1 msg="\n$uefi_config_load" load
					fi
				
			### Else efi boot is not enabled
				else
					
				### Chroot into system and install grub to root drive
					arch-chroot "$ARCH" grub-install /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.5 msg="\n$grub_load1" load
				fi

			### Chroot into system and configure grub
				arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
				pid=$! pri=0.1 msg="\n$grub_load2" load
			fi

		### When install is complete continue to the configure system function
			configure_system

	### Else user selected no to installing system
		else

		### Display are you sure you dont want to install new system message and return to main menu function
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$exit_msg" 10 60) then
				main_menu
			else
				install_base
			fi
		fi

### Else if system has already been installed display error message and return to main menu
	elif "$INSTALLED" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$install_err_msg0" 10 60
		main_menu

### Else drive has not been mounted
### Prompt user to return to prepare drive function
### else return to main menu
	else

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$install_err_msg1" 10 60) then
			prepare_drives
		else
			whiptail --title "$title" --ok-button "$ok" --msgbox "$install_err_msg2" 10 60
			main_menu
		fi
	fi

}

### This function is responsible for configuring the newly installed system

configure_system() {

	if ! "$INSTALLED" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$install_err_msg3" 10 60
		main_menu
	fi

### Check if system is encrypted
	if "$crypted" ; then

	### If system is enctypted and efi boot is enabled echo new boot data into fstab
		if "$UEFI" ; then 
			echo "/dev/$BOOT              /boot           vfat         rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro        0       2" > "$ARCH"/etc/fstab
		
	### Else if system is only encrypted not with efi enabled echo new boot data into grub
		else 
			echo "/dev/$BOOT              /boot           $FS         defaults        0       2" > "$ARCH"/etc/fstab
		fi

	### echo new encrypted volume data into fstab
		echo "/dev/mapper/root        /               $FS         defaults        0       1" >> "$ARCH"/etc/fstab
		echo "/dev/mapper/tmp         /tmp            tmpfs        defaults        0       0" >> "$ARCH"/etc/fstab
		
	### echo data for encrypted tmp volume into crypttab
		echo "tmp	       /dev/lvm/tmp	       /dev/urandom	tmp,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab

		if "$SWAP" ; then
			
		### if enctypted swap volume exists echo data into fstab and crypttab
			echo "/dev/mapper/swap     none            swap          sw                    0       0" >> "$ARCH"/etc/fstab
			echo "swap	/dev/lvm/swap	/dev/urandom	swap,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab
		fi

	### use sed to insert lvm2 and encrypt into mkinitcpio.conf and reconfigure kernel with encryption options
		sed -i 's/k filesystems k/k lvm2 encrypt filesystems k/' "$ARCH"/etc/mkinitcpio.conf
		arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
		pid=$! pri=1 msg="\n$encrypt_load1" load
	fi

### Configure new system locale with data from LOCALE variable
	sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
	echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
	arch-chroot "$ARCH" locale-gen &> /dev/null &
	pid=$! pri=0.1 msg="\n$locale_load_var" load
	
### If keyboard variable is not set to default echo keymap into vconsole.conf
	if [ "$keyboard" != "$default" ]; then
		echo "KEYMAP=$keyboard" > "$ARCH"/etc/vconsole.conf
	fi

### if sub-subzone variable is set then set timezone to zone subzone sub-subzone
	if [ -n "$SUB_SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE"/"$SUB_SUBZONE" /etc/localtime &
		pid=$! pri=0.1 msg="\n$zone_load_var0" load

### else if subzone variable is set then set timezone to zone subzone
	elif [ -n "$SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" /etc/localtime &
		pid=$! pri=0.1 msg="\n$zone_load_var1" load

### else set timezone to zone
	else
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE" /etc/localtime &
		pid=$! pri=0.1 msg="\n$zone_load_var2" load	
	fi

### If system architecture is x86_64 prompt user to add multilib repos to pacman.conf
	if [ "$arch" == "x86_64" ]; then
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "\n$multilib_msg" 12 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
		fi
	fi

### Prompt user to enable dhcp at boot
	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "\n$dhcp_msg" 12 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.1 msg="\n$dhcp_load" load
	fi

	set_hostname

}

### This function is responsible for setting the new system hostname and also the root passowrd

set_hostname() {

### Prompt user to input the system hostname default is 'arch-anywhere' using sed to remove spaces from output
	hostname=$(whiptail --title "$title" --ok-button "$ok" --nocancel --inputbox "\n$host_msg" 12 55 "arch-anywhere" 3>&1 1>&2 2>&3 | sed 's/ //g')
	
### If hostname input contains special chatracters display error message and return to beginning of function
	if (<<<$hostname grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()+=<>~;:/?.,^{}]\|]" &> /dev/null); then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$host_err_msg" 10 60
		set_hostname
	fi
	
### Echo new hostname into newly installed system
	echo "$hostname" > "$ARCH"/etc/hostname
	
### Begin set root password loop until new password is equal to new password check
	while [ "$input" != "$input_chk" ]
	  do
	 	
	### Ask user to enter new root password
	 	input=$(whiptail --passwordbox --nocancel --ok-button "$ok" "$root_passwd_msg0" 11 55 --title "$title" 3>&1 1>&2 2>&3)
     	input_chk=$(whiptail --passwordbox --nocancel "$root_passwd_msg1" 11 55 --title "$title" 3>&1 1>&2 2>&3)
	 	
	### If user doesn't enter password then display error and return to beginning of loop
	 	if [ -z "$input" ]; then
	 		whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg0" 10 55
	 		input_chk=default
	 	
	### else if password input does not match display error and return to beginning of loop
	 	elif [ "$input" != "$input_chk" ]; then
	 	     whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg1" 10 55
	 	fi
	done

	(printf "$input\n$input" | arch-chroot "$ARCH" passwd) &> /dev/null &
	pid=$! pri=0.1 msg="$wait_load" load
	unset input ; input_chk=default

	hostname_set=true
	add_user

}

### This function is responsible for adding a new user account

add_user() {

### Prompt user to create new user account
	if ! "$menu_enter" ; then
		if ! (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$user_msg0" 10 60) then
			graphics
		fi
	fi

### Prompt user to input a new username
	user=$(whiptail --nocancel --inputbox "\n$user_msg1" 11 55 "" 3>&1 1>&2 2>&3 | sed 's/ //g')
		
### If no username is entered display error and return to beginning of function
### Check output of user variable for anything beginning with 0-9 or containing capital letters or special characters
### display error message if true and return to beginning of function
### check to see if user has already been created
	if [ -z "$user" ]; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg" 10 60
		add_user

	elif (<<<$user grep "^[0-9]\|[ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]" &> /dev/null); then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg" 10 60
		add_user
	
	elif (<<<$user grep "$created_user" &> /dev/null); then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg1" 10 60
		add_user
	fi

### Chroot into system and create new user account
	(arch-chroot "$ARCH" useradd -m -g users -G audio,network,power,storage,optical -s /bin/bash "$user") &>/dev/null &
	pid=$! pri=0.1 msg="$wait_load" load
	source "$lang_file"
	
### Begin user password while loop
	while [ "$input" != "$input_chk" ]
	  do
		 
	### Prompt user to enter a new password for user account
		input=$(whiptail --passwordbox --nocancel "$user_var0" 10 55 --title "$title" 3>&1 1>&2 2>&3)
        input_chk=$(whiptail --passwordbox --nocancel "$user_var1" 10 55 --title "$title" 3>&1 1>&2 2>&3)
		 
	### If no password entered display error and return to beginning of loop
		if [ -z "$input" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg0" 10 55
			input_chk=default
		 
	### else if passwords do not match display error and return to beginning of loop
		elif [ "$input" != "$input_chk" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg1" 10 55
		fi
	done

	(printf "$input\n$input" | arch-chroot "$ARCH" passwd "$user") &> /dev/null &
	pid=$! pri=0.1 msg="$wait_load" load
	unset input ; input_chk=default

### Prompt user to enable sudo for new user account
	if [ -n "$sudo_user" ]; then
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$sudo_var" 10 60) then
			(arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
			pid=$! pri=0.1 msg="$wait_load" load
		fi
	else
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$sudo_var" 10 60) then
			(sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
			arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
			pid=$! pri=0.1 msg="$wait_load" load
			sudo_user="$user"
		fi
	fi

	user_added=true 
	
	if "$menu_enter" ; then
		reboot_system
	else	
		graphics
	fi

}
	
### This function is responsible for installing xorg server a dektop or window manager and graphics drivers

graphics() {

	if ! "$menu_enter" ; then
		if ! (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_msg" 10 60) then
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_cancel_msg" 10 60) then	
				install_software
			fi	
		fi
	fi
	
	DE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$enviornment_msg" 18 60 10 \
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
		if ! "$menu_enter" ; then
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_cancel_msg" 10 60) then	
				install_software
			fi
		else
			reboot_system
		fi
	else
		de_set=true
	fi

	case "$DE" in
		"xfce4") 	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg0" 10 60) then
						DE="xfce4 xfce4-goodies"
					fi
					start_term="exec startxfce4"
		;;
		"gnome")	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg1" 10 60) then
						DE="gnome gnome-extra"
					fi
					 start_term="exec gnome-session"
		;;
		"mate")		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg2" 10 60) then
						DE="mate mate-extra"
					fi
					 start_term="exec mate-session"
		;;
		"KDE plasma")	if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$extra_msg3" 10 60) then
							DE="kde-applications plasma-desktop"
						else
							DE="kde-applications plasma"
						fi 
						 start_term="exec startkde" dm_set=true
		;;
		"cinnamon") 
			start_term="exec cinnamon-session" ;;
		"lxde") 
			start_term="exec startlxde" ;;
		"lxqt") 
			start_term="exec startlxqt" 
			DE="lxqt oxygen-icons" ;;
		"enlightenment") 
			start_term="exec enlightenment_start"
			DE="enlightenment terminology" ;;
		"fluxbox") 
			start_term="exec startfluxbox" ;;
		"openbox") 
			start_term="exec openbox-session" ;;
		"awesome") 
			start_term="exec awesome" ;;	
		"dwm") 
			start_term="exec dwm" ;;
		"i3") 
			start_term="exec i3" ;;
		esac

	if ! $desktop ; then
		until "$gpu_set"
		  do
			GPU=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 17 60 6 \
				"$default"			"$gr0" \
				"mesa-libgl"        "$gr1" \
				"Nvidia"            "$gr2" \
				"Vbox-Guest-Utils"  "$gr3" \
				"xf86-video-ati"    "$gr4" \
				"xf86-video-intel"  "$gr5" 3>&1 1>&2 2>&3)

			if [ "$?" -gt "0" ]; then
				graphics
			
			elif [ "$GPU" == "Nvidia" ]; then
				GPU=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$nvidia_msg" 15 60 4 \
					"nvidia"       "$gr6" \
					"nvidia-340xx" "$gr7" \
					"nvidia-304xx" "$gr8" 3>&1 1>&2 2>&3)

				if [ "$?" -eq "0" ]; then
					gpu_set=true
					GPU="$GPU ${GPU}-libgl"
				fi 
			else
				gpu_set=true
			fi
		done
			
		if [ "$GPU" == "Vbox-Guest-Utils" ]; then
			GPU="virtualbox-guest-utils mesa-libgl"
			echo -e "vboxguest\nvboxsf\nvboxvideo" > "$ARCH"/etc/modules-load.d/virtualbox.conf
		elif [ "$GPU" == "$default" ]; then
			unset GPU
		fi

		if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$touchpad_msg" 10 60) then
			GPU="xf86-input-synaptics $GPU"
		fi
	fi
	
	if ! "$dm_set" ; then
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$lightdm_msg" 10 60) then
			DE="$DE lightdm lightdm-gtk-greeter"
			enable_dm=true
		else
			whiptail --title "$title" --ok-button "$ok" --msgbox "$startx_msg" 10 60
		fi
	fi

	if ! "$menu_enter" ; then
		DE="$DE xorg-server xorg-server-utils xorg-xinit xterm $GPU"
	fi
	
	pacstrap "$ARCH" --print-format='%s' $(echo "$DE") | sed '1,6d' | awk '{s+=$1} END {print s/1024/1024}' &> /tmp/size.var &
	pid=$! pri=0.1 msg="$wait_load" load
	download_size=$(</tmp/size.var)
	export software_size=$(echo "$download_size Mib")
	cal_rate

	if (whiptail --title "$title" --yes-button "$install" --no-button "$cancel" --yesno "$desktop_confirm_var" 18 60) then
		pacstrap "$ARCH" $(echo "$DE") &> /dev/null &
		pid=$! pri="$down" msg="$desktop_load" load
		desktop=true
			
		if "$enable_dm" ; then
			if ! "$dm_set" ; then
				arch-chroot "$ARCH" systemctl enable lightdm.service &> /dev/null &
				pid=$! pri="0.1" msg="\n$dm_load" load
				dm_set=true
			fi
		fi

		if "$user_added" ; then
			echo "$start_term" > "$ARCH"/home/"$user"/.xinitrc
		fi
				
		echo "$start_term" > "$ARCH"/root/.xinitrc
	else
		if ! "$menu_enter" ; then
			if ! (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --default-no --yesno "$desktop_cancel_msg" 10 60) then
				graphics
			fi
		fi
	fi

	if "$menu_enter" ; then
		reboot_system
	fi

	install_software

}

install_software() {

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$software_msg0" 10 60) then
		
		until "$software_selected"
		  do
			unset software
			err=false
			if ! "$skip" ; then
				software_menu=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$software_type_msg" 21 63 11 \
					"$audio" "$audio_msg" \
					"$games" "$games_msg" \
					"$graphic" "$graphic_msg" \
					"$internet" "$internet_msg" \
					"$multimedia" "$multimedia_msg" \
					"$office" "$office_msg" \
					"$terminal" "$terminal_msg" \
					"$text_editor" "$text_editor_msg" \
					"$shell" "$shell_msg" \
					"$system" "$system_msg" \
					"$done_msg" "$install" 3>&1 1>&2 2>&3)
			
				if [ "$?" -gt "0" ]; then
					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$software_warn_msg" 10 60) then
						software_selected=true
						err=true
						unset software_menu
					else
						err=true
					fi
				fi
			else
				skip=false
			fi

			case "$software_menu" in
				"$audio")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 60 10 \
						"audacity"		"$audio0" OFF \
						"audacious"		"$audio1" OFF \
						"cmus"			"$audio2" OFF \
						"jack2"         "$audio3" OFF \
						"projectm"		"$audio4" OFF \
						"lmms"			"$audio5" OFF \
						"mpd"			"$audio6" OFF \
						"ncmpcpp"		"$audio7" OFF \
						"pianobar"		"$audio9" OFF \
						"pulseaudio"	"$audio8" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$internet")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 19 60 9 \
						"chromium"			"$net0" OFF \
						"elinks"			"$net3" OFF \
						"filezilla"			"$net1" OFF \
						"firefox"			"$net2" OFF \
						"lynx"				"$net3" OFF \
						"minitube"			"$net4" OFF \
						"networkmanager"    "$net5" ON \
						"thunderbird"		"$net6" OFF \
						"transmission-cli" 	"$net7" OFF \
						"transmission-gtk"	"$net8" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					elif "$desktop" ; then
						if (<<<$download grep "networkmanager"); then
							download=$(<<<$download sed 's/networkmanager/networkmanager network-manager-applet/')
						fi
					fi
				;;
				"$games")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 70 10 \
						"alienarena"	"$game0" OFF \
						"bsd-games"		"$game1" OFF \
						"bzflag"		"$game2" OFF \
						"flightgear"	"$game3" OFF \
						"gnuchess"      "$game4" OFF \
						"supertux"		"$game5" OFF \
						"supertuxkart"	"$game6" OFF \
						"urbanterror"	"$game7" OFF \
						"warsow"		"$game8" OFF \
						"xonotic"		"$game9" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$graphic")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 16 63 6 \
						"blender"		"$graphic0" OFF \
						"darktable"		"$graphic1" OFF \
						"gimp"			"$graphic2" OFF \
						"graphviz"		"$graphic3" OFF \
						"imagemagick"	"$graphic4" OFF \
						"pinta"			"$graphic5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$multimedia")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 63 7 \
						"handbrake"				"$media0" OFF \
						"mplayer"				"$media1" OFF \
						"pitivi"				"$media2" OFF \
						"simplescreenrecorder"	"$media3" OFF \
						"smplayer"				"$media4" OFF \
						"totem"					"$media5" OFF \
						"vlc"         	   		"$media6" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$office")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 16 63 6 \
						"abiword"               "$office0" OFF \
						"calligra"              "$office1" OFF \
						"calligra-sheets"		"$office2" OFF \
						"gnumeric"				"$office3" OFF \
						"libreoffice-fresh"		"$office4" OFF \
						"libreoffice-still"		"$office5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$terminal")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 18 63 8 \
						"fbterm"			"$term0" OFF \
						"guake"             "$term1" OFF \
						"kmscon"			"$term2" OFF \
						"pantheon-terminal"	"$term3" OFF \
						"rxvt-unicode"      "$term4" OFF \
						"terminator"        "$term5" OFF \
						"xfce4-terminal"    "$term6" OFF \
						"yakuake"           "$term7" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$text_editor")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 60 7 \
						"emacs"			"$edit0" OFF \
						"geany"			"$edit1" OFF \
						"gedit"			"$edit2" OFF \
						"gvim"			"$edit3" OFF \
						"mousepad"		"$edit4" OFF \
						"neovim"		"$edit5" OFF \
						"vim"			"$edit6" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$shell")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 15 50 5 \
						"dash"	"$shell0" OFF \
						"fish"	"$shell1" OFF \
						"mksh"	"$shell2" OFF \
						"tcsh"	"$shell3" OFF \
						"zsh"	"$shell4" ON 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$system")
					software=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 65 10 \
						"arch-wiki"		"$sys0" ON \
						"apache"		"$sys1" OFF \
						"conky"			"$sys2" OFF \
						"git"			"$sys3" OFF \
						"gparted"		"$sys4" OFF \
						"gpm"			"$sys5" OFF \
						"htop"			"$sys6" OFF \
						"inxi"			"$sys7" OFF \
						"k3b"			"$sys8" OFF \
						"nmap"			"$sys9" OFF \
						"openssh"		"$sys10" OFF \
						"screen"		"$sys11" OFF \
						"screenfetch"	"$sys12" ON \
						"scrot"			"$sys13" OFF \
						"tmux"			"$sys14" OFF \
						"tuxcmd"		"$sys15" OFF \
						"virtualbox"	"$sys16" OFF \
						"ufw"			"$sys17" ON \
						"wget"			"$sys18" ON 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi

					wiki=$(<<<$software grep "arch-wiki")

					if [ -n "$wiki" ]; then
						cp /usr/bin/arch-wiki "$ARCH"/usr/bin
						software=$(<<<$software sed 's/arch-wiki/lynx/')
					fi
				;;
				"$done_msg")
				# Check if user selected any additional software
					if [ -z "$final_software" ]; then
					# If no software selected ask to confirm
						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$software_warn_msg" 10 60) then
							software_selected=true
							err=true
						fi
					else
					# List of packages for pacstrap command
						download=$(echo "$final_software" | sed 's/\"//g' | tr ' ' '\n' | nl | sort -u -k2 | sort -n | cut -f2- | sed 's/$/ /g' | tr -d '\n')
						
					# List of packages displayed for user
						export download_list=$(echo "$download" |  sed -e 's/^[ \t]*//')
						
					# Total sum of all packages
						pacstrap "$ARCH" --print-format='%s' $(echo "$download") | sed '1,6d' | awk '{s+=$1} END {print s/1024/1024}' &> /tmp/size.var &
						pid=$! pri=0.1 msg="$wait_load" load
						download_size=$(</tmp/size.var)
						
					# Total sum displayed to user and total number of packages to install
						export software_size=$(echo "$download_size Mib")
						export software_int=$(echo "$download" | wc -w)
						cal_rate

						if [ "$software_int" -lt "20" ]; then
							height=18
						elif [ "$software_int" -lt "40" ]; then
							height=22
						else
							height=25
						fi
						
						if (whiptail --title "$title" --yes-button "$install" --no-button "$cancel" --yesno "$software_confirm_var1" "$height" 65) then
							
						# Check for program requirements	
							if (<<<download grep "virtualbox"); then
								echo -e "vboxdrv\nvboxnetflt\nvboxnetadp\nvboxpci" > "$ARCH"/etc/modules-load.d/virtualbox.conf
							fi

						# Install additional software
						    pacstrap "$ARCH" $(echo "$download") &> /dev/null &
						    pid=$! pri="$down" msg="\n$software_load" load
	  					    software_selected=true
							err=true
						else
							unset final_software
							err=true
						fi
					fi
				;;
			esac
			
			if ! "$err" ; then
			# If software not defined when leaving menu ask to confirm
				if [ -z "$software" ]; then
					if ! (whiptail --title "$title" --yes-button "$ok" --no-button "$no" --defaultno --yesno "$software_noconfirm_msg ${software_menu}?" 10 60) then
						skip=true
					fi
				else
				# Add software from menu list
					add_software=$(echo "$software" | sed 's/\"//g')
					software_list=$(echo "$add_software" | sed -e 's/^[ \t]*//')
					
				# Total sum of all packages
					pacstrap "$ARCH" --print-format='%s' $(echo "$add_software") | sed '1,6d' | awk '{s+=$1} END {print s/1024/1024}' &> /tmp/size.var &
					pid=$! pri=0.1 msg="$wait_load" load
					download_size=$(</tmp/size.var)	
				# Total sum displayed to user and total number of packages to install
					software_size=$(echo "$download_size Mib")
					software_int=$(echo "$add_software" | wc -w)
					source "$lang_file"
				
					if [ "$software_int" -lt "15" ]; then
						height=15
					else
						height=17
					fi

				# Confirm adding software message:
					if (whiptail --title "$title" --yes-button "$add" --no-button "$cancel" --yesno "$software_confirm_var0" "$height" 60) then
						final_software="$software $final_software"
					fi
				fi
			fi
		done
		err=false
	fi

	if [ -f "$ARCH"/usr/bin/NetworkManager ]; then
		arch-chroot "$ARCH" systemctl enable NetworkManager &>/dev/null &
	
	elif [ -f "$ARCH"/usr/bin/netctl ]; then
		arch-chroot "$ARCH" systemctl enable netctl.service &>/dev/null &
	fi
	
	if [ -f "$ARCH"/var/lib/pacman/db.lck ]; then
		rm "$ARCH"/var/lib/pacman/db.lck
	fi

	arch-chroot "$ARCH" pacman -Sy &> /dev/null &
	pid=$! pri=1 msg="\n$pacman_load" load

	software_selected=false
	reboot_system

}

reboot_system() {

	if "$INSTALLED" ; then

		if ! "$bootloader" ; then

			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$complete_no_boot_msg" 10 60) then
				clear ; exit
			fi
		fi

		reboot_menu=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$complete_msg" 16 60 6 \
			"$reboot0" "-" \
			"$reboot2" "-" \
			"$reboot1" "-" \
			"$reboot3" "-" \
			"$reboot4" "-" \
			"$reboot5" "-" 3>&1 1>&2 2>&3)
		
		case "$reboot_menu" in
			"$reboot0")		umount -R "$ARCH"
							clear ; reboot ; exit
			;;
			"$reboot1")		umount -R "$ARCH"
							clear ; exit
			;;
			"$reboot2")		echo -e "$arch_chroot_msg" 
							echo "/root" > /tmp/chroot_dir.var
							arch_anywhere_chroot
			;;
			"$reboot3")		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$user_exists_msg" 10 60); then
								menu_enter=true
								add_user	
							else
								reboot_system
							fi
			;;
			"$reboot4")		if "$desktop" ; then
								if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_exists_msg" 10 60); then
									menu_enter=true
									graphics
								else
									reboot_system
								fi
							else
								if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_exists_msg" 10 60); then
									graphics
								fi
							fi
			;;
			"$reboot5")		install_software
			;;
		esac

	else

		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$not_complete_msg" 10 60) then
			umount -R $ARCH
			clear ; reboot ; exit
		else
			main_menu
		fi
	fi

}

main_menu() {

	menu_item=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$menu" 22 60 10 \
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
						if (whiptail --title "$title" --yes-button "$yes" --no-button --default-no --yesno "$menu_err_msg3" 10 60); then
							prepare_drives
						else
							main_menu
						fi
					fi
 					prepare_drives 
		;;
		"$menu4") 	update_mirrors
		;;
		"$menu5")	install_base
		;;
		"$menu11") 	reboot_system
		;;
		"$menu12") 	if "$INSTALLED" ; then
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
		"$menu13")	echo -e "alias arch-anywhere=exit ; echo -e '$return_msg'" > /tmp/.zshrc
					ZDOTDIR=/tmp/ zsh
					rm /tmp/.zshrc
					clear
					main_menu
		;;
	esac

}

arch_anywhere_chroot() {

	local char=
    local input=
    local -a history=( )
    local -i histindex=0
	trap ctrl_c INT
	working_dir=$(</tmp/chroot_dir.var)
	
	while (true)
	  do
		echo -n "${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}" ; while IFS= read -r -n 1 -s char
		  do
			if [ "$char" == $'\x1b' ]; then
				while IFS= read -r -n 2 -s rest
          		  do
                	char+="$rest"
                	break
            	done
        	fi

			if [ "$char" == $'\x1b[D' ]; then
				pos=-1

			elif [ "$char" == $'\x1b[C' ]; then
				pos=1

			elif [[ $char == $'\177' ]];  then
				input="${input%?}"
				echo -ne "\r\033[K${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}${input}"
			
			elif [ "$char" == $'\x1b[A' ]; then
            # Up
            	if [ $histindex -gt 0 ]; then
                	histindex+=-1
                	input=$(echo -ne "${history[$histindex]}")
					echo -ne "\r\033[K${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}${history[$histindex]}"
				fi  
        	elif [ "$char" == $'\x1b[B' ]; then
            # Down
            	if [ $histindex -lt $((${#history[@]} - 1)) ]; then
                	histindex+=1
                	input=$(echo -ne "${history[$histindex]}")
                	echo -ne "\r\033[K${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}${history[$histindex]}"
				fi  
        	elif [ -z "$char" ]; then
            # Newline
				echo
            	history+=( "$input" )
            	histindex=${#history[@]}
				break
        	else
            	echo -n "$char"
            	input+="$char"
        	fi  
		done
    	
		if [ "$input" == "arch-anywhere" ] || [ "$input" == "exit" ]; then
        	
        	if [ -n "$yaourt_user" ]; then
				sed -i 's!'$yaourt_user' ALL = NOPASSWD: /usr/bin/makepkg, /usr/bin/pacman!!' "$ARCH"/etc/sudoers
				arch-chroot "$ARCH" /bin/bash -c "userdel -r $yaourt_user" &> /dev/null
			fi

			rm /tmp/chroot_dir.var &> /dev/null
			clear
			break

	    elif (<<<"$input" grep "^cd " &> /dev/null); then 
	    	ch_dir=$(<<<$input cut -c4-)
	        arch-chroot "$ARCH" /bin/bash -c "cd $working_dir ; cd $ch_dir ; pwd > /etc/chroot_dir.var"
	        mv "$ARCH"/etc/chroot_dir.var /tmp/
			working_dir=$(</tmp/chroot_dir.var)
	        
		elif  (<<<"$input" grep "^help" &> /dev/null); then
			echo -e "$arch_chroot_msg"
			
		elif (<<<"$input" grep "^yaourt" &> /dev/null); then
			
			if [ ! -f "$ARCH"/usr/bin/yaourt ]; then
				echo
				echo -n " ${Yellow}Would you like to install yaourt on your system? [y/N]: ${ColorOff}"
				read input
				echo

				case "$input" in
					y|Y|yes|Yes|yY|Yy|yy|YY)
						if [ -z "$yaourt_user" ]; then
							arch-chroot "$ARCH" /bin/bash -c "useradd -m compile-user"
							yaourt_user="compile-user"
							echo "$yaourt_user ALL = NOPASSWD: /usr/bin/makepkg, /usr/bin/pacman" >> "$ARCH"/etc/sudoers
						fi
						
						cd "$ARCH"/home/"$yaourt_user"
						wget https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
						wget https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz
						tar zxvf package-query.tar.gz
						tar zxvf yaourt.tar.gz
						arch-chroot "$ARCH" /bin/bash -c "chown --recursive $yaourt_user /home/$yaourt_user ; pacman -Sy --noconfirm --needed base-devel ; cd /home/$yaourt_user/package-query ; su -c 'makepkg -si' -m $yaourt_user"
						arch-chroot "$ARCH" /bin/bash -c "cd /home/$yaourt_user/yaourt ; su -c 'makepkg -si' -m $yaourt_user"

						if [ "$?" -eq "0" ]; then
							echo -e "\n ${Green}Yaourt installed successfully!\n You may now install AUR packages with: yaourt <package> ${ColorOff}\n"
						else
							echo -e "\n ${Red}Error: yaourt failed to install...${ColorOff}\n"
						fi
						
						rm -r "$ARCH"/home/"$yaourt_user"/{yaourt,yaourt.tar.gz,package-query,package-query.tar.gz}
						cd ~/
					;;
				esac
			else
				input=$(<<<"$input" cut -d' ' -f2-)
				arch-chroot "$ARCH" /bin/bash -c "su -c 'yaourt $input' -m $yaourt_user"
			fi

		else
	    	arch-chroot "$ARCH" /bin/bash -c "cd $working_dir ; $input"
	    fi   
	input=
	done

	reboot_system

}

ctrl_c() {

	echo
	echo "${Red} Exiting and cleaning up..."
	sleep 0.5
	
	if [ -n "$yaourt_user" ]; then
		sed -i 's!'$yaourt_user' ALL = NOPASSWD: /usr/bin/makepkg, /usr/bin/pacman!!' "$ARCH"/etc/sudoers
		arch-chroot "$ARCH" /bin/bash -c "userdel -r $yaourt_user" &> /dev/null
	fi
	
	unset input
	rm /tmp/chroot_dir.var &> /dev/null
	clear
	reboot_system

}

cal_rate() {
			
	case "$connection_rate" in
		KB/s) 
			down_sec=$(echo "$download_size*1024/$connection_speed" | bc)
		;;
		MB/s)
			down_sec=$(echo "$download_size/$connection_speed" | bc)
		;;
		*) 
			down_sec="1" 
		;;
	esac
        
	down=$(echo "$down_sec/100+$cpu_sleep" | bc)
	down_min=$(echo "$down*100/60" | bc)
	
	if ! (<<<$down grep "^[1-9]" &> /dev/null); then
		down=3
		down_min=5
	fi
	
	export down down_min
	source "$lang_file"

}

load() {

	{	int="1"
        	while (true)
    	    	do
    	            proc=$(ps | grep "$pid")
    	            if [ "$?" -gt "0" ]; then break; fi
    	            sleep $pri
    	            echo $int
    	            int=$((int+1))
    	        done
            echo 100
            sleep 1
	} | whiptail --title "$title" --gauge "$msg" 8 76 0

}

init
