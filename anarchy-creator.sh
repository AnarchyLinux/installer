#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### anarchy-creator.sh
###
### Copyright (C) 2017 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: http://arch-anywhere.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Anarchy.
###
### License: GPL v2.0
###############################################################

set_version() {

	### Set the ISO release variable here:
	export iso_rel="1.0.0"

	### Note ISO label must remain 11 characters long:
	export iso_label="ANARCHYV100"

	case "$interface" in
		cli)	export version="anarchy-cli-${iso_rel}-x86_64.iso"
		;;
		gui)	export version="anarchy-${iso_rel}-x86_64.iso"
		;;
	esac

}

init() {

	### Only works with x86_64
	sys=x86_64

	### Location variables all directories must exist
	export aa=$(pwd)
	export customiso="$aa/customiso"

	if (ls "$aa"/archlinux-* &>/dev/null); then
		export iso=$(ls "$aa"/archlinux-* | tail -n1 | sed 's!.*/!!')
	fi

	update=false
	check_depends
	update_iso
	aur_builds

}

check_depends() {

	# Check depends
	if [ ! -f /usr/bin/7z ] || [ ! -f /usr/bin/mksquashfs ] || [ ! -f /usr/bin/xorriso ] || [ ! -f /usr/bin/wget ] || [ ! -f /usr/bin/arch-chroot ] || [ ! -f /usr/bin/xxd ]; then
		depends=false
		until "$depends"
		  do
			echo
			echo -n "ISO creation requires arch-install-scripts, squashfs-tools, libisoburn, p7zip, vim, and wget, would you like to install missing dependencies now? [y/N]: "
			read -r input

			case "$input" in
				y|Y|yes|Yes|yY|Yy|yy|YY)
					if [ ! -f /usr/bin/wget ]; then query="$query wget"; fi
					if [ ! -f /usr/bin/xorriso ]; then query="$query libisoburn"; fi
					if [ ! -f /usr/bin/mksquashfs ]; then query="$query squashfs-tools"; fi
					if [ ! -f /usr/bin/7z ]; then query="$query p7zip" ; fi
					if [ ! -f /usr/bin/arch-chroot ]; then query="$query arch-install-scripts"; fi
					if [ ! -f /usr/bin/xxd ]; then query="$query xxd"; fi
					sudo pacman -Syy "$query"
					depends=true
				;;
				n|N|no|No|nN|Nn|nn|NN)
					echo "Error: missing depends, exiting."
					exit 1
				;;
				*)
					echo
					echo "$input is an invalid option"
				;;
			esac
		done
	fi

}

update_iso() {

	# Check for latest Arch Linux ISO on website Download page
	export archiso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//')

	# Link to the iso used to create Anarchy Linux
	echo "Checking for updated ISO..."
	export archiso_link=http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso
	export iso_date=$(<<<"$archiso_link" sed 's!.*/!!')

	if [ "$iso_date" != "$iso" ]; then
		if [ -z "$iso" ]; then
			echo -en "\nNo archiso found under $aa\nWould you like to download now? [y/N]: "
			read -r input

			case "$input" in
				y|Y|yes|Yes|yY|Yy|yy|YY) update=true
				;;
				n|N|no|No|nN|Nn|nn|NN)	echo "Error: Creating the ISO requires the official archiso to be located at '$aa', exiting."
							exit 1
				;;
			esac
		else
			echo -en "An updated version of the archiso is available for download\n'$iso_ver'\nDownload now? [y/N]: "
			read -r input

			case "$input" in
				y|Y|yes|Yes|yY|Yy|yy|YY) update=true
				;;
				n|N|no|No|nN|Nn|nn|NN)	echo -e "Continuing using old iso\n'$iso'"
										sleep 1
				;;
			esac
		fi

		if "$update" ; then
			cd "$aa" || exit
			wget "$archiso_link"
			if [ "$?" -gt "0" ]; then
				echo "Error: requires wget, exiting"
				exit 1
			fi
			export iso=$(ls "$aa"/archlinux-* | tail -n1 | sed 's!.*/!!')
		fi
	fi

}

aur_builds() {

	### First update pacman databases
	sudo pacman -Sy

	if [ ! -d /tmp/fetchmirrors ]; then
		### Build fetchmirrors
		cd /tmp || exit
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/fetchmirrors.tar.gz"
		tar -xf fetchmirrors.tar.gz
		cd fetchmirrors || exit
		makepkg -s
	fi

	if [ ! -d /tmp/arch-wiki-cli ]; then
		### Build arch-wiki
		cd /tmp || exit
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/arch-wiki-cli.tar.gz"
		tar -xf arch-wiki-cli.tar.gz
		cd arch-wiki-cli || exit
		makepkg -s
	fi

	if [ ! -d /tmp/numix-icon-theme-git ]; then
                 ### Build numix icons
                 cd /tmp || exit
                 wget "https://aur.archlinux.org/cgit/aur.git/snapshot/numix-icon-theme-git.tar.gz"
                 tar -xf numix-icon-theme-git.tar.gz
                 cd numix-icon-theme-git || exit
                 makepkg -si
         fi

         if [ ! -d /tmp/numix-circle-icon-theme-git ]; then
                 ### Build numix icons
                 cd /tmp || exit
                 wget "https://aur.archlinux.org/cgit/aur.git/snapshot/numix-circle-icon-theme-git.tar.gz"
                 tar -xf numix-circle-icon-theme-git.tar.gz
                 cd numix-circle-icon-theme-git || exit
                 makepkg -s
	fi

	if [ ! -d /tmp/lightdm-slick-greeter ]; then
                 ### Build slick greeter
                 cd /tmp || exit
                 wget "https://aur.archlinux.org/cgit/aur.git/snapshot/lightdm-slick-greeter.tar.gz"
                 tar -xf lightdm-slick-greeter.tar.gz
                 cd lightdm-slick-greeter || exit
                 makepkg -si
         fi

         if [ ! -d /tmp/lightdm-settings ]; then
                 ### Build lightdm settings
                 cd /tmp || exit
                 wget "https://aur.archlinux.org/cgit/aur.git/snapshot/lightdm-settings.tar.gz"
                 tar -xf lightdm-settings.tar.gz
                 cd lightdm-settings || exit
                 makepkg -s
         fi

	 if [ ! -d /tmp/oh-my-zsh-git ]; then
                 ### Build oh-my-zsh
                 cd /tmp || exit
                 wget "https://aur.archlinux.org/cgit/aur.git/snapshot/oh-my-zsh-git.tar.gz"
                 tar -xf oh-my-zsh-git.tar.gz
                 cd oh-my-zsh-git || exit
                 makepkg -s
         fi

	 if [ ! -d /tmp/opensnap ]; then
                 ### Build opensnap
                 cd /tmp || exit
                 wget "https://aur.archlinux.org/cgit/aur.git/snapshot/opensnap.tar.gz"
                 tar -xf opensnap.tar.gz
                 cd opensnap || exit
                 makepkg -s
         fi

}

extract_iso() {

	if [ -d "$customiso" ]; then
		sudo rm -rf "$customiso"
	fi

	# Extract archiso to mntdir and continue with build
	7z x "$iso" -o"$customiso"

}

build_conf() {

	### Change directory into the ISO where the filesystem is stored.
	### Unsquash root filesystem 'airootfs.sfs' this creates a directory 'squashfs-root' containing the entire system
	echo "Preparing $sys"
	if [ "$interface" == "cli" ]; then
		cd "$customiso"/arch/"$sys" || exit
		sudo unsquashfs airootfs.sfs
	else
		cd "$customiso"/arch/"$sys" || exit
		sudo unsquashfs airootfs.sfs
		sudo mount -t proc proc "$customiso"/arch/"$sys"/squashfs-root/proc/
		sudo mount -t sysfs sys "$customiso"/arch/"$sys"/squashfs-root/sys/
		sudo mount -o bind /dev "$customiso"/arch/"$sys"/squashfs-root/dev/
		sudo cp "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf.bak
		sudo cp "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio-archiso.conf "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf
	fi

	### Copy over vconsole.conf (sets font at boot) & locale.gen (enables locale(s) for font) & uvesafb.conf
	sudo cp "$aa"/etc/{vconsole.conf,locale.gen} "$customiso"/arch/"$sys"/squashfs-root/etc
	sudo arch-chroot squashfs-root /bin/bash locale-gen

	### Copy over main anarchy config, installer script, and arch-wiki,  make executeable
	sudo cp "$aa"/etc/anarchy.conf "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp "$aa"/anarchy-installer.sh "$customiso"/arch/"$sys"/squashfs-root/usr/bin/anarchy
	sudo cp "$aa"/extra/{sysinfo,iptest} "$customiso"/arch/"$sys"/squashfs-root/usr/bin/
	sudo chmod +x "$customiso"/arch/"$sys"/squashfs-root/usr/bin/{anarchy,sysinfo,iptest}

	### Create anarchy directory and lang directory copy over all lang files
	sudo mkdir -p "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/{lang,extra,boot,etc}
	sudo cp "$aa"/lang/* "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/lang

	### Create shell function library
	sudo mkdir "$customiso"/arch/"$sys"/squashfs-root/usr/lib/anarchy
	sudo cp "$aa"/lib/* "$customiso"/arch/"$sys"/squashfs-root/usr/lib/anarchy

	### Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
	sudo cp "$aa"/extra/{.zshrc,.help,.dialogrc} "$customiso"/arch/"$sys"/squashfs-root/root/
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/"$sys"/squashfs-root/etc/zsh/zshrc
	sudo cp "$aa"/extra/{.bashrc,.bashrc-root,.tcshrc,.tcshrc.conf,.mkshrc,.zshrc,.zshrc-oh-my,.zshrc-grml} "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/extra/
	sudo sed -i -e '$a\\nalias help="cat ~/.help"\nalias start="cat ~/.issue_cli"\nalias 1="anarchy"\nalias 2="anarchy -u"\nalias 3="arch-wiki"\nalias 4="iptest"\nalias 5="sysinfo"\nalias 6="fetchmirrors"' "$customiso"/arch/"$sys"/squashfs-root/root/.zshrc
	sudo cp -r "$aa"/extra/desktop "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/extra/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp "$aa"/boot/issue_cli "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp -r "$aa"/boot/loader/ "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/boot/
	sudo cp "$aa"/boot/splash.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/boot/
	sudo cp "$aa"/etc/{nvidia340.xx,nvidia304.xx} "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/etc/

	### Copy over built packages and create repository
	sudo mkdir "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/arch-wiki-cli/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/fetchmirrors/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/numix-icon-theme-git/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/numix-circle-icon-theme-git/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/lightdm-slick-greeter/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/lightdm-settings/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/oh-my-zsh-git/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	sudo cp /tmp/opensnap/*.pkg.tar.xz "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg
	cd "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg || exit
	sudo repo-add anarchy-local.db.tar.gz *.pkg.tar.xz
	sudo sed -i -e '$a\\n[anarchy-local]\nServer = file:///usr/share/anarchy/pkg\nSigLevel = Never' "$customiso"/arch/"$sys"/squashfs-root/etc/pacman.conf

}

build_sys() {

	cd "$customiso"/arch/"$sys" || exit
	### Install fonts, fbterm, fetchmirrors, arch-wiki
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Syyy terminus-font acpi
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/arch-wiki-cli/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.${sys}.txt
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Scc
	sudo rm -f "$customiso"/arch/"$sys"/squashfs-root/var/cache/pacman/pkg/*

	### cd back into root system directory, remove old system
	cd "$customiso"/arch/"$sys" || exit
	rm airootfs.sfs

	### Recreate the ISO using compression remove unsquashed system generate checksums
	echo "Recreating $sys..."
	sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	sudo rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5

}

build_sys_gui() {

	cd "$customiso"/arch/"$sys" || exit
	### Install fonts, fbterm, fetchmirrors, arch-wiki, and uvesafb drivers onto system and cleanup
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config /etc/pacman.conf --noconfirm --needed -Syyy terminus-font xorg-server xorg-xinit xf86-video-vesa vlc galculator file-roller gparted gimp git networkmanager network-manager-applet pulseaudio-alsa \
		zsh-syntax-highlighting arc-gtk-theme elementary-icon-theme thunar base-devel gvfs xdg-user-dirs xfce4 xfce4-goodies libreoffice-fresh chromium virtualbox-guest-dkms virtualbox-guest-utils linux linux-headers libdvdcss simplescreenrecorder screenfetch htop acpi pavucontrol \
		oblogout
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/arch-wiki-cli/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/numix-icon-theme-git/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/numix-circle-icon-theme-git/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.${sys}.txt
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Scc
	sudo rm -f "$customiso"/arch/"$sys"/squashfs-root/var/cache/pacman/pkg/*
	sudo mv "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf.bak "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf

	### Disable netctl enable networkmanager
	sudo arch-chroot squashfs-root systemctl disable netctl.service
	sudo arch-chroot squashfs-root systemctl enable NetworkManager.service

	### Copy new kernel
	sudo rm "$customiso"/arch/"$sys"/squashfs-root/boot/initramfs-linux-fallback.img
	sudo mv "$customiso"/arch/"$sys"/squashfs-root/boot/vmlinuz-linux "$customiso"/arch/boot/"$sys"/vmlinuz
	sudo mv "$customiso"/arch/"$sys"/squashfs-root/boot/initramfs-linux.img "$customiso"/arch/boot/"$sys"/archiso.img

	### Configure xfce4
	sudo rm "$customiso"/arch/"$sys"/squashfs-root/root/install.txt
	sudo arch-chroot squashfs-root useradd -m -g users -G power,audio,video,storage -s /usr/bin/zsh user
	sudo arch-chroot squashfs-root su user -c xdg-user-dirs-update
	sudo sed -i 's/root/user/' "$customiso"/arch/"$sys"/squashfs-root/etc/systemd/system/getty@tty1.service.d/autologin.conf
	sudo cp -r "$aa"/extra/gui/{Fetchmirrors.desktop,gparted.desktop,chromium.desktop,exo-terminal-emulator.desktop,Install.desktop} "$customiso"/arch/"$sys"/squashfs-root/home/user/Desktop
	sudo cp -r "$aa"/extra/gui/{Fetchmirrors.desktop,Install.desktop} "$customiso"/arch/"$sys"/squashfs-root/usr/share/applications
	sudo cp -r "$aa"/extra/gui/{issue,sudoers} "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp -r "$aa"/extra/desktop/anarchy-icon.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/pixmaps
	sudo cp -r "$aa"/extra/desktop/wallpapers/*.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/pixmaps
	sudo cp -r "$aa"/extra/desktop/wallpapers/*.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/backgrounds/xfce
	sudo cp -r "$aa"/extra/desktop/anarchy-icon.png "$customiso"/arch/"$sys"/squashfs-root/root/.face
	sudo cp -r "$aa"/extra/desktop/anarchy-icon.png "$customiso"/arch/"$sys"/squashfs-root/home/user/.face
	sudo cp -r "$aa"/extra/desktop/ttf-zekton-rg "$customiso"/arch/"$sys"/squashfs-root/usr/share/fonts
	sudo cp -r "$aa"/extra/gui/{.xinitrc,.automated_script.sh} "$customiso"/arch/"$sys"/squashfs-root/root
	sudo cp -r "$aa"/extra/gui/{.xinitrc,.automated_script.sh} "$customiso"/arch/"$sys"/squashfs-root/home/user
	sudo cp -r "$aa"/extra/.zshrc "$customiso"/arch/"$sys"/squashfs-root/home/user/.zshrc
	sudo sed -i -e '$a\\nalias help="cat ~/.help"\nalias start="cat ~/.issue_cli"\nalias 1="anarchy"\nalias 2="anarchy -u"\nalias 3="arch-wiki"\nalias 4="iptest"\nalias 5="sysinfo"\nalias 6="fetchmirrors"' "$customiso"/arch/"$sys"/squashfs-root/home/user/.zshrc
	sudo cp -r "$aa"/extra/gui/.config "$customiso"/arch/"$sys"/squashfs-root/home/user/
	sudo cp -r "$aa"/extra/gui/.config "$customiso"/arch/"$sys"/squashfs-root/root
	sudo cp -r "$customiso"/arch/"$sys"/squashfs-root/root/.zlogin "$customiso"/arch/"$sys"/squashfs-root/home/user
	sudo arch-chroot squashfs-root chown -R user /home/user/
	sudo touch "$customiso"/arch/"$sys"/squashfs-root/etc/modules-load.d/virtualbox-guest-modules-arch.conf

	### cd back into root system directory, remove old system
	cd "$customiso"/arch/"$sys" || exit
	rm airootfs.sfs

	### Recreate the ISO using compression remove unsquashed system generate checksums
	echo "Recreating $sys..."
	sudo umount "$customiso"/arch/"$sys"/squashfs-root/proc/
	sudo umount "$customiso"/arch/"$sys"/squashfs-root/sys/
	sudo umount "$customiso"/arch/"$sys"/squashfs-root/dev/
	sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	sudo rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5

}

configure_boot() {

	archiso_label=$(<"$customiso"/loader/entries/archiso-x86_64.conf awk 'NR==5{print $NF}' | sed 's/.*=//')
	archiso_hex=$(<<<"$archiso_label" xxd -p)
	iso_hex=$(<<<"$iso_label" xxd -p)
	cp "$aa"/boot/splash.png "$customiso"/arch/boot/syslinux
	cp "$aa"/boot/iso/archiso_head.cfg "$customiso"/arch/boot/syslinux
	sed -i "s/$archiso_label/$iso_label/;s/Arch Linux archiso/Anarchy Linux/" "$customiso"/loader/entries/archiso-x86_64.conf
	sed -i "s/$archiso_label/$iso_label/;s/Arch Linux/Anarchy Linux/" "$customiso"/arch/boot/syslinux/archiso_sys.cfg
	sed -i "s/$archiso_label/$iso_label/;s/Arch Linux/Anarchy Linux/" "$customiso"/arch/boot/syslinux/archiso_pxe.cfg
	cd "$customiso"/EFI/archiso/ || exit
	echo -e "Replacing label hex in efiboot.img...\n$archiso_label $archiso_hex > $iso_label $iso_hex"
	xxd -c 256 -p efiboot.img | sed "s/$archiso_hex/$iso_hex/" | xxd -r -p > efiboot1.img
	if ! (xxd -c 256 -p efiboot1.img | grep "$iso_hex" &>/dev/null); then
		echo "\nError: failed to replace label hex in efiboot.img"
		echo "Please look into this issue before releasing ISO"
		echo "Press any key to continue" ; read input
	fi
	mv efiboot1.img efiboot.img

}

create_iso() {

	cd "$aa" || exit
	xorriso -as mkisofs \
	 -iso-level 3 \
	-full-iso9660-filenames \
	-volid "$iso_label" \
	-eltorito-boot isolinux/isolinux.bin \
	-eltorito-catalog isolinux/boot.cat \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-isohybrid-mbr customiso/isolinux/isohdpfx.bin \
	-eltorito-alt-boot \
	-e EFI/archiso/efiboot.img \
	-no-emul-boot -isohybrid-gpt-basdat \
	-output "$version" \
	"$customiso"

	if [ "$?" -eq "0" ]; then
		rm -rf "$customiso"
		check_sums
	else
		echo "Error: ISO creation failed, please email the developer: deadhead3492@gmail.com"
		exit 1
	fi

}

check_sums() {

	echo "Generating ISO checksums..."
	md5_sum=$(md5sum "$version" | awk '{print $1}')
	sha1_sum=$(sha1sum "$version" | awk '{print $1}')
	timestamp=$(timedatectl | grep "Universal" | awk '{print $4" "$5" "$6}')
	echo "Checksums generated. Saved to $(sed 's/.iso//' <<<"$version")-checksums.txt"
	echo -e "- Anarchy Linux is licensed under GPL v2\n- Developer: Dylan Schacht (deadhead3492@gmail.com)\n- Webpage: http://arch-anywhere.org\n- ISO timestamp: $timestamp\n- $version Official Check Sums:\n\n* md5sum: $md5_sum\n* sha1sum: $sha1_sum" > "$(sed 's/.iso//' <<<"$version")-checksums.txt"

}

usage() {

	echo "Usage options for: anarchy-creator"
	echo "	-a|--all)	create cli and gui iso"
	echo "	-c|--cli)	create anarchy cli iso"
	echo "	-g|--gui)	create anarchy gui iso"
}

case "$1" in
	-c|--cli)	interface="cli"
			set_version
			init
			extract_iso
			build_conf
			build_sys
			configure_boot
			create_iso
			echo "$version ISO generated successfully! Exiting ISO creator."
			exit
	;;
	-g|--gui)	interface="gui"
			set_version
			init
			extract_iso
			build_conf
			build_sys_gui
			configure_boot
			create_iso
			echo "$version ISO generated successfully! Exiting ISO creator."
			exit

	;;
	-a|--all)	interface="cli"
			set_version
			init
			extract_iso
                        build_conf
			build_sys
                        configure_boot
                        create_iso
			echo "$version ISO generated successfully!."
			interface="gui"
			set_version
			extract_iso
			build_conf
			build_sys_gui
                        configure_boot
                        create_iso
			echo "$version ISO generated successfully! Exiting ISO creator."
			exit
	;;
	*)	usage
		exit
	;;
esac

# vim: ai:ts=8:sw=8:sts=8:noet
