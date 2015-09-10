#!/bin/bash

ARCH=/mnt
mounted=false
INSTALLED=false
bootloader=false
system_configured=false
hostname_set=false
user_added=false
network_configured=false
arch=$(uname -a | grep -o "x86_64\|i386\|i686")

check_connection() {
	clear
	if ! (whiptail --title "Arch Linux Anywhere" --yesno "Welcome to the Arch Linux Anywhere installer! \n\n *Would you like to begin the install process?" 10 60) then
		exit
	fi
	ping -w 2 google.com &> /dev/null
	if [ "$?" -gt "0" ]; then
		whiptail --title "Arch Linux Anywhere" --msgbox "Error. No connection found, exiting." 10 60
		clear
		exit 1
	else		
		start=$(date +%s)
		wget -O /dev/null http://cachefly.cachefly.net/10mb.test &> /dev/null &
		pid=$! pri=1 msg="Please wait while we test your connection..." load
		end=$(date +%s)
		diff=$((end-start))
		case "$diff" in
			[1-4]) export down="1" ;;
			[5-9]) export down="2" ;;
			1[0-9]) export down="3" ;;
			2[0-9]) export down="4" ;;
			3[0-9]) export down="5" ;;
			4[0-9]) export down="6" ;;
			5[0-9]) export down="7" ;;
			6[0-9]) export down="8" ;;
			[0-9][0-9][0-9]) 
				if (whiptail --title "Arch Linux Anywhere" --yesno "Your connection is very slow, this might take a long time...\n\n *Continue with install?" 10 60) then
					export down="15"
				else
					exit
				fi
			;;
			*) export down="10" ;;
		esac
	fi
	set_locale
}

set_locale() {
	LOCALE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Please select your desired locale:" 15 60 6 \
	"en_US.UTF-8" "-" \
	"en_AU.UTF-8" "-" \
	"en_CA.UTF-8" "-" \
	"en_GB.UTF-8" "-" \
	"en_MX.UTF-8" "-" \
	"Other"       "-"		 3>&1 1>&2 2>&3)
	if [ "$LOCALE" = "Other" ]; then
		localelist=$(</etc/locale.gen  awk '{print substr ($1,2) " " ($2);}' | grep -F ".UTF-8" | sed "1d" | sed 's/$/  -/g;s/ UTF-8//g')
		LOCALE=$(whiptail --title "Arch Linux Anywhere" --menu "Please select your desired locale:" 15 60 6  $localelist 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then set_locale ; fi
	fi
	locale_set=true set_zone
}

set_zone() {
	zonelist=$(find /usr/share/zoneinfo -maxdepth 1 | sed -n -e 's!^.*/!!p' | grep -v "posix\|right\|zoneinfo\|zone.tab\|zone1970.tab\|W-SU\|WET\|posixrules\|MST7MDT\|iso3166.tab\|CST6CDT" | sort | sed 's/$/ -/g')
	ZONE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Please enter your Time Zone:" 15 60 6 $zonelist 3>&1 1>&2 2>&3)
		check_dir=$(find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE")
		if [ -n "$check_dir" ]; then
			sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
			SUBZONE=$(whiptail --title "Arch Linux Anywhere" --menu "Please enter your sub-zone:" 15 60 6 $sublist 3>&1 1>&2 2>&3)
			if [ "$?" -gt "0" ]; then set_zone ; fi
			chk_dir=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE")
			if [ -n "$chk_dir" ]; then
				sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
				SUB_SUBZONE=$(whiptail --title "Arch Linux Anywhere" --menu "Please enter your sub-zone:" 15 60 6 $sublist 3>&1 1>&2 2>&3)
				if [ "$?" -gt "0" ]; then set_zone ; fi
			fi
		fi
	zone_set=true set_keys
}

set_keys() {
	keyboard=$(whiptail --nocancel --inputbox "Set key-map: \n\n *If unsure leave default" 10 35 "us" 3>&1 1>&2 2>&3)
	keys_set=true prepare_drives
}

prepare_drives() {
	drive=$(lsblk | grep "disk" | grep -v "rom" | awk '{print $1   " "   $4}')
	DRIVE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Select the drive you would like to install arch onto:" 15 60 5 $drive 3>&1 1>&2 2>&3)
	PART=$(whiptail --title "Arch Linux Anywhere" --menu "Select your desired method of partitioning: \n\n *NOTE Auto Partitioning will format the selected drive" 15 60 5 \
	"Auto Partition Drive"           "-" \
	"Auto partition encrypted LVM"   "-" \
	"Manual Partition Drive"         "-" \
	"Return To Menu"                 "-" 3>&1 1>&2 2>&3)
	if [ "$?" -gt "0" ]; then
		prepare_drives
	elif [ "$PART" == "Return To Menu" ]; then
		main_menu
	elif [ "$PART" == "Auto partition encrypted LVM" ] || [ "$PART" == "Auto Partition Drive" ]; then
		crypted=false
		if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "WARNING! Will erase all data on drive /dev/$DRIVE! \n\n *Would you like to contunue?" 10 60) then
			sgdisk --zap-all "$DRIVE" &> /dev/null
		else
			prepare_drives
		fi
		FS=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Select your desired filesystem type: \n *Default is ext4" 15 60 6 \
		"ext4"      "4th extended file system" \
		"ext3"      "3rd extended file system" \
		"ext2"      "2nd extended file system" \
		"btrfs"     "B-Tree File System" \
		"jfs"       "Journaled File System" \
		"f2fs"      "Flash-Friendly File System" \
		"reiserfs"  "Reiser File System" 3>&1 1>&2 2>&3)
		SWAP=false
		if (whiptail --title "Arch Linux Anywhere" --yesno "Create SWAP space?" 10 60) then
			d_bytes=$(fdisk -l | grep -w "$DRIVE" | awk '{print $5}') t_bytes=$((d_bytes-2000000000))
			swapped=false
			while [ "$swapped" != "true" ]
				do
					SWAPSPACE=$(whiptail --inputbox --nocancel "Specify your desired swap size: \n *(Align to M or G):" 10 35 "512M" 3>&1 1>&2 2>&3)
					unit=$(grep -o ".$" <<< "$SWAPSPACE")
					if [ "$unit" == "M" ]; then unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE") p_bytes=$((unit_size*1000*1000))
						if [ "$p_bytes" -lt "$t_bytes" ]; then SWAP=true swapped=true
						else whiptail --title "Arch Linux Anywhere" --msgbox "Error not enough space on drive!" 10 60 ; fi
					elif [ "$unit" == "G" ]; then unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE") p_bytes=$((unit_size*1000*1000*1000))
						if [ "$p_bytes" -lt "$t_bytes" ]; then SWAP=true swapped=true
						else whiptail --title "Arch Linux Anywhere" --msgbox "Error not enough space on drive!" 10 60 ; fi
					else whiptail --title "Arch Linux Anywhere" --msgbox "Error setting swap! Be sure it is a number ending in 'M' or 'G'" 10 60 ; fi
				done
		fi
		UEFI=false
		if [ "$arch" == "x86_64" ]; then
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Would you like to enable UEFI bios? \n\n *May not work on some systems \n *Enable with caution" 10 60) then VBOX=false
				if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Is this a Virtualbox EFI guest install? \n\n *Are you installing Arch in Virtualbox? \n *Must have EFI setting on in virtualbox!" 10 60) then VBOX=true ; fi
				GPT=true UEFI=true
			fi
		fi
		if [ "$UEFI" == "false" ]; then GPT=false
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Would you like to use GPT partitioning?" 10 60) then GPT=true ; fi
		fi
	else
		UEFI=false
		if [ "$arch" == "x86_64" ]; then
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Would you like to enable UEFI bios? \n\n *May not work on some systems \n *Enable with caution" 10 60) then VBOX=false
				if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Is this a Virtualbox EFI guest install? \n\n *Are you installing Arch in Virtualbox? \n *Must have EFI setting on in virtualbox!" 10 60) then VBOX=true ; fi
				whiptail --title "Arch Linux Anywhere" --msgbox "Note you must create a UEFI bios partition! \n\n *Size of 512M-1024M type of EF00 \n *Partition scheme must be GPT!" 10 60
				if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "System will not boot if you don't setup UEFI partition properly! \n\n *Are you sure you want to continue? \n *Only proceed if you know what you're doing." 10 60) then
					UEFI=true
				else
					prepare_drives
				fi	
			fi
		fi
		part_tool=$(whiptail --title "Arch Linux Anywhere" --menu "Please select your desired partitioning tool:" 15 60 5 \
					"cfdisk"  "Best For Beginners" \
					"fdisk"   "CLI Partitioning" \
					"gdisk"   "GPT Partitioning" \
					"parted"  "GNU Parted CLI" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then prepare_drives ; fi
	fi
	case "$PART" in
		"Auto Partition Drive")
			if "$GPT" ; then
				if "$UEFI" ; then
					if "$SWAP" ; then
						echo -e "n\n\n\n512M\nef00\nn\n3\n\n+512M\n8200\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					else
						echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
					fi
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				else
					if "$SWAP" ; then
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n4\n\n+$SWAPSPACE\n8200\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==5) print substr ($1,3) }')"
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					else
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
					fi
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"	
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
				fi
			else
				if "$SWAP" ; then
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n3\n\n+$SWAPSPACE\nt\n\n82\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
					SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"					
					wipefs -a /dev/"$SWAP" &> /dev/null
					mkswap /dev/"$SWAP" &> /dev/null
					swapon /dev/"$SWAP" &> /dev/null
				else
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
				fi				
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
			fi
			wipefs -a /dev/"$BOOT" &> /dev/null
			wipefs -a /dev/"$ROOT" &> /dev/null
			if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
				if "$UEFI" ; then
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating efi boot partition..." load
				else
					echo -e "y" | mkfs -t "$FS" /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating boot partition..." load
				fi
				echo -e "y" | mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="Please wait while creating $FS filesystem" load
			else
				if "$UEFI" ; then
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating efi boot partition..." load
				else
					mkfs -t "$FS" /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating boot partition..." load
				fi
				mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="Please wait while creating $FS filesystem" load
			fi
			mount /dev/"$ROOT" "$ARCH"
			if [ "$?" -eq "0" ]; then
				mounted=true
			fi
			if [[ "$UEFI" == "true" && "$VBOX" == "false" ]] ; then
				mkdir -p $ARCH/boot/efi
				mount /dev/"$BOOT" "$ARCH"/boot/efi
			else
				mkdir $ARCH/boot
				mount /dev/"$BOOT" "$ARCH"/boot
			fi
		;;
		"Auto partition encrypted LVM")
			if "$GPT" ; then
				if "$UEFI" ; then
					echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				else
					echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				fi
			else
				echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.3 msg="Partitioning /dev/$DRIVE..." load
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				
			fi
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Warning this will encrypt /dev/$DRIVE \n\n *Continue?" 10 60) then
				wipefs -a /dev/"$ROOT" &> /dev/null
				lvm pvcreate /dev/"$ROOT" &> /dev/null
				lvm vgcreate lvm /dev/"$ROOT" &> /dev/null
				if "$SWAP" ; then
					lvm lvcreate -L $SWAPSPACE -n swap lvm &> /dev/null
				fi
				lvm lvcreate -L 500M -n tmp lvm &> /dev/null
				lvm lvcreate -l 100%FREE -n lvroot lvm &> /dev/null
    			input=default
				while [ "$input" != "$input_chk" ]
            		do
            	    	input=$(whiptail --passwordbox --nocancel "Please enter a new password for /dev/$DRIVE \n\n *Note this password is used to unencrypt your drive at boot" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            	    	input_chk=$(whiptail --passwordbox --nocancel "New /dev/$DRIVE password again" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            	        if [ "$input" != "$input_chk" ]; then
            	        	whiptail --title "Arch Linux Anywhere" --msgbox "Passwords do not match, please try again." 10 60
            	        fi
            	 	done
				printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot - &
				pid=$! pri=0.2 msg="Encrypting drive..." load
				printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -
				input=""
				if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
					echo -e "y" | mkfs -t "$FS" /dev/mapper/root &> /dev/null &
					pid=$! pri=1 msg="Please wait while creating $FS filesystem" load
				else
					mkfs -t "$FS" /dev/mapper/root &> /dev/null &
					pid=$! pri=1 msg="Please wait while creating $FS filesystem..." load
				fi
				mount /dev/mapper/root "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
					crypted=true
				fi
				wipefs -a /dev/"$BOOT" &> /dev/null
				if "$UEFI" ; then
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating efi boot partition..." load
				else
					mkfs -t "$FS" /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating boot partition..." load
				fi
				if [[ "$UEFI" == "true" && "$VBOX" == "false" ]] ; then
					mkdir -p $ARCH/boot/efi
					mount /dev/"$BOOT" "$ARCH"/boot/efi
				else
					mkdir $ARCH/boot
					mount /dev/"$BOOT" "$ARCH"/boot
				fi
			else
				prepare_drives
			fi
		;;
		"Manual Partition Drive")
			$part_tool /dev/"$DRIVE"
			lsblk | egrep "$DRIVE[0-9]"
			if [ "$?" -gt "0" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "An error was detected during partitioning \n\n *Returing partitioning menu" 10 60
				prepare_drives
			fi
			clear
			partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K" | sed "1d" | cut -c7- | awk '{print $1" "$4}')
			if "$UEFI" ; then
				BOOT=$(whiptail --nocancel --title "Arch Linux Anywhere" --nocancel --menu "Please select your EFI boot partition: \n\n *Generally the first partition size of 512M-1024M" 15 60 5 $partition 3>&1 1>&2 2>&3)
				i=$(<<<$BOOT cut -c4-)
				if (whiptail --title "Arch Linux Anywhere" --yesno "This will create a fat32 formatted EFI partition. \n\n *Are you sure you want to do this?" 10 60) then
					echo -e "t\n${i}\nEF00\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Creating efi boot partition..." load
				else
					prepare_drives
				fi
				partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K\|$BOOT" | sed "1d" | cut -c7- | awk '{print $1" "$4}')
			fi
			ROOT=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Please select your desired root partition: \n\n *This is the main partition all others will be under" 15 60 5 $partition 3>&1 1>&2 2>&3)
			if (whiptail --title "Arch Linux Anywhere" --yesno "This will create a new filesystem on the partition. \n\n *Are you sure you want to do this?" 10 60) then
				FS=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Select your desired filesystem type: \n\n *Default is ext4" 15 60 6 \
				"ext4"      "4th extended file system" \
				"ext3"      "3rd extended file system" \
				"ext2"      "2nd extended file system" \
				"btrfs"     "B-Tree File System" \
				"jfs"       "Journaled File System" \
				"f2fs"      "Flash-Friendly File System" \
				"reiserfs"  "Reiser File System" 3>&1 1>&2 2>&3)
				wipefs -a -q /dev/"$ROOT" &> /dev/null
				if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
					echo -e "y" | mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="Please wait while creating $FS filesystem..." load
				else
					mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="Please wait while creating $FS filesystem..." load
				fi
				mount /dev/"$ROOT" "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
				else
					whiptail --title "Arch Linux Anywhere" --msgbox "An error was detected during partitioning \n\n *Returing partitioning menu" 10 60
					prepare_drives
				fi
			else
				prepare_drives
			fi
			if "$UEFI" ; then
				points=$(echo -e "/home   >\n/srv    >\n/usr    >\n/var    >\nSWAP   >")
				if ! "$VBOX" ; then
					mkdir -p $ARCH/boot/efi
					mount /dev/"$BOOT" "$ARCH"/boot/efi
				else
					mkdir $ARCH/boot
					mount /dev/"$BOOT" "$ARCH"/boot
				fi			
			else
				points=$(echo -e "/boot   >\n/home   >\n/srv    >\n/usr    >\n/var    >\nSWAP   >")
			fi
			until [ "$new_mnt" == "Done" ] 
				do
					partition=$(lsblk | grep "$DRIVE" | grep -v "/\|[SWAP]\|1K" | sed "1d" | cut -c7- | awk '{print $1"     "$4}')
					new_mnt=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Select a partition to create a mount point: \n\n *Select done when finished*" 15 60 6 $partition "Done" "Continue" 3>&1 1>&2 2>&3)
					if [ "$new_mnt" != "Done" ]; then
						MNT=$(whiptail --title "Arch Linux Anywhere" --menu "Select a mount point for /dev/$new_mnt" 15 60 6 $points 3>&1 1>&2 2>&3)
						if [ "$?" -gt "0" ]; then
							:
						elif [ "$MNT" == "SWAP" ]; then
							if (whiptail --title "Arch Linux Anywhere" --yesno "Will create a swap space on /dev/$new_mnt \n\n *Continue?" 10 60) then
								wipefs -a -q /dev/"$new_mnt"
								mkswap /dev/"$new_mnt" &> /dev/null
								swapon /dev/"$new_mnt" &> /dev/null
							fi
						else
							if (whiptail --title "Arch Linux Anywhere" --yesno "Will create mount point $MNT with /dev/$new_mnt \n\n *Continue?" 10 60) then
								FS=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Select your desired filesystem type for $MNT: \n\n *Default is ext4" 15 60 6 \
								"ext4"      "4th extended file system" \
								"ext3"      "3rd extended file system" \
								"ext2"      "2nd extended file system" \
								"btrfs"     "B-Tree File System" \
								"jfs"       "Journaled File System" \
								"f2fs"      "Flash-Friendly File System" \
								"reiserfs"  "Reiser File System" 3>&1 1>&2 2>&3)
								wipefs -a -q /dev/"$new_mnt"
								if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
									echo -e "y" | mkfs -t "$FS" /dev/"$new_mnt" &> /dev/null &
									pid=$! pri=1 msg="Please wait while creating $FS filesystem..." load
								else
									mkfs -t "$FS" /dev/"$new_mnt" &> /dev/null &
									pid=$! pri=1 msg="Please wait while creating $FS filesystem..." load
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
		whiptail --title "Arch Linux Anywhere" --msgbox "An error was detected during partitioning \n\n *Returing to drive partitioning" 10 60
		prepare_drives
	fi
	update_mirrors
}

update_mirrors() {
	countries=$(echo -e "AT Austria\n AU  Australia\n BE Belgium\n BG Bulgaria\n BR Brazil\n BY Belarus\n CA Canada\n CL Chile \n CN China\n CO Columbia\n CZ Czech-Republic\n DK Denmark\n EE Estonia\n ES Spain\n FI Finland\n FR France\n GB United-Kingdom\n HU Hungary\n IE Ireland\n IL Isreal\n IN India\n IT Italy\n JP Japan\n KR Korea\n KZ Kazakhstan\n LK Sri-Lanka\n LU Luxembourg\n LV Lativia\n MK Macedonia\n NC New-Caledonia\n NL Netherlands\n NO Norway\n NZ New-Zealand\n PL Poland\n PT Portugal\n RO Romania\n RS Serbia\n RU Russia\n SE Sweden\n SG Singapore\n SK Slovakia\n TR Turkey\n TW Taiwan\n UA Ukraine\n US United-States\n UZ Uzbekistan\n VN Viet-Nam\n ZA South-Africa")
	if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to update your mirrorlist now?" 10 60) then
		code=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Please select your country code:" 15 60 6 $countries 3>&1 1>&2 2>&3)
		wget --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak &
		pid=$! pri=0.2 msg="Retreiving new mirrorlist..." load
		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist &
  		pid=$! pri=0.5 msg="Please wait while ranking mirrors" load
 		mirrors_updated=true
	fi
	install_base
}

install_base() {
	if ! "$INSTALLED" && "$mounted" ; then	
		if (whiptail --title "Arch Linux Anywhere" --yesno "Begin installing Arch Linux base onto /dev/$DRIVE?" 10 60) then
			pacstrap "$ARCH" base base-devel libnewt &> /dev/null &
			pid=$! pri="$down" msg="Please wait while we install Arch Linux... \n\n *This may take awhile" load
			genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab &> /dev/null &
			if [ "$?" -eq "0" ]; then
				INSTALLED=true
			else
				INSTALLED=false
				whiptail --title "Arch Linux Anywhere" --msgbox "An error occured returning to menu... \n\n *Fstab was not generated!" 10 60
				main_menu
			fi		
			while [ ! -n "$loader" ]
				do
					if (whiptail --title "Arch Linux Anywhere" --yesno "Install GRUB bootloader? \n\n *Required to make system bootable" 10 60) then
						if (whiptail --title "Arch Linux Anywhere" --yesno "Install os-prober first? \n\n *Required for multiboot" 10 60) then
							pacstrap "$ARCH" os-prober &> /dev/null &
							pid=$! pri=0.5 msg="Installing os-prober..." load
						fi
						pacstrap "$ARCH" grub &> /dev/null &
						pid=$! pri=0.5 msg="Installing grub..." load
						if [ "$crypted" == "true" ]; then
							sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
						fi
						if "$UEFI" ; then
							pacstrap "$ARCH" efibootmgr &> /dev/null &
							pid=$! pri=0.5 msg="Installing efibootmgr..." load
							if "$VBOX" ; then
								arch-chroot "$ARCH" grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot --recheck &> /dev/null &
								pid=$! pri=0.5 msg="Installing grub to drive..." load
								mv "$ARCH"/boot/EFI/boot/grubx64.efi "$ARCH"/boot/EFI/boot/bootx64.efi
							else
								arch-chroot "$ARCH" grub-install --efi-directory=/boot/efi --target=x86_64-efi --bootloader-id=grub_uefi --recheck &> /dev/null &
								pid=$! pri=0.5 msg="Installing grub to drive..." load
							fi
						else
							arch-chroot "$ARCH" grub-install --recheck /dev/"$DRIVE" &> /dev/null &
							pid=$! pri=0.5 msg="Installing grub to drive..." load
						fi
						arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
						pid=$! pri=0.2 msg="Configuring grub..." load
						if [[ "$UEFI" == "true" && "$crypted" == "false" ]] ; then
							arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
							pid=$! pri=1 msg="Please wait while configuring kernel for uEFI..." load
						fi
						loader=true
						bootloader=true
					else
						if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Warning! System will not be bootable! \n\n *You will need to configure a bootloader yourself \n *Continue without a bootloader?" 10 60) then
							whiptail --title "Arch Linux Anywhere" --msgbox "After install is complete choose not to reboot, you may choose to keep the system mounted at $ARCH allowing you to arch-chroot into it and configure your own bootloader." 10 60
							loader=true
						fi
					fi
				done
			configure_system
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "Ready to install system to $ARCH \n\n *Are you sure you want to exit to menu?" 10 60) then
				main_menu
			else
				install_base
			fi
		fi
	elif "$INSTALLED" ; then
		whiptail --title "Arch Linux Anywhere" --msgbox "Error root filesystem already installed at $ARCH \n\n *Continuing to menu." 10 60
		main_menu
	else
		if (whiptail --title "Arch Linux Anywhere" --yesno "Error no filesystem mounted \n\n *Return to drive partitioning?" 10 60) then
			prepare_drives
		else
			whiptail --title "Arch Linux Anywhere" --msgbox "Error no filesystem mounted \n\n *Continuing to menu." 10 60
			main_menu
		fi
	fi
}

configure_system() {
	if "$system_configured" ; then
		whiptail --title "Arch Linux Anywhere" --msgbox "The system has already been configured. \n\n *Continuing to menu..." 10 60
		main_menu
	fi
	if "$crypted" ; then
		if "$UEFI" ; then
			echo "/dev/$BOOT              /boot           vfat         defaults        0       2" > "$ARCH"/etc/fstab
		else
			echo "/dev/$BOOT              /boot           $FS         defaults        0       2" > "$ARCH"/etc/fstab
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
		pid=$! pri=1 msg="Please wait while configuring kernel for encryption..." load
	fi
	sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
	echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
	arch-chroot "$ARCH" locale-gen &> /dev/null &
	pid=$! pri=0.2 msg="Generating $LOCALE locale..." load
	arch-chroot "$ARCH" loadkeys "$keyboard" &> /dev/null &
	pid=$! pri=0.2 msg="Loading $keyboard keymap..." load
	if [ -n "$SUB_SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE"/"$SUB_SUBZONE" /etc/localtime
	elif [ -n "$SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" /etc/localtime
	elif [ -n "$ZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE" /etc/localtime
	fi
	if [ "$arch" == "x86_64" ]; then
		if (whiptail --title "Arch Linux Anywhere" --yesno "64 bit architecture detected.\n\n *Add multilib repos to pacman.conf?" 10 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
		fi
	fi
	system_configured=true
	set_hostname
}

set_hostname() {
	hostname=$(whiptail --nocancel --inputbox "Set your system hostname:" 10 40 "arch" 3>&1 1>&2 2>&3)
	echo "$hostname" > "$ARCH"/etc/hostname
	user=root
	echo -e 'user='$user'
		input=default
		while [ "$input" != "$input_chk" ]
            		do
                   			 input=$(whiptail --passwordbox --nocancel "Please enter a new $user password" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            		         input_chk=$(whiptail --passwordbox --nocancel "New $user password again" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
                   			 if [ "$input" != "$input_chk" ]; then
                      		      whiptail --title "Arch Linux Anywhere" --msgbox "Passwords do not match, please try again." 10 60
                     		 fi
         		        done
    			echo -e "$input\n$input\n" | passwd "$user" &> /dev/null' > /mnt/root/set.sh
	chmod +x "$ARCH"/root/set.sh
	arch-chroot "$ARCH" ./root/set.sh
	rm "$ARCH"/root/set.sh
	if "$hostname_set" ; then main_menu ;fi
	hostname_set=true
	add_user
}

add_user() {
	if "$user_added" ; then
		whiptail --title "Arch Linux Anywhere" --msgbox "User already added \n\n *Continuing to menu." 10 60
		main_menu
	fi
	if (whiptail --title "Arch Linux Anywhere" --yesno "Create a new user account now?" 10 60) then
		user=$(whiptail --nocancel --inputbox "Set username:" 10 40 "" 3>&1 1>&2 2>&3)
	else
		configure_network
	fi
	arch-chroot "$ARCH" useradd -m -g users -G wheel,audio,network,power,storage,optical -s /bin/bash "$user"
	echo -e 'user='$user'
			   input=default
			           while [ "$input" != "$input_chk" ]
            				do
                   					 input=$(whiptail --passwordbox --nocancel "Please enter a new password for $user" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            				         input_chk=$(whiptail --passwordbox --nocancel "New password for $user again" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
                   					 if [ "$input" != "$input_chk" ]; then
                      				      whiptail --title "Arch Linux Anywhere" --msgbox "Passwords do not match, please try again." 10 60
                     				 fi
         				        done
    					echo -e "$input\n$input\n" | passwd "$user" &> /dev/null' > /mnt/root/set.sh
	chmod +x "$ARCH"/root/set.sh
	arch-chroot "$ARCH" ./root/set.sh
	rm "$ARCH"/root/set.sh
	if (whiptail --title "Arch Linux Anywhere" --yesno "Enable sudo privelege for $user? \n\n *Enables administrative privelege with sudo." 10 60) then
		sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
	fi
	user_added=true configure_network
}

configure_network() {
	if (whiptail --title "Arch Linux Anywhere" --yesno "Enable DHCP at boot? \n\n *Automatic IP configuration." 10 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null
	fi
	if (whiptail --title "Arch Linux Anywhere" --yesno "Install wireless tools, netctl, and WPA supplicant? \n\n *Necessary if using wifi \n *Provides wifi-menu" 10 60) then
		pacstrap "$ARCH" wireless_tools wpa_supplicant netclt dialog wpa_actiond &> /dev/null &
		pid=$! pri=0.5 msg="Installing wireless tools and WPA supplicant..." load
	fi
	if "$network_configured" ; then main_menu ; fi
	network_configured=true graphics
}

graphics() {
	if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install xorg-server now? \n\n *Select yes for a graphical interface" 10 60) then
		pacstrap "$ARCH" xorg-server xorg-server-utils xorg-xinit xterm mesa-libgl &> /dev/null &
		pid=$! pri="$down" msg="Please wait while installing xorg-server..." load
		if "$VBOX" ; then
			pacstrap "$ARCH" virtualbox-guest-utils &> /dev/null &
			pid=$! pri=1 msg="Please wait while installing virtualbox guest utils..." load
			echo -e "vboxguest\nvboxsf\nvboxvideo" > "$ARCH"/etc/modules-load.d/virtualbox.conf
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install graphics drivers now? \n\n *If no default drivers will be used. \n *Virtualbox guests select yes" 10 60) then
				until [ "$GPU" == "set" ]
					do
						i=false
						GPU=$(whiptail --title "Arch Linux Anywhere" --menu "Select your desired drivers:" 15 60 5 \
						"xf86-video-ati"         "AMD/ATI Graphics" \
						"xf86-video-intel"       "Intel Graphics" \
						"Nvidia"  			     "NVIDIA Graphics" \
						"virtualbox-guest-utils" "VirtualBox Graphics" 3>&1 1>&2 2>&3)
						if [ "$?" -gt "0" ]; then
							if (whiptail --title "Arch Linux Anywhere" --yesno "Continue without installing graphics drivers? \n\n *Default drivers will be used." 10 60) then
								GPU=set
							fi
						else
							i=true
						fi
						if [ "$GPU" == "Nvidia" ]; then
							GPU=$(whiptail --title "Arch Linux Anywhere" --menu "Select your desired Nvidia driver: \n\n *Cancel if none" 15 60 4 \
							"nvidia"       "Latest stable nvidia" \
							"nvidia-340xx" "Legacy 340xx branch" \
							"nvidia-304xx" "Legaxy 304xx branch" 3>&1 1>&2 2>&3)
							if [ "$?" -gt "0" ]; then
								i=false
							fi
						elif [ "$GPU" == "virtualbox-guest-utils" ]; then
							echo -e "vboxguest\nvboxsf\nvboxvideo" > "$ARCH"/etc/modules-load.d/virtualbox.conf
						fi
						if "$i" ; then
							pacstrap "$ARCH" "$GPU" &> /dev/null &
							pid=$! pri=1 msg="Please wait while installing graphics drivers..." load
							GPU=set
						fi
					done
			fi
		fi
		if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install a desktop or window manager?" 10 60) then
			until [ "$DE" == "set" ]
				do
					i=false
					DE=$(whiptail --title "Arch Linux Installer" --menu "Select your desired enviornment:" 15 60 6 \
					"xfce4"         "Light DE" \
					"mate"          "Light DE" \
					"lxde"          "Light DE" \
					"lxqt"          "Light DE" \
					"gnome"         "Modern DE" \
					"cinnamon"      "Eligant DE" \
					"KDE plasma"    "Rich DE" \
					"enlightenment" "Light WM/DE" \
					"openbox"       "Stacking WM" \
					"awesome"       "Awesome WM" \
					"i3"            "Tiling WM" \
					"fluxbox"       "Light WM" \
					"dwm"           "Dynamic WM" 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						DE=set
					else
						i=true
						if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install LightDM display manager?" 10 60) then
							pacstrap "$ARCH" lightdm lightdm-gtk-greeter &> /dev/null &
							pid=$! pri="$down" msg="Please wait while installing LightDM..." load
							arch-chroot "$ARCH" systemctl enable lightdm.service &> /dev/null
						else
							whiptail --title "Arch Linux Anywhere" --msgbox "After login use the command 'startx' to access your desktop." 10 60
						fi
					fi
					case "$DE" in
						"xfce4") start_term="exec startxfce4" 
							if (whiptail --title "Arch Linux Installer" --yesno "Install xfce4 goodies?" 10 60) then
								DE="xfce4 xfce4-goodies"
							fi ;;
						"gnome") start_term="exec gnome-session"
							if (whiptail --title "Arch Linux Installer" --yesno "Install gnome extras?" 10 60) then
								DE="gnome gnome-extra"
								down=$((down+4))
							fi ;;
						"cinnamon") start_term="exec cinnamon-session" ;;
						"mate") start_term="exec mate-session"
							if (whiptail --title "Arch Linux Installer" --yesno "Install mate extras?" 10 60) then
								DE="mate mate-extra"
							fi ;;
						"KDE plasma") start_term="exec startkde"
							if (whiptail --title "Arch Linux Installer" --defaultno --yesno "Install minimal plasma desktop?" 10 60) then
								DE="kde-applications plasma-desktop"
							else
								DE="kde-applications plasma"
							fi ;;
						"lxde") start_term="exec startlxde" ;;
						"lxqt") start_term="exec startlxqt" DE="lxqt oxygen-icons" ;;
						"enlightenment") start_term="exec enlightenment_start" DE="enlightenment terminology" ;;
						"fluxbox") start_term="exec startfluxbox" ;;
						"openbox") start_term="exec openbox-session" ;;
						"awesome") start_term="exec awesome" ;;
						"dwm") start_term="exec dwm" ;;
						"i3") start_term="exec i3" ;;
					esac
					if "$i" ; then
						pacstrap "$ARCH" $(<<<"$DE") &> /dev/null &
						pid=$! pri="$down" msg="Please wait while installing desktop..." load
						if [ "$user_added" == "true" ]; then
							echo "$start_term" > "$ARCH"/home/"$user"/.xinitrc
						else
							echo "$start_term" > "$ARCH"/root/.xinitrc
						fi
						DE=set
					fi
				done
		fi
	fi
	install_software
}

install_software() {
	if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install some common software?" 10 60) then
		software=$(whiptail --title "Arch Linux Anywhere" --checklist "Choose your desired software: \n\n *Use spacebar to check/uncheck software \n *Press enter when finished" 20 60 10 \
					"openssh"     	       "Secure Shell Deamon" ON \
					"pulseaudio"  	       "Popular sound server" ON \
					"vim"         	       "Popular Text Editor" ON \
					"wget"        	       "CLI web downloader" ON \
					"zsh"         	       "The Z shell" ON \
					"apache"  	  	       "Web Server" OFF \
					"chromium"    	       "Graphical Web Browser" OFF \
					"cmus"        	       "CLI music player" OFF \
					"conky"       	       "Light system monitor for X" OFF \
					"dropbox"              "Cloud file sharing" OFF \
					"firefox"     	       "Graphical Web Browser" OFF \
					"gimp"        	       "GNU Image Manipulation " OFF \
					"git"                  "Source control managment" OFF \
					"gparted"     	       "GNU Parted GUI" OFF \
					"htop"        	       "CLI process Info" OFF \
					"libreoffice" 	       "Open source word processing " OFF \
					"lynx"        	       "Terminal Web Browser" OFF \
					"mpd"         	       "Music Player Daemon" OFF \
					"mplayer"     	       "Media Player" OFF \
					"ncmpcpp"     	       "GUI client for MPD" OFF \
					"nmap"                 "CLI network analyzer" OFF \
					"pitivi"               "Video editing software" OFF \
					"projectm"             "Music visuliaztions" OFF \
					"screen"  	  	       "GNU Screen" OFF \
					"screenfetch" 	       "Display System Info" OFF \
					"simplescreenrecorder" "Screen capture software" OFF \
					"tmux"    	  	   	   "Terminal multiplxer" OFF \
					"transmission-cli" 	   "CLI torrent client" OFF \
					"transmission-gtk"     "Graphical torrent client" OFF \
					"virtualbox"  	       "Desktop virtuialization" OFF \
					"vlc"         	   "GUI media player" OFF \
					"ufw"         	   "Uncomplicated Firewall" OFF 3>&1 1>&2 2>&3)
		download=$(echo "$software" | sed 's/\"//g')
    	pacstrap "$ARCH" ${download} &> /dev/null &
    	pid=$! pri=1 msg="Please wait while installing software..." load
	fi
	reboot_system
}

reboot_system() {
	if "$INSTALLED" ; then
		if ! "$bootloader" ; then
			if (whiptail --title "Arch Linux Anywhere" --yesno "Install process complete! \n\n *You did not configure a bootloader \n *Return to the command line to configure?" 10 60) then
				clear ; exit
			fi
		fi
		if (whiptail --title "Arch Linux Anywhere" --yesno "Install process complete! Reboot now? \n\n *Select yes to reboot now \n *No to return to command line" 10 60) then
			umount -R $ARCH
		    clear ; reboot ; exit
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "System fully installed \n\n *Would you like to unmount?" 10 60) then
				umount -R "$ARCH"
				clear ; exit
			else
				clear ; exit
			fi
		fi
	else
		if (whiptail --title "Arch Linux Anywhere" --yesno "Install not complete, are you sure you want to reboot?" 10 60) then
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
    	            if [ "$?" -gt "0" ]; then break; fi
    	            sleep $pri
    	            echo $int
    	            int=$((int+1))
    	        done
            echo 100
            sleep 1
	} | whiptail --title "Arch Linux Anywhere" --gauge "$msg" 8 78 0
}

main_menu() {
	return=(whiptail --title "Arch Linux Anywhere" --msgbox "The system hasn't been installed yet \n *returning to menu" 10 60)
	menu_item=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Menu Items:" 15 60 6 \
		"Set Locale"            "-" \
		"Set Timezone"          "-" \
		"Set Keymap"            "-" \
		"Partition Drive"       "-" \
		"Update Mirrors"        "-" \
		"Install Base System"   "-" \
		"Configure System"      "-" \
		"Set Hostname"          "-" \
		"Add User"              "-" \
		"Configure Network"     "-" \
		"Install Graphics"      "-" \
		"Install Software"      "-" \
		"Reboot System"         "-" \
		"Exit Installer"        "-" 3>&1 1>&2 2>&3)
	case "$menu_item" in
		"Set Locale" ) 
			if "$locale_set" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Locale already set, returning to menu" 10 60 ; main_menu ; fi
			set_locale ;;
		"Set Timezone")
			if "$zone_set" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Timezone already set, returning to menu" 10 60 ; main_menu ; fi
			set_zone ;;
		"Set Keymap")
			if "$keys_set" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Keymap already set, returning to menu" 10 60 ; main_menu ; fi
			set_keys ;;
		"Partition Drive")
			if "$mounted" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Drive already mounted, try install base system \n returning to menu" 10 60 ; main_menu ; fi
 			prepare_drives ;;
		"Update Mirrors") update_mirrors ;;
		"Install Base System") install_base ;;
		"Configure System") if "$INSTALLED" ; then configure_system ; fi ;;
		"Set Hostname") if "$INSTALLED" ; then set_hostname ; fi ;;
		"Add User") if "$INSTALLED" ; then add_user ; fi ;;
		"Configure Network") if "$INSTALLED" ; then configure_network ; fi ;;
		"Install Graphics") if "$INSTALLED" ; then graphics ; fi ;;
		"Install Software") if "$INSTALLED" ; then install_software ; fi ;;
		"Reboot System") reboot_system ;;
		"Exit Installer") 
			if "$INSTALLED" ; then
				whiptail --title "Arch Linux Anywhere" --msgbox "System installed \n\n Exiting arch installer..." 10 60
				clear
				exit
			else
				if (whiptail --title "Arch Linux Anywhere" --yesno "System not installed yet... \n\n Are you sure you want to exit?" 10 60) then
					clear
					exit
				else
					main_menu
				fi
			fi
		;;
	esac
	$return ; main_menu
}
check_connection
