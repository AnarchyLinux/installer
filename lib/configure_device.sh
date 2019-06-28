#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### configure_device.sh
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

prepare_drives() {

	op_title="$part_op_msg"
	if (df | grep "$ARCH" &> /dev/null); then
		umount -R "$ARCH" &> /dev/null &
		pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2umount -R $ARCH\Zn" load
		swapoff -a &> /dev/null &
	fi

	until "$mounted"
	  do
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
				$(lsblk -nio NAME,SIZE,TYPE | egrep "disk|raid[0-9]+$" | sed 's/[^[:alnum:]_., ]//g' | column -t | sort -k 1,1 | uniq | awk '{print "\""$1"\"""  ""\"| "$2" | "$3" |==>\""" \\"}' | column -t)
				3>&1 1>&2 2>&3
			EOF

			DRIVE=$(bash "$tmp_menu")
			rm "$tmp_menu"

			if [ -n "$DRIVE" ]; then
				if (<<<"$DRIVE" egrep "nvme.*|mmc.*|md.*" &> /dev/null) then
					PART_PREFIX="p"
				fi

				drive_byte=$(lsblk -nibo NAME,SIZE | grep -w "$DRIVE" | awk '{print $2}')
				drive_mib=$((drive_byte/1024/1024))
				drive_gigs=$((drive_mib/1024))
				f2fs=$(lsblk -dnro ROTA /dev/$DRIVE)
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
					unset PART
				fi
			else
				continue
			fi
		fi

		case "$PART" in
			"$method0")
					auto_part
					if ! "$mounted" ; then
						dialog --ok-button "$ok" --msgbox "\n$part_err_msg" 10 60
					fi
			;;
			"$method1")
					auto_encrypt
					if ! "$mounted" ; then
						dialog --ok-button "$ok" --msgbox "\n$part_err_msg" 10 60
					fi
			;;
			"$method2")
					points=$(echo -e "$points_orig\n$custom $custom-mountpoint")
					part_menu
			;;
		esac
	done

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
		return
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
	dev_menu="|  Device:  |  Size:  |  Used:  |  FS:  |  Mount:  |  Type:  |"
	device_list=$(lsblk -no NAME,SIZE,TYPE,FSTYPE | egrep -v "$USB|loop[0-9]+|sr[0-9]+|fd[0-9]+" | sed 's/[^[:alnum:]_., -]//g' | column -t | sort -k 1,1 | uniq)
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

		test -z "$dev_fs" || test "$dev_fs" == "linux_raid_member" && dev_fs=$empty_value
		test -z "$dev_used" && dev_used=$empty_value
		test -z "$dev_mnt" && dev_mnt=$empty_value

		parent_device=$(lsblk -dnro PKNAME /dev/${device/-//})
		if [ -z "$parent_device" ]; then
			dev_type=$(<<<"$device_list" grep -w "$device" | awk '{print $3}')
		else
			dev_type=$(fdisk -lo Device,Type /dev/$parent_device | grep -w "$device" | cut -d ' ' -f 2- | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//;s/ /_/g')
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
		return
	else
		part_size=$(<<<"$device_list" grep -w "$part" | awk '{print $2}')
		part_type=$(<<<"$device_list" grep -w "$part" | awk '{print $3}')
		part_fs=$(<<<"$device_list" grep -w "$part" | awk '{print $4}')
		part_mount=$(df | grep -w "$part" | awk '{print $6}' | sed 's/mnt\/\?//')
	fi

	if [ "$part_type" == "lvm" ]; then
		part=${part/-//}
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
				select_util
				if "$gpart" ; then
					$UTIL /dev/"$part" &>/dev/null
				else
					$UTIL /dev/"$part"
				fi
				sleep 0.5
				clear
			fi
		elif (dialog --yes-button "$edit" --no-button "$cancel" --yesno "\n$manual_part_var3" 12 60) then
			select_util
			if "$gpart" ; then
				$UTIL /dev/"$part" &>/dev/null
			else
				$UTIL /dev/"$part"
			fi
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
				return
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
						f2fs=$(lsblk -dnro ROTA /dev/$part)
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
								if [ "$part_type" == "lvm" ]; then
									lvm_pv=$(lvdisplay -m | grep -A 20 /dev/$part | grep "Physical volume" | sed 's/^\s\+//g;s/\s\+/ /g' | cut -d ' ' -f 3)
									DRIVE=$(lsblk -dnro PKNAME $lvm_pv)
								else
									DRIVE=$(lsblk -dnro PKNAME /dev/$part)
								fi
							else
								dialog --ok-button "$ok" --msgbox "\n$part_err_msg1" 10 60
								return
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
			if (fdisk -l /dev/$(lsblk -dnro PKNAME /dev/$part) | grep "gpt" &>/dev/null) then
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
					f2fs=$(lsblk -dnro ROTA /dev/$part)

					if [ "$mnt" == "/boot/EFI" ] || [ "$mnt" == "/boot/efi" ]; then
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
			FS=$(dialog --nocancel --menu "$fs_msg" 17 65 8 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"btrfs"     "$fs3" \
				"f2fs"	    "$fs6" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" \
				"xfs"       "$fs8" 3>&1 1>&2 2>&3)
		elif "$btrfs" ; then
			FS=$(dialog --nocancel --menu "$fs_msg" 16 65 7 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"btrfs"     "$fs3" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" \
				"xfs"       "$fs8" 3>&1 1>&2 2>&3)
		else
			FS=$(dialog --nocancel --menu "$fs_msg" 15 65 6 \
				"ext4"      "$fs0" \
				"ext3"      "$fs1" \
				"ext2"      "$fs2" \
				"jfs"       "$fs4" \
				"reiserfs"  "$fs5" \
				"xfs"       "$fs8" 3>&1 1>&2 2>&3)
				btrfs=true
		fi
	fi

	if [ "$FS" == "f2fs" ]; then
		enable_f2fs=true
	elif [ "$FS" == "btrfs" ]; then
		enable_btrfs=true
  elif [ "$FS" == "xfs" ]; then
		enable_xfs=true
	fi

}

select_util() {

	gpart=false

	if "$GUI" ; then
		UTIL=$(dialog --menu "$vfat_msg" 14 65 4 \
			"gparted"	"$part_util" \
			"cfdisk"	"$part_util0" \
			"fdisk"		"$part_util1" \
			"gdisk"		"$part_util2" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			part_menu
		elif [ "$UTIL" == "gparted" ]; then
			gpart=true
		fi
	else
		UTIL=$(dialog --menu "$vfat_msg" 13 65 3 \
			"cfdisk"	"$part_util0" \
			"fdisk"		"$part_util1" \
			"gdisk"		"$part_util2" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			part_menu
		fi
	fi

}

# vim: ai:ts=8:sw=8:sts=8:noet
