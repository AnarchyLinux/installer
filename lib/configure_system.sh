#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
### configure_system.sh
###
### Copyright (C) 2017 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: http://arch-anywhere.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0
###############################################################

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
			elif [ "$kernel" == "linux-hardened" ]; then
				echo -e "$hardened_hook\nExec = /usr/bin/cp /boot/{vmlinuz-linux-hardened,initramfs-linux-hardened.img,initramfs-linux-hardened-fallback.img} ${esp_mnt}" > "$ARCH"/etc/pacman.d/hooks/linux-esp.hook
				cp "$ARCH"/boot/{vmlinuz-linux-hardened,initramfs-linux-hardened.img,initramfs-linux-hardened-fallback.img} ${ARCH}${esp_mnt}
			elif [ "$kernel" == "linux-zen" ]; then
                                echo -e "$zen_hook\nExec = /usr/bin/cp /boot/{vmlinuz-linux-zen,initramfs-linux-zen.img,initramfs-linux-zen-fallback.img} ${esp_mnt}" > "$ARCH"/etc/pacman.d/hooks/linux-esp.hook
                                cp "$ARCH"/boot/{vmlinuz-linux-zen,initramfs-linux-zen.img,initramfs-linux-zen-fallback.img} ${ARCH}${esp_mnt}
			fi) &
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

	if (<<<"$BOOT" egrep "nvme.*" &> /dev/null) then
		sed -i 's/MODULES="/MODULES="nvme /;s/ "/"/' "$ARCH"/etc/mkinitcpio.conf
		if ! "$crypted" ; then
			arch-chroot "$ARCH" mkinitcpio -p "$kernel" &>/dev/null &
			pid=$! pri=1 msg="\n$kernel_config_load \n\n \Z1> \Z2mkinitcpio -p $kernel\Zn" load
		fi
		echo "$(date -u "+%F %H:%M") : Configure system for nvme" >> "$log"
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

	if [ -n "$config_DE" ]; then
		config_env &
		pid=$! pri="0.1" msg="$wait_load \n\n \Z1> \Z2arch-anywhere config_env\Zn" load
	fi

	if "$add_repo" ; then
		echo -e "\n[arch-anywhere]\nServer = $aa_repo\nSigLevel = Never" >> "$ARCH"/etc/pacman.conf
	fi

	if "$multilib" ; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' "$ARCH"/etc/pacman.conf
		echo "$(date -u "+%F %H:%M") : Include multilib" >> "$log"
	fi

	if "$aa_repo" ; then
		sed -i -e '$a\\n[arch-anywhere]\nServer = http://arch-anywhere.org/repo/$arch\nSigLevel = Never' "$ARCH"/etc/pacman.conf
	fi

	if "$dhcp" ; then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.1 msg="\n$dhcp_load \n\n \Z1> \Z2systemctl enable dhcpcd\Zn" load
		echo "$(date -u "+%F %H:%M") : Enable dhcp" >> "$log"
	fi

	if [ -f "$ARCH"/var/lib/pacman/db.lck ]; then
		rm "$ARCH"/var/lib/pacman/db.lck &> /dev/null
	fi

	arch-chroot "$ARCH" pacman -Sy &> /dev/null &
	pid=$! pri=0.8 msg="\n$pacman_load \n\n \Z1> \Z2pacman -Sy\Zn" load
	echo "$(date -u "+%F %H:%M") : Updated pacman databases" >> "$log"

	if [ "$sh" == "/bin/bash" ]; then
		cp "$ARCH"/etc/skel/.bash_profile "$ARCH"/root/
	elif [ "$sh" == "/usr/bin/zsh" ]; then
		cp "$aa_dir"/extra/.zshrc "$ARCH"/root/
		cp "$aa_dir"/extra/.zshrc "$ARCH"/etc/skel/
	elif [ "$shell" == "fish" ]; then
		echo "exec fish" >> "$aa_dir"/extra/.bashrc-root
		echo "exec fish" >> "$aa_dir"/extra/.bashrc
	elif [ "$shell" == "tcsh" ]; then
		cp "$aa_dir"/extra/{.tcshrc,.tcshrc.conf} "$ARCH"/root/
		cp "$aa_dir"/extra/{.tcshrc,.tcshrc.conf} "$ARCH"/etc/skel/
	elif [ "$shell" == "mksh" ]; then
		cp "$aa_dir"/extra/.mkshrc "$ARCH"/root/
		cp "$aa_dir"/extra/.mkshrc "$ARCH"/etc/skel/
	fi

	cp "$aa_dir"/extra/.bashrc-root "$ARCH"/root/.bashrc
	cp "$aa_dir"/extra/.bashrc "$ARCH"/etc/skel/

}

set_hostname() {

	op_title="$host_op_msg"

	while (true)	## Begin set hostname loop
	  do		## Prompt user to enter hostname check for starting with numbers or containg special char
		hostname=$(dialog --ok-button "$ok" --nocancel --inputbox "\n$host_msg" 12 55 "arch-anywhere" 3>&1 1>&2 2>&3 | sed 's/ //g')

		if (<<<$hostname grep "^[0-9]\|[\[\$\!\'\"\`\\|%&#@()+=<>~;:/?.,^{}]\|]" &> /dev/null); then
			dialog --ok-button "$ok" --msgbox "\n$host_err_msg" 10 60
		else
			break
		fi
	done

	echo "$hostname" > "$ARCH"/etc/hostname
	arch-chroot "$ARCH" chsh -s "$sh" &>/dev/null
	echo "$(date -u "+%F %H:%M") : Hostname set: $hostname" >> "$log"
	user=root
	set_password

}
