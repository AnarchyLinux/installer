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

### Ping google to check status of internet connection
	ping -w 1 google.com &> /dev/null
	
	if [ "$?" -gt "0" ]; then
		err=true
	fi

### Begin connection test and error check
	until "$connection"
	  do
	
	### If ping exited with error
		if "$err" ; then
    	
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
						err=false
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
	
	### Else ping did not exit with error
		else
		
		### Test connection speed with 10mb file output into /dev/null
			wget --append-output=/tmp/wget.log -O /dev/null "http://speedtest.wdc01.softlayer.com/downloads/test10.zip" &
			pid=$! pri=1 msg="\n$connection_load" load

		### For testing purpose only - leave this line commented 
#			wget --append-output=/tmp/wget.log -O /dev/null "ftp://192.168.1.68/dh-repo/x86_64/lib32-gcc-libs-5.3.0-3-x86_64.pkg.tar.xz" &
#			pid=$! pri=1 msg="\n$connection_load" load

		### Define network connection speed variables from data in wget.log
			export connection_speed=$(tail -n 2 /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $1}')
			export connection_rate=$(tail -n 2 /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $2}')
        
    	### Define cpu frequency variables
        	cpu_mhz=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | sed 's/\..*//')
        
			if [ "$?" -gt "0" ]; then
				cpu_mhz=$(lscpu | grep "CPU MHz" | awk '{print $3}' | sed 's/\..*//')
			fi
        
       ### Define cpu sleep variable based on total cpu frequency
			case "$cpu_mhz" in
				[0-9][0-9][0-9]) export cpu_sleep=5 ;;
				[1][0-9][0-9][0-9]) export cpu_sleep=4 ;;
				[2][0-9][0-9][0-9]) export cpu_sleep=3 ;;
				[3-5][0-9][0-9][0-9]) export cpu_sleep=2 ;;
			esac
        	
			connection=true
		fi
	done

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
		LOCALE=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$locale_msg" 15 60 6  $localelist 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then 
			set_locale
		fi
	fi

	locale_set=true
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

	zone_set=true
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

	keys_set=true 
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
	
	### Prompt user to select drive for auto partitioning
		cat <<-EOF > /tmp/part.sh
			#!/bin/bash
			# simple script used to generate block device menu
			auto_part=\$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$drive_msg" 15 60 4 \\
			$(lsblk | grep "disk" | awk '{print "\""$1"\"""    ""\"""Type: "$6"    ""'$size': "$4"\""" \\"}' |
			sed "s/\.[0-9]*//;s/ [0-9][G,M]/&   /;s/ [0-9][0-9][G,M]/&  /;s/ [0-9][0-9][0-9][G,M]/& /")
			3>&1 1>&2 2>&3) ; echo "\$auto_part" > /tmp/part.var
		EOF
	
		bash /tmp/part.sh
		
		DRIVE=$(</tmp/part.var)
	
		if [ "$?" -gt "0" ]; then
			prepare_drives
		fi
		
	### Read total gigabytes of selected drive and source language file variables
		drive_gigs=$(lsblk | grep -w "$DRIVE" | awk '{print $4}' | grep -o '[0-9]*' | awk 'NR==1') 
		source "$lang_file"

	### Prompt user to format selected drive
		if (whiptail --title "$title" --defaultno --yes-button "$write" --no-button "$cancel" --yesno "$drive_var" 12 60) then
			sgdisk --zap-all /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.1 msg="$wait_load" load
	
	### Else reset back to beginning of prepare drives function
		else
			prepare_drives
		fi

	### Prompt user to select new filesystem type
		FS=$(whiptail --title "$title" --nocancel --menu "$fs_msg" 16 65 6 \
			"ext4"      "$fs0" \
			"ext3"      "$fs1" \
			"ext2"      "$fs2" \
			"btrfs"     "$fs3" \
			"jfs"       "$fs4" \
			"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
		source "$lang_file"

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
					if [ $(grep -o ".$" <<< "$SWAPSPACE") == "M" ]; then 
						
					### If swapsize exceeded the total volume of the drive in MiB taking into account 4 GiB for install space
						if [ $(grep -o '[0-9]*' <<< "$SWAPSPACE") -lt $(echo "$drive_gigs*1000-4096" | bc) ]; then 
							SWAP=true 
							swapped=true
						
					### Else selected swap size exceedes total volume of drive print error message
						else 
							whiptail --title "$title" --ok-button "$ok" --msgbox "$swap_err_msg0" 10 60
						fi

				### Else if selected unit is set to 'G' GiB
					elif [ $(grep -o ".$" <<< "$SWAPSPACE") == "G" ]; then 

				### If swapsize exceeded the total volume of the drive in GiB taking into account 4 GiB for install space
						if [ $(grep -o '[0-9]*' <<< "$SWAPSPACE") -lt $(echo "$drive_gigs-4" | bc) ]; then 
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
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					
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
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					
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
					wipefs -a /dev/"$SWAP" &> /dev/null
					mkswap /dev/"$SWAP" &> /dev/null
					swapon /dev/"$SWAP" &> /dev/null
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

		### Wipe the filesystems on the new boot and root partitions
			wipefs -a /dev/"$BOOT" &> /dev/null
			wipefs -a /dev/"$ROOT" &> /dev/null

		### If uefi boot is set to true create new boot filesystem type of 'vfat'
			if "$UEFI" ; then
				mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.1 msg="\n$efi_load" load
			
		### Else create new boot filesystem using selected filesystem type
			else
				mkfs -F -t "$FS" /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.1 msg="\n$boot_load" load
			fi

		### Create root filesystem using desired filesystem type
			mkfs -F -t "$FS" /dev/"$ROOT" &> /dev/null &
			pid=$! pri=1 msg="\n$load_var1" load

		### Mount root partition at arch mountpoint
			mount /dev/"$ROOT" "$ARCH"

			if [ "$?" -eq "0" ]; then
				mounted=true
			fi

		### Create boot directory and mount boot partition
			mkdir $ARCH/boot
			mount /dev/"$BOOT" "$ARCH"/boot
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
			wipefs -a /dev/"$ROOT" &> /dev/null
			
		### Create new physical volume and volume group on root partition using LVM
			lvm pvcreate /dev/"$ROOT" &> /dev/null
			lvm vgcreate lvm /dev/"$ROOT" &> /dev/null

		### If swap is set to true create new swap logical volume set to size of swapspace
			if "$SWAP" ; then
				lvm lvcreate -L $SWAPSPACE -n swap lvm &> /dev/null
			fi

		### Create new locical volume for tmp and root filesystems 'tmp' and 'lvroot'
			lvm lvcreate -L 500M -n tmp lvm &> /dev/null
			lvm lvcreate -l 100%FREE -n lvroot lvm &> /dev/null

		### Encrypt root logical volume using cryptsetup lukas format
			printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot - &
			pid=$! pri=0.2 msg="\n$encrypt_load" load

		### Open new encrypted volume
			printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -
			unset input

		### Create and mount root filesystem on new encrypted volume
			mkfs -F -t "$FS" /dev/mapper/root &> /dev/null &
			pid=$! pri=1 msg="\n$load_var1" load
			mount /dev/mapper/root "$ARCH"

			if [ "$?" -eq "0" ]; then
				mounted=true
				crypted=true
			fi

		### Wipe boot partition filesystem
			wipefs -a /dev/"$BOOT" &> /dev/null

		### If efi is true create new boot filesystem using 'vfat'
			if "$UEFI" ; then
				mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="\n$efi_load" load
			
		### Else create new boot filesystem using selected filesystem type
			else
				mkfs -F -t "$FS" /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="\n$boot_load" load
			fi

		### Create new boot mountpoint and mount boot partition
			mkdir $ARCH/boot
			mount /dev/"$BOOT" "$ARCH"/boot
		;;

	### Manual partitioning selected
		"$method2")
		
		### Set mountpoints variable and move into manual partition function
			points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
			manual_partition
			clear
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

manual_partition() {

### Reset variables
	unset manual_part
	rm -r /tmp/{part.var,part.sh} &> /dev/null
	part_count=$(lsblk | grep "disk\|part" | wc -l)
	
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
	
	cat <<-EOF > /tmp/part.sh
		#!/bin/bash
		# simple script used to generate block device menu
		manual_part=\$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$manual_part_msg" 15 70 4 \\
		$(lsblk | grep -v "K" | grep "disk\|part" | sed 's/\/mnt/\//;s/\/\//\//' | awk '{print "\""$1"\"""    ""\"""Type: "$6"    ""'$size': "$4"    '$mountpoint': "$7"\""" \\"}' |
		sed "s/\.[0-9]*//;s/ [0-9][G,M]/&   /;s/ [0-9][0-9][G,M]/&  /;s/ [0-9][0-9][0-9][G,M]/& /;s/\(^\"sd.*Size:......\).*/\1\" \\\/")
		"$done_msg" "$write>" 3>&1 1>&2 2>&3) ; echo "\$manual_part" > /tmp/part.var
	EOF

### Run the script which does all of whatever the above stuff is and end up with a beautiful menu... somehow...
	bash /tmp/part.sh

### All the above lines just to set one variable from the output in one file
	manual_part=$(</tmp/part.var)
	
	if [ -z "$manual_part" ]; then
		prepare_drives
	
	elif (<<<$manual_part grep "[0-9]"); then
		part=$(<<<$manual_part sed 's/├─//;s/└─//')
		part_size=$(lsblk | grep "$part" | awk '{print $4}')
		part_mount=$(lsblk | grep "$part" | awk '{print $7}' | sed 's/\/mnt/\//;s/\/\//\//')
		source "$lang_file"
	
		if ! (lsblk | grep "part" | grep "/"); then
	
			case "$part_size" in
				[4-9]G|[0-9][0-9]*G|[4-9].*G|T)
					# Ask to create root if no partitions and size is in range
					if (whiptail --title "$title" --yes-button "$yes" --no-button "$cancel" --defaultno --yesno "$root_var" 13 60) then
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

						source "$lang_file"

						if (whiptail --title "$title" --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$root_confirm_var" 14 50) then
						
						### Wipe root filesystem
							wipefs -a -q /dev/"$part" &> /dev/null &
							pid=$! pri=0.1 msg="$wait_load" load

						### Create new filesystem on root partition
							mkfs -F -t "$FS" /dev/"$part" &> /dev/null &
							pid=$! pri=1 msg="\n$load_var1" load

						### Mount new root partition at arch mountpoint
							mount /dev/"$part" "$ARCH" &> /dev/null &

							if [ "$?" -eq "0" ]; then
								mounted=true
								ROOT="$part"
								DRIVE=$(<<<$part sed 's/[0-9]//')
								manual_partition
							else

							### Partition failed to mount display error and return to prepare drives function
								whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg1" 10 60
								prepare_drives
							fi
						fi
					fi
				;;
				*)
					### Partition too small to be root partition display error
					whiptail --title "$title" --ok-button "$ok" --msgbox "$root_err_msg" 10 60
				;;
			esac

		elif [ -n "$part_mount" ]; then
			if (whiptail --title "$title" --yes-button "$edit" --no-button "$back" --defaultno --yesno "$manual_part_var0" 13 60) then
			
				if [ "$part" == "$ROOT" ]; then
					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$manual_part_var2" 11 60) then
						mounted=false
						unset ROOT DRIVE
						umount -R "$ARCH" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load" load
					fi
				else
			
					if [ "$part_mount" == "[SWAP]" ]; then
						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$manual_swap_var" 10 60) then
							swapoff /dev/"$part" &> /dev/null
						fi
					else
						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --defaultno --yesno "$manual_part_var1" 10 60) then
							umount  "$ARCH"/"$part_mount" &> /dev/null &
							pid=$! pri=0.1 msg="$wait_load" load
							rm -r "$ARCH"/"$part_mount"
							points=$(echo -e "$part_mount   mountpoint>\n$points")
						fi
					fi
				fi
			fi

		else
			# Create a new mountpoint on part?
			if (whiptail --title "$title" --yes-button "$edit" --no-button "$cancel" --yesno "$manual_new_part_var" 12 60) then
				mnt=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$mnt_var0" 15 60 6 $points 3>&1 1>&2 2>&3)
				
				if [ "$?" -gt "0" ]; then
					manual_partition
				fi

				if [ "$mnt" == "$custom" ]; then
					err=true

					until ! "$err"
					  do
						mnt=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --inputbox "$custom_msg" 10 50 "/" 3>&1 1>&2 2>&3)
					
						if [ "$?" -gt "0" ]; then
							err=false
							manual_partition
						elif (<<<$mnt grep "[\[\$\!\'\"\`\\|%&#@()+=<>~;:?.,^{}]\|]"); then
							whiptail --title "$title" --ok-button "$ok" --msgbox "$custom_err_msg0" 10 60
						elif (<<<$mnt grep "^[/]$"); then
							whiptail --title "$title" --ok-button "$ok" --msgbox "$custom_err_msg1" 10 60
						else
							err=false
						fi
					done
				fi

				if [ "$mnt" == "SWAP" ]; then
					wipefs -a -q /dev/"$part"
					mkswap /dev/"$part" &> /dev/null
					pid=$! pri=0.1 msg="$wait_load" load
					swapon /dev/"$part" &> /dev/null
				else
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
					
					points=$(echo  "$points" | grep -v "$mnt")
					source "$lang_file"

					if (whiptail --title "$title" --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$part_confirm_var" 14 50) then
						wipefs -a -q /dev/"$part" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load" load
					
						mkfs -F -t "$FS" /dev/"$part" &> /dev/null &
						pid=$! pri=1 msg="\n$load_var1" load
					
						mkdir -p "$ARCH"/"$mnt"
						mount /dev/"$part" "$ARCH"/"$mnt" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load" load
					
						if [ "$?" -gt "0" ]; then
							whiptail --title "$title" --ok-button "$ok" --msgbox "$part_err_msg1" 10 60
						fi
					fi
				fi
			fi
			
		fi

		manual_partition

	elif [ "$manual_part" == "$done_msg" ]; then
	
		if ! "$mounted" ; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$root_err_msg1" 10 60
			manual_partition
		else
			final_part=$(lsblk | grep "/\|[SWAP]" | grep "part" | awk '{print $1"      "$4"       "$7}' | sed 's/\/mnt/\//;s/\/\//\//;1i'$partition': '$size':       '$mountpoint': ' | sed "s/\.[0-9]*//;s/ [0-9][G,M]/&   /;s/ [0-9][0-9][G,M]/&  /;s/ [0-9][0-9][0-9][G,M]/& /")
			final_count=$(lsblk | grep "/\|[SWAP]" | grep "part"  | wc -l)

			if [ "$final_count" -lt "7" ]; then
				height=17
			elif [ "$final_count" -lt "13" ]; then
				height=23
			elif [ "$final_count" -lt "17" ]; then
				height=26
			else
				height=30
			fi

			if ! (whiptail --title "$title" --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$write_confirm_msg \n\n $final_part \n\n $write_confirm" "$height" 50) then
				manual_partition
			fi
		fi
	else
		part_size=$(lsblk | grep "$manual_part" | awk 'NR==1 {print $4}')
		source "$lang_file"

		if (lsblk | grep "$manual_part" | grep "$ARCH"); then	
			if (whiptail --title "$title" --yes-button "$edit" --no-button "$cancel" --defaultno --yesno "$mount_warn_var" 10 60) then
				points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
				umount -R "$ARCH" &> /dev/null &
				pid=$! pri=0.1 msg="$wait_load" load
				swapoff -a &> /dev/null
				mounted=false
				unset DRIVE
				cfdisk /dev/"$manual_part"
			fi
		elif (whiptail --title "$title" --yes-button "$edit" --no-button "$cancel" --yesno "$manual_part_var3" 12 60) then
			cfdisk /dev/"$manual_part"
		fi

		manual_partition
	fi

}

update_mirrors() {

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$mirror_msg0" 10 60) then
		code=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$mirror_msg1" 18 60 10 $countries 3>&1 1>&2 2>&3)
		wget --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak &
		pid=$! pri=0.2 msg="\n$mirror_load0" load
		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist &
 		pid=$! pri=0.8 msg="\n$mirror_load1" load
 		mirrors_updated=true
	fi

	install_base

}

install_base() {

	if ! "$INSTALLED" && "$mounted" ; then	

		install_menu=$(whiptail --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$install_type_msg" 14 64 4 \
			"Arch-Linux-Base" 			"$base_msg0" \
			"Arch-Linux-Base-Devel" 	"$base_msg1" \
			"Arch-Linux-LTS-Base" 		"$LTS_msg0" \
			"Arch-Linux-LTS-Base-Devel" "$LTS_msg1" 3>&1 1>&2 2>&3)
		
		if [ "$?" -gt "0" ]; then
			if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$exit_msg" 10 60) then
				main_menu
			else
				install_base
			fi

		elif ! "$wifi" ; then
			if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$wifi_option_msg" 11 60) then
				wifi=true
			fi
		fi

		case "$install_menu" in
			"Arch-Linux-Base")
				base_install="base libnewt sudo"
			;;
			"Arch-Linux-Base-Devel") 
				base_install="base base-devel libnewt"
			;;
			"Arch-Linux-LTS-Base")
				base_install="base linux-lts libnewt sudo"
			;;
			"Arch-Linux-LTS-Base-Devel")
				base_install="base base-devel linux-lts libnewt"
			;;
		esac

		if "$wifi" ; then
			base_install="$base_install wireless_tools wpa_supplicant wpa_actiond netctl dialog"
		fi

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

		if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$os_prober_msg" 10 60) then
			base_install="$base_install os-prober"
		fi

		pacstrap "$ARCH" --print-format='%s' $(echo "$base_install") | sed '1,6d' | awk '{s+=$1} END {print s/1024/1024}' &> /tmp/size.var &
		pid=$! pri=1 msg="\n$pacman_load" load
		download_size=$(</tmp/size.var)
		export add_int=$(echo "$download_size" | sed 's/\..*$//')
		export software_size=$(echo "$download_size Mib")
		cal_rate

		if (whiptail --title "$title" --yes-button "$install" --no-button "$cancel" --yesno "\n$install_var" 16 60) then
			pacstrap "$ARCH" $(echo "$base_install") &> /dev/null &
			pid=$! pri="$down" msg="$install_load" load
			genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab
			INSTALLED=true

			if "$bootloader" ; then
						
				if "$crypted" ; then
					sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
				else
					sed -i 's/quiet//' "$ARCH"/etc/default/grub
				fi

				if "$UEFI" ; then
					pacstrap "$ARCH" efibootmgr &> /dev/null &
					pid="\n$efi_load" load
					arch-chroot "$ARCH" grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot &> /dev/null &
					pid=$! pri=0.5 msg="\n$grub_load1" load
					mv "$ARCH"/boot/EFI/boot/grubx64.efi "$ARCH"/boot/EFI/boot/bootx64.efi
							
					if ! "$crypted" ; then
						arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
						pid=$! pri=1 msg="\n$uefi_config_load" load
					fi
				else
					arch-chroot "$ARCH" grub-install /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.5 msg="\n$grub_load1" load
				fi

				arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
				pid=$! pri=0.1 msg="\n$grub_load2" load
			fi

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
		pid=$! pri=1 msg="\n$encrypt_load1" load
	fi

	sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
	echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
	arch-chroot "$ARCH" locale-gen &> /dev/null &
	pid=$! pri=0.1 msg="\n$locale_load_var" load
	
	if [ "$keyboard" != "$default" ]; then
		echo "KEYMAP=$keyboard" > "$ARCH"/etc/vconsole.conf
	fi

	if [ -n "$SUB_SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE"/"$SUB_SUBZONE" /etc/localtime &
		pid=$! pri=0.1 msg="\n$zone_load_var0" load

	elif [ -n "$SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" /etc/localtime &
		pid=$! pri=0.1 msg="\n$zone_load_var1" load

	elif [ -n "$ZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE" /etc/localtime &
		pid=$! pri=0.1 msg="\n$zone_load_var2" load	
	fi

	if [ "$arch" == "x86_64" ]; then
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "\n$multilib_msg" 12 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
		fi
	fi

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "\n$dhcp_msg" 12 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.1 msg="\n$dhcp_load" load
	fi

	system_configured=true
	set_hostname

}

set_hostname() {

	hostname=$(whiptail --title "$title" --ok-button "$ok" --nocancel --inputbox "\n$host_msg" 12 55 "arch-anywhere" 3>&1 1>&2 2>&3)
	hostname=$(<<<$hostname sed 's/ //g')
	
	if (<<<$hostname grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()+=<>~;:/?.,^{}]\|]"); then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$host_err_msg" 10 60
		set_hostname
	fi
	
	echo "$hostname" > "$ARCH"/etc/hostname
	
	while [ "$input" != "$input_chk" ]
	  do
	 	input=$(whiptail --passwordbox --nocancel --ok-button "$ok" "$root_passwd_msg0" 11 55 --title "$title" 3>&1 1>&2 2>&3)
     	input_chk=$(whiptail --passwordbox --nocancel "$root_passwd_msg1" 11 55 --title "$title" 3>&1 1>&2 2>&3)
	 	if [ -z "$input" ]; then
	 		whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg0" 10 55
	 		input_chk=default
	 	elif [ "$input" != "$input_chk" ]; then
	 	     whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg1" 10 55
	 	fi
	done

	printf "$input\n$input" | arch-chroot "$ARCH" passwd &> /dev/null
	unset input ; input_chk=default

	hostname_set=true
	add_user

}

add_user() {

	if "$user_added" ; then
		whiptail --title "$title" --ok-button "$ok" --msgbox "$user_exists_msg" 10 60
		main_menu
	fi

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$user_msg0" 10 60) then
		user=$(whiptail --nocancel --inputbox "\n$user_msg1" 11 55 "" 3>&1 1>&2 2>&3)
		
		if [ -z "$user" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg" 10 60
			add_user
		fi

		user=$(<<<$user sed 's/ //g')
		user_check=$(<<<$user grep "^[0-9]\|[ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]")	
		if [ -n "$user_check" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$user_err_msg" 10 60
			add_user
		fi

	else
		graphics
	fi

	source "$lang_file"
	arch-chroot "$ARCH" useradd -m -g users -G wheel,audio,network,power,storage,optical -s /bin/bash "$user"
	pid=$! pri=0.1 msg="$wait_load" load
	
	while [ "$input" != "$input_chk" ]
	  do
		 input=$(whiptail --passwordbox --nocancel "$user_var0" 10 55 --title "$title" 3>&1 1>&2 2>&3)
         input_chk=$(whiptail --passwordbox --nocancel "$user_var1" 10 55 --title "$title" 3>&1 1>&2 2>&3)
		 
		 if [ -z "$input" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg0" 11 55
			input_chk=default
		 elif [ "$input" != "$input_chk" ]; then
			whiptail --title "$title" --ok-button "$ok" --msgbox "$passwd_msg1" 11 55
		fi
	done

	printf "$input\n$input" | arch-chroot "$ARCH" passwd "$user" &> /dev/null
	unset input ; input_chk=default

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$sudo_var" 10 60) then
		sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
	fi

	export "$user"
	export user_added=true 
	graphics

}
	
graphics() {

	if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_msg" 10 60) then
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
				if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_cancel_msg" 10 60) then	
					install_software
				fi
			else
				de_set=true
			fi

			case "$DE" in
				"xfce4") start_term="exec startxfce4" 

						if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg0" 10 60) then
							DE="xfce4 xfce4-goodies"
						fi
				;;
				"gnome") start_term="exec gnome-session"

					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg1" 10 60) then
						DE="gnome gnome-extra"
					fi 
				;;
				"mate") start_term="exec mate-session"

					if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$extra_msg2" 10 60) then
						DE="mate mate-extra"
					fi
				;;
				"KDE plasma") start_term="exec startkde" dm_set=true

					if (whiptail --title "$title" --defaultno --yes-button "$yes" --no-button "$no" --yesno "$extra_msg3" 10 60) then
						DE="kde-applications plasma-desktop"
					else
						DE="kde-applications plasma"
					fi 
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

	else
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$desktop_cancel_msg" 10 60) then
			install_software
		else
			graphics
		fi
	fi


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

	if ! "$dm_set" ; then
		if (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --yesno "$lightdm_msg" 10 60) then
			DE="$DE lightdm lightdm-gtk-greeter"
			enable_dm=true
		else
			whiptail --title "$title" --ok-button "$ok" --msgbox "$startx_msg" 10 60
		fi
	fi
				
	DE="$DE xorg-server xorg-server-utils xorg-xinit xterm $GPU"
	pacstrap "$ARCH" --print-format='%s' $(echo "$DE") | sed '1,6d' | awk '{s+=$1} END {print s/1024/1024}' &> /tmp/size.var &
	pid=$! pri=0.1 msg="$wait_load" load
	download_size=$(</tmp/size.var)
	export add_int=$(echo "$download_size" | sed 's/\..*$//')
	export software_size=$(echo "$download_size Mib")
	cal_rate

	if (whiptail --title "$title" --yes-button "$install" --no-button "$cancel" --yesno "$desktop_confirm_var" 18 60) then
		pacstrap "$ARCH" $(echo "$DE") &> /dev/null &
		pid=$! pri="$down" msg="$desktop_load" load
		desktop=true
			
		if "$enable_dm" ; then
			arch-chroot "$ARCH" systemctl enable lightdm.service &> /dev/null &
			pid=$! pri="0.1" msg="$wait_load" load
		fi

		if "$user_added" ; then
			echo "$start_term" > "$ARCH"/home/"$user"/.xinitrc
		fi
				
		echo "$start_term" > "$ARCH"/root/.xinitrc
	else
		if ! (whiptail --title "$title" --yes-button "$yes" --no-button "$no" --default-no --yesno "$desktop_cancel_msg" 10 60) then
			graphics
		fi
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
						"urbanterror"	"$game7" OFF\
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
						export add_int=$(echo "$download_size" | sed 's/\..*$//')
						
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

cal_rate() {
			
	case "$connection_rate" in
		KB/s) down_sec=$((add_int*1024/connection_speed)) ;;
		MB/s) down_sec=$(echo "$add_int/$connection_speed" | bc) ;;
		GB/s) down_sec="1" down_min="1" ;;
	esac
        
	export down=$((down_sec/100+cpu_sleep+1))
	export down_min=$((down*100/60+1))
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
	} | whiptail --title "$title" --gauge "$msg $int" 8 72 0

}

main_menu() {

	menu_item=$(whiptail --nocancel --title "$title" --ok-button "$ok" --menu "$menu" 18 60 10 \
		"$menu0" "-" \
		"$menu1" "-" \
		"$menu2" "-" \
		"$menu3" "-" \
		"$menu4" "-" \
		"$menu5" "-" \
		"$menu6" "-" \
		"$menu7" "-" \
		"$menu8" "-" \
		"$menu9" "-" \
		"$menu10" "-" \
		"$menu11" "-" \
		"$menu12" "-" 3>&1 1>&2 2>&3)

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

init
