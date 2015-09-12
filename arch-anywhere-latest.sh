#!/bin/bash

ARCH=/mnt
connection=false
wifi=false
UEFI=false
mounted=false
INSTALLED=false
bootloader=false
system_configured=false
hostname_set=false
user_added=false
arch=$(uname -a | grep -o "x86_64\|i386\|i686")

check_connection() {
	if ! (whiptail --title "Arch Linux Anywhere" --yesno "Bine aţi venit la Arch Linux Anywhere! \n\n *Doriţi să începeţi procesul de instalare?" 10 60) then
		clear ; exit
	fi
	ping -w 2 google.com &> /dev/null
	if [ "$?" -gt "0" ]; then
		wifi_network=$(ip addr | grep "wlp" | awk '{print $2}' sed 's/://')
		if [ -n "$wifi_network" ]; then
			if (whiptail --title "Arch Linux Anywhere" --yesno "Reţea Wifi detectată, doriţi să vă conectaţi?" 10 60) then
				wifi_menu
				if [ "$?" -gt "0" ]; then
					if ! (whiptail --title "Arch Linux Anywhere" --yesno "Imposibil de conectat la reţeaua Wifi, continuaţi instalarea offline?" 10 60) then
						clear ; exit 1
					fi
				else
					connection=true 
					wifi=true
				fi
			fi
		fi
	else
		connection=true
	fi	
	if "$connection" ; then
		start=$(date +%s)
		wget -O /dev/null http://cachefly.cachefly.net/10mb.test &> /dev/null &
		pid=$! pri=1 msg="Vă rugăm aşteptaţi, se verifică conexiunea..." load
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
				if (whiptail --title "Arch Linux Anywhere" --yesno "Conexiunea dvs este foarte lentă, ar putea să dureze ceva timp...\n\n *Continuaţi instalarea?" 10 60) then
					export down="15"
				else
					exit
				fi
			;;
			*) export down="10" ;;
		esac
	else
		whiptail --title "Arch Linux Anywhere" --msgbox "Eroare. Conexiune indisponibilă, ieşire. \n\n *Încercaţi instalarea Arch-Anywhere offline" 10 60
		clear
		exit 1

	fi
	set_locale
}

set_locale() {
	LOCALE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Selectaţi limba de sistem dorită:" 15 60 6 \
	"en_US.UTF-8" "-" \
	"en_AU.UTF-8" "-" \
	"en_CA.UTF-8" "-" \
	"en_GB.UTF-8" "-" \
	"en_MX.UTF-8" "-" \
	"Other"       "-"		 3>&1 1>&2 2>&3)
	if [ "$LOCALE" = "Other" ]; then
		localelist=$(</etc/locale.gen  awk '{print substr ($1,2) " " ($2);}' | grep -F ".UTF-8" | sed "1d" | sed 's/$/  -/g;s/ UTF-8//g')
		LOCALE=$(whiptail --title "Arch Linux Anywhere" --menu "Selectaţi limba de sistem dorită:" 15 60 6  $localelist 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then set_locale ; fi
	fi
	locale_set=true set_zone
}

set_zone() {
	zonelist=$(find /usr/share/zoneinfo -maxdepth 1 | sed -n -e 's!^.*/!!p' | grep -v "posix\|right\|zoneinfo\|zone.tab\|zone1970.tab\|W-SU\|WET\|posixrules\|MST7MDT\|iso3166.tab\|CST6CDT" | sort | sed 's/$/ -/g')
	ZONE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Introduceţi fusul orar:" 15 60 6 $zonelist 3>&1 1>&2 2>&3)
		check_dir=$(find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE")
		if [ -n "$check_dir" ]; then
			sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g')
			SUBZONE=$(whiptail --title "Arch Linux Anywhere" --menu "Tastaţi o sub-zonă:" 15 60 6 $sublist 3>&1 1>&2 2>&3)
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
	keyboard=$(whiptail --nocancel --inputbox "Setare aranjament tastatură: \n\n *Dacă nu sunteţi sigur lăsaţi implicit" 10 35 "us" 3>&1 1>&2 2>&3)
	keys_set=true prepare_drives
}

prepare_drives() {
	drive=$(lsblk | grep "disk" | grep -v "rom" | awk '{print $1   " "   $4}')
	DRIVE=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Selectatţi discul unde doriţi să instalaţi arch linux:" 15 60 5 $drive 3>&1 1>&2 2>&3)
	PART=$(whiptail --title "Arch Linux Anywhere" --menu "Selectaţi metoda dorită de partiţionare: \n\n *NOTĂ: Partiţionarea automată va formata unitatea selectată \n *Apăsaţi Cancel pentru a reveni la selectare disc" 15 60 4 \
	"Pariţionare automată"           "-" \
	"Partiţionare automată-criptare LVM"   "-" \
	"Partiţionare manuală"         "-" \
	"Înapoi la Meniu"                 "-" 3>&1 1>&2 2>&3)
	if [ "$?" -gt "0" ]; then
		prepare_drives
	elif [ "$PART" == "Înapoi la Meniu" ]; then
		main_menu
	elif [ "$PART" == "Partiţionare automată-criptare LVM" ] || [ "$PART" == "Partiţionare automată" ]; then
		crypted=false
		if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "AVERTISMENT! Va şterge toate datele de pe /dev/$DRIVE! \n\n *Doriţi să continuaţi?" 10 60) then
			sgdisk --zap-all "$DRIVE" &> /dev/null
		else
			prepare_drives
		fi
		FS=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Selectaţi sistemul de fişiere dorit: \n *Implicit este ext4" 15 60 6 \
		"ext4"      "Sistem de fişiere ext4" \
		"ext3"      "Sistem de fişiere ext3" \
		"ext2"      "Sistem de fişiere ext2" \
		"btrfs"     "Sistem de fişiere btrfs" \
		"jfs"       "Sistem de fişiere JFS cu jurnalizare" \
		"reiserfs"  "Sistem de fişiere ReiserFS" 3>&1 1>&2 2>&3)
		SWAP=false
		if (whiptail --title "Arch Linux Anywhere" --yesno "Creaţi zonă de SWAP?" 10 60) then
			d_bytes=$(fdisk -l | grep -w "$DRIVE" | awk '{print $5}') t_bytes=$((d_bytes-2000000000))
			swapped=false
			while [ "$swapped" != "true" ]
				do
					SWAPSPACE=$(whiptail --inputbox --nocancel "Specificaţi dimensiunea pentru zona de swap: \n *(Align to M or G):" 10 35 "512M" 3>&1 1>&2 2>&3)
					unit=$(grep -o ".$" <<< "$SWAPSPACE")
					if [ "$unit" == "M" ]; then unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE") p_bytes=$((unit_size*1000*1000))
						if [ "$p_bytes" -lt "$t_bytes" ]; then SWAP=true swapped=true
						else whiptail --title "Arch Linux Anywhere" --msgbox "Eroare: Spaţiu insuficient pe disc!" 10 60 ; fi
					elif [ "$unit" == "G" ]; then unit_size=$(grep -o '[0-9]*' <<< "$SWAPSPACE") p_bytes=$((unit_size*1000*1000*1000))
						if [ "$p_bytes" -lt "$t_bytes" ]; then SWAP=true swapped=true
						else whiptail --title "Arch Linux Anywhere" --msgbox "Eroare: Spaţiu insuficient pe disc!" 10 60 ; fi
					else whiptail --title "Arch Linux Anywhere" --msgbox "Eroare setare zonă de swap! Asiguraţi-vă că este un număr terminat în 'M' sau 'G'" 10 60 ; fi
				done
		fi
		efivar -l
		if [ "$?" -eq "0" ]; then
			if [ "$arch" == "x86_64" ]; then
				if (whiptail --title "Arch Linux Anywhere" --yesno "Doriţi să activaţi UEFI bios? \n\n *Poate să nu funţioneze pe unele sisteme \n *Activaţi cu prudenţă" 10 60) then
					GPT=true UEFI=true down=$((down+1))
				fi
			fi
		fi
		if ! "$UEFI" ; then GPT=false
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Doriţi să folosiţi partiţionare GPT?" 10 60) then 
				GPT=true
			fi
		fi
	else
		efivar -l
		if [ "$?" -eq "0" ]; then
			if [ "$arch" == "x86_64" ]; then
				if (whiptail --title "Arch Linux Anywhere" --yesno "Doriţi să activaţi UEFI? \n\n *Poate să nu funţioneze pe unele sisteme \n *Activaţi cu prudenţă" 10 60) then
					whiptail --title "Arch Linux Anywhere" --msgbox "Notă: Trebuie să creaţi o partiţie UEFI! \n\n *Dimensiune 512M-1024M tip EF00 \n *Sistemul de partiţie trebuie să fie GPT!" 10 60
					if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Sistemul nu va boota dacă nu setaţi corect o partiţie UEFI! \n\n *Sigur doriţi să continuaţi? \n *Continuaţi numai dacă ştiţi ce faceţi." 10 60) then
						UEFI=true down=$((down+1))
					else
						prepare_drives
					fi	
				fi
			fi
		fi
		part_tool=$(whiptail --title "Arch Linux Anywhere" --menu "Selectaţi utilitarul dorit pentru partiţionare:" 15 60 5 \
					"cfdisk"  "Bun pentru începători" \
					"fdisk"   "Partiţionare CLI" \
					"gdisk"   "Partiţionare GPT" \
					"parted"  "Partiţionare GNU CLI" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then prepare_drives ; fi
	fi
	case "$PART" in
		"Partiţionare automată")
			if "$GPT" ; then
				if "$UEFI" ; then
					if "$SWAP" ; then
						echo -e "n\n\n\n512M\nef00\nn\n3\n\n+512M\n8200\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					else
						echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
					fi
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				else
					if "$SWAP" ; then
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n4\n\n+$SWAPSPACE\n8200\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
						SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==5) print substr ($1,3) }')"
						wipefs -a /dev/"$SWAP" &> /dev/null
						mkswap /dev/"$SWAP" &> /dev/null
						swapon /dev/"$SWAP" &> /dev/null
					else
						echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
						pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
					fi
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"	
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
				fi
			else
				if "$SWAP" ; then
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n3\n\n+$SWAPSPACE\nt\n\n82\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
					SWAP="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"					
					wipefs -a /dev/"$SWAP" &> /dev/null
					mkswap /dev/"$SWAP" &> /dev/null
					swapon /dev/"$SWAP" &> /dev/null
				else
					echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Pariţionare /dev/$DRIVE..." load
				fi				
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
			fi
			wipefs -a /dev/"$BOOT" &> /dev/null
			wipefs -a /dev/"$ROOT" &> /dev/null
			if "$UEFI" ; then
				mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="Se crează partiţia de boot efi..." load
			else
				mkfs -t ext4 /dev/"$BOOT" &> /dev/null &
				pid=$! pri=0.2 msg="Se crează partiţia de boot..." load
			fi
			if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
				echo -e "y" | mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
			else
				mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
				pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
			fi
			mount /dev/"$ROOT" "$ARCH"
			if [ "$?" -eq "0" ]; then
				mounted=true
			fi
			mkdir $ARCH/boot
			mount /dev/"$BOOT" "$ARCH"/boot
		;;
		"Partiţionare automată-criptare LVM")
			if "$GPT" ; then
				if "$UEFI" ; then
					echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				else
					echo -e "o\ny\nn\n1\n\n+100M\n\nn\n2\n\n+1M\nEF02\nn\n3\n\n\n\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null &
					pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
					ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==4) print substr ($1,3) }')"
					BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				fi
			else
				echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\nw" | fdisk /dev/"$DRIVE" &> /dev/null &
				pid=$! pri=0.3 msg="Partiţionare /dev/$DRIVE..." load
				BOOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==2) print substr ($1,3) }')"
				ROOT="$(lsblk | grep "$DRIVE" |  awk '{ if (NR==3) print substr ($1,3) }')"
				
			fi
			if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Avertisment: Această acţiune va cripta /dev/$DRIVE \n\n *Continuaţi?" 10 60) then
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
            	    	input=$(whiptail --passwordbox --nocancel "Tastaţi o parolă nouă pentru /dev/$DRIVE \n\n *Notă: Această parolă este folosită pentru decriptarea disc-ului la boot-are" 10 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            	    	input_chk=$(whiptail --passwordbox --nocancel "Taastaţi din nou parola pentru /dev/$DRIVE again..." 9 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            	        if [ "$input" != "$input_chk" ]; then
            	        	whiptail --title "Arch Linux Anywhere" --msgbox "Parolele nu se potrivesc, încercaţi din nou." 10 60
            	        fi
            	 	done
				printf "$input" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/lvm/lvroot - &
				pid=$! pri=0.2 msg="Criptare disc..." load
				printf "$input" | cryptsetup open --type luks /dev/lvm/lvroot root -
				input=""
				if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
					echo -e "y" | mkfs -t "$FS" /dev/mapper/root &> /dev/null &
					pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS " load
				else
					mkfs -t "$FS" /dev/mapper/root &> /dev/null &
					pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
				fi
				mount /dev/mapper/root "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
					crypted=true
				fi
				wipefs -a /dev/"$BOOT" &> /dev/null
				if "$UEFI" ; then
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Se crează partiţia de boot efi..." load
				else
					mkfs -t ext4 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Se crează partiţia de boot..." load
				fi
				mkdir $ARCH/boot
				mount /dev/"$BOOT" "$ARCH"/boot
			else
				prepare_drives
			fi
		;;
		"Partiţionare manuală")
			clear
			$part_tool /dev/"$DRIVE"
			lsblk | egrep "$DRIVE[0-9]"
			if [ "$?" -gt "0" ]; then
				whiptail --title "Arch Linux Anywhere" --msgbox "O eroare a fost detectată în timpul partiţionării \n\n *Revenire la meniul partiţionare" 10 60
				prepare_drives
			fi
			clear
			partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K" | sed "1d" | cut -c7- | awk '{print $1" "$4}')
			if "$UEFI" ; then
				BOOT=$(whiptail --nocancel --title "Arch Linux Anywhere" --nocancel --menu "Selectaţi partiţia de boot EFI: \n\n *Generally the first partition size of 512M-1024M" 15 60 5 $partition 3>&1 1>&2 2>&3)
				i=$(<<<$BOOT cut -c4-)
				if (whiptail --title "Arch Linux Anywhere" --yesno "This will create a fat32 formatted EFI partition. \n\n *Are you sure you want to do this?" 10 60) then
					echo -e "t\n${i}\nEF00\nw\ny" | gdisk /dev/"$DRIVE" &> /dev/null
					mkfs.vfat -F32 /dev/"$BOOT" &> /dev/null &
					pid=$! pri=0.2 msg="Se crează partiţia de boot efi..." load
				else
					prepare_drives
				fi
				partition=$(lsblk | grep "$DRIVE" | grep -v "/\|1K\|$BOOT" | sed "1d" | cut -c7- | awk '{print $1" "$4}')
			fi
			ROOT=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Selectaţi partiţia dorită pentru root: \n\n *This is the main partition all others will be under" 15 60 5 $partition 3>&1 1>&2 2>&3)
			if (whiptail --title "Arch Linux Anywhere" --yesno "Această operaţiune va crea un sistem de fişiere pe partiţie. \n\n *Sigur doriţi acest lucru?" 10 60) then
				FS=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Selectaţi sistemul de fişiere dorit: \n\n *Implicit este ext4" 15 60 6 \
				"ext4"      "Sistem de fişiere ext4" \
				"ext3"      "Sistem de fişiere ext3" \
				"ext2"      "Sistem de fişiere ext2" \
				"btrfs"     "Sistem de fişiere btrfs" \
				"jfs"       "Sistem de fişiere JFS cu jurnalizare" \
				"reiserfs"  "Sistem de fişiere ReiserFS" 3>&1 1>&2 2>&3)
				wipefs -a -q /dev/"$ROOT" &> /dev/null
				if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
					echo -e "y" | mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
				else
					mkfs -t "$FS" /dev/"$ROOT" &> /dev/null &
					pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
				fi
				mount /dev/"$ROOT" "$ARCH"
				if [ "$?" -eq "0" ]; then
					mounted=true
				else
					whiptail --title "Arch Linux Anywhere" --msgbox "O eroare a fost detectată în timpul partiţionării \n\n *Revenire la meniul partiţionare" 10 60
					prepare_drives
				fi
			else
				prepare_drives
			fi
			if "$UEFI" ; then
				points=$(echo -e "/home   >\n/srv    >\n/usr    >\n/var    >\nSWAP   >")
				mkdir $ARCH/boot
				mount /dev/"$BOOT" "$ARCH"/boot
			else
				points=$(echo -e "/boot   >\n/home   >\n/srv    >\n/usr    >\n/var    >\nSWAP   >")
			fi
			until [ "$new_mnt" == "Done" ] 
				do
					partition=$(lsblk | grep "$DRIVE" | grep -v "/\|[SWAP]\|1K" | sed "1d" | cut -c7- | awk '{print $1"     "$4}')
					new_mnt=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Selectaţi o partiţie pentru a crea un punct de montare: \n\n *Selectaţi done când aţi terminat*" 15 60 6 $partition "Done" "Continue" 3>&1 1>&2 2>&3)
					if [ "$new_mnt" != "Done" ]; then
						MNT=$(whiptail --title "Arch Linux Anywhere" --menu "Selectaţi un punct de montare pentru /dev/$new_mnt" 15 60 6 $points 3>&1 1>&2 2>&3)
						if [ "$?" -gt "0" ]; then
							:
						elif [ "$MNT" == "SWAP" ]; then
							if (whiptail --title "Arch Linux Anywhere" --yesno "Va crea o zonă de swap pe /dev/$new_mnt \n\n *Continuaţi?" 10 60) then
								wipefs -a -q /dev/"$new_mnt"
								mkswap /dev/"$new_mnt" &> /dev/null
								swapon /dev/"$new_mnt" &> /dev/null
							fi
						else
							if (whiptail --title "Arch Linux Anywhere" --yesno "Va crea un punct de montare pentru $MNT cu /dev/$new_mnt \n\n *Continuaţi?" 10 60) then
								FS=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Selectaţi tipul de sistem de fişiere pentru $MNT: \n\n *Implicit este ext4" 15 60 6 \
								"ext4"      "4th extended file system" \
								"ext3"      "3rd extended file system" \
								"ext2"      "2nd extended file system" \
								"btrfs"     "B-Tree File System" \
								"jfs"       "Journaled File System" \
								"reiserfs"  "Reiser File System" 3>&1 1>&2 2>&3)
								wipefs -a -q /dev/"$new_mnt"
								if [ "$FS" == "jfs" ] || [ "$FS" == "reiserfs" ]; then
									echo -e "y" | mkfs -t "$FS" /dev/"$new_mnt" &> /dev/null &
									pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
								else
									mkfs -t "$FS" /dev/"$new_mnt" &> /dev/null &
									pid=$! pri=1 msg="Vă rugăm aşteptaţi până se crează sistemul de fişiere $FS ..." load
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
	clear
	if ! "$mounted" ; then
		whiptail --title "Arch Linux Anywhere" --msgbox "O eroare a fost detectată în timpul partiţionării \n\n *Revenire la meniul partiţionare" 10 60
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
			if "$wifi" ; then
				pacstrap "$ARCH" base base-devel libnewt wireless_tools wpa_supplicant wpa_actiond netctl dialog &> /dev/null &
				pid=$! pri="$down" msg="Vă rugăm aşteptaţi până se instalează Arch Linux... \n\n *Acest lucru poate să dureze" load
			else
				if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Install wireless tools, netctl, and WPA supplicant? Provides wifi-menu command. \n\n *Necessary for connecting to wifi \n *Select yes if using wifi" 11 60) then
					pacstrap "$ARCH" base base-devel libnewt wireless_tools wpa_supplicant wpa_actiond netctl dialog &> /dev/null &
					pid=$! pri="$down" msg="Vă rugăm aşteptaţi până se instalează Arch Linux... \n\n *Acest lucru poate să dureze" load
				else
					pacstrap "$ARCH" base base-devel libnewt &> /dev/null &
					pid=$! pri="$down" msg="Vă rugăm aşteptaţi până se instalează Arch Linux... \n\n *Acest lucru poate să dureze" load
				fi
			fi
			genfstab -U -p "$ARCH" >> "$ARCH"/etc/fstab
			INSTALLED=true
			while [ ! -n "$loader" ]
				do
					if (whiptail --title "Arch Linux Anywhere" --yesno "Instalaţi bootloader-ul GRUB? \n\n *Necesar pentru a face sistemul bootabil" 10 60) then
						if (whiptail --title "Arch Linux Anywhere" --defaultno --yesno "Instalaţi întâi os-prober? \n\n *Necesar pentru multiboot \n *Dacă aveţi dual boot selectaţi yes" 10 60) then
							pacstrap "$ARCH" os-prober &> /dev/null &
							pid=$! pri=0.5 msg="Instalare os-prober..." load
						fi
						pacstrap "$ARCH" grub &> /dev/null &
						pid=$! pri=0.5 msg="Instalare grub..." load
						if [ "$crypted" == "true" ]; then
							sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$ARCH"/etc/default/grub
						fi
						if "$UEFI" ; then
							pacstrap "$ARCH" efibootmgr &> /dev/null &
							pid=$! pri=0.5 msg="Se instaleză efibootmgr..." load
							arch-chroot "$ARCH" grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot --recheck &> /dev/null &
							pid=$! pri=0.5 msg="Instalare grub pe disc..." load
							mv "$ARCH"/boot/EFI/boot/grubx64.efi "$ARCH"/boot/EFI/boot/bootx64.efi
						else
							arch-chroot "$ARCH" grub-install --recheck /dev/"$DRIVE" &> /dev/null &
							pid=$! pri=0.5 msg="Instalare grub pe disc..." load
						fi
						arch-chroot "$ARCH" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
						pid=$! pri=0.2 msg="Configurare grub..." load
						if [[ "$UEFI" == "true" && "$crypted" == "false" ]] ; then
							arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
							pid=$! pri=1 msg="Vă rugăm aşteptaţi până se configureză kernel-ul pentru uEFI..." load
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
			echo "/dev/$BOOT              /boot           vfat         rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro        0       2" > "$ARCH"/etc/fstab
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
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE"/"$SUB_SUBZONE" /etc/localtime &
		pid=$! pri=0.2 msg="Setting timezone $ZONE $SUBZONE $SUB_SUBZONE..." load
	elif [ -n "$SUBZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" /etc/localtime &
		pid=$! pri=0.2 msg="Setting timezone $ZONE $SUBZONE..." load
	elif [ -n "$ZONE" ]; then
		arch-chroot "$ARCH" ln -s /usr/share/zoneinfo/"$ZONE" /etc/localtime &
		pid=$! pri=0.2 msg="Setting timezone $ZONE..." load
	fi
	if [ "$arch" == "x86_64" ]; then
		if (whiptail --title "Arch Linux Anywhere" --yesno "64 bit architecture detected.\n\n *Add multilib repos to pacman.conf?" 10 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
		fi
	fi
	if (whiptail --title "Arch Linux Anywhere" --yesno "Activaţi DHCP la bootare? \n\n *Configurare automată IP." 10 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.2 msg="Se activează DHCP..." load
	fi
	system_configured=true
	set_hostname
}

set_hostname() {
	hostname=$(whiptail --nocancel --inputbox "Set your system hostname:" 10 40 "arch" 3>&1 1>&2 2>&3)
	echo "$hostname" > "$ARCH"/etc/hostname
	echo -e 'input=default
		while [ "$input" != "$input_chk" ]
            		do
                   		input=$(whiptail --passwordbox --nocancel "Tastaţi o parolă pentru root \n\n *Setaţi o parolă puternică" 10 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            			input_chk=$(whiptail --passwordbox --nocancel "Tastaţi din nou parola pentru root" 9 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
                   		 if [ "$input" != "$input_chk" ]; then
                      	      whiptail --title "Arch Linux Anywhere" --msgbox "Parolele nu se potrivesc, încercaţi din nou." 10 60
                     	 fi
         		    done
    			echo -e "$input\n$input\n" | passwd &> /dev/null' > /mnt/root/set.sh
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
		user=$(whiptail --nocancel --inputbox "Setare utilizator: \n\n *Numai litere şi numere \n *Fără spaţii sau caractere speciale!" 10 60 "" 3>&1 1>&2 2>&3)
		user=$(<<<$user sed 's/ //g')
		user_check=$(<<<$user grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()_-+=<>~;:/?.,^{}]\|]")
		if [ -n "$user_check" ]; then
			whiptail --title "Arch Linux Anywhere" --msgbox "Eroare: Utilizatorul trebuie să înceapă cu litere şi nu carcatere speciale. \n\n *Încercaţi din nou." 10 60
			add_user
		fi
	else
		graphics
	fi
	arch-chroot "$ARCH" useradd -m -g users -G wheel,audio,network,power,storage,optical -s /bin/bash "$user"
	echo -e 'user='$user'
			   input=default
			           while [ "$input" != "$input_chk" ]
            				do
                   					 input=$(whiptail --passwordbox --nocancel "Tastaţi o parolă nouă pentru $user" 9 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
            				         input_chk=$(whiptail --passwordbox --nocancel "Tastaţi din nou parola nouă pentru $user " 9 78 --title "Arch Linux Anywhere" 3>&1 1>&2 2>&3)
                   					 if [ "$input" != "$input_chk" ]; then
                      				      whiptail --title "Arch Linux Anywhere" --msgbox "Parolele nu se potrivesc, încercaţi din nou." 10 60
                     				 fi
         				        done
    					echo -e "$input\n$input\n" | passwd "$user" &> /dev/null' > /mnt/root/set.sh
	chmod +x "$ARCH"/root/set.sh
	arch-chroot "$ARCH" ./root/set.sh
	rm "$ARCH"/root/set.sh
	if (whiptail --title "Arch Linux Anywhere" --yesno "Activaţi privilegiu sudo pentru $user? \n\n *Activaţi privilegii administrative pentru $user." 10 60) then
		sed -i '/%wheel ALL=(ALL) ALL/s/^#//' $ARCH/etc/sudoers
	fi
	user_added=true graphics
}
	
graphics() {
	if (whiptail --title "Arch Linux Anywhere" --yesno "Doriţi să instalaţi xorg-server? \n\n *Selectaţi yes pentru o interfaţă grafică" 10 60) then
		GPU=$(whiptail --title "Arch Linux Anywhere" --nocancel --menu "Selectaţi driverul video dorit: \n\n *Dacă sunteţi nesigur folosiţi mesa-libgl sau implicit \n *Dacă instalaţi în VirtualBox selectaţi guest-utils" 17 60 6 \
		"Default"				 "Implicit" \
		"mesa-libgl"             "Driver Mesa" \
		"Nvidia"                 "Driver NVIDIA" \
		"Vbox-Guest-Utils"       "Driver VirtualBox" \
		"xf86-video-ati"         "Driver AMD/ATI" \
		"xf86-video-intel"       "Driver Intel" 3>&1 1>&2 2>&3)
	else
		if (whiptail --title "Arch Linux Anywhere" --yesno "Sigur doriţi să nu instalaţi xorg-server? \n\n *You will be booted into command line only." 10 60) then
			install_software
		else
			graphics
		fi
	fi
	if [ "$GPU" == "Nvidia" ]; then
			GPU=$(whiptail --title "Arch Linux Anywhere" --menu "Selectaţi driverul Nvidia dorit: \n\n *Cancel if none" 15 60 4 \
			"nvidia"       "Latest stable nvidia" \
			"nvidia-340xx" "Legacy 340xx branch" \
			"nvidia-304xx" "Legaxy 304xx branch" 3>&1 1>&2 2>&3)
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
	pacstrap "$ARCH" xorg-server xorg-server-utils xorg-xinit xterm $(echo "$GPU") &> /dev/null &
	pid=$! pri="$down" msg="Vă rugăm aşteptaţi până se instalează xorg-server..." load
	if (whiptail --title "Arch Linux Anywhere" --yesno "Doriţi să instalaţi un mediu desktop sau manager de ferestre?" 10 60) then
		until [ "$DE" == "set" ]
			do
				i=false
				DE=$(whiptail --title "Arch Linux Installer" --menu "Selectaţi mediul desktop dorit:" 15 60 6 \
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
					if (whiptail --title "Arch Linux Anywhere" --yesno "Doriţi să instalaţi managerul de ferestre LightDM? \n\n *Manager de logare grafic." 10 60) then
						pacstrap "$ARCH" lightdm lightdm-gtk-greeter &> /dev/null &
						pid=$! pri="$down" msg="Vă rugăm aşteptaţi până se instalează LightDM..." load
						arch-chroot "$ARCH" systemctl enable lightdm.service &> /dev/null
					else
						whiptail --title "Arch Linux Anywhere" --msgbox "După logare folosiţi comanda 'startx' pentru a accesa desktopul dvs." 10 60
					fi
				fi
				case "$DE" in
					"xfce4") start_term="exec startxfce4" 
						if (whiptail --title "Arch Linux Installer" --yesno "Instalaţi suplimente(addons) xfce4?" 10 60) then
							DE_EXTRA="xfce4-goodies"
						fi ;;
					"gnome") start_term="exec gnome-session"
						if (whiptail --title "Arch Linux Installer" --yesno "Install gnome extras?" 10 60) then
							DE_EXTRA="gnome-extra" down=$((down+5))
						fi ;;
					"mate") start_term="exec mate-session"
						if (whiptail --title "Arch Linux Installer" --yesno "Install mate extras?" 10 60) then
							DE_EXTRA="mate-extra" down=$((down+2))
						fi ;;
					"KDE plasma") start_term="exec startkde" DE="kde-applications"
						if (whiptail --title "Arch Linux Installer" --defaultno --yesno "Install minimal plasma desktop?" 10 60) then
							DE_EXTRA="plasma-desktop" down=$((down+4))
						else
							DE_EXTRA="plasma" down=$((down+5))
						fi ;;
					"cinnamon") start_term="exec cinnamon-session" ;;
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
					pacstrap "$ARCH" $(echo "$DE") &> /dev/null &
					pid=$! pri="$down" msg="Please wait while installing desktop... \n\n *This may take awhile" load
					if [ "$user_added" == "true" ]; then
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
	if (whiptail --title "Arch Linux Anywhere" --yesno "Would you like to install some common software? \n\n *Select yes for a list of additional software" 10 60) then
		software=$(whiptail --title "Arch Linux Anywhere" --checklist "Choose your desired software: \n\n *Use spacebar to check/uncheck software \n *Press enter when finished" 20 60 10 \
					"arch-wiki"            "Arch wiki from the CLI" ON \
					"openssh"     	       "Secure Shell Deamon" ON \
					"pulseaudio"  	       "Popular sound server" ON \
					"screenfetch"          "Display System Info" ON \
					"vim"         	       "Popular Text Editor" ON \
					"wget"        	       "CLI web downloader" ON \
					"apache"  	  	       "Web Server" OFF \
					"audacity"             "Audio editing program" OFF \
					"chromium"    	       "Graphical Web Browser" OFF \
					"cmus"        	       "CLI music player" OFF \
					"conky"       	       "Light system monitor for X" OFF \
					"dropbox"              "Cloud file sharing" OFF \
					"emacs"                "OS in a text editor" OFF \
					"firefox"     	       "Graphical Web Browser" OFF \
					"gimp"        	       "GNU Image Manipulation " OFF \
					"git"                  "Source control managment" OFF \
					"gparted"     	       "GNU Parted GUI" OFF \
					"htop"        	       "CLI process Info" OFF \
					"libreoffice" 	       "Open source word processing " OFF \
					"lmms"                 "Linux MultiMedia Studio" OFF \
					"lynx"        	       "Terminal Web Browser" OFF \
					"mpd"         	       "Music Player Daemon" OFF \
					"mplayer"     	       "Media Player" OFF \
					"ncmpcpp"     	       "GUI client for MPD" OFF \
					"nmap"                 "CLI network analyzer" OFF \
					"pitivi"               "Video editing software" OFF \
					"projectm"             "Music visuliaztions" OFF \
					"screen"  	  	       "GNU Screen" OFF \
					"simplescreenrecorder" "Screen capture software" OFF \
					"steam"                "Multi-platform gaming" OFF \
					"tmux"    	  	   	   "Terminal multiplxer" OFF \
					"transmission-cli" 	   "CLI torrent client" OFF \
					"transmission-gtk"     "Graphical torrent client" OFF \
					"virtualbox"  	       "Desktop virtuialization" OFF \
					"vlc"         	   	   "GUI media player" OFF \
					"ufw"         	       "Uncomplicated Firewall" OFF \
					"zsh"                  "The Z-Shell" OFF 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			reboot_system
		fi
		download=$(echo "$software" | sed 's/\"//g')
		wiki=$(<<<$download grep "arch-wiki")
		if [ -n "$wiki" ]; then
			wget -O "$ARCH"/usr/bin/arch-wiki https://raw.githubusercontent.com/deadhead420/archlinux/master/wiki/wiki.sh &> /dev/null &
			pid=$! pri=1 msg="Instalare arch-wiki..." load
			chmod +x "$ARCH"/usr/bin/arch-wiki
			download=$(<<<$download sed 's/arch-wiki/lynx/')
		fi
    	pacstrap "$ARCH" ${download} &> /dev/null &
    	pid=$! pri=1 msg="Vă rugăm aşteptaţi până se instalează programele... \n\n *Acest lucru poate dura, în funcţie de programele selectate" load
	fi
	arch-chroot "$ARCH" pacman -Syy &> /dev/null &
	pid=$! pri=1 msg="Actualizarea bazelor de date pacman..." load
	reboot_system
}

reboot_system() {
	if "$INSTALLED" ; then
		if ! "$bootloader" ; then
			if (whiptail --title "Arch Linux Anywhere" --yesno "Instalare completă! \n\n *Nu aţi configurat un bootloader \n *Reveniţi în linia de comandă pentru configurare?" 10 60) then
				clear ; exit
			fi
		fi
		if (whiptail --title "Arch Linux Anywhere" --yesno "Instalare completă! Restartez acum? \n\n *Selectaţi yes pentru a restarta acum \n *No pentru a reveni în linia de comandă" 10 60) then
			umount -R $ARCH
		    clear ; reboot ; exit
		else
			if (whiptail --title "Arch Linux Anywhere" --yesno "Sistem instalat complet \n\n *Would you like to unmount?" 10 60) then
				umount -R "$ARCH"
				clear ; exit
			else
				clear ; exit
			fi
		fi
	else
		if (whiptail --title "Arch Linux Anywhere" --yesno "Instalarea nu este completă, sigur doriţi să restartaţi?" 10 60) then
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
	return=(whiptail --title "Arch Linux Anywhere" --msgbox "Sistemul nu este instalat încă \n *revenire la meniu" 10 60)
	menu_item=$(whiptail --nocancel --title "Arch Linux Anywhere" --menu "Iteme Meniu:" 15 60 6 \
		"Setare localizare"			"-" \
		"Setare fus orar"       	"-" \
		"Setare tastatură"      	"-" \
		"Partiţionare hard"     	"-" \
		"Actualizare Mirror"       	"-" \
		"Instalare sistem de bază"  "-" \
		"Configurare Sistem"      	"-" \
		"Setare Hostname"          	"-" \
		"Adăugare Utilizator"   	"-" \
		"Install drivere video"    	"-" \
		"Instalare programe"      	"-" \
		"Restartare Sistem"        	"-" \
		"Ieşire Instalare"        	"-" 3>&1 1>&2 2>&3)
	case "$menu_item" in
		"Setare localizare" ) 
			if "$locale_set" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Localizarea este setată deja, revenire la meniu" 10 60 ; main_menu ; fi
			set_locale ;;
		"Setare fus orar")
			if "$zone_set" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Fusul orar este setat deja, revenire la meniu" 10 60 ; main_menu ; fi
			set_zone ;;
		"Setare tastatură")
			if "$keys_set" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Tastatura este setată deja, revenire la meniu" 10 60 ; main_menu ; fi
			set_keys ;;
		"Partiţionare hard")
			if "$mounted" ; then whiptail --title "Arch Linux Anywhere" --msgbox "Unitatea este montată deja, încercaţi instalarea sistemului de bază \n revenire la meniu" 10 60 ; main_menu ; fi
 			prepare_drives ;;
		"Actualizare Mirror-uri") update_mirrors ;;
		"Instalare sistem de bază") install_base ;;
		"Configurare sistem") if "$INSTALLED" ; then configure_system ; fi ;;
		"Setare hostname") if "$INSTALLED" ; then set_hostname ; fi ;;
		"Adăugare utilizator") if "$INSTALLED" ; then add_user ; fi ;;
		"Instalare drivere video") if "$INSTALLED" ; then graphics ; fi ;;
		"Instalare programe") if "$INSTALLED" ; then install_software ; fi ;;
		"Restartare Sistem") reboot_system ;;
		"Ieşire Instalare") 
			if "$INSTALLED" ; then
				whiptail --title "Arch Linux Anywhere" --msgbox "Sistemul este instalat \n\n Ieşire instalare arch..." 10 60
				clear ; exit
			else
				if (whiptail --title "Arch Linux Anywhere" --yesno "Sistemul nu este instalat încă... \n\n Sigur doriţi să ieşiţi?" 10 60) then
					clear ; exit
				else
					main_menu
				fi
			fi
		;;
	esac
	$return ; main_menu
}
check_connection
