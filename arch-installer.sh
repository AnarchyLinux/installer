#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
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
################################################################

init() {

	trap '' 2
	source "$aa_conf"
	op_title=" -| Language Select |- "
	ILANG=$(dialog --nocancel --menu "\nArch Anywhere Installer\n\n \Z2*\Zn Select your install language:" 20 60 10 \
		"English" "-" \
		"Dutch" "Nederlands" \
		"French" "Français" \
		"German" "Deutsch" \
		"Greek" "Greek" \
		"Hungarian" "Magyar" \
		"Indonesian" "bahasa Indonesia" \
		"Italian" "Italiano" \
		"Latvian" "Latviešu" \
		"Polish" "Polski" \
		"Portuguese" "Português" \
		"Portuguese-Brazilian" "Português do Brasil" \
		"Romanian" "Română" \
		"Russian" "Russian" \
		"Spanish" "Español" \
		"Swedish" "Svenska" 3>&1 1>&2 2>&3)

	case "$ILANG" in
		"English") export lang_file="$aa_dir"/lang/arch-installer-english.conf ;;
		"Dutch") export lang_file="$aa_dir"/lang/arch-installer-dutch.conf lib=nl bro=nl kdel=nl ;;
		"French") export lang_file="$aa_dir"/lang/arch-installer-french.conf lib=fr bro=fr kdel=fr ;;
		"German") export lang_file="$aa_dir"/lang/arch-installer-german.conf lib=de bro=de kdel=de ;;
		"Greek") export lang_file="$aa_dir"/lang/arch-installer-greek.conf lib=el bro=el kdel=el ;;
		"Hungarian") export lang_file="$aa_dir"/lang/arch-installer-hungarian.conf lib=hu bro=hu kdel=hu ;;
		"Indonesian") export lang_file="$aa_dir"/lang/arch-installer-indonesia.conf lib=id bro=id kdel=id ;;
		"Italian") export lang_file="$aa_dir"/lang/arch-installer-italian.conf lib=it bro=it kdel=it ;;
		"Latvian") export lang_file="$aa_dir"/lang/arch-installer-latvian.conf lib=lv bro=lv kdel=lv ;;
		"Polish") export lang_file="$aa_dir"/lang/arch-installer-polish.conf lib=pl bro=pl kdel=pl ;;
		"Portuguese") export lang_file="$aa_dir"/lang/arch-installer-portuguese.conf lib=pt bro=pt-pt kdel=pt ;;
		"Portuguese-Brazilian") export lang_file="$aa_dir"/lang/arch-installer-portuguese-br.conf lib=pt-BR bro=pt-br kdel=pt_br ;;
		"Romanian") export lang_file="$aa_dir"/lang/arch-installer-romanian.conf lib=ro bro=ro kdel=ro ;;
		"Russian") export lang_file="$aa_dir"/lang/arch-installer-russian.conf lib=ru bro=ru kdel=ru ;;
		"Spanish") export lang_file="$aa_dir"/lang/arch-installer-spanish.conf lib=es bro=es-es kdel=es ;;
		"Swedish") export lang_file="$aa_dir"/lang/arch-installer-swedish.conf lib=sv bro=sv-se kdel=sv ;;
	esac

	source "$lang_file"
	export log=/tmp/arch-anywhere.log
	export reload=true
	echo "$(date -u "+%F %H:%M") : Language: $ILANG" > "$log"
	update_mirrors

}

update_mirrors() {

	op_title="$welcome_op_msg"
	if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$intro_msg" 10 60) then
		reset ; exit
	fi

	if ! (</etc/pacman.d/mirrorlist grep "rankmirrors" &>/dev/null) then
		op_title="$mirror_op_msg"
		code=$(dialog --nocancel --ok-button "$ok" --menu "$mirror_msg1" 17 60 10 \
			"$default" "->" \
			$countries 3>&1 1>&2 2>&3)

		if [ "$code" == "$default" ]; then
			(wget -4 --no-check-certificate --append-output=/dev/null "https://git.archlinux.org/svntogit/packages.git/plain/trunk/mirrorlist?h=packages/pacman-mirrorlist" -O /tmp/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var 
			head -n10 /tmp/mirrorlist.bak | sed 's/#//' > /etc/pacman.d/mirrorlist.bak 
			sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/all\Zn" load
		elif [ "$code" == "AL" ]; then
			(wget -4 --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/all/" -O /etc/pacman.d/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/all\Zn" load
		elif [ "$code" == "AS" ]; then
			(wget -4 --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/all/https/" -O /etc/pacman.d/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/all/https\Zn" load
		else
			(wget -4 --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak
			echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
			pid=$! pri=0.1 msg="\n$mirror_load0 \n\n \Z1> \Z2wget -O /etc/pacman.d/mirrorlist archlinux.org/mirrorlist/?country=$code\Zn" load
		fi

		echo "$(date -u "+%F %H:%M") : Updated Mirrors From: $code" >> "$log"
		
		while [ "$(</tmp/ex_status.var)" -gt "0" ]
		  do
			if [ -n "$wifi_network" ]; then
				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$wifi_msg0" 10 60) then
					wifi-menu
					if [ "$?" -gt "0" ]; then
						dialog --ok-button "$ok" --msgbox "\n$wifi_msg1" 10 60
						echo "$(date -u "+%F %H:%M") : Failed to connect to wifi: Exit 1" >> "$log"
						setterm -background black -store ; reset ; echo "$connect_err1" | sed 's/\\Z1//;s/\\Zn//' ; exit 1
					else
						echo "0" > /tmp/ex_status.var
						echo "$(date -u "+%F %H:%M") : Connected to: $wifi_network" >> "$log"
					fi
				else
					unset wifi_network
				fi
			else
				dialog --ok-button "$ok" --msgbox "\n$connect_err0" 10 60
				echo "$(date -u "+%F %H:%M") : Failed to connect to wifi: Exit 1" >> "$log"
				setterm -background black -store ; reset ; echo -e "$connect_err1" | sed 's/\\Z1//;s/\\Zn//' ;  exit 1
			fi
		done

		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist &
	 	pid=$! pri=0.8 msg="\n$mirror_load1 \n\n \Z1> \Z2rankmirrors -n 6 /etc/pacman.d/mirrorlist\Zn" load

	 	echo "$(date -u "+%F %H:%M") : Ranked mirrorlist: /etc/pacman.d/mirrorlist" >> "$log"
	fi

	check_connection

}

check_connection() {
	
	op_title="$connection_op_msg"
	(test_mirror=$(</etc/pacman.d/mirrorlist grep "^Server" | awk 'NR==1{print $3}' | sed 's/$.*//')
	test_pkg=bluez-utils
	test_pkg_ver=$(curl -s https://www.archlinux.org/packages/extra/i686/$test_pkg/ | grep "<title>" | awk '{print $5}')
	test_link="${test_mirror}extra/os/i686/${test_pkg}-${test_pkg_ver}-i686.pkg.tar.xz"
	wget -4 --no-check-certificate --append-output=/tmp/wget.log -O /dev/null "${test_link}") &
	pid=$! pri=0.3 msg="\n$connection_load \n\n \Z1> \Z2wget -O /dev/null test_link/test1Mb.db\Zn" load
	
	sed -i 's/\,/\./' /tmp/wget.log
	connection_speed=$(tail /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $1}')
	connection_rate=$(tail /tmp/wget.log | grep -oP '(?<=\().*(?=\))' | awk '{print $2}')
	
	if (lscpu | grep "max MHz" &>/dev/null); then
		cpu_mhz=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | sed 's/\..*//')
	else
		cpu_mhz=$(lscpu | grep "CPU MHz" | awk '{print $3}' | sed 's/\..*//')
	fi

	case "$cpu_mhz" in
		[0-9][0-9][0-9]) 
			cpu_sleep=4.5
		;;
		[1][0-9][0-9][0-9])
			cpu_sleep=4
		;;
		[2][0-9][0-9][0-9])
			cpu_sleep=3.5
		;;
		*)
			cpu_sleep=2.5
		;;
	esac
        		
	export connection_speed connection_rate cpu_sleep
	echo "$(date -u "+%F %H:%M") : Ranked connection speed: $connection_speed $connection_rate" >> "$log"
	echo "$(date -u "+%F %H:%M") : Clocked CPU MHz: $cpu_mhz" >> "$log"
	rm /tmp/{ex_status.var,wget.log} &> /dev/null
	set_keys

}

set_keys() {
	
	op_title="$key_op_msg"
	keyboard=$(dialog --nocancel --ok-button "$ok" --menu "$keys_msg" 18 60 10 \
	"$default" "$default Keymap" \
	"us" "United States" \
	"de" "German" \
	"el" "Greek" \
	"hu" "Hungarian" \
	"es" "Spanish" \
	"fr" "French" \
	"it" "Italian" \
	"pt-latin9" "Portugal" \
	"ro" "Romanian" \
	"ru" "Russian" \
	"sv" "Swedish" \
	"uk" "United Kingdom" \
	"$other"       "$other-keymaps"		 3>&1 1>&2 2>&3)
	source "$lang_file"

	if [ "$keyboard" = "$other" ]; then
		keyboard=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$keys_msg" 19 60 10  $key_maps 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			set_keys
		fi
	fi
	
	export keyboard
	localectl set-keymap "$keyboard"
	echo "$(date -u "+%F %H:%M") : Set keymap to: $keyboard" >> "$log"
	set_locale

}

set_locale() {

	op_title="$locale_op_msg"
	LOCALE=$(dialog --nocancel --ok-button "$ok" --menu "$locale_msg" 18 60 11 \
	"en_US.UTF-8" "United States" \
	"en_AU.UTF-8" "Australia" \
	"pt_BR.UTF-8" "Brazil" \
	"en_CA.UTF-8" "Canada" \
	"es_ES.UTF-8" "Spanish" \
	"fr_FR.UTF-8" "French" \
	"de_DE.UTF-8" "German" \
	"el_GR.UTF-8" "Greek" \
	"en_GB.UTF-8" "Great Britain" \
	"hu_HU.UTF-8" "Hungary" \
	"it_IT.UTF-8" "Italian" \
	"lv_LV.UTF-8" "Latvian" \
	"en_MX.UTF-8" "Mexico" \
	"pt_PT.UTF-8" "Portugal" \
	"ro_RO.UTF-8" "Romanian" \
	"ru_RU.UTF-8" "Russian" \
	"es_ES.UTF-8" "Spanish" \
	"sv_SE.UTF-8" "Swedish" \
	"$other"       "$other-locale"		 3>&1 1>&2 2>&3)

	if [ "$LOCALE" = "$other" ]; then
		LOCALE=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$locale_msg" 18 60 11 $localelist 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then 
			set_locale
		fi
	fi

	echo "$(date -u "+%F %H:%M") : Set locale to: $LOCALE" >> "$log"
	set_zone

}


set_zone() {

	op_title="$zone_op_msg"
	ZONE=$(dialog --nocancel --ok-button "$ok" --menu "$zone_msg0" 18 60 11 $zonelist 3>&1 1>&2 2>&3)
	if (find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE" &> /dev/null); then
		sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g' | grep -v "$ZONE")
		SUBZONE=$(dialog --ok-button "$ok" --cancel-button "$back" --menu "$zone_msg1" 18 60 11 $sublist 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then 
			set_zone 
		fi
		if (find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE" &> /dev/null); then
			sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g' | grep -v "$SUBZONE")
			SUB_SUBZONE=$(dialog --ok-button "$ok" --cancel-button "$back" --menu "$zone_msg1" 15 60 7 $sublist 3>&1 1>&2 2>&3)
			if [ "$?" -gt "0" ]; then
				set_zone 
			fi
			ZONE="${ZONE}/${SUBZONE}/${SUB_SUBZONE}"
		else
			ZONE="${ZONE}/${SUBZONE}"
		fi
	fi

	echo "$(date -u "+%F %H:%M") : Set timezone to: $ZONE" >> "$log"
	prepare_drives

}

prepare_drives() {

	op_title="$part_op_msg"
	tmp_menu=/tmp/part.sh

	if (df | grep "$ARCH" &> /dev/null); then
		umount -R "$ARCH" &> /dev/null &
		pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2umount -R $ARCH\Zn" load
		swapoff -a &> /dev/null &
	fi
	
	PART=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$part_msg" 16 64 4 \
	"$method0" "-" \
	"$method1" "-" \
	"$method2"  "-" \
	"$menu_msg" "-" 3>&1 1>&2 2>&3)

	if [ "$?" -gt "0" ] || [ "$PART" == "$menu_msg" ]; then
		main_menu
	elif [ "$PART" != "$method2" ]; then
		dev_menu="           Device: | Size: | Type:  |"
		if "$screen_h" ; then
			cat <<-EOF > "$tmp_menu"
					dialog --colors --backtitle "$backtitle" --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$drive_msg \n\n $dev_menu" 16 60 5 \\
				EOF
		else
			cat <<-EOF > "$tmp_menu"
					dialog --colors --title "$title" --ok-button "$ok" --cancel-button "$cancel" --menu "$drive_msg \n\n $dev_menu" 16 60 5 \\
				EOF
		fi

		cat <<-EOF >> "$tmp_menu"
			$(lsblk -nio NAME,SIZE,TYPE | egrep "disk|raid[0-9]+$" | sed 's/[^[:alnum:]_., ]//g' | sort -k 1,1 | uniq | awk '{print "\""$1"\"""  ""\"| "$2" | "$3" |==>\""" \\"}' | column -t)
			3>&1 1>&2 2>&3
		EOF

		DRIVE=$(bash "$tmp_menu")
		rm "$tmp_menu"
		
		if [ -z "$DRIVE" ]; then
			prepare_drives
		fi

		if (<<<"$DRIVE" egrep "nvme.*|mmc.*|md.*" &> /dev/null) then
			PART_PREFIX="p"
		fi

		drive_byte=$(lsblk -nibo NAME,SIZE | grep -w "$DRIVE" | awk '{print $2}')
		drive_mib=$((drive_byte/1024/1024))
		drive_gigs=$((drive_mib/1024))
		f2fs=$(cat /sys/block/"$DRIVE"/queue/rotational)
		echo "$(date -u "+%F %H:%M") : Drive size in MB: $drive_mib" >> "$log"
		echo "$(date -u "+%F %H:%M") : F2FS state: $f2fs" >> "$log"
		fs_select

		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$swap_msg0" 10 60) then
			while (true)
			  do
				SWAPSPACE=$(dialog --ok-button "$ok" --cancel-button "$cancel" --inputbox "\n$swap_msg1" 11 55 "512M" 3>&1 1>&2 2>&3)
					
				if [ "$?" -gt "0" ]; then
					SWAP=false ; break
				else
					if [ "$(grep -o ".$" <<< "$SWAPSPACE")" == "M" ]; then 
						SWAPSPACE=$(<<<$SWAPSPACE sed 's/M//;s/\..*//')
						if [ "$SWAPSPACE" -lt "$(echo "$drive_mib-5120" | bc)" ]; then 
							SWAP=true ; break
						else 
							dialog --ok-button "$ok" --msgbox "\n$swap_err_msg0" 10 60
						fi
					elif [ "$(grep -o ".$" <<< "$SWAPSPACE")" == "G" ]; then
						SWAPSPACE=$(echo "$(<<<$SWAPSPACE sed 's/G//')*1024" | bc | sed 's/\..*//')
						if [ "$SWAPSPACE" -lt "$(echo "$drive_mib-5120" | bc)" ]; then
							SWAP=true ; break
						else 
							dialog --ok-button "$ok" --msgbox "\n$swap_err_msg0" 10 60
						fi
					else
						dialog --ok-button "$ok" --msgbox "\n$swap_err_msg1" 10 60
					fi
				fi
			done

			echo "$(date -u "+%F %H:%M") : Swapspace size set to: $SWAPSPACE" >> "$log"
		fi
			
		if (efivar -l &> /dev/null); then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$efi_msg0" 10 60) then
				GPT=true
				UEFI=true
				echo "$(date -u "+%F %H:%M") : UEFI boot activated" >> "$log"
			fi
		fi

		if ! "$UEFI" ; then 
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$gpt_msg" 10 60) then 
				GPT=true
				echo "$(date -u "+%F %H:%M") : GPT partition scheme activated" >> "$log"
			fi
		fi

		source "$lang_file"

		if "$SWAP" ; then
			drive_var="$drive_var1"
			height=13
			if "$UEFI" ; then
				drive_var="$drive_var2"
				height=14
			fi
		elif "$UEFI" ; then
			drive_var="$drive_var3"
			height=13
		else
			height=11
		fi
	
		if (dialog --defaultno --yes-button "$write" --no-button "$cancel" --yesno "\n$drive_var" "$height" 60) then
			(sgdisk --zap-all /dev/"$DRIVE"
			wipefs -a /dev/"$DRIVE") &> /dev/null &
			pid=$! pri=0.1 msg="\n$frmt_load \n\n \Z1> \Z2sgdisk --zap-all /dev/$DRIVE\Zn" load
			echo "$(date -u "+%F %H:%M") : Format device: /dev/$DRIVE" >> "$log"
		else
			prepare_drives
		fi
	fi
	
	case "$PART" in
		"$method0")	echo "$(date -u "+%F %H:%M") : Begin auto_part function" >> "$log"
				auto_part
		;;
		"$method1")	echo "$(date -u "+%F %H:%M") : Begin auto_encrypt function" >> "$log"
				auto_encrypt
		;;
		"$method2")	points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
				echo "$(date -u "+%F %H:%M") : Begin part_menu function" >> "$log"
				part_menu
		;;
	esac

	if ! "$mounted" ; then
		dialog --ok-button "$ok" --msgbox "\n$part_err_msg" 10 60
		echo "$(date -u "+%F %H:%M") : Failed to mount root filesystem for unknown reason" >> "$log"
		prepare_drives
	else
		prepare_base
	fi

}

auto_part() {
	
	op_title="$partload_op_msg"
	if "$GPT" ; then
		if "$UEFI" ; then
			if "$SWAP" ; then
				echo -e "n\n\n\n512M\nef00\nn\n3\n\n+${SWAPSPACE}M\n8200\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2gdisk /dev/$DRIVE\Zn" load
				SWAP="${DRIVE}${PART_PREFIX}3"
				(wipefs -a /dev/"$SWAP"
				mkswap /dev/"$SWAP"
				swapon /dev/"$SWAP") &> /dev/null &
				pid=$! pri=0.1 msg="\n$swap_load \n\n \Z1> \Z2mkswap /dev/$SWAP\Zn" load
				echo "$(date -u "+%F %H:%M") : Created and activate swapspace: $SWAP" >> "$log"
			else
				echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2gdisk /dev/$DRIVE\Zn" load
			fi
			BOOT="${DRIVE}${PART_PREFIX}1"
			ROOT="${DRIVE}${PART_PREFIX}2"
		else
			if "$SWAP" ; then
				echo -e "o\ny\nn\n1\n\n+212M\n\nn\n2\n\n+1M\nEF02\nn\n4\n\n+${SWAPSPACE}M\n8200\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2gdisk /dev/$DRIVE\Zn" load
				SWAP="${DRIVE}${PART_PREFIX}4"
				(wipefs -a /dev/"$SWAP"
				mkswap /dev/"$SWAP"
				swapon /dev/"$SWAP") &> /dev/null &
				pid=$! pri=0.1 msg="\n$swap_load \n\n \Z1> \Z2mkswap /dev/$SWAP\Zn" load
				echo "$(date -u "+%F %H:%M") : Created and activate swapspace: $SWAP" >> "$log"
			else
				echo -e "o\ny\nn\n1\n\n+212M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2gdisk /dev/$DRIVE\Zn" load
			fi
			BOOT="${DRIVE}${PART_PREFIX}1"
			ROOT="${DRIVE}${PART_PREFIX}3"
		fi
	else
		if "$SWAP" ; then
			echo -e "o\nn\np\n1\n\n+212M\nn\np\n3\n\n+${SWAPSPACE}M\nt\n\n82\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2fdisk /dev/$DRIVE\Zn" load
			SWAP="${DRIVE}${PART_PREFIX}3"
			(wipefs -a /dev/"$SWAP"
			mkswap /dev/"$SWAP"
			swapon /dev/"$SWAP") &> /dev/null &
			pid=$! pri=0.1 msg="\n$swap_load \n\n \Z1> \Z2mkswap /dev/$SWAP\Zn" load
			echo "$(date -u "+%F %H:%M") : Created and activate swapspace: $SWAP" >> "$log"

		else
			echo -e "o\nn\np\n1\n\n+212M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2fdisk /dev/$DRIVE\Zn" load
		fi				
		BOOT="${DRIVE}${PART_PREFIX}1"
		ROOT="${DRIVE}${PART_PREFIX}2"
	fi
	
	echo "$(date -u "+%F %H:%M") : Create boot partition: $BOOT" >> "$log"
	echo "$(date -u "+%F %H:%M") : Create root partition: $ROOT" >> "$log"
	
	if "$UEFI" ; then
		(sgdisk --zap-all /dev/"$BOOT"
		wipefs -a /dev/"$BOOT"
		mkfs.vfat -F32 /dev/"$BOOT") &> /dev/null &
		pid=$! pri=0.1 msg="\n$efi_load1 \n\n \Z1> \Z2mkfs.vfat -F32 /dev/$BOOT\Zn" load
		esp_part="$BOOT"
		esp_mnt=/boot
		echo "$(date -u "+%F %H:%M") : ESP part set to: $esp_part" >> "$log"
		echo "$(date -u "+%F %H:%M") : ESP mnt set to: $esp_mnt" >> "$log"
		echo "$(date -u "+%F %H:%M") : Created boot filesystem: vfat" >> "$log"
	else
		(sgdisk --zap-all /dev/"$BOOT"
		wipefs -a /dev/"$BOOT"
		mkfs.ext4 -O \^64bit /dev/"$BOOT") &> /dev/null &
		pid=$! pri=0.1 msg="\n$boot_load \n\n \Z1> \Z2mkfs.ext4 /dev/$BOOT\Zn" load
		echo "$(date -u "+%F %H:%M") : Boot set to: /boot" >> "$log"
		echo "$(date -u "+%F %H:%M") : Created boot filesystem: ext4" >> "$log"
	fi
		
	case "$FS" in
		jfs|reiserfs)	(echo -e "y" | mkfs."$FS" /dev/"$ROOT"
						sgdisk --zap-all /dev/"$ROOT"
						wipefs -a /dev/"$ROOT") &> /dev/null &
		;;
		*)	(sgdisk --zap-all /dev/"$ROOT"
			wipefs -a /dev/"$ROOT"
			mkfs."$FS" /dev/"$ROOT") &> /dev/null &
		;;
	esac
	pid=$! pri=0.6 msg="\n$load_var1 \n\n \Z1> \Z2mkfs.$FS /dev/$ROOT\Zn" load
	echo "$(date -u "+%F %H:%M") : Create root filesystem: $FS" >> "$log"

	(mount /dev/"$ROOT" "$ARCH"
	echo "$?" > /tmp/ex_status.var
	mkdir $ARCH/boot
	mount /dev/"$BOOT" "$ARCH"/boot) &> /dev/null &
	pid=$! pri=0.1 msg="\n$mnt_load \n\n \Z1> \Z2mount /dev/$ROOT $ARCH\Zn" load
	echo "$(date -u "+%F %H:%M") : Root filesystem mounted: $ARCH" >> "$log"
	echo "$(date -u "+%F %H:%M") : Boot filesystem mounted: $ARCH/boot" >> "$log"

	if [ "$(</tmp/ex_status.var)" -eq "0" ]; then
		mounted=true
	fi

	rm /tmp/ex_status.var

}

auto_encrypt() {
	
	op_title="$partload_op_msg"
	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$encrypt_var0" 10 60) then
		while [ "$input" != "$input_chk" ]
		  do
			input=$(dialog --nocancel --clear --insecure --passwordbox "$encrypt_var1" 12 55 --stdout)
			input_chk=$(dialog --nocancel --clear --insecure --passwordbox "$encrypt_var2" 12 55 --stdout)
			
			if [ -z "$input" ]; then
				dialog --ok-button "$ok" --msgbox "\n$passwd_msg0" 10 60
		 		input_chk=default
			elif [ "$input" != "$input_chk" ]; then
		  		dialog --ok-button "$ok" --msgbox "\n$passwd_msg1" 10 60
		 	fi
		 done
	else
		prepare_drives
	fi

	if "$GPT" ; then
		if "$UEFI" ; then
			echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2gdisk /dev/$DRIVE\Zn" load
			BOOT="${DRIVE}${PART_PREFIX}1"
			ROOT="${DRIVE}${PART_PREFIX}2"
		else
			echo -e "o\ny\nn\n1\n\n+512M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
			pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2gdisk /dev/$DRIVE\Zn" load
			BOOT="${DRIVE}${PART_PREFIX}1"
			ROOT="${DRIVE}${PART_PREFIX}3"
		fi
	else
		echo -e "o\nn\np\n1\n\n+512M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
		pid=$! pri=0.1 msg="\n$load_var0 \n\n \Z1> \Z2fdisk /dev/$DRIVE\Zn" load
		BOOT="${DRIVE}${PART_PREFIX}1"
		ROOT="${DRIVE}${PART_PREFIX}2"
	fi

	echo "$(date -u "+%F %H:%M") : Create boot partition: $BOOT" >> "$log"
	echo "$(date -u "+%F %H:%M") : Create root partition: $ROOT" >> "$log"
	(sgdisk --zap-all /dev/"$ROOT"
	sgdisk --zap-all /dev/"$BOOT"
	wipefs -a /dev/"$ROOT"
	wipefs -a /dev/"$BOOT") &> /dev/null &
	pid=$! pri=0.1 msg="\n$frmt_load \n\n \Z1> \Z2wipefs -a /dev/$ROOT\Zn" load
	echo "$(date -u "+%F %H:%M") : Wipe boot partition" >> "$log"
	echo "$(date -u "+%F %H:%M") : Wipe root partition" >> "$log"

	(lvm pvcreate /dev/"$ROOT"
	lvm vgcreate lvm /dev/"$ROOT") &> /dev/null &
	pid=$! pri=0.1 msg="\n$pv_load \n\n \Z1> \Z2lvm pvcreate /dev/$ROOT\Zn" load
	echo "$(date -u "+%F %H:%M") : Create physical root volume: /dev/$ROOT" >> "$log"

	if "$SWAP" ; then
		lvm lvcreate -L "${SWAPSPACE}M" -n swap lvm &> /dev/null &
		pid=$! pri=0.1 msg="\n$swap_load \n\n \Z1> \Z2lvm lvcreate -L ${SWAPSPACE}M -n swap lvm\Zn" load
		echo "$(date -u "+%F %H:%M") : Create logical swapspace" >> "$log"
	fi

	(lvm lvcreate -L 500M -n tmp lvm
	lvm lvcreate -l 100%FREE -n lvroot lvm) &> /dev/null &
	pid=$! pri=0.1 msg="\n$lv_load \n\n \Z1> \Z2lvm lvcreate -l 100%FREE -n lvroot lvm\Zn" load
	echo "$(date -u "+%F %H:%M") : Create logical root volume: lvroot" >> "$log"
	echo "$(date -u "+%F %H:%M") : Create logical tmp filesystem: tmp" >> "$log"

	(printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot -
	printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -) &> /dev/null &
	pid=$! pri=0.2 msg="\n$encrypt_load \n\n \Z1> \Z2cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot\Zn" load
	echo "$(date -u "+%F %H:%M") : Encrypt logical volume: lvroot" >> "$log"
	unset input input_chk ; input_chk=default
	wipefs -a /dev/mapper/root &> /dev/null
	
	case "$FS" in
		jfs|reiserfs)
			echo -e "y" | mkfs."$FS" /dev/mapper/root &> /dev/null &
		;;
		*)
			mkfs."$FS" /dev/mapper/root &> /dev/null &
		;;
	esac
	pid=$! pri=1 msg="\n$load_var1 \n\n \Z1> \Z2mkfs.$FS /dev/mapper/root\Zn" load
	echo "$(date -u "+%F %H:%M") : Create root filesystem: $FS" >> "$log"
	
	if "$UEFI" ; then
		mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
		pid=$! pri=0.2 msg="\n$efi_load1 \n\n \Z1> \Z2mkfs.vfat -F32 /dev/$BOOT\Zn" load
		esp_part="/dev/$BOOT"
		esp_mnt=/boot
		echo "$(date -u "+%F %H:%M") : Create boot filesystem: vfat" >> "$log"
	else
		mkfs.ext4 -O \^64bit /dev/"$BOOT" &> /dev/null &
		pid=$! pri=0.2 msg="\n$boot_load \n\n \Z1> \Z2mkfs.ext4 /dev/$BOOT\Zn" load
		echo "$(date -u "+%F %H:%M") : Create boot filesystem: ext4" >> "$log"
	fi

	(mount /dev/mapper/root "$ARCH"
	echo "$?" > /tmp/ex_status.var
	mkdir $ARCH/boot
	mount /dev/"$BOOT" "$ARCH"/boot) &> /dev/null &
	pid=$! pri=0.1 msg="\n$mnt_load \n\n \Z1> \Z2mount /dev/mapper/root $ARCH\Zn" load
	echo "$(date -u "+%F %H:%M") : Mount root filesystem: $ARCH" >> "$log"
	echo "$(date -u "+%F %H:%M") : Mount boot filesystem: $ARCH/boot" >> "$log"

	if [ $(</tmp/ex_status.var) -eq "0" ]; then
		mounted=true
		crypted=true
	fi

	rm /tmp/ex_status.var

}

part_menu() {

	op_title="$manual_op_msg"
	unset part
	tmp_menu=/tmp/part.sh tmp_list=/tmp/part.list
	dev_menu="|  Device:  |  Size:  |  Used:  |  FS:  |  Mount:  |  Type:  |"
	device_list=$(lsblk -nio NAME,SIZE,TYPE,FSTYPE | egrep -v "$USB|loop[0-9]+|sr[0-9]+|fd[0-9]+" | sed 's/[^[:alnum:]_., ]//g' | column -t | sort -k 1,1 | uniq)
	device_count=$(<<<"$device_list" wc -l)

	if "$screen_h" ; then
		echo "dialog --extra-button --extra-label \"$write\" --colors --backtitle \"$backtitle\" --title \"$op_title\" --ok-button \"$edit\" --cancel-button \"$cancel\" --menu \"$manual_part_msg \n\n $dev_menu\" 21 68 9 \\" > "$tmp_menu"
	else
		echo "dialog --extra-button --extra-label \"$write\" --colors --title \"$title\" --ok-button \"$edit\" --cancel-button \"$cancel\" --menu \"$manual_part_msg \n\n $dev_menu\" 20 68 8 \\" > "$tmp_menu"
	fi

	int=1
	empty_value="----"
	until [ "$int" -gt "$device_count" ]
	do
		device=$(<<<"$device_list" awk '{print $1}' | awk "NR==$int")
		dev_size=$(<<<"$device_list" grep -w "$device" | awk '{print $2}')
		dev_type=$(<<<"$device_list" grep -w "$device" | awk '{print $3}')
		dev_fs=$(<<<"$device_list" grep -w "$device" | awk '{print $4}')
		dev_mnt=$(df | grep -w "$device" | awk '{print $6}' | sed 's/mnt\/\?//')

		if (<<<"$dev_mnt" grep "/" &> /dev/null) then
			dev_used=$(df -T | grep -w "$device" | awk '{print $6}')
		else
			dev_used=$(swapon -s | grep -w "$device" | awk '{print $4}')
			if [ -n "$dev_used" ]; then
				dev_used=$dev_used%
			fi
		fi

		test -z "$dev_fs" && dev_fs=$empty_value
		test -z "$dev_used" && dev_used=$empty_value
		test -z "$dev_mnt" && dev_mnt=$empty_value

		if [ "$dev_fs" != "$empty_value" ] && (<<<"$device" egrep -v "md[0-9]+$" &> /dev/null); then
			if (fdisk -l | grep "gpt" &>/dev/null) then
				part_type_uuid=$(fdisk -l -o Device,Type-UUID | grep -w "$device" | awk '{print $2}')

				if [ $part_type_uuid == "0FC63DAF-8483-4772-8E79-3D69D8477DE4" ] ||
				   [ $part_type_uuid == "44479540-F297-41B2-9AF7-D131D5F0458A" ] ||
				   [ $part_type_uuid == "4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709" ]; then
					dev_type="Linux"
				elif [ $part_type_uuid == "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" ]; then
					dev_type="Linux/SWAP"
				elif [ $part_type_uuid == "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" ]; then
					dev_type="EFI/ESP"
				else
					dev_type=$part_type_uuid
				fi
			else
				part_type_id=$(fdisk -l -o Device,Id | grep -w "$device" | awk '{print $2}')

				if [ $part_type_id == "83" ]; then
					dev_type="Linux"
				elif [ $part_type_id == "82" ]; then
					dev_type="Linux/SWAP"
				else
					dev_type=$part_type_id
				fi
			fi
		fi

		echo "\"$device\" \"$dev_size $dev_used $dev_fs $dev_mnt $dev_type\" \\" >> "$tmp_list"

		int=$((int+1))
	done

	<"$tmp_list" column -t >> "$tmp_menu"
	echo "\"$done_msg\" \"$write\" 3>&1 1>&2 2>&3" >> "$tmp_menu"
	echo "if [ \"\$?\" -eq \"3\" ]; then clear ; echo \"$done_msg\" ; fi" >> "$tmp_menu"
	part=$(bash "$tmp_menu" | sed 's/^\s\+//g;s/\s\+$//g')
	if (<<<"$part" grep "$done_msg" &> /dev/null) then part="$done_msg" ; fi
	rm $tmp_menu $tmp_list
	part_class

}
	
part_class() {

	op_title="$edit_op_msg"
	if [ -z "$part" ]; then
		unset DRIVE ROOT
		prepare_drives
	else
        part_size=$(<<<"$device_list" grep -w "$part" | awk '{print $2}')
		part_type=$(<<<"$device_list" grep -w "$part" | awk '{print $3}')
		part_fs=$(<<<"$device_list" grep -w "$part" | awk '{print $4}')
		part_mount=$(df | grep -w "$part" | awk '{print $6}' | sed 's/mnt\/\?//')
	fi

	if [ "$part_fs" == "linux_raid_member" ]; then # do nothing
		part_menu
	elif ([ "$part_type" == "disk" ]) || ( (<<<"$part_type" egrep "raid[0-9]+" &> /dev/null) && [ -z "$part_fs" ] ); then # Partition

        source "$lang_file"

		if (df | grep -w "$part" | grep "$ARCH" &> /dev/null); then
			if (dialog --yes-button "$edit" --no-button "$cancel" --defaultno --yesno "\n$mount_warn_var" 10 60) then
				points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
				(umount -R "$ARCH"
				swapoff -a) &> /dev/null &
				pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2umount -R /mnt\Zn" load
				mounted=false
				unset DRIVE
				cfdisk /dev/"$part"
				sleep 0.5
				clear
			fi
		elif (dialog --yes-button "$edit" --no-button "$cancel" --yesno "\n$manual_part_var3" 12 60) then
			cfdisk /dev/"$part"
			sleep 0.5
			clear
		fi

		part_menu

    elif [ "$part" == "$done_msg" ]; then # Done

        if ! "$mounted" ; then
			dialog --ok-button "$ok" --msgbox "\n$root_err_msg1" 10 60
			part_menu
		else
			if [ -z "$BOOT" ]; then
				BOOT="$ROOT"
			fi

			final_part=$((df -h | grep "$ARCH" | awk '{print $1,$2,$6 "\\n"}' | sed 's/mnt\/\?//' ; swapon | awk 'NR==2 {print $1,$3,"SWAP"}') | column -t)
			final_count=$(<<<"$final_part" wc -l)

			if [ "$final_count" -lt "7" ]; then
				height=17
			elif [ "$final_count" -lt "13" ]; then
				height=23
			elif [ "$final_count" -lt "17" ]; then
				height=26
			else
				height=30
			fi

			part_menu="$partition: $size: $mountpoint:"

			if (dialog --yes-button "$write" --no-button "$cancel" --defaultno --yesno "\n$write_confirm_msg \n\n $part_menu \n\n$final_part \n\n $write_confirm" "$height" 50) then
				if (efivar -l &>/dev/null); then
					if (fdisk -l | grep "EFI" &>/dev/null); then
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$efi_man_msg" 11 60) then
							if [ "$(fdisk -l | grep "EFI" | wc -l)" -gt "1" ]; then
								efint=1
								while (true)
								  do
									if [ "$(fdisk -l | grep "EFI" | awk "NR==$efint {print \$1}")" == "" ]; then
										dialog --ok-button "$ok" --msgbox "$efi_err_msg1" 10 60
										part_menu
									fi
									esp_part=$(fdisk -l | grep "EFI" | awk "NR==$efint {print \$1}")
									esp_mnt=$(df -T | grep "$esp_part" | awk '{print $7}' | sed 's|/mnt||')
									if (df -T | grep "$esp_part" &> /dev/null); then
										break
									else
										efint=$((efint+1))
									fi
								done
							else
								esp_part=$(fdisk -l | grep "EFI" | awk '{print $1}')
								if ! (df -T | grep "$esp_part" &> /dev/null); then
									source "$lang_file"
									if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$efi_mnt_var" 11 60) then
										if ! (mountpoint "$ARCH"/boot &> /dev/null); then
											mkdir "$ARCH"/boot &> /dev/null
											mount "$esp_part" "$ARCH"/boot
										else
											dialog --ok-button "$ok" --msgbox "\n$efi_err_msg" 10 60
											part_menu
										fi
									else
										part_menu
									fi
								else
									esp_mnt=$(df -T | grep "$esp_part" | awk '{print $7}' | sed 's|/mnt||')
								fi
							fi
							source "$lang_file"
							if ! (df -T | grep "$esp_part" | grep "vfat" &>/dev/null) then
								if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$vfat_var" 11 60) then
										(umount -R "$esp_mnt"
										mkfs.vfat -F32 "$esp_part"
										mount "$esp_part" "$esp_mnt") &> /dev/null &
										pid=$! pri=0.2 msg="\n$efi_load1 \n\n \Z1> \Z2mkfs.vfat -F32 $esp_part\Zn" load
										UEFI=true
								else
									part_menu
								fi
							else
								UEFI=true
								export esp_part esp_mnt
							fi
						fi
					fi
				fi

				if "$enable_f2fs" ; then
					if ! (df | grep "$ARCH/boot\|$ARCH/boot/efi" &> /dev/null) then
						FS="f2fs" source "$lang_file"
						dialog --ok-button "$ok" --msgbox "\n$fs_err_var" 10 60
						part_menu
					fi
				elif "$enable_btrfs" ; then
					if ! (df | grep "$ARCH/boot\|$ARCH/boot/efi" &> /dev/null) then
						FS="btrfs" source "$lang_file"
						dialog --ok-button "$ok" --msgbox "\n$fs_err_var" 10 60
						part_menu
					fi
				fi

				sleep 1
				pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2Finalize...\Zn" load
				prepare_base
			else
				part_menu
			fi
		fi

	else # Install on a partition or md device with a file system

		source "$lang_file"  &> /dev/null

		if [ -z "$ROOT" ]; then
			case "$part_size" in
				[4-9]G|[1-9][0-9]*G|[4-9].*G|[4-9],*G|T)
					if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$root_var" 13 60) then
						if (<<<"$part" egrep "md[0-9]+$" &> /dev/null); then
							f2fs=$(cat /sys/block/$part/queue/rotational)
						else
							f2fs=$(cat /sys/block/$(echo $part | sed 's/[0-9]\+$//;/[0-9]/s/p$//')/queue/rotational)
						fi
						fs_select

						if [ "$?" -gt "0" ]; then
							part_menu
						fi

						source "$lang_file"

						if (dialog --yes-button "$write" --no-button "$cancel" --defaultno --yesno "\n$root_confirm_var" 14 50) then
							(sgdisk --zap-all /dev/"$part"
							wipefs -a /dev/"$part") &> /dev/null &
							pid=$! pri=0.1 msg="\n$frmt_load \n\n \Z1> \Z2wipefs -a /dev/$part\Zn" load

							case "$FS" in
								jfs|reiserfs)
									echo -e "y" | mkfs."$FS" /dev/"$part" &> /dev/null &
								;;
								*)
									mkfs."$FS" /dev/"$part" &> /dev/null &
								;;
							esac
							pid=$! pri=1 msg="\n$load_var1 \n\n \Z1> \Z2mkfs.$FS /dev/$part\Zn" load

							(mount /dev/"$part" "$ARCH"
							echo "$?" > /tmp/ex_status.var) &> /dev/null &
							pid=$! pri=0.1 msg="\n$mnt_load \n\n \Z1> \Z2mount /dev/$part $ARCH\Zn" load

							if [ $(</tmp/ex_status.var) -eq "0" ]; then
								mounted=true
								ROOT="$part"
								DRIVE=$(<<<$part sed 's/[0-9]\+$//;/[0-9]/s/p$//')
							else
								dialog --ok-button "$ok" --msgbox "\n$part_err_msg1" 10 60
								prepare_drives
							fi
						fi
					else
						part_menu
					fi
				;;
				*)
					dialog --ok-button "$ok" --msgbox "\n$root_err_msg" 10 60
				;;
			esac
		elif [ -n "$part_mount" ]; then
			if (dialog --yes-button "$edit" --no-button "$back" --defaultno --yesno "\n$manual_part_var0" 13 60) then
				if [ "$part" == "$ROOT" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$manual_part_var2" 11 60) then
						mounted=false
						unset ROOT DRIVE
						umount -R "$ARCH" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2umount -R $ARCH\Zn" load
					fi
				else
					if [ "$part_mount" == "[SWAP]" ]; then
						if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$manual_swap_var" 10 60) then
							swapoff /dev/"$part" &> /dev/null &
							pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2swapoff /dev/$part\Zn" load
						fi
					elif (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$manual_part_var1" 10 60) then
						umount  "$ARCH"/"$part_mount" &> /dev/null &
						pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2umount ${ARCH}${part_mount}\Zn" load
						rm -r "$ARCH"/"$part_mount"
						points=$(echo -e "$part_mount   mountpoint>\n$points")
					fi
				fi
			fi
		elif (dialog --yes-button "$edit" --no-button "$back" --yesno "\n$manual_new_part_var" 12 60) then
			part_swap=false
			if (fdisk -l | grep "gpt" &>/dev/null) then
				part_type_uuid=$(fdisk -l -o Device,Size,Type-UUID | grep -w "$part" | awk '{print $3}')

				if [ $part_type_uuid == "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" ]; then
					part_swap=true
				fi
			else
				part_type_id=$(fdisk -l | grep -w "$part" | sed 's/\*//' | awk '{print $6}')

				if [ $part_type_id == "82" ]; then
					part_swap=true
				fi
			fi

			if ($part_swap); then
				mnt="SWAP"
			else
				mnt=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$mnt_var0" 15 60 6 $points 3>&1 1>&2 2>&3)
				if [ "$?" -gt "0" ]; then
					part_menu
				fi
			fi
	
			if [ "$mnt" == "$custom" ]; then
				while (true)
				  do
					mnt=$(dialog --ok-button "$ok" --cancel-button "$cancel" --inputbox "$custom_msg" 10 50 "/" 3>&1 1>&2 2>&3)
					
					if [ "$?" -gt "0" ]; then
						part_menu ; break
					elif (<<<$mnt grep "[\[\$\!\'\"\`\\|%&#@()+=<>~;:?.,^{}]\|]" &> /dev/null); then
						dialog --ok-button "$ok" --msgbox "\n$custom_err_msg0" 10 60
					elif (<<<$mnt grep "^[/]$" &> /dev/null); then
						dialog --ok-button "$ok" --msgbox "\n$custom_err_msg1" 10 60
					else
						break
					fi
				done
			fi
			
			if [ "$mnt" != "SWAP" ]; then
				if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$part_frmt_msg" 11 50) then
					f2fs=$(cat /sys/block/$(echo $part | sed 's/[0-9]\+$//;/[0-9]/s/p$//')/queue/rotational)
					
					if [ "$mnt" == "/boot" ] || [ "$mnt" == "/boot/EFI" ] || [ "$mnt" == "/boot/efi" ]; then
						f2fs=1
						btrfs=false
					fi
					
					if (fdisk -l | grep "$part" | grep "EFI" &> /dev/null); then
						vfat=true
					fi
					
					fs_select

					if [ "$?" -gt "0" ]; then
						part_menu
					fi
					frmt=true
				else	
					frmt=false
				fi

				if [ "$mnt" == "/boot" ] || [ "$mnt" == "/boot/EFI" ] || [ "$mnt" == "/boot/efi" ]; then
					BOOT="$part"
				fi
			else
				FS="SWAP"
			fi

			source "$lang_file"
		
			if [ "$mnt" == "SWAP" ]; then
				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$swap_frmt_msg" 11 50) then
					(wipefs -a -q /dev/"$part"
					mkswap /dev/"$part"
					swapon /dev/"$part") &> /dev/null &
					pid=$! pri=0.1 msg="\n$swap_load \n\n \Z1> \Z2mkswap /dev/$part\Zn" load
				else
					swapon /dev/"$part" &> /dev/null
					if [ "$?" -gt "0" ]; then
						dialog --ok-button "$ok" --msgbox "$swap_err_msg2" 10 60
					fi
				fi
			else
				points=$(echo  "$points" | grep -v "$mnt")
			
				if "$frmt" ; then
					if (dialog --yes-button "$write" --no-button "$cancel" --defaultno --yesno "$part_confirm_var" 12 50) then
						(sgdisk --zap-all /dev/"$part"
						wipefs -a /dev/"$part") &> /dev/null &
						pid=$! pri=0.1 msg="\n$frmt_load \n\n \Z1> \Z2wipefs -a /dev/$part\Zn" load
			
						case "$FS" in
							vfat)
								mkfs.vfat -F32 /dev/"$part" &> /dev/null &
							;;
							jfs|reiserfs)
								echo -e "y" | mkfs."$FS" /dev/"$part" &> /dev/null &
							;;
							*)
								mkfs."$FS" /dev/"$part" &> /dev/null &
							;;
						esac
						pid=$! pri=1 msg="\n$load_var1 \n\n \Z1> \Z2mkfs.$FS /dev/$part\Zn" load
					else
						part_menu
					fi
				fi
					
				(mkdir -p "$ARCH"/"$mnt"
				mount /dev/"$part" "$ARCH"/"$mnt" ; echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null &
				pid=$! pri=0.1 msg="\n$mnt_load \n\n \Z1> \Z2mount /dev/$part ${ARCH}${mnt}\Zn" load

				if [ "$(</tmp/ex_status.var)" -gt "0" ]; then
					dialog --ok-button "$ok" --msgbox "\n$part_err_msg2" 10 60
				fi
			fi
		fi

		part_menu
	fi

}

fs_select() {

	if "$vfat" ; then
		FS=$(dialog --menu "$vfat_msg" 11 65 1 \
			"vfat"  "$fs7" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			part_menu
		fi
		vfat=false
	else
		if [ "$f2fs" -eq "0" ]; then
			FS=$(dialog --nocancel --menu "$fs_msg" 17 65 7 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"btrfs"     "$fs3" \
				"f2fs"		"$fs6" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
		elif "$btrfs" ; then
				FS=$(dialog --nocancel --menu "$fs_msg" 16 65 6 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"btrfs"     "$fs3" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
		else
			FS=$(dialog --nocancel --menu "$fs_msg" 15 65 5 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" 3>&1 1>&2 2>&3)
				btrfs=true
		fi
	fi

	if [ "$FS" == "f2fs" ]; then
		enable_f2fs=true
	elif [ "$FS" == "btrfs" ]; then
		enable_btrfs=true
	fi

}

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
				"networkmanager" 		"$net_util_msg1" \
				"netctl"			"$net_util_msg0" \
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
	
	graphics

}

graphics() {

	op_title="$de_op_msg"
	if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_msg" 10 60) then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then	
			x="17" ; install_base
		fi	
	fi
	
	DE=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$environment_msg" 18 60 11 \
		"AA-Xfce"	"$de15" \
		"AA-Openbox"	"$de18" \
		"budgie"	"$de17" \
		"cinnamon"      "$de5" \
		"deepin"	"$de14" \
		"gnome"         "$de4" \
		"KDE plasma"    "$de6" \
		"lxde"          "$de2" \
		"lxqt"          "$de3" \
		"mate"          "$de1" \
		"xfce4"         "$de0" \
		"awesome"       "$de9" \
		"bspwm"		"$de13" \
		"dwm"           "$de12" \
		"enlightenment" "$de7" \
		"fluxbox"       "$de11" \
		"i3"            "$de10" \
		"openbox"       "$de8" \
		"xmonad"	"$de16"  3>&1 1>&2 2>&3)
	if [ "$?" -gt "0" ]; then 
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then	
			install_base
		fi
	fi

	source "$lang_file"

	case "$DE" in
		"AA-Xfce") 	env="$DE"
				DE="xfce4 xfce4-goodies gvfs zsh zsh-syntax-highlighting htop lynx xscreensaver"
				start_term="exec startxfce4"
		;;
		"AA-Openbox")	env="$DE"
				DE="openbox thunar thunar-volman xfce4-terminal xfce4-panel xfce4-whiskermenu-plugin xcompmgr transset-df obconf lxappearance-obconf wmctrl gxmessage xfce4-pulseaudio-plugin xfdesktop xdotool htop lynx xscreensaver"
				start_term="exec openbox-session"
		;;
		"xfce4") 	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg0" 10 60) then
					DE="xfce4 xfce4-goodies"
				fi
				start_term="exec startxfce4"
		;;
		"budgie")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg6" 10 60) then
					DE="budgie-desktop gnome"
				else
					DE="budgie-desktop"
				fi
				start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
		;;
		"gnome")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg1" 10 60) then
					DE="gnome gnome-extra"
				fi
				 start_term="exec gnome-session"
		;;
		"mate")		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$gtk3_var" 10 60) then 
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg2" 10 60) then
						DE="mate-gtk3 mate-extra-gtk3 gtk3-print-backends"
					else
						DE="mate-gtk3"
					fi
					GTK3=true
				else
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg2" 10 60) then
						DE="mate mate-extra gtk-engine-murrine"
					else
						DE="mate gtk-engine-murrine"
					fi
				fi
				 start_term="exec mate-session"
		;;
		"KDE plasma")	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg3" 10 60) then
					DE="plasma-desktop sddm konsole dolphin plasma-nm plasma-pa libxshmfence kscreen"
							
					if "$LAPTOP" ; then
						DE+=" powerdevil"
					fi
				else
					DE="plasma kde-applications"
				fi
						
				if [ -n "$kdel" ]; then
					DE+=" kde-l10n-$kdel"
				fi

				DM="sddm"
				enable_dm=true
				start_term="exec startkde"
		;;
		"deepin")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg4" 10 60) then
					DE="deepin deepin-extra"
				fi
 				start_term="exec startdde"
 		;;
 		"xmonad")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg5" 10 60) then 
                        		DE="xmonad xmonad-contrib"
                    		fi
                    		start_term="exec xmonad"
		;;	
		"cinnamon")	DE+=" gnome-terminal file-roller p7zip zip unrar"
				start_term="exec cinnamon-session" 
		;;
		"lxde") if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$gtk3_var" 10 60) then 
				DE="lxde-gtk3"
				GTK3=true
			fi
			start_term="exec startlxde" 
		;;
		"lxqt") start_term="exec startlxqt" 
			DE="lxqt oxygen-icons breeze-icons"
		;;
		"enlightenment") 	start_term="exec enlightenment_start"
					DE="enlightenment terminology"
		;;
		"bspwm")	start_term="sxhkd & ; exec bspwm"
				DE="bspwm sxhkd"
		;;
		"fluxbox")	start_term="exec startfluxbox" 
		;;
		"openbox")	start_term="exec openbox-session"
		;;
		"awesome") 	start_term="exec awesome" 
		;;	
		"dwm") 		start_term="exec dwm" 
		;;
		"i3") 		start_term="exec i3" 
		;;
	esac

	while (true)
	  do
	  	if "$VM" ; then
	  		case "$virt" in
	  			vbox)	dialog --ok-button "$ok" --msgbox "\n$vbox_msg" 10 60
						GPU="virtualbox-guest-utils"
						if [ "$kernel" == "linux" ]; then
							GPU+=" virtualbox-guest-modules-arch"
						else
							GPU+=" virtualbox-guest-dkms"
						fi
	  			;;
	  			vmware)	dialog --ok-button "$ok" --msgbox "\n$vmware_msg" 10 60
						GPU="xf86-video-vmware xf86-input-vmmouse open-vm-tools net-tools gtkmm mesa mesa-libgl"
	  			;;
	  			hyper-v) dialog --ok-button "$ok" --msgbox "\n$hyperv_msg" 10 60
						 GPU="xf86-video-fbdev mesa-libgl"
	  			;;
	  			*) 		dialog --ok-button "$ok" --msgbox "\n$vm_msg" 10 60
						GPU="xf86-video-fbdev mesa-libgl"
	  			;;
	  		esac
	  		break
	  	fi

	  	if "$NVIDIA" ; then
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 18 60 6 \
				"$default"			 "$gr0" \
				"xf86-video-ati"     "$gr4" \
				"xf86-video-intel"   "$gr5" \
				"xf86-video-nouveau" "$gr9" \
				"xf86-video-vesa"	 "$gr1" \
				"NVIDIA"             "$gr2 ->" 3>&1 1>&2 2>&3)
			ex="$?"
		else
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 17 60 5 \
				"$default"			 "$gr0" \
				"xf86-video-ati"     "$gr4" \
				"xf86-video-intel"   "$gr5" \
				"xf86-video-nouveau" "$gr9" \
				"xf86-video-vesa"	 "$gr1" 3>&1 1>&2 2>&3)
			ex="$?"
		fi
		
		if [ "$ex" -gt "0" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "$desktop_cancel_msg" 10 60) then
				install_base
			fi
		elif [ "$GPU" == "NVIDIA" ]; then
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$nvidia_msg" 15 60 4 \
				"$gr0"		   "->"	  \
				"nvidia"       "$gr6" \
				"nvidia-340xx" "$gr7" \
				"nvidia-304xx" "$gr8" 3>&1 1>&2 2>&3)
			
			if [ "$?" -eq "0" ]; then
				if [ "$GPU" == "$gr0" ]; then
					pci_id=$(lspci -nn | grep "VGA" | egrep -o '\[.*\]' | awk '{print $NF}' | sed 's/.*://;s/]//')
			        if (<"$aa_dir"/etc/nvidia340.xx grep "$pci_id" &>/dev/null); then
        			    if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_340msg" 10 60); then
        			    	if [ "$kernel" == "lts" ]; then
								GPU="nvidia-340xx-lts"
        			    	else
        			    		GPU="nvidia-340xx"
        			    	fi
        			    	GPU+=" nvidia-340xx-libgl nvidia-340xx-utils"
        			    	break
        			    fi
					elif (<"$aa_dir"/etc/nvidia304.xx grep "$pci_id" &>/dev/null); then
           				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_304msg" 10 60); then
           					if [ "$kernel" == "lts" ]; then
								GPU="nvidia-304xx-lts"
           					else
           						GPU="nvidia-304xx"
           					fi
           					GPU+=" nvidia-304xx-libgl nvidia-304xx-utils"
           					break
			        	fi
			        else
            			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_curmsg" 10 60); then
            				if [ "$kernel" == "lts" ]; then
								GPU="nvidia-lts"
            				else
            					GPU="nvidia"
							fi
							
							if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
								drm=true
							fi
							GPU+=" nvidia-libgl nvidia-utils"
            				break
            			fi
			        fi
				elif [ "$GPU" == "nvidia" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
						drm=true
					fi
					
					if [ "$kernel" == "lts" ]; then
						GPU="nvidia-lts nvidia-libgl nvidia-utils"
					else
						GPU+=" ${GPU}-libgl ${GPU}-utils"
					fi
					break
				else
					if [ "$kernel" == "lts" ]; then
						GPU="${GPU}-lts ${GPU}-libgl ${GPU}-utils"
					else
						GPU+=" ${GPU}-libgl ${GPU}-utils"
					fi
					break
				fi
			fi
		elif [ "$GPU" == "$default" ]; then
			GPU="$default_GPU mesa-libgl"
			break
		else
			GPU+=" mesa-libgl"
			break
		fi
	done
	
	DE="$DE xdg-user-dirs xorg-server xorg-server-utils xorg-xinit xterm arc-icon-theme arc-gtk-theme elementary-icon-theme ttf-dejavu gvfs pulseaudio pavucontrol pulseaudio-alsa alsa-utils unzip screenfetch $GPU"
		
	if [ "$net_util" == "networkmanager" ] ; then
		if (<<<"$DE" grep "plasma" &> /dev/null); then
			DE+=" plasma-nm"
		else
			DE+=" network-manager-applet"
		fi
	fi

	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$touchpad_msg" 10 60) then
		if (<<<"$DE" grep "gnome" &> /dev/null); then
			DE+=" xf86-input-libinput"
		else
			DE+=" xf86-input-synaptics"
		fi
	fi

	if "$enable_bt" ; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$blueman_msg" 10 60) then
			DE+=" blueman"
		fi
	fi
	
	if ! "$enable_dm" ; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$dm_msg" 10 60) then
			DM=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$dm_msg1" 13 64 4 \
				"lightdm"	"$dm1" \
				"gdm"		"$dm0" \
				"lxdm"		"$dm2" \
				"sddm"		"$dm3" 3>&1 1>&2 2>&3)
			if [ "$?" -eq "0" ]; then
				if [ "$DM" == "lightdm" ]; then
					DE+=" $DM lightdm-gtk-greeter"
				elif [ "$DM" == "lxdm" ] && "$GTK3"; then
					DE+=" ${DM}-gtk3"
				else
					DE+=" $DM"
				fi
				
				enable_dm=true
			fi
		else
			dialog --ok-button "$ok" --msgbox "\n$startx_msg" 10 60
		fi
	fi
	
	base_install+=" $DE"
	desktop=true x=19
	echo "$(date -u "+%F %H:%M") : Base install packages set: $base_install" >> "$log"
	install_base

}


install_base() {

	op_title="$install_op_msg"
	pacman -Sy --print-format='%s' $(echo "$base_install") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
	pid=$! pri=0.6 msg="\n$pacman_load \n\n \Z1> \Z2pacman -Sy\Zn" load
	download_size=$(</tmp/size) ; rm /tmp/size
	export software_size="$download_size Mib"
	cal_rate
	
	if (dialog --yes-button "$install" --no-button "$cancel" --yesno "\n$install_var" "$x" 65); then
		tmpfile=$(mktemp)
		echo "$(date -u "+%F %H:%M") : Begin base install" >> "$log"

		if [ "$kernel" == "linux" ]; then
			base_install="$(pacman -Sqg base) $base_install"
		else
			base_install="$(pacman -Sqg base | sed 's/^linux//') $base_install"
		fi
		
		(pacstrap "$ARCH" --force $(echo "$base_install") ; echo "$?" > /tmp/ex_status) &> "$tmpfile" &
		pid=$! pri=$(echo "$down" | sed 's/\..*$//') msg="\n$install_load_var" load_log

		genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab
		<"$tmpfile" >> "$log"
		rm "$tmpfile"
	
		if [ $(</tmp/ex_status) -eq "0" ]; then
			INSTALLED=true
			echo "$(date -u "+%F %H:%M") : Install Complete" >> "$log"
			echo "$(date -u "+%F %H:%M") : Generate fstab:\n$(<$ARCH/etc/fstab)" >> "$log"
		else
			dialog --ok-button "$ok" --msgbox "\n$failed_msg" 10 60
			echo "$(date -u "+%F %H:%M") : Install failed: please report to developer" >> "$log"
			reset ; tail "$log" ; exit 1
		fi
						
		if "$intel" && ! "$VM" ; then
			if (dialog --yes-button "$install" --no-button "$cancel" --yesno "\n$ucode_msg" 11 60); then
				arch-chroot "$ARCH" pacman -Sy intel-ucode &> "$log" &
				pid=$! pri=1 msg="\n$wait_load \n\n \Z1> \Z2pacman -Sy intel-ucode\Zn" load

				if [ -f "$ARCH/boot/intel-ucode.img" ]; then
					ucode=true
					echo "$(date -u "+%F %H:%M") : Installed intel-ucode" >> "$log"
				else
					dialog --ok-button "$ok" --msgbox "\n$ucode_failed_msg" 10 60
					echo "$(date -u "+%F %H:%M") : intel-ucode install failed" >> "$log"
				fi
			fi
		fi

		case "$bootloader" in
			grub) grub_config ;;
			syslinux) syslinux_config ;;
			systemd-boot) systemd_config ;;
		esac

		echo "$(date -u "+%F %H:%M") : Configured bootloader: $bootloader" >> "$log"
		configure_system
	else
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
			main_menu
		else
			install_base
		fi
	fi

}

grub_config() {
	
	if "$crypted" ; then
		sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
	else
		sed -i 's/quiet//' "$ARCH"/etc/default/grub
	fi

	if "$drm" ; then
		sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/ s/.$/ nvidia-drm.modeset=1"/;s/" /"/' "$ARCH"/etc/default/grub
	fi

	if "$UEFI" ; then
		(arch-chroot "$ARCH" grub-install --efi-directory="$esp_mnt" --target=x86_64-efi --bootloader-id=boot
		mv "$ARCH"/"$esp"/EFI/boot/grubx64.efi "$ARCH"/"$esp"/EFI/boot/bootx64.efi) &> /dev/null &
		pid=$! pri=0.1 msg="\n$grub_load1 \n\n \Z1> \Z2grub-install --efi-directory="$esp_mnt"\Zn" load
				
		if ! "$crypted" ; then
			arch-chroot "$ARCH" mkinitcpio -p "$kernel" &>/dev/null &
			pid=$! pri=1 msg="\n$uefi_config_load \n\n \Z1> \Z2mkinitcpio -p $kernel\Zn" load
		fi
	else
		arch-chroot "$ARCH" grub-install /dev/"$DRIVE" &> /dev/null &
		pid=$! pri=0.1 msg="\n$grub_load1 \n\n \Z1> \Z2grub-install /dev/$DRIVE\Zn" load
	fi
	arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
	pid=$! pri=0.1 msg="\n$grub_load2 \n\n \Z1> \Z2grub-mkconfig -o /boot/grub/grub.cfg\Zn" load

}

syslinux_config() {

	if "$UEFI" ; then
		esp_part_int=$(<<<"$esp_part" grep -o "[0-9]")
		esp_part=$(<<<"$esp_part" grep -o "sd[a-z]")
		esp_mnt=$(<<<$esp_mnt sed "s!$ARCH!!")
		(mkdir -p ${ARCH}${esp_mnt}/EFI/syslinux
		cp -r "$ARCH"/usr/lib/syslinux/efi64/* ${ARCH}${esp_mnt}/EFI/syslinux/
		cp "$aa_dir"/boot/loader/syslinux/syslinux_efi.cfg ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
		cp "$aa_dir"/boot/splash.png ${ARCH}${esp_mnt}/EFI/syslinux
		
		if [ "$kernel" == "linux-lts" ]; then
			sed -i 's/vmlinuz-linux/vmlinuz-linux-lts/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux.img/initramfs-linux-lts.img/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux-fallback.img/initramfs-linux-lts-fallback.img/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
		elif [ "$kernel" == "linux-grsec" ]; then
			sed -i 's/vmlinuz-linux/vmlinuz-linux-grsec/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux.img/initramfs-linux-grsec.img/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux-fallback.img/initramfs-linux-grsec-fallback.img/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
		fi

		arch-chroot "$ARCH" efibootmgr -c -d /dev/"$esp_part" -p "$esp_part_int" -l /EFI/syslinux/syslinux.efi -L "Syslinux") &> /dev/null &
		pid=$! pri=0.1 msg="\n$syslinux_load \n\n \Z1> \Z2syslinux install efi mode...\Zn" load
			
		if "$crypted" ; then
			sed -i "s|APPEND.*$|APPEND root=/dev/mapper/root cryptdevice=/dev/lvm/lvroot:root rw|" ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
		else
			sed -i "s|APPEND.*$|APPEND root=/dev/$ROOT|" ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
		fi

		if "$ucode" ; then
			if [ "$kernel" == "linux" ]; then
				sed -i "s|../../initramfs-linux.img|../../intel-ucode.img,../../initramfs-linux.img|" ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			elif [ "$kernel" == "linux-lts" ]; then
				sed -i "s|../../initramfs-linux-lts.img|../../intel-ucode.img,../../initramfs-linux-lts.img|" ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			else
				sed -i "s|../../initramfs-linux-grsec.img|../../intel-ucode.img,../../initramfs-linux-grsec.img|" ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
			fi
		fi
		
		if "$drm" ; then
			sed -i '/APPEND/ s/$/ nvidia-drm.modeset=1/' ${ARCH}${esp_mnt}/EFI/syslinux/syslinux.cfg
		fi

	else
		(syslinux-install_update -i -a -m -c "$ARCH"
		cp "$aa_dir"/boot/loader/syslinux/syslinux.cfg "$ARCH"/boot/syslinux/
		cp "$aa_dir"/boot/splash.png "$ARCH"/boot/syslinux/) &> /dev/null &
		pid=$! pri=0.1 msg="\n$syslinux_load \n\n \Z1> \Z2syslinux-install_update -i -a -m -c $ARCH\Zn" load
		
		if [ "$kernel" == "linux-lts" ]; then
			sed -i 's/vmlinuz-linux/vmlinuz-linux-lts/' ${ARCH}/boot/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux.img/initramfs-linux-lts.img/' ${ARCH}/boot/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux-fallback.img/initramfs-linux-lts-fallback.img/' ${ARCH}/boot/syslinux/syslinux.cfg
		elif [ "$kernel" == "linux-grsec" ]; then
			sed -i 's/vmlinuz-linux/vmlinuz-linux-grsec/' ${ARCH}/boot/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux.img/initramfs-linux-grsec.img/' ${ARCH}/boot/syslinux/syslinux.cfg
			sed -i 's/initramfs-linux-fallback.img/initramfs-linux-grsec-fallback.img/' ${ARCH}/boot/syslinux/syslinux.cfg
		fi

		if "$crypted" ; then
			sed -i "s|APPEND.*$|APPEND root=/dev/mapper/root cryptdevice=/dev/lvm/lvroot:root rw|" "$ARCH"/boot/syslinux/syslinux.cfg
		else
			sed -i "s|APPEND.*$|APPEND root=/dev/$ROOT|" "$ARCH"/boot/syslinux/syslinux.cfg
		fi

		if "$ucode" ; then
			if [ "$kernel" == "linux" ]; then
				sed -i "s|../initramfs-linux.img|../intel-ucode.img,../initramfs-linux.img|" "$ARCH"/boot/syslinux/syslinux.cfg
			elif [ "$kernel" == "linux-lts" ]; then
				sed -i "s|../initramfs-linux-lts.img|../intel-ucode.img,../initramfs-linux-lts.img|" "$ARCH"/boot/syslinux/syslinux.cfg
			else
				sed -i "s|../initramfs-linux-grsec.img|../intel-ucode.img,../initramfs-linux-grsec.img|" "$ARCH"/boot/syslinux/syslinux.cfg
			fi
		fi

		if "$drm" ; then
			sed -i '/APPEND/ s/$/ nvidia-drm.modeset=1/' ${ARCH}/boot/syslinux/syslinux.cfg
		fi
	fi

}

systemd_config() {

	esp_mnt=$(<<<$esp_mnt sed "s!$ARCH!!")
	(arch-chroot "$ARCH" bootctl --path="$esp_mnt" install
	cp /usr/share/systemd/bootctl/loader.conf ${ARCH}${esp_mnt}/loader/
	echo "timeout 4" >> ${ARCH}${esp_mnt}/loader/loader.conf) &> /dev/null &
	pid=$! pri=0.1 msg="\n$syslinux_load \n\n \Z1> \Z2bootctl --path="$esp_mnt" install\Zn" load
	
	if [ "$kernel" == "linux" ]; then
		echo -e "title          Arch Linux\nlinux          /vmlinuz-linux\ninitrd         /initramfs-linux.img" > ${ARCH}${esp_mnt}/loader/entries/arch.conf
	elif [ "$kernel" == "linux-lts" ]; then
		echo -e "title          Arch Linux\nlinux          /vmlinuz-linux-lts\ninitrd         /initramfs-linux-lts.img" > ${ARCH}${esp_mnt}/loader/entries/arch.conf
	else
		echo -e "title          Arch Linux\nlinux          /vmlinuz-linux-grsec\ninitrd         /initramfs-linux-grsec.img" > ${ARCH}${esp_mnt}/loader/entries/arch.conf
	fi
	
	if "$crypted" ; then
		echo "options		cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root quiet rw" >> ${ARCH}${esp_mnt}/loader/entries/arch.conf
	else
		echo "options		root=PARTUUID=$(blkid -s PARTUUID -o value $(df | grep -m1 "$ARCH" | awk '{print $1}')) rw" >> ${ARCH}${esp_mnt}/loader/entries/arch.conf
	fi

	if "$ucode" ; then
		sed -i '/initrd/i\initrd  \/intel-ucode.img' ${ARCH}${esp_mnt}/loader/entries/arch.conf
	fi

	if "$drm" ; then
		sed -i '/options/ s/$/ nvidia-drm.modeset=1/' ${ARCH}${esp_mnt}/loader/entries/arch.conf
	fi

}

configure_system() {

	op_title="$config_op_msg"
	
	if [ "$bootloader" == "syslinux" ] || [ "$bootloader" == "systemd-boot" ] && "$UEFI" ; then
		if [ "$esp_mnt" != "/boot" ]; then
			(mkdir "$ARCH"/etc/pacman.d/hooks
			if [ "$kernel" == "linux" ]; then
				echo -e "$linux_hook\nExec = /usr/bin/cp /boot/{vmlinuz-linux,initramfs-linux.img,initramfs-linux-fallback.img} ${esp_mnt}" > "$ARCH"/etc/pacman.d/hooks/linux-esp.hook
				cp "$ARCH"/boot/{vmlinuz-linux,initramfs-linux.img,initramfs-linux-fallback.img} ${ARCH}${esp_mnt}
			elif [ "$kernel" == "linux-lts" ]; then
				echo -e "$lts_hook\nExec = /usr/bin/cp /boot/{vmlinuz-linux-lts,initramfs-linux-lts.img,initramfs-linux-lts-fallback.img} ${esp_mnt}" > "$ARCH"/etc/pacman.d/hooks/linux-esp.hook
				cp "$ARCH"/boot/{vmlinuz-linux-lts,initramfs-linux-lts.img,initramfs-linux-lts-fallback.img} ${ARCH}${esp_mnt}
			else
				echo -e "$grs_hook\nExec = /usr/bin/cp /boot/{vmlinuz-linux-grsec,initramfs-linux-grsec.img,initramfs-linux-grsec-fallback.img} ${esp_mnt}" > "$ARCH"/etc/pacman.d/hooks/linux-esp.hook
				cp "$ARCH"/boot/{vmlinuz-linux-grsec,initramfs-linux-grsec.img,initramfs-linux-grsec-fallback.img} ${ARCH}${esp_mnt}
			fi 
			
			if "$ucode" ; then
				echo -e "$intel_hook\nExec = /usr/bin/cp /boot/intel-ucode.img ${esp_mnt}" > "$ARCH"/etc/pacman.d/hooks/intel-esp.hook
				cp "$ARCH"/boot/intel-ucode.img ${ARCH}${esp_mnt}
			fi ) &
			pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2cp "$ARCH"/boot/ ${ARCH}${esp_mnt}\Zn" load
		fi
	fi
	
	if "$drm" ; then
		sed -i 's/MODULES=""/MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"/' "$ARCH"/etc/mkinitcpio.conf
		sed -i 's!FILES=""!FILES="/etc/modprobe.d/nvidia.conf"!' "$ARCH"/etc/mkinitcpio.conf
		echo "options nvidia_drm modeset=1" > "$ARCH"/etc/modprobe.d/nvidia.conf
		
		if [ ! -d "$ARCH"/etc/pacman.d/hooks ]; then
			mkdir "$ARCH"/etc/pacman.d/hooks
		fi
		
		echo -e "$nvidia_hook\nExec=/usr/bin/mkinitcpio -p $kernel" > "$ARCH"/etc/pacman.d/hooks/nvidia.hook
		
		if ! "$crypted" && ! "$enable_f2fs" ; then
			arch-chroot "$ARCH" mkinitcpio -p "$kernel" &>/dev/null &
			pid=$! pri=1 msg="\n$kernel_config_load \n\n \Z1> \Z2mkinitcpio -p $kernel\Zn" load
		fi

		echo "$(date -u "+%F %H:%M") : Enable nvidia drm" >> "$log"
	fi

	if "$enable_f2fs" ; then
		sed -i '/MODULES=/ s/.$/ f2fs crc32 libcrc32c crc32c_generic crc32c-intel crc32-pclmul"/;s/" /"/' "$ARCH"/etc/mkinitcpio.conf
		if ! "$crypted" ; then
			arch-chroot "$ARCH" mkinitcpio -p "$kernel" &>/dev/null &
			pid=$! pri=1 msg="\n$f2fs_config_load \n\n \Z1> \Z2mkinitcpio -p $kernel\Zn" load
		fi
		echo "$(date -u "+%F %H:%M") : Configure system for f2fs" >> "$log"
	fi

	if "$crypted" && "$UEFI" ; then
		echo "/dev/$BOOT              $esp           vfat         rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro        0       2" > "$ARCH"/etc/fstab
	elif "$crypted" ; then
		echo "/dev/$BOOT              /boot           $FS         defaults        0       2" > "$ARCH"/etc/fstab
	fi
		
	if "$crypted" ; then
		(echo "/dev/mapper/root        /               $FS         defaults        0       1" >> "$ARCH"/etc/fstab
		echo "/dev/mapper/tmp         /tmp            tmpfs        defaults        0       0" >> "$ARCH"/etc/fstab
		echo "tmp	       /dev/lvm/tmp	       /dev/urandom	tmp,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab
		if "$SWAP" ; then
			echo "/dev/mapper/swap     none            swap          sw                    0       0" >> "$ARCH"/etc/fstab
			echo "swap	/dev/lvm/swap	/dev/urandom	swap,cipher=aes-xts-plain64,size=256" >> "$ARCH"/etc/crypttab
		fi
		sed -i 's/HOOKS=.*/HOOKS="base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck"/' "$ARCH"/etc/mkinitcpio.conf
		arch-chroot "$ARCH" mkinitcpio -p "$kernel") &> /dev/null &
		pid=$! pri=1 msg="\n$encrypt_load1 \n\n \Z1> \Z2mkinitcpio -p $kernel\Zn" load
		echo "$(date -u "+%F %H:%M") : Configure system for encryption" >> "$log"
	fi

	(sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
	echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
	arch-chroot "$ARCH" locale-gen) &> /dev/null &
	pid=$! pri=0.1 msg="\n$locale_load_var \n\n \Z1> \Z2LANG=$LOCALE ; locale-gen\Zn" load
	echo "$(date -u "+%F %H:%M") : Set system locale: $LOCALE" >> "$log"
	
	if [ "$keyboard" != "$default" ]; then
		echo "KEYMAP=$keyboard" > "$ARCH"/etc/vconsole.conf
		if "$desktop" ; then
			echo -e "Section \"InputClass\"\nIdentifier \"system-keyboard\"\nMatchIsKeyboard \"on\"\nOption \"XkbLayout\" \"$keyboard\"\nEndSection" > "$ARCH"/etc/X11/xorg.conf.d/00-keyboard.conf
		fi
		echo "$(date -u "+%F %H:%M") : Set system keymap: $keyboard" >> "$log"
	fi

	(arch-chroot "$ARCH" ln -sf /usr/share/zoneinfo/"$ZONE" /etc/localtime ; sleep 0.5) &
	pid=$! pri=0.1 msg="\n$zone_load_var \n\n \Z1> \Z2ln -sf $ZONE /etc/localtime\Zn" load
	echo "$(date -u "+%F %H:%M") : Set system timezone: $ZONE" >> "$log"

	case "$net_util" in
		networkmanager)	arch-chroot "$ARCH" systemctl enable NetworkManager.service &>/dev/null
				pid=$! pri=0.1 msg="\n$nwmanager_msg0 \n\n \Z1> \Z2systemctl enable NetworkManager.service\Zn" load
				echo "$(date -u "+%F %H:%M") : Enable networkmanager" >> "$log"
		;;
		netctl)	arch-chroot "$ARCH" systemctl enable netctl.service &>/dev/null &
		  	pid=$! pri=0.1 msg="\n$nwmanager_msg1 \n\n \Z1> \Z2systemctl enable netctl.service\Zn" load
		  	echo "$(date -u "+%F %H:%M") : Enable netctl" >> "$log"
		;;
	esac

	if "$enable_bt" ; then
 	   	arch-chroot "$ARCH" systemctl enable bluetooth &>/dev/null &
		pid=$! pri=0.1 msg="\n$btenable_msg \n\n \Z1> \Z2systemctl enable bluetooth.service\Zn" load
		echo "$(date -u "+%F %H:%M") : Enable bluetooth" >> "$log"
	fi
	
	if "$desktop" ; then
		echo "$start_term" > "$ARCH"/etc/skel/.xinitrc
		echo "$start_term" > "$ARCH"/root/.xinitrc
		echo "$(date -u "+%F %H:%M") : Create xinitrc: $start_term" >> "$log"
	fi
	
	if "$enable_dm" ; then 
		arch-chroot "$ARCH" systemctl enable "$DM".service &> /dev/null &
		pid=$! pri="0.1" msg="$wait_load \n\n \Z1> \Z2systemctl enable "$DM"\Zn" load
		echo "$(date -u "+%F %H:%M") : Enable $DM" >> "$log"
	fi
		
	if "$VM" ; then
		case "$virt" in
			vbox)	arch-chroot "$ARCH" systemctl enable vboxservice &>/dev/null &
				pid=$! pri=0.1 msg="\n$vbox_enable_msg \n\n \Z1> \Z2systemctl enable vboxservice\Zn" load
				echo "$(date -u "+%F %H:%M") : Enable vboxservice" >> "$log"
			;;
			vmware)	(arch-chroot "$ARCH" systemctl enable vmware-vmblock-fuse
				mkdir "$ARCH"/etc/init.d
				for x in {0..6}; do mkdir -p "$ARCH"/etc/init.d/rc${x}.d; done) &>/dev/null &
				pid=$! pri=0.1 msg="\n$vbox_enable_msg \n\n \Z1> \Z2systemctl enable vboxservice\Zn" load
				echo "$(date -u "+%F %H:%M") : Enable vmware" >> "$log"
			;;
		esac
	fi

	if [ ! -z "$env" ]; then	
		config_env &
		pid=$! pri="0.1" msg="$wait_load \n\n \Z1> \Z2arch-anywhere config_env\Zn" load
	fi	
	
	if [ "$arch" == "x86_64" ]; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n\n$multilib_msg" 11 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
			echo "$(date -u "+%F %H:%M") : Include multilib" >> "$log"
		fi
	fi
	
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n\n$dhcp_msg" 11 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.1 msg="\n$dhcp_load \n\n \Z1> \Z2systemctl enable dhcpcd\Zn" load
		echo "$(date -u "+%F %H:%M") : Enable dhcp" >> "$log"
	fi

	if [ "$sh" == "/bin/bash" ]; then
		cp "$ARCH"/etc/skel/.bash_profile "$ARCH"/root/
	elif [ "$sh" == "/usr/bin/zsh" ]; then
		cp "$aa_dir"/extra/.zshrc "$ARCH"/root/
		cp "$aa_dir"/extra/.zshrc "$ARCH"/etc/skel/
	elif [ "$shell" == "fish" ]; then
		echo "fish && exit" >> "$aa_dir"/extra/.bashrc-root
		echo "fish && exit" >> "$aa_dir"/extra/.bashrc
	elif [ "$shell" == "tcsh" ]; then
		cp "$aa_dir"/extra/{.tcshrc,.tcshrc.conf} "$ARCH"/root/
		cp "$aa_dir"/extra/{.tcshrc,.tcshrc.conf} "$ARCH"/etc/skel/
	elif [ "$shell" == "mksh" ]; then
		cp "$aa_dir"/extra/.mkshrc "$ARCH"/root/
		cp "$aa_dir"/extra/.mkshrc "$ARCH"/etc/skel/
	fi

	cp "$aa_dir"/extra/.bashrc-root "$ARCH"/root/.bashrc
	cp "$aa_dir"/extra/.bashrc "$ARCH"/etc/skel/
	set_hostname

}

config_env() {

	sh="/usr/bin/zsh"
	arch-chroot "$ARCH" chsh -s /usr/bin/zsh &> /dev/null
	cp -r "$aa_dir"/pkg/arch-wiki-*.pkg.tar.xz "$ARCH"/var/cache/pacman/pkg
	cp -r "$aa_dir"/pkg/fetchmirrors-*.pkg.tar.xz "$ARCH"/var/cache/pacman/pkg
	arch-chroot "$ARCH" pacman --noconfirm -U /var/cache/pacman/pkg/$(ls "$aa_dir"/pkg/arch-wiki-*.pkg.tar.xz | sed 's!.*/!!') &>/dev/null
	arch-chroot "$ARCH" pacman --noconfirm -U /var/cache/pacman/pkg/$(ls "$aa_dir"/pkg/fetchmirrors-*.pkg.tar.xz | sed 's!.*/!!') &>/dev/null
	cp -r "$aa_dir"/extra/desktop/ttf-zekton-rg "$ARCH"/usr/share/fonts
	cp "$aa_dir"/extra/.zshrc "$ARCH"/root/
	cp "$aa_dir"/extra/.zshrc "$ARCH"/etc/skel/
	cp "$aa_dir"/extra/desktop/arch-anywhere-icon.png "$ARCH"/root/.face
	cp "$aa_dir"/extra/desktop/arch-anywhere-icon.png "$ARCH"/etc/skel/.face
	cp -r "$aa_dir"/extra/desktop/{arch-anywhere-wallpaper.png,arch-anywhere-icon.png} "$ARCH"/usr/share/pixmaps
	
	case "$env" in
		AA-Xfce)
			cp -r "$aa_dir"/extra/desktop/xfce4/.config "$ARCH"/root/
			cp -r "$aa_dir"/extra/desktop/xfce4/.config "$ARCH"/etc/skel/
			cp -r "$aa_dir"/extra/desktop/AshOS-Dark-2.0 "$ARCH"/usr/share/themes/
			cp -r "$aa_dir"/extra/desktop/arch-anywhere-wallpaper.png "$ARCH"/usr/share/backgrounds/xfce/
			cp "$ARCH"/usr/share/backgrounds/xfce/arch-anywhere-wallpaper.png "$ARCH"/usr/share/backgrounds/xfce/xfce-teal.jpg
		;;
		AA-Openbox)
			for file in $(ls -A "$aa_dir/extra/desktop/openbox"); do
				cp -r "$aa_dir/extra/desktop/openbox/$file" "$ARCH"/root/
				cp -r "$aa_dir/extra/desktop/openbox/$file" "$ARCH"/etc/skel/
			done
			cp -r "$aa_dir"/extra/desktop/Arc/openbox-3 "$ARCH"/usr/share/themes/Arc
			cp -r "$aa_dir"/extra/desktop/Arc-Dark/openbox-3 "$ARCH"/usr/share/themes/Arc-Dark
			cp -r "$aa_dir"/extra/desktop/Arc-Darker/openbox-3 "$ARCH"/usr/share/themes/Arc-Darker
			cp -r "$aa_dir"/extra/desktop/obpower.sh "$ARCH"/usr/bin/obpower
			chmod +x "$ARCH"/usr/bin/obpower
			cp -r "$aa_dir"/pkg/opensnap-*.pkg.tar.xz "$ARCH"/var/cache/pacman/pkg
			arch-chroot "$ARCH" pacman --noconfirm -U /var/cache/pacman/pkg/$(ls /usr/share/arch-anywhere/pkg/opensnap-*.pkg.tar.xz | sed 's!.*/!!') &>/dev/null
			if [ "$virt" == "vbox" ]; then
				echo "VBoxClient-all &" >> "$ARCH"/etc/skel/.config/openbox/autostart
				echo "VBoxClient-all &" >> "$ARCH"/root/.config/openbox/autostart
			fi
		;;
	esac

	echo "$(date -u "+%F %H:%M") : Configured: $env" >> "$log"
	arch-chroot "$ARCH" fc-cache -f

}

set_hostname() {

	op_title="$host_op_msg"
	hostname=$(dialog --ok-button "$ok" --nocancel --inputbox "\n$host_msg" 12 55 "arch-anywhere" 3>&1 1>&2 2>&3 | sed 's/ //g')
	
	if (<<<$hostname grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()+=<>~;:/?.,^{}]\|]" &> /dev/null); then
		dialog --ok-button "$ok" --msgbox "\n$host_err_msg" 10 60
		set_hostname
	fi
	
	echo "$hostname" > "$ARCH"/etc/hostname
	echo "$(date -u "+%F %H:%M") : Hostname set: $hostname" >> "$log"
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
	echo "$(date -u "+%F %H:%M") : Root password set" >> "$log"
	add_user

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
	echo "$(date -u "+%F %H:%M") : Added user: $user" >> "$log"

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
	echo "$(date -u "+%F %H:%M") : User password set" >> "$log"
	op_title="$user_op_msg"
	
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$sudo_var" 10 60) then
		(sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
		arch-chroot "$ARCH" usermod -a -G wheel "$user") &> /dev/null &
		pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2usermod -a -G wheel $user\Zn" load
		echo "$(date -u "+%F %H:%M") : Sudo enabled for: $user" >> "$log"
	fi

	if "$menu_enter" ; then
		reboot_system
	else	
		install_software
	fi

}

install_software() {

	op_title="$software_op_msg"
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$software_msg0" 10 60) then
		
		while (true)
		  do
			unset software
			add_soft=true
			if ! "$skip" ; then
				software_menu=$(dialog --extra-button --extra-label "$install" --ok-button "$select" --cancel-button "$cancel" --menu "$software_type_msg" 20 63 11 \
					"$aar" "$aar_msg" \
					"$audio" "$audio_msg" \
					"$games" "$games_msg" \
					"$graphic" "$graphic_msg" \
					"$internet" "$internet_msg" \
					"$multimedia" "$multimedia_msg" \
					"$office" "$office_msg" \
					"$terminal" "$terminal_msg" \
					"$text_editor" "$text_editor_msg" \
					"$system" "$system_msg" \
					"$done_msg" "$install \Z2============>\Zn" 3>&1 1>&2 2>&3)
				ex="$?"
				
				if [ "$ex" -eq "1" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_warn_msg" 10 60) then
						break
					else
						add_soft=false
					fi
				elif [ "$ex" -eq "3" ]; then
					software_menu="$done_msg"
				elif [ "$software_menu" == "$aar" ]; then
					if ! (<"$ARCH"/etc/pacman.conf grep "arch-anywhere"); then
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$aar_add_msg" 10 60) then
							echo -e "\n[arch-anywhere]\nServer = $aa_repo\nSigLevel = Never" >> "$ARCH"/etc/pacman.conf
						fi
					fi
				fi
			else
				skip=false
			fi

			case "$software_menu" in
				"$aar")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 60 7 \
						"arch-wiki-cli"		"$aar0" ON \
						"downgrade"		"$aar6" OFF \
						"dolphin-libre"	"$aar7" OFF \
						"fetchmirrors"		"$aar1" ON \
						"octopi"		"$aar4" OFF \
						"pacaur"		"$aar2" OFF \
						"pamac-aur"		"$aar5" OFF \
						"yaourt"		"$aar3" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
					
					if (<<<"$software" grep "dolphin-libre") then
						software=$(<<<"$software" sed 's/dolphin-libre/dolphin-libreoffice-templates/')
					fi
				;;
				"$audio")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 60 10 \
						"audacity"		"$audio0" OFF \
						"audacious"		"$audio1" OFF \
						"cmus"			"$audio2" OFF \
						"jack2"         "$audio3" OFF \
						"projectm"		"$audio4" OFF \
						"lmms"			"$audio5" OFF \
						"mpd"			"$audio6" OFF \
						"ncmpcpp"		"$audio7" OFF \
						"pianobar"		"$audio9" OFF \
						"pavucontrol"	"$audio8" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$internet")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 19 60 9 \
						"chromium"			"$net0" OFF \
						"elinks"			"$net3" OFF \
						"filezilla"			"$net1" OFF \
						"firefox"			"$net2" OFF \
						"irssi"				"$net9" OFF \
						"lynx"				"$net3" OFF \
						"minitube"			"$net4" OFF \
						"opera"				"$net5" OFF \
						"thunderbird"			"$net6" OFF \
						"transmission-cli" 		"$net7" OFF \
						"transmission-gtk"		"$net8" OFF \
						"hexchat"			"$net11" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
					
					if (<<<"$software" grep "firefox" &>/dev/null) && [ -n "$bro" ]; then
						software+=" firefox-i18n-$bro"
					fi
					
					if (<<<"$software" grep "thunderbird" &>/dev/null) && [ -n "$bro" ] && [ "$bro" != "lv" ]; then
							software+=" thunderbird-i18n-$bro"
					fi
				;;
				"$games")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 70 10 \
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
						add_soft=false
					fi
				;;
				"$graphic")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 63 7 \
						"blender"		"$graphic0" OFF \
						"darktable"		"$graphic1" OFF \
						"feh"			"$graphic6" OFF \
						"gimp"			"$graphic2" OFF \
						"graphviz"		"$graphic3" OFF \
						"imagemagick"	"$graphic4" OFF \
						"pinta"			"$graphic5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$multimedia")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 63 7 \
						"handbrake"				"$media0" OFF \
						"mplayer"				"$media1" OFF \
						"mpv"					"$media7" OFF \
						"multimedia-codecs"			"$media8" OFF \
						"pitivi"				"$media2" OFF \
						"simplescreenrecorder"			"$media3" OFF \
						"smplayer"				"$media4" OFF \
						"totem"					"$media5" OFF \
						"vlc"         	   			"$media6" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
					
					if (<<<"$software" grep "multimedia-codecs") then
						software=$(<<<"$software" sed 's/multimedia-codecs/gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly ffmpegthumbnailer gst-libav/')
					fi
				;;
				"$office")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 16 63 6 \
						"abiword"               "$office0" OFF \
						"calligra"              "$office1" OFF \
						"gnumeric"				"$office3" OFF \
						"libreoffice-fresh"		"$office4" OFF \
						"libreoffice-still"		"$office5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi

					if (<<<"$software" grep "libreoffice-fresh" &>/dev/null) && [ -n "$lib" ]; then
						software+=" libreoffice-fresh-$lib"
					fi
					
					if (<<<"$software" grep "libreoffice-still" &>/dev/null) && [ -n "$lib" ]; then
						software+=" libreoffice-still-$lib"
					fi
				;;
				"$terminal")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 18 63 8 \
						"fbterm"			"$term0" OFF \
						"guake"             "$term1" OFF \
						"kmscon"			"$term2" OFF \
						"pantheon-terminal"	"$term3" OFF \
						"rxvt-unicode"      "$term4" OFF \
						"terminator"        "$term5" OFF \
						"xfce4-terminal"    "$term6" OFF \
						"yakuake"           "$term7" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$text_editor")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 18 60 8 \
						"atom"			"$edit7" OFF \
						"emacs"			"$edit0" OFF \
						"geany"			"$edit1" OFF \
						"gedit"			"$edit2" OFF \
						"gvim"			"$edit3" OFF \
						"mousepad"		"$edit4" OFF \
						"neovim"		"$edit5" OFF \
						"vim"			"$edit6" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$system")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 65 10 \
						"apache"		"$sys1" OFF \
						"bleachbit"		"$sys22" OFF \
						"conky"			"$sys2" OFF \
						"dmenu"			"$sys19" OFF \
						"git"			"$sys3" OFF \
						"gparted"		"$sys4" OFF \
						"gpm"			"$sys5" OFF \
						"htop"			"$sys6" OFF \
						"inxi"			"$sys7" OFF \
						"k3b"			"$sys8" OFF \
						"nmap"			"$sys9" OFF \
						"openssh"		"$sys10" OFF \
						"pcmanfm"		"$sys21" OFF \
						"ranger"		"$sys20" OFF \
						"screen"		"$sys11" OFF \
						"screenfetch"		"$sys12" ON \
						"scrot"			"$sys13" OFF \
						"tmux"			"$sys14" OFF \
						"tuxcmd"		"$sys15" OFF \
						"virtualbox"		"$sys16" OFF \
						"ufw"			"$sys17" ON \
						"wget"			"$sys18" ON \
						"xfe"			"$sys23" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$done_msg")
					if [ -z "$final_software" ]; then
						if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_warn_msg" 10 60) then
							break
						else
							add_soft=false
						fi
					else
						download=$(echo "$final_software" | sed 's/\"//g' | tr ' ' '\n' | nl | sort -u -k2 | sort -n | cut -f2- | sed 's/$/ /g' | tr -d '\n')
						export download_list=$(echo "$download" |  sed -e 's/^[ \t]*//')
						arch-chroot "$ARCH" pacman -Sy --print-format='%s' $(echo "$download") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
						pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2pacman -S --print-format\Zn" load
						download_size=$(</tmp/size) ; rm /tmp/size
						export software_size=$(echo "$download_size Mib")
						export software_int=$(echo "$download" | wc -w)
						cal_rate

						if [ "$software_int" -lt "20" ]; then
							height=17
						else
							height=20
						fi
						
						if (dialog --yes-button "$install" --no-button "$cancel" --yesno "\n$software_confirm_var1" "$height" 65) then
							tmpfile=$(mktemp)
							echo "$(date -u "+%F %H:%M") : Add software list: $download" >> "$log"
							echo "$(date -u "+%F %H:%M") : Begin installing software" >> "$log"
							arch-chroot "$ARCH" pacman --noconfirm -Sy $(echo "$download") &> "$tmpfile" &
							pid=$! pri=$(<<<"$down" sed 's/\..*$//') msg="\n$software_load_var" load_log
							echo "$(date -u "+%F %H:%M") : Finished installing software" >> "$log"
							<"$tmpfile" >> "$log"
							rm "$tmpfile"
							unset final_software
							break
						else
							unset final_software
							add_soft=false
						fi
					fi
				;;
			esac
			
			if "$add_soft" ; then
				if [ -z "$software" ]; then
					if ! (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_noconfirm_msg ${software_menu}?" 10 60) then
						skip=true
					fi
				else
					add_software=$(echo "$software" | sed 's/\"//g')
					software_list=$(echo "$add_software" | sed -e 's/^[ \t]*//')
					arch-chroot "$ARCH" pacman -Sy --print-format='%s' $(echo "$add_software") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
					pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2pacman -Sy --print-format\Zn" load
					download_size=$(</tmp/size) ; rm /tmp/size
					software_size=$(echo "$download_size Mib")
					software_int=$(echo "$add_software" | wc -w)
					source "$lang_file"
				
					if [ "$software_int" -lt "15" ]; then
						height=14
					else
						height=16
					fi

					if (dialog --yes-button "$add" --no-button "$cancel" --yesno "\n$software_confirm_var0" "$height" 60) then
						final_software="$software $final_software"
					fi
				fi
			fi
		done
	fi
	
	if ! "$pac_update" ; then
		if [ -f "$ARCH"/var/lib/pacman/db.lck ]; then
			rm "$ARCH"/var/lib/pacman/db.lck &> /dev/null
		fi

		arch-chroot "$ARCH" pacman -Sy &> /dev/null &
		pid=$! pri=0.8 msg="\n$pacman_load \n\n \Z1> \Z2pacman -Sy\Zn" load
		echo "$(date -u "+%F %H:%M") : Updated pacman databases" >> "$log"
		pac_update=true
	fi

	software_selected=false
	echo "$(date -u "+%F %H:%M") : Install finished" >> "$log"
	reboot_system

}

reboot_system() {

	op_title="$complete_op_msg"
	if "$INSTALLED" ; then
		if [ "$bootloader" == "$none" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$complete_no_boot_msg" 10 60) then
				reset ; exit
			fi
		fi

		reboot_menu=$(dialog --nocancel --ok-button "$ok" --menu "$complete_msg" 16 60 7 \
			"$reboot0" "-" \
			"$reboot6" "-" \
			"$reboot2" "-" \
			"$reboot1" "-" \
			"$reboot4" "-" \
			"$reboot3" "-" \
			"$reboot5" "-" 3>&1 1>&2 2>&3)
		
		case "$reboot_menu" in
			"$reboot0")	umount -R "$ARCH"
					reset ; reboot ; exit
			;;
			"$reboot6")	umount -R "$ARCH"
					reset ; poweroff ; exit
			;;
			"$reboot1")	umount -R "$ARCH"
					reset ; exit
			;;
			"$reboot2")	clear
					echo -e "$arch_chroot_msg" 
					echo "/root" > /tmp/chroot_dir.var
					arch_anywhere_chroot
					clear
			;;
			"$reboot3")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "$user_exists_msg" 10 60); then
						menu_enter=true
						add_user	
					else
						reboot_system
					fi
			;;
			"$reboot5")	install_software
			;;
			"$reboot4")	clear
					less "$log"
					clear
					reboot_system
			;;
		esac

	else

		if (dialog --yes-button "$yes" --no-button "$no" --yesno "$not_complete_msg" 10 60) then
			umount -R $ARCH
			reset ; reboot ; exit
		else
			main_menu
		fi
	fi

}

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
	unset input
	rm /tmp/chroot_dir.var &> /dev/null
	clear
	reboot_system

}

dialog() {

	if "$screen_h" ; then
		/usr/bin/dialog --colors --backtitle "$backtitle" --title "$op_title" "$@"
	else
		/usr/bin/dialog --colors --title "$title" "$@"
	fi

}

cal_rate() {
			
	case "$connection_rate" in
		KB/s) 
			down_sec=$(echo "$download_size*1024/$connection_speed" | bc) ;;
		MB/s)
			down_sec=$(echo "$download_size/$connection_speed" | bc) ;;
		*) 
			down_sec="1" ;;
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
        	while ps | grep "$pid" &> /dev/null
    	    	do
    	            sleep $pri
    	            echo $int
    	        	if [ "$int" -lt "100" ]; then
    	        		int=$((int+1))
    	        	fi
    	        done
            echo 100
            sleep 1
	} | dialog --gauge "$msg" 9 79 0

}

load_log() {
	
	{	int=1
		pos=1
		pri=$((pri*2))
		while ps | grep "$pid" &> /dev/null
    	    do
    	        sleep 0.5
    	        if [ "$pos" -eq "$pri" ] && [ "$int" -lt "100" ]; then
    	        	pos=0
    	        	int=$((int+1))
    	        fi
    	        log=$(tail -n 1 "$tmpfile" | sed 's/.pkg.tar.xz//')
    	        echo "$int"
    	        echo -e "XXX$msg \n \Z1> \Z2$log\Zn\nXXX"
    	        pos=$((pos+1))
    	    done
            echo 100
            sleep 1
	} | dialog --gauge "$msg" 10 79 0

}

opt="$1"
if [ $(basename "$0") = "arch-anywhere" ]; then
	aa_dir="/usr/share/arch-anywhere" # Arch Anywhere iso
	aa_conf="/etc/arch-anywhere.conf"
else
	aa_dir=$(dirname $(readlink -f "$0")) # Arch Anywhere git repository
	aa_conf="$aa_dir"/etc/arch-anywhere.conf
fi
init
# vim: ai:ts=8:sw=8:sts=8:noet
