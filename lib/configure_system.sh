#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Configure new system
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

configure_system() {

	op_title="$config_op_msg"
	
	if "$drm" ; then
		sed -i 's/MODULES=""/MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"/' "$ARCH"/etc/mkinitcpio.conf
		sed -i 's!FILES=""!FILES="/etc/modprobe.d/nvidia.conf"!' "$ARCH"/etc/mkinitcpio.conf
		echo "options nvidia_drm modeset=1" > "$ARCH"/etc/modprobe.d/nvidia.conf
		echo -e "$nvidia_hook\nExec=/usr/bin/mkinitcpio -p linux" > "$ARCH"/etc/pacman.d/hooks/nvidia.hook
		if ! "$crypted" && ! "$enable_f2fs" ; then
			arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
			pid=$! pri=1 msg="\n$kernel_config_load \n\n \Z1> \Z2mkinitcpio -p linux\Zn" load
		fi
	fi

	if "$enable_f2fs" ; then
		sed -i '/MODULES=/ s/.$/ f2fs crc32 libcrc32c crc32c_generic crc32c-intel crc32-pclmul"/;s/" /"/' "$ARCH"/etc/mkinitcpio.conf
		if ! "$crypted" ; then
			arch-chroot "$ARCH" mkinitcpio -p linux &> /dev/null &
			pid=$! pri=1 msg="\n$f2fs_config_load \n\n \Z1> \Z2mkinitcpio -p linux\Zn" load
		fi
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
		sed -i 's/k filesystems k/k lvm2 keymap encrypt filesystems k/' "$ARCH"/etc/mkinitcpio.conf
		arch-chroot "$ARCH" mkinitcpio -p linux) &> /dev/null &
		pid=$! pri=1 msg="\n$encrypt_load1 \n\n \Z1> \Z2mkinitcpio -p linux\Zn" load
	fi

	(sed -i -e "s/#$LOCALE/$LOCALE/" "$ARCH"/etc/locale.gen
	echo LANG="$LOCALE" > "$ARCH"/etc/locale.conf
	arch-chroot "$ARCH" locale-gen) &> /dev/null &
	pid=$! pri=0.1 msg="\n$locale_load_var \n\n \Z1> \Z2LANG=$LOCALE ; locale-gen\Zn" load
	
	if [ "$keyboard" != "$default" ]; then
		echo "KEYMAP=$keyboard" > "$ARCH"/etc/vconsole.conf
		if "$desktop" ; then
			echo -e "Section \"InputClass\"\nIdentifier \"system-keyboard\"\nMatchIsKeyboard \"on\"\nOption \"XkbLayout\" \"$keyboard\"\nEndSection" > "$ARCH"/etc/X11/xorg.conf.d/00-keyboard.conf
		fi
	fi

	(arch-chroot "$ARCH" ln -sf /usr/share/zoneinfo/"$ZONE" /etc/localtime
	sleep 0.5) &
	pid=$! pri=0.1 msg="\n$zone_load_var \n\n \Z1> \Z2ln -sf $ZONE /etc/localtime\Zn" load

	case "$net_util" in
		networkmanager)	arch-chroot "$ARCH" systemctl enable NetworkManager.service &>/dev/null
		pid=$! pri=0.1 msg="\n$nwmanager_msg0 \n\n \Z1> \Z2systemctl enable NetworkManager.service\Zn" load
		;;
		netctl)	arch-chroot "$ARCH" systemctl enable netctl.service &>/dev/null &
    	pid=$! pri=0.1 msg="\n$nwmanager_msg1 \n\n \Z1> \Z2systemctl enable netctl.service\Zn" load
		;;
	esac

    if "$enable_bt" ; then
 	   	arch-chroot "$ARCH" systemctl enable bluetooth &>/dev/null &
    	pid=$! pri=0.1 msg="\n$btenable_msg \n\n \Z1> \Z2systemctl enable bluetooth.service\Zn" load
    fi
	
	if "$desktop" ; then
		echo "$start_term" > "$ARCH"/etc/skel/.xinitrc
		echo "$start_term" > "$ARCH"/root/.xinitrc
	fi
	
	if "$enable_dm" ; then 
		arch-chroot "$ARCH" systemctl enable "$DM".service &> /dev/null &
		pid=$! pri="0.1" msg="$wait_load \n\n \Z1> \Z2systemctl enable "$DM"\Zn" load
	fi
		
	if "$VM" ; then
		case "$virt" in
			vbox)	arch-chroot "$ARCH" systemctl enable vboxservice &>/dev/null &
					pid=$! pri=0.1 msg="\n$vbox_enable_msg \n\n \Z1> \Z2systemctl enable vboxservice\Zn" load
			;;
			vmware)	arch-chroot "$ARCH" systemctl enable vmware-vmblock-fuse &>/dev/null &
					pid=$! pri=0.1 msg="\n$vbox_enable_msg \n\n \Z1> \Z2systemctl enable vboxservice\Zn" load
			;;
		esac
	fi

	if "$de_config" ; then	
		config_env &
		pid=$! pri="0.1" msg="$wait_load \n\n \Z1> \Z2arch-anywhere config_env\Zn" load
	fi	
	
	if [ "$arch" == "x86_64" ]; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n\n$multilib_msg" 11 60) then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf
		fi
	fi
	
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n\n$dhcp_msg" 11 60) then
		arch-chroot "$ARCH" systemctl enable dhcpcd.service &> /dev/null &
		pid=$! pri=0.1 msg="\n$dhcp_load \n\n \Z1> \Z2systemctl enable dhcpcd\Zn" load
	fi
	
	if [ "$sh" == "/usr/bin/zsh" ]; then
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

}

config_env() {

	sh="/usr/bin/zsh"
	arch-chroot "$ARCH" chsh -s /usr/bin/zsh &> /dev/null
	cp "$aa_dir"/extra/.zshrc "$ARCH"/root/
	mkdir "$ARCH"/root/.config/ &> /dev/null
	cp -r "$aa_dir"/extra/desktop/.config/{xfce4,Thunar} "$ARCH"/root/.config/
	cp -r "$aa_dir"/extra/{.zshrc,desktop/.config/} "$ARCH"/etc/skel/
	cp "$aa_dir"/extra/desktop/arch-anywhere-icon.png "$ARCH"/etc/skel/.face
	cp -r "$aa_dir"/extra/desktop/AshOS-Dark-2.0 "$ARCH"/usr/share/themes/
	cp "$aa_dir"/extra/desktop/arch-anywhere-wallpaper.png "$ARCH"/usr/share/backgrounds/xfce/
	cp "$ARCH"/usr/share/backgrounds/xfce/arch-anywhere-wallpaper.png "$ARCH"/usr/share/backgrounds/xfce/xfce-teal.jpg
	cp "$aa_dir"/extra/desktop/arch-anywhere-icon.png "$ARCH"/usr/share/pixmaps/

}
