#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### anarchy-creator-gui.sh
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

# Set the version here
export version="anarchy-1.0-x86_64.iso"

# Set the ISO label here
export iso_label="ANARCHYV100"

# Location variables all directories must exist
export aa=$(pwd)
export customiso="$aa/customiso"
if (ls "$aa"/archlinux-* &>/dev/null); then
	export iso=$(ls "$aa"/archlinux-* | tail -n1 | sed 's!.*/!!')
fi
update=false
trap quit EXIT

# Check depends
if [ ! -f /usr/bin/7z ] || [ ! -f /usr/bin/mksquashfs ] || [ ! -f /usr/bin/xorriso ] || [ ! -f /usr/bin/wget ] || [ ! -f /usr/bin/arch-chroot ] || [ ! -f /usr/bin/xxd ]; then
	depends=false
	until "$depends"
	  do
		echo
		echo -n "ISO creation requires arch-install-scripts, lynx, squashfs-tools, libisoburn, p7zip, vim, and wget, would you like to install missing dependencies now? [y/N]: "
		read input

		case "$input" in
			y|Y|yes|Yes|yY|Yy|yy|YY)
				if [ ! -f "/usr/bin/wget" ]; then query="wget"; fi
				if [ ! -f /usr/bin/xorriso ]; then query="$query libisoburn"; fi
				if [ ! -f /usr/bin/mksquashfs ]; then query="$query squashfs-tools"; fi
				if [ ! -f /usr/bin/lynx ]; then query="$query lynx" ; fi
				if [ ! -f /usr/bin/7z ]; then query="$query p7zip" ; fi
				if [ ! -f /usr/bin/arch-chroot ]; then query="$query arch-install-scripts"; fi
				if [ ! -f /usr/bin/xxd ]; then query="$query xxd"; fi
				sudo pacman -Syy $(echo "$query")
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


# Link to the archiso used to create Anarchy
echo "Checking for updated ISO..."
export archiso_link=$(lynx -dump $(lynx -dump http://arch.localmsp.org/arch/iso | grep "8\. " | awk '{print $2}') | grep "7\. " | awk '{print $2}')

if [ -z "$archiso_link" ]; then
	echo -e "ERROR: archiso link not found\nRequired for updating archiso.\nPlease install 'lynx' to resolve this issue"
	sleep 4
else
	iso_ver=$(<<<"$archiso_link" sed 's!.*/!!')
fi

if [ "$iso_ver" != "$iso" ]; then
	if [ -z "$iso" ]; then
		echo -en "\nNo archiso found under $aa\nWould you like to download now? [y/N]: "
		read input

		case "$input" in
			y|Y|yes|Yes|yY|Yy|yy|YY) update=true
			;;
			n|N|no|No|nN|Nn|nn|NN)	echo "Error: Creating the ISO requires the official archiso to be located at '$aa', exiting."
									exit 1
			;;
		esac
	else
		echo -en "An updated version of the archiso is available for download\n'$iso_ver'\nDownload now? [y/N]: "
		read input

		case "$input" in
			y|Y|yes|Yes|yY|Yy|yy|YY) update=true
			;;
			n|N|no|No|nN|Nn|nn|NN)	echo -e "Continuing using old iso\n'$iso'"
									sleep 1
			;;
		esac
	fi

	if "$update" ; then
		cd "$aa"
		wget "$archiso_link"
		if [ "$?" -gt "0" ]; then
			echo "Error: requires wget, exiting"
			exit 1
		fi
		export iso=$(ls "$aa"/archlinux-* | tail -n1 | sed 's!.*/!!')
	fi
fi

init() {

	if [ -d "$customiso" ]; then
		sudo rm -rf "$customiso"
	fi

	# Extract archiso to mntdir and continue with build
	7z x "$iso" -o"$customiso"
	builds

}

builds() {

	if [ ! -d /tmp/fetchmirrors ]; then
		### Build fetchmirrors
		cd /tmp
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/fetchmirrors.tar.gz"
		tar -xf fetchmirrors.tar.gz
		cd fetchmirrors
		makepkg -s
	fi

	if [ ! -d /tmp/arch-wiki-cli ]; then
		### Build arch-wiki
		cd /tmp
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/arch-wiki-cli.tar.gz"
		tar -xf arch-wiki-cli.tar.gz
		cd arch-wiki-cli
		makepkg -s
	fi

	if [ ! -d /tmp/numix-icon-theme-git ]; then
		### Build numix icons
		cd /tmp
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/numix-icon-theme-git.tar.gz"
		tar -xf numix-icon-theme-git.tar.gz
		cd numix-icon-theme-git
		makepkg -s
	fi

	if [ ! -d /tmp/numix-circle-icon-theme-git ]; then
		### Build numix icons
		cd /tmp
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/numix-circle-icon-theme-git.tar.gz"
		tar -xf numix-circle-icon-theme-git.tar.gz
		cd numix-circle-icon-theme-git
		makepkg -s
	fi

	if [ ! -d /tmp/opensnap ]; then
		### Build opensnap
		cd /tmp
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/opensnap.tar.gz"
		tar -xf opensnap.tar.gz
		cd opensnap
		makepkg -s
	fi

	if [ ! -d /tmp/perl-linux-desktopfiles ]; then
		### Build numix icons
		cd /tmp
		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/perl-linux-desktopfiles.tar.gz"
		tar -xf perl-linux-desktopfiles.tar.gz
		cd perl-linux-desktopfiles
		makepkg -s
	fi

#	if [ ! -d /tmp/obmenu-generator ]; then
#		### Build numix icons
#		cd /tmp
#		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/obmenu-generator.tar.gz"
#		tar -xf obmenu-generator.tar.gz
#		cd obmenu-generator
#		makepkg -s
#	fi

#	if [ ! -d /tmp/archlabs-oblogout-themes-git ]; then
#		### Build oblogout theme
#		cd /tmp
#		wget "https://aur.archlinux.org/cgit/aur.git/snapshot/archlabs-oblogout-themes-git.tar.gz"
#		tar -xf archlabs-oblogout-themes-git.tar.gz
#		cd archlabs-oblogout-themes-git
#		makepkg -s
#	fi

	prepare_sys

}

prepare_sys() {

### Set system architecture
	sys=x86_64

### Change directory into the ISO where the filesystem is stored.
### Unsquash root filesystem 'airootfs.sfs' this creates a directory 'squashfs-root' containing the entire system
	echo "Preparing $sys"
	cd "$customiso"/arch/"$sys"
	sudo unsquashfs airootfs.sfs
	sudo mount -t proc proc "$customiso"/arch/"$sys"/squashfs-root/proc/
	sudo mount -t sysfs sys "$customiso"/arch/"$sys"/squashfs-root/sys/
	sudo mount -o bind /dev "$customiso"/arch/"$sys"/squashfs-root/dev/
	sudo cp "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf.bak
	sudo cp "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio-archiso.conf "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf


### Install fonts, fbterm, fetchmirrors, arch-wiki, and uvesafb drivers onto system and cleanup
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config /etc/pacman.conf --noconfirm --needed -Syyy terminus-font xorg-server xorg-xinit xf86-video-vesa vlc galculator file-roller gparted gimp git networkmanager network-manager-applet pulseaudio-alsa \
		zsh-syntax-highlighting arc-gtk-theme elementary-icon-theme thunar base-devel xfce4 xfce4-goodies libreoffice-fresh chromium virtualbox-guest-dkms virtualbox-guest-utils xdg-user-dirs linux linux-headers oblogout libdvdcss simplescreenrecorder acpi
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/arch-wiki-cli/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/numix-icon-theme-git/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/numix-circle-icon-theme-git/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/archlabs-oblogout-themes-git/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/dropbox/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.${sys}.txt
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Scc
	sudo rm -f "$customiso"/arch/"$sys"/squashfs-root/var/cache/pacman/pkg/*
	sudo mv "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf.bak "$customiso"/arch/"$sys"/squashfs-root/etc/mkinitcpio.conf

### Copy over vconsole.conf (sets font at boot) & locale.gen (enables locale(s) for font) & uvesafb.conf
	sudo cp "$aa"/etc/{vconsole.conf,locale.gen} "$customiso"/arch/"$sys"/squashfs-root/etc
#	sudo cp "$aa"/etc/uvesafb.conf "$customiso"/arch/"$sys"/squashfs-root/etc/modules-load.d/
	sudo arch-chroot squashfs-root /bin/bash locale-gen

### Copy over main arch anywhere config, installer script, and arch-wiki,  make executeable
	sudo cp "$aa"/etc/anarchy.conf "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp "$aa"/anarchy-installer.sh "$customiso"/arch/"$sys"/squashfs-root/usr/bin/anarchy
	sudo cp "$aa"/extra/{sysinfo,iptest} "$customiso"/arch/"$sys"/squashfs-root/usr/bin/
	sudo chmod +x "$customiso"/arch/"$sys"/squashfs-root/usr/bin/{anarchy,sysinfo,iptest}

### Create arch-anywhere directory and lang directory copy over all lang files
	sudo mkdir -p "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/{lang,extra,boot,etc}
	sudo cp "$aa"/lang/* "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/lang

### Create shell function library
	sudo mkdir "$customiso"/arch/"$sys"/squashfs-root/usr/lib/anarchy
	sudo cp "$aa"/lib/* "$customiso"/arch/"$sys"/squashfs-root/usr/lib/anarchy

### Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
	sudo cp "$aa"/extra/{.zshrc,.help,.dialogrc} "$customiso"/arch/"$sys"/squashfs-root/root/
	sudo cp "$aa"/extra/{.bashrc,.bashrc-root,.tcshrc,.tcshrc.conf,.mkshrc,.zshrc-default,.zshrc-oh-my,.zshrc-grml} "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/extra/
	sudo cp -r "$aa"/extra/desktop "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/extra/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp "$aa"/boot/issue_cli "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp -r "$aa"/boot/loader/ "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/boot/
	sudo cp "$aa"/boot/splash.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/boot/
	sudo cp "$aa"/etc/{nvidia340.xx,nvidia304.xx} "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/etc/

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
	sudo sed -i 's/root/user/' "$customiso"/arch/"$sys"/squashfs-root/etc/systemd/system/getty@tty1.service.d/autologin.conf
	sudo mkdir "$customiso"/arch/"$sys"/squashfs-root/home/user/Desktop/
	sudo cp -r "$aa"/extra/gui/Fetchmirrors.desktop "$customiso"/arch/"$sys"/squashfs-root/home/user/Desktop/Fetchmirrors.desktop
	sudo cp -r "$aa"/extra/gui/gparted.desktop "$customiso"/arch/"$sys"/squashfs-root/home/user/Desktop/gparted.desktop
	sudo cp -r "$aa"/extra/gui/Install.desktop "$customiso"/arch/"$sys"/squashfs-root/home/user/Desktop/Install.desktop
	sudo cp -r "$aa"/extra/gui/{issue,oblogout.conf,sudoers} "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp -r "$aa"/extra/gui/net.launchpad.plank.gschema.xml "$customiso"/arch/"$sys"/squashfs-root/usr/share/glib-2.0/schemas/
	sudo cp -r "$aa"/extra/desktop/anarchy-icon.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/pixmaps
	sudo cp -r "$aa"/extra/desktop/wallpapers/*.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/pixmaps
	sudo cp -r "$aa"/extra/desktop/wallpapers/*.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/backgrounds/xfce
	sudo cp -r "$aa"/extra/desktop/anarchy-icon.png "$customiso"/arch/"$sys"/squashfs-root/root/.face
	sudo cp -r "$aa"/extra/desktop/anarchy-icon.png "$customiso"/arch/"$sys"/squashfs-root/home/user/.face
	sudo cp -r "$aa"/extra/desktop/ttf-zekton-rg "$customiso"/arch/"$sys"/squashfs-root/usr/share/fonts
	sudo cp -r "$aa"/extra/gui/{.xinitrc,.automated_script.sh} "$customiso"/arch/"$sys"/squashfs-root/root
	sudo cp -r "$aa"/extra/gui/{.xinitrc,.automated_script.sh} "$customiso"/arch/"$sys"/squashfs-root/home/user
	sudo cp -r "$aa"/extra/.zshrc-default "$customiso"/arch/"$sys"/squashfs-root/home/user/.zshrc
	sudo cp -r "$aa"/extra/gui/.config "$customiso"/arch/"$sys"/squashfs-root/home/user/
	sudo cp -r "$aa"/extra/gui/.config "$customiso"/arch/"$sys"/squashfs-root/root
	sudo cp -r "$aa"/extra/gui/.config "$customiso"/arch/"$sys"/squashfs-root/root/.zlogin "$aa"/extra/gui/.config "$customiso"/arch/"$sys"/squashfs-root/home/user
	sudo chmod +x "$customiso"/arch/"$sys"/squashfs-root/home/user/.automated_script.sh
	sudo arch-chroot squashfs-root chown -R user /home/user/{.zlogin,.zshrc,.face,.automated_script.sh,.config/}
	sudo touch "$customiso"/arch/"$sys"/squashfs-root/etc/modules-load.d/virtualbox-guest-modules-arch.conf

### cd back into root system directory, remove old system
	cd "$customiso"/arch/"$sys"
	rm airootfs.sfs

### Recreate the ISO using compression remove unsquashed system generate checksums and continue to i686
	echo "Recreating $sys..."
	sudo umount "$customiso"/arch/"$sys"/squashfs-root/proc/
	sudo umount "$customiso"/arch/"$sys"/squashfs-root/sys/
	sudo umount "$customiso"/arch/"$sys"/squashfs-root/dev/
	sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	sudo rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5

### Begin configure boot function
	configure_boot

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
	cd "$customiso"/EFI/archiso/
	echo -e "Replacing label hex in efiboot.img...\n$archiso_label $archiso_hex > $iso_label $iso_hex"
	xxd -c 256 -p efiboot.img | sed "s/$archiso_hex/$iso_hex/" | xxd -r -p > efiboot1.img
	if ! (xxd -c 256 -p efiboot1.img | grep "$iso_hex" &>/dev/null); then
		echo "\nError: failed to replace label hex in efiboot.img"
		echo "Please look into this issue before releasing ISO"
		echo "Press any key to continue" ; read input
	fi
	mv efiboot1.img efiboot.img
	create_iso

}

create_iso() {

	cd "$aa"
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
		echo -n "ISO creation successful, would you like to remove the $customiso directory and cleanup? [y/N]: "
		read input

		case "$input" in
			y|Y|yes|Yes|yY|Yy|yy|YY)
				rm -rf "$customiso"
				check_sums
			;;
			n|N|no|No|nN|Nn|nn|NN)
				check_sums
			;;
		esac
	else
		echo "Error: ISO creation failed, please email the developer: deadhead3492@gmail.com"
		exit 1
	fi

}

check_sums() {

	echo
	echo "Generating ISO checksums..."
	md5_sum=$(md5sum "$version" | awk '{print $1}')
	sha1_sum=$(sha1sum "$version" | awk '{print $1}')
	timestamp=$(timedatectl | grep "Universal" | awk '{print $4" "$5" "$6}')
	echo "Checksums generated. Saved to anarchy-checksums.txt"
	echo -e "- Anarchy Linux is licensed under GPL v2\n- Developer: Dylan Schacht (deadhead3492@gmail.com)\n- Webpage: http://arch-anywhere.org\n- ISO timestamp: $timestamp\n- $version Official Check Sums:\n\n* md5sum: $md5_sum\n* sha1sum: $sha1_sum" > anarchy-checksums.txt
	echo
	echo "$version ISO generated successfully! Exiting ISO creator."
	echo
	exit

}

quit() {

	if (mount | grep "$customiso" &>/dev/null); then
		sudo umount "$customiso"/arch/"$sys"/squashfs-root/proc/
		sudo umount "$customiso"/arch/"$sys"/squashfs-root/sys/
		sudo umount "$customiso"/arch/"$sys"/squashfs-root/dev/
	fi

}

init

# vim: ai:ts=8:sw=8:sts=8:noet
