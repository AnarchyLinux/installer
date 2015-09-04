#!/bin/bash

ARCH=/mnt
INSTALLED=false

check_connection() {
	clear
	if ! (whiptail --title "Arch Linux Anywhere" --yesno "Welcome to the Arch Linux Anywhere installer! \n Would you like to begin the install process?" 10 60) then
		exit
	fi
	ping -w 2 google.com &> /dev/null
	if [ "$?" -gt "0" ]; then
		connection=false		
		cp /root/local-pacman.conf /etc/pacman.conf
		down="0.7"
	else
		connection=true
		if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Would you like to install from the local repository? \n\n *This will ensure an extremly fast install, \n  but may not contain the most updated packages." 10 60) then
			cp /root/local-pacman.conf /etc/pacman.conf
			down="1"
		else
			start=$(date +%s)
			wget http://cachefly.cachefly.net/10mb.test &> /dev/null &
			pid=$! pri=1 msg="Please wait while we test your connection..." load
			end=$(date +%s)
			diff=$((end-start))
			case "$diff" in
				[1-4]) down="1" ;;
				[5-9]) down="2" ;;
				1[0-9]) down="3" ;;
				2[0-9]) down="4" ;;
				3[0-9]) down="5" ;;
				4[0-9]) down="6" ;;
				5[0-9]) down="7" ;;
				6[0-9]) down="8" ;;
				[0-9][0-9][0-9]) 
					if (whiptail --title "Arch Linux Anywhere" --yesno "Your connection is very slow, this might take a long time...\n *Continue?" 10 60) then
						down="15"
					else
						exit
					fi
				;;
				*) down="10" ;;
			esac
		fi
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
		if [ "$?" -gt "0" ]; then
			set_locale
		fi
	fi
	locale_set=true
	set_zone
}

set_zone() {
	zonelist=$(find /usr/share/zoneinfo -maxdepth 1 | sed -n -e 's!^.*/!!p' | grep -v "posix\|right\|zoneinfo\|zone.tab\|zone1970.tab\|W-SU\|WET\|posixrules\|MST7MDT\|iso3166.tab\|CST6CDT" | sort | sed 's/$/ -/g')
	ZONE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Please enter your Time Zone:" 15 60 6 $zonelist 3>&1 1>&2 2>&3)
		check_dir=$(find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE")
		if [ -n "$check_dir" ]; then
			sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
			SUBZONE=$(whiptail --title "Arch Linux Anywhere" --menu "Please enter your sub-zone:" 15 60 6 $sublist 3>&1 1>&2 2>&3)
			if [ "$?" -gt "0" ]; then
				set_zone
			fi
			chk_dir=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE")
			if [ -n "$chk_dir" ]; then
				sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
				SUB_SUBZONE=$(whiptail --title "Arch Linux Anywhere" --menu "Please enter your sub-zone:" 15 60 6 $sublist 3>&1 1>&2 2>&3)
				if [ "$?" -gt "0" ]; then
					set_zone
				fi
			fi
		fi
	zone_set=true
	set_keys
}

set_keys() {
	keyboard=$(whiptail --nocancel --inputbox "Set key-map: \n *If unsure leave default" 10 35 "us" 3>&1 1>&2 2>&3)
	keys_set=true
	prepare_drives
}

prepare_drives() {
	drive=$(lsblk | grep "disk" | grep -v "rom" | awk '{print $1   " "   $4}')
	DRIVE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Select the drive you would like to install arch onto:" 15 60 5 $drive 3>&1 1>&2 2>&3)
	PART=$(whiptail --title "Arch Linux Anywhere" --menu "Select your desired method of partitioning: \n *NOTE Auto Partitioning will format the selected drive" 15 60 5 \
	"Auto Partition Drive"           "-" \
	"Auto partition encrypted LVM"   "-" \
	"Manual Partition Drive"         "-" \
	"Return To Menu"                 "-" \
	"Back"                 "-" 3>&1 1>&2 2>&3)
	if [ "$PART" == "Back" ]; then
		prepare_drives
	elif [ "$PART" == "Return To Menu" ]; then
		main_menu
	elif [ "$PART" == "Auto partition encrypted LVM" ] || [ "$PART" == "Auto Partition Drive" ]; then
		if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "WARNING! Will erase all data on drive /dev/$DRIVE! \n *Would you like to contunue?" 10 60) then
			sgdisk --zap-all "$DRIVE" &> /dev/null
		else
			prepare_drives
		fi
		SWAP=false
		if (whiptail --title "Arch Linux Anywhere" --yesno "Create SWAP space?" 10 60) then
			d_bytes=$(fdisk -l | grep -w "$DRIVE" | awk '{print $5}')
			t_bytes=$((d_bytes-2000000000))
			swapped=false
			while [ "$swapped" != "true" ]
				do
					SWAPSPACE=$(whiptail --inputbox "Specify your desired swap size: \n *(Align to M or G):" 10 35 "512M" 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						swapped=true
					fi
					unit=$(grep -o ".$" <<< "$SWAPSPACE")
					if [ "$unit" == "M" ]; then
						unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE")
						p_bytes=$((unit_size*1000*1000))
						if [ "$p_bytes" -lt "$t_bytes" ]; then
							SWAP=true
							swapped=true
						else
							whiptail --title "Arch Linux Anywhere" --msgbox "Error not enough space on drive!" 10 60
						fi
					elif [ "$unit" == "G" ]; then
						unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE")
						p_bytes=$((unit_size*1000*1000*1000))
						if [ "$p_bytes" -lt "$t_bytes" ]; then
							SWAP=true
							swapped=true
						else
							whiptail --title "Arch Linux Anywhere" --msgbox "Error not enough space on drive!" 10 60
						fi
					else
						whiptail --title "Arch Linux Anywhere" --msgbox "Error setting swap! Be sure it is a number ending in 'M' or 'G'" 10 60
					fi
				done
		fi
#		UEFI=false
#		if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Would you like to enable UEFI bios?" 10 60) then
#			GPT=true			
#			UEFI=true
#		else
			GPT=false
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Would you like to use GPT partitioning?" 10 60) then
				GPT=true
			fi
#		fi
	else
		part_tool=$(whiptail --title "Arch Linux Anywhere" --menu "Please select your desired partitioning tool:" 15 60 5 \
					"cfdisk"  "Best For Beginners" \
					"fdisk"   "CLI Partitioning" \
					"gdisk"   "GPT Partitioning" \
					"parted"  "GNU Parted CLI" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			prepare_drives
		fi
	fi
	case "$PART" in
		"Auto Partition Drive")
			if "$GPT" ; then
				if "$SWAP" ; then
					echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n4\n\n+$SWAPSPACE\n8200\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null
					SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==5) print substr ($1,3) }')"
					wipefs -a -q /dev/"$SWAP"
					mkswap /dev/"$SWAP" &> /dev/null
					swapon /dev/"$SWAP" &> /dev/null
				else
					echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null
				fi
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"	
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
					wipefs -a -q /dev/"$BOOT" &> /dev/null
					wipefs -a -q /dev/"$ROOT" &> /dev/null
					mkfs.ext4 -q /dev/"$BOOT" &> /dev/null
					mkfs.ext4 -q /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="Please wait while creating filesystem" load
					mount /dev/"$ROOT" "$ARCH"
					if [ "$?" -eq "0" ]; then
						mounted=true
					fi
					mkdir $ARCH/boot
					mount /dev/"$BOOT" "$ARCH"/boot
			else
				if "$SWAP" ; then
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n3\n\n+$SWAPSPACE\nt\n\n82\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null
					SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"					
					wipefs -a -q /dev/"$SWAP"
					mkswap /dev/"$SWAP" &> /dev/null
					swapon /dev/"$SWAP" &> /dev/null
				else
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null
				fi
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				wipefs -a -q /dev/"$BOOT" &> /dev/null
				wipefs -a -q /dev/"$ROOT" &> /dev/null
				mkfs.ext4 -q /dev/"$BOOT" &> /dev/null
				mkfs.ext4 -q /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="Please wait while creating filesystem..." load
		        mount /dev/"$ROOT" "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
				fi
				mkdir "$ARCH"/boot		
				mount /dev/"$BOOT" "$ARCH"/boot
			fi
		;;
		"Auto partition encrypted LVM")
			if "$GPT" ; then
				echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
			else
				echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				
			fi
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Warning this will encrypt /dev/$DRIVE \n *Continue?" 10 60) then
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
            	    	input=$(whiptail --passwordbox --nocancel "Please enter a new password for /dev/$DRIVE \n *Note this password is used to unencrypt your drive" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            	    	input_chk=$(whiptail --passwordbox --nocancel "New /dev/$DRIVE password again" 8 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            	        if [ "$input" != "$input_chk" ]; then
            	        	whiptail --title "Arch Linux Anywhere" --msgbox "Passwords do not match, please try again." 10 60
            	        fi
            	 	done
				printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot - &
				pid=$! pri=0.2 msg="Encrypting drive..." load
				printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -
				input=""
				mkfs -q -t ext4 /dev/mapper/root &> /dev/null &
				pid=$! pri=1 msg="Please wait while creating filesystem..." load
				mount -t ext4 /dev/mapper/root "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
					crypted=true
				fi
				wipefs -a /dev/"$BOOT" &> /dev/null
				mkfs -q -t ext4 /dev/"$BOOT" &> /dev/null
				mkdir "$ARCH"/boot
				mount -t ext4 /dev/"$BOOT" "$ARCH"/boot
			else
				prepare_drives
			fi
		;;
		"Manual Partition Drive")
			$part_tool /dev/"$DRIVE"
			lsblk | egrep "$DRIVE[0-9]"
			if [ "$?" -gt "0" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "An error was detected during partitioning \n *Returing partitioning menu" 10 60
				prepare_drives
			fi
			clear
			partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K" | sed "1d" | cut -c7- | awk '{print $1" "$4}')
			ROOT=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Please select your desired root partition first:" 15 60 5 $partition 3>&1 1>&2 2>&3)
			if (whiptail --title "Arch Linux Anywhere" --yesno "This will create a new filesystem on the partition. \n *Are you sure you want to do this?" 10 60) then
				wipefs -a -q /dev/"$ROOT" &> /dev/null
				mkfs.ext4 -q /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="Please wait while creating filesystem..." load
				mount /dev/"$ROOT" "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
				else
					whiptail --title "Arch Linux Anywhere" --msgbox "An error was detected during partitioning \n *Returing partitioning menu" 10 60
					prepare_drives
				fi
			else
				prepare_drives
			fi
			points=$(echo -e "/boot   >\n/home   >\n/srv    >\n/usr    >\n/var    >\nSWAP   >")
			until [ "$new_mnt" == "Done" ] 
				do
					partition=$(lsblk | grep "$DRIVE" | grep -v "/\|[SWAP]\|1K" | sed "1d" | cut -c7- | awk '{print $1"     "$4}')
					new_mnt=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Select a partition to create a mount point: \n *Select done when finished*" 15 60 5 $partition "Done" "Continue" 3>&1 1>&2 2>&3)
					if [ "$new_mnt" != "Done" ]; then
						MNT=$(whiptail --title "Arch Linux Anywhere" --menu "Select a mount point for /dev/$new_mnt" 15 60 5 $points 3>&1 1>&2 2>&3)				
						if [ "$?" -gt "0" ]; then
							:
						elif [ "$MNT" == "SWAP" ]; then
							if (whiptail --title "Arch Linux Anywhere" --yesno "Will create a swap space on /dev/$new_mnt \n *Continue?" 10 60) then
								wipefs -a -q /dev/"$new_mnt"
								mkswap /dev/"$new_mnt" &> /dev/null
								swapon /dev/"$new_mnt" &> /dev/null
							fi
						else
							if (whiptail --title "Arch Linux Anywhere" --yesno "Will create mount point $MNT with /dev/$new_mnt \n *Continue?" 10 60) then
								wipefs -a -q /dev/"$new_mnt"
								mkfs.ext4 -q /dev/"$new_mnt" &> /dev/null &
								pid=$! pri=1 msg="Please wait while creating filesystem..." load
								mkdir "$ARCH"/"$MNT"
								mount /dev/"$new_mnt" "$ARCH"/"$MNT"
								points=$(echo  "$points" | grep -v "$MNT")
							fi
						fi
					fi
				done
		;;
	esac
	if [ "$mounted" != "true" ]; then
		whiptail --title "Arch Linux Anywhere" --msgbox "An error was detected during partitioning \n *Returing to drive partitioning" 10 60
		prepare_drives
	fi
	update_mirrors
}

update_mirrors() {
	if [ "$connection" == "true" ]; then
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
	fi
	install_base
}

install_base() {
	if [[ -n "$ROOT" && "$INSTALLED" == "false"  && "$mounted" == "true" ]]; then	
		if (whiptail --title "Arch Linux Anywhere" --yesno "Begin installing Arch Linux base onto /dev/$DRIVE?" 10 60) then
			pacstrap "$ARCH" base base-devel grub libnewt &> /dev/null &
			pid=$! pri="$down" msg="Please wait while we install Arch Linux... \n *This may take awhile" load
			if [ "$?" -eq "0" ]; then
				INSTALLED=true
			else
				INSTALLED=false
				whiptail --title "Arch Linux Anywhere" --msgbox "An error occured returning to menu" 10 60
				main_menu
			fi
			genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab
			intel=$(< /proc/cpuinfo grep vendor_id | grep -iq intel)
			if [ -n "$intel" ]; then
				pacstrap $ARCH intel-ucode
			fi
			if (whiptail --title "Arch Linux Anywhere" --yesno "Install os-prober? \n *Required for dualboot" 10 60) then
				pacstrap "$ARCH" os-prober &> /dev/null &
				pid=$! pri=0.5 msg="Installing os-prober..." load
			fi
			if [ "$crypted" == "true" ]; then
				sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
				echo "/dev/$BOOT                    /boot           ext4           defaults        0       2" > "$ARCH"/etc/fstab
				echo "/dev/mapper/root        /                      ext4            defaults       0       1" >> "$ARCH"/etc/fstab
				echo "/dev/mapper/tmp       /tmp             tmpfs        defaults        0       0" >> "$ARCH"/etc/fstab
				echo "tmp	       /dev/lvm/tmp	       /dev/urandom	tmp,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab
				if "$SWAP" ; then
					echo "/dev/mapper/swap     none            swap          sw                    0       0" >> "$ARCH"/etc/fstab
					echo "swap	/dev/lvm/swap	/dev/urandom	swap,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab
				fi
			fi
			arch-chroot "$ARCH" grub-install --recheck /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.5 msg="Installing grub..." load
			loader_installed=true
			arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
			pid=$! pri=0.5 msg="Configuring grub..." load
			configure_system
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "Ready to install system to $ARCH \n *Are you sure you want to exit to menu?" 10 60) then
				main_menu
			else
				install_base
			fi
		fi
	else
		if [ "$INSTALLED" == "true" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "Error root filesystem already installed at $ARCH \n *Continuing to menu." 10 60
				main_menu
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "Error no filesystem mounted \n *Return to drive partitioning?" 10 60) then
				prepare_drives
			else
				whiptail --title "Arch Linux Anywhere" --msgbox "Error no filesystem mounted \n *Continuing to menu." 10 60
				main_menu
			fi
		fi
	fi
}

configure_system() {
	if [ "$INSTALLED" == "true" ]; then
		if [ "$system_configured" == "true" ]; then
			whiptail --title "Arch Linux Anywhere" --msgbox "Error system already configured \n *Continuing to menu." 10 60
			main_menu
		fi
		if [ "$crypted" == "true" ]; then
			sed -i 's/k filesystems k/k lvm2 encrypt filesystems k/' "$ARCH"/etc/mkinitcpio.conf
			arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
			pid=$! pri=1 msg="Please wait while configuring kernel for encryption" load
		fi
		sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
		echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
		arch-chroot "$ARCH" locale-gen &> /dev/null
		arch-chroot "$ARCH" loadkeys "$keyboard" &> /dev/null
		if [ -n "$SUB_SUBZONE" ]; then
			arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE"/"$SUB_SUBZONE" /etc/localtime
		elif [ -n "$SUBZONE" ]; then
			arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" /etc/localtime
		elif [ -n "$ZONE" ]; then
			arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE" /etc/localtime
		fi
		arch=$(uname -a | grep -o "x86_64\|i386\|i686")
		if [ "$arch" == "x86_64" ]; then
			if (whiptail --title "Arch Linux Anywhere" --yesno "64 bit architecture detected.\n *Add multilib repos to pacman.conf?" 10 60) then
				sed -i '/\[multilib]$/ {
				N
				/Include/s/#//g}' /mnt/etc/pacman.conf
			fi
		fi
		system_configured=true
		set_hostname
	else
		whiptail --title "Arch Linux Anywhere" --msgbox "Error no root filesystem installed at $ARCH \n *Continuing to menu." 10 60
		main_menu
	fi
}

set_hostname() {
	if [ "$INSTALLED" == "true" ]; then
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
		add_user
	else
		whiptail --title "Arch Linux Anywhere" --msgbox "Error no root filesystem installed at $ARCH \n *Continuing to menu." 10 60
		main_menu
	fi
}

add_user() {
	if [ "$user_added" == "true" ]; then
		whiptail --title "Arch Linux Anywhere" --msgbox "User already added \n *Continuing to menu." 10 60
		main_menu
	elif [ "$INSTALLED" == "true" ]; then
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
		if (whiptail --title "Arch Linux Anywhere" --yesno "Enable sudo privelege for $user? \n *Enables administrative privelege with sudo." 10 60) then
			sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
		fi
		user_added=true
		configure_network
	else
		whiptail --title "Arch Linux Anywhere" --msgbox "Error no root filesystem installed at $ARCH \n *Continuing to menu." 10 60
		main_menu
	fi
}

configure_network() {
	if [ "$INSTALLED" == "true" ]; then
		#Enable DHCP
			if (whiptail --title "Arch Linux Anywhere" --yesno "Enable DHCP at boot? \n *Automatic IP configuration." 10 60) then
				arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null
			fi
		#Wireless tools
			if (whiptail --title "Arch Linux Anywhere" --yesno "Install wireless tools and WPA supplicant? \n *Necessary if using wifi" 10 60) then
				pacstrap "$ARCH" wireless_tools wpa_supplicant &> /dev/null &
				pid=$! pri=0.5 msg="Installing wireless tools and WPA supplicant..." load
			fi
			graphics
	else
		whiptail --title "Arch Linux Anywhere" --msgbox "Error no root filesystem installed at $ARCH \n *Continuing to menu." 10 60
		main_menu
	fi
}

graphics() {
	if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install xorg-server now? \n *Select yes for a graphical interface" 10 60) then
		pacstrap "$ARCH" xorg-server xorg-server-utils xorg-xinit xterm &> /dev/null &
		pid=$! pri="$down" msg="Please wait while installing xorg-server..." load
		if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install graphics drivers now? \n *If no default drivers will be used." 10 60) then
			until [ "$GPU" == "set" ]
				do
					i=false
					GPU=$(whiptail --title "Arch Linux Anywhere" --menu "Select your desired drivers:" 15 60 5 \
					"xf86-video-ati"         "AMD/ATI Graphics" \
					"xf86-video-intel"       "Intel Graphics" \
					"Nvidia"  			     "NVIDIA Graphics" \
					"virtualbox-guest-utils" "VirtualBox Graphics" 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						if (whiptail --title "Arch Linux Anywhere" --yesno "Continue without installing graphics drivers? \n *Default drivers will be used." 10 60) then
							GPU=set
						fi
					else
						i=true
					fi
					if [ "$GPU" == "Nvidia" ]; then
						GPU=$(whiptail --title "Arch Linux Anywhere" --menu "Select your desired Nvidia driver: \n *Cancel if none" 15 60 4 \
						"nvidia"       "Latest stable nvidia" \
						"nvidia-340xx" "Legacy 340xx branch" \
						"nvidia-304xx" "Legaxy 304xx branch" 3>&1 1>&2 2>&3)
						if [ "$?" -gt "0" ]; then
							i=false
						fi
					fi
					if "$i" ; then
						pacstrap "$ARCH" ${GPU} &> /dev/null &
						pid=$! pri=1 msg="Please wait while installing graphics drivers..." load
						GPU=set
					fi
				done
		fi
		if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install a desktop or window manager?" 10 60) then
			until [ "$DE" == "set" ]
				do
					i=false
					DE=$(whiptail --title  "Arch Linux Installer" --menu "Select your desired enviornment:" 15 60 6 \
					"xfce4"    "Light DE" \
					"openbox"  "Stacking WM" \
					"awesome"  "Awesome WM" \
					"i3"       "Tiling WM" \
					"dwm"      "Dynamic WM" 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						DE=set
					else
						i=true
						if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install LightDM display manager?" 10 60) then
							pacstrap "$ARCH" lightdm lightdm-gtk-greeter &> /dev/null &
							pid=$! pri="$down" msg="Please wait while installing LightDM..." load
							arch-chroot "$ARCH" systemctl enable lightdm.service &> /dev/null
						fi
					fi
					case "$DE" in
						"xfce4") start_term="exec startxfce4" ;;
						"openbox") start_term="exec openbox-session" ;;
						"awesome") start_term="exec awesome" ;;
						"dwm") start_term="exec dwm" ;;
						"i3") start_term="exec i3" ;;
					esac
					if "$i" ; then
						pacstrap "$ARCH" ${DE} &> /dev/null &
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
		software=$(whiptail --title "Arch Linux Anywhere" --checklist "Choose your desired software: \n *Use spacebar to check/uncheck \n *press enter when finished" 20 60 10 \
					"cmus"        "CLI music player" OFF \
					"conky"       "Light system monitor for X " OFF \
					"htop"        "CLI process Info" OFF \
					"lynx"        "CLI web browser" OFF \
					"midori"	  "Light web browser" OFF \
					"netctl"      "Network controls" OFF \
					"openssh"     "Secure Shell Deamon" OFF \
					"pulseaudio"  "Popular sound server" ON \
					"screenfetch" "Display System Info" ON \
					"zsh"         "The Z Shell" OFF 3>&1 1>&2 2>&3)
		download=$(echo "$software" | sed 's/\"//g')
    	pacstrap "$ARCH" ${download} &> /dev/null &
    	pid=$! pri=1 msg="Please wait while installing software..." load
	fi
	reboot_system
}

reboot_system() {
	if [ "$INSTALLED" == "true" ]; then	
		if (whiptail --title "Arch Linux Anywhere" --yesno "Install process complete! Reboot now?" 10 60) then
			umount -R $ARCH
			reboot
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "System fully installed \n *Would you like to unmount?" 10 60) then
				clear
				umount -R "$ARCH"
				exit
			else
				clear
				exit
			fi
		fi
	else
		if (whiptail --title "Arch Linux Anywhere" --yesno "Install not complete, are you sure you want to reboot?" 10 60) then
			umount -R $ARCH
			reboot
		else
			main_menu
		fi
	fi
}

load() {
	{       int="1"
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
			if [ "$locale_set" == "true" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "Locale already set, returning to menu" 10 60
				main_menu
			fi	
			set_locale ;;
		"Set Timezone")
			if [ "$zone_set" == "true" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "Timezone already set, returning to menu" 10 60
				main_menu
			fi	
			 set_zone ;;
		"Set Keymap")
			if [ "$keys_set" == "true" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "Keymap already set, returning to menu" 10 60
				main_menu
			fi	
			set_keys ;;
		"Partition Drive")
			if [ "$mounted" == "true" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "Drive already mounted, try install base system \n returning to menu" 10 60
				main_menu
			fi	
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
				whiptail --title "Arch Linux Anywhere" --msgbox "System fully installed \n Exiting arch installer" 10 60
				exit
			else
				if (whiptail --title "Arch Linux Anywhere" --yesno "System not installed yet \n Are you sure you want to exit?" 10 60) then
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
