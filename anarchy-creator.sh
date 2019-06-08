#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### anarchy-creator.sh
###
### Copyright (C) 2018 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: https://anarchylinux.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Anarchy.
###
### License: GPL v2.0
###############################################################

set_version() {

	### Set the ISO release variable here:
	export iso_rel="1.0.4"

	### Note ISO label must remain 11 characters long:
	export iso_label="ANARCHYV104"

	### ISO name
	case "$interface" in
		cli)	export version="anarchy-cli-${iso_rel}-$sys.iso"
		;;
		gui)	export version="anarchy-${iso_rel}-$sys.iso"
		;;
	esac

}

init() {

	### Location variables
	export aa=$(pwd)
	export customiso="$aa/customiso"
	export sq="$customiso/arch/$sys/squashfs-root"

	### Check for existing archiso
	if (ls "$aa"/archlinux-*-$sys.iso &>/dev/null); then
		export iso=$(ls "$aa"/archlinux-*-${sys}.iso | tail -n1 | sed 's!.*/!!')
	fi

	### Link to AUR snapshots
	aur="https://aur.archlinux.org/cgit/aur.git/snapshot/"

	### Array packages to be build and added to ISO local repo
	export builds=(
		'fetchmirrors'
		'numix-icon-theme-git'
		'numix-circle-icon-theme-git'
		'oh-my-zsh-git'
		'opensnap'
		'perl-linux-desktopfiles'
		'obmenu-generator'
		'yay')

	check_depends
	update_iso
	aur_builds

}

check_depends() {

	# Check depends
	if [ ! -f /usr/bin/wget ]; then query="$query wget "; fi
	if [ ! -f /usr/bin/xorriso ]; then query+="libisoburn "; fi
	if [ ! -f /usr/bin/mksquashfs ]; then query+="squashfs-tools "; fi
	if [ ! -f /usr/bin/7z ]; then query+="p7zip " ; fi
	if [ ! -f /usr/bin/arch-chroot ]; then query+="arch-install-scripts "; fi
	if [ ! -f /usr/bin/xxd ]; then query+="xxd "; fi
	if [ ! -f /usr/bin/gtk3-demo ]; then query+="gtk3 "; fi
        if [ ! -f /usr/bin/rankmirrors ]; then query+="pacman-contrib "; fi

	if [ ! -z "$query" ]; then
		echo -en "Error: missing dependencies: ${query}\n > Install missing dependencies now? [y/N]: "
		read -r input

		case $input in
			y|Y)	sudo pacman -Sy $query ;;
			*)	echo "Error: missing depends, exiting." ; exit 1 ;;
		esac
	fi

}

update_iso() {

	update=false

	# Check for latest Arch Linux ISO on website Download page
	if [ $sys == x86_64 ]; then
		export archiso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//')
		export archiso_link=http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso
	else
		export archiso_latest=$(curl -s https://mirror.archlinux32.org/archisos/ | grep -o ">.*.iso<" | tail -1 | sed 's/>//;s/<//')
		export archiso_link=https://mirror.archlinux32.org/archisos/$archiso_latest
	fi

	echo "Checking for updated ISO..."
	export iso_date=$(<<<"$archiso_link" sed 's!.*/!!')
	if [ "$iso_date" != "$iso" ]; then
		if [ -z "$iso" ]; then
			echo -en "\nError: no archiso found under $aa\n > Download archiso now? [y/N]: "
			read -r input

			case "$input" in
				y|Y) update=true
				;;
				*)	echo "Error: creation script requires archiso located at: $aa"
					exit 1
				;;
			esac
		else
			echo -en "Updated archiso available: $archiso_latest\n > Download new archiso? [y/N]: "
			read -r input

			case "$input" in
				y|Y)	update=true
				;;
				n|N)	echo -e "Continuing using old iso\n'$iso'"
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
			export iso=$(ls "$aa"/archlinux-*-$sys.iso | tail -n1 | sed 's!.*/!!')
		fi
	fi

}

aur_builds() {

	### First update pacman databases
	sudo pacman -Sy

	### Begin build loop checking /tmp for existing builds
	### Build packages & install if required
	for pkg in $(echo ${builds[@]}); do
		if [ ! -d /tmp/$pkg ]; then
			wget -qO- "$aur/${pkg}.tar.gz" | tar xz -C /tmp
			cd /tmp/$pkg || exit
			case $pkg in
				perl-*|numix-*) makepkg -si --needed --noconfirm ;;
				*) makepkg -s ;;
			esac
		fi
	done

}

extract_iso() {

	cd "$aa" || exit

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
		sudo cp "$sq"/etc/mkinitcpio.conf "$sq"/etc/mkinitcpio.conf.bak
		sudo cp "$sq"/etc/mkinitcpio-archiso.conf "$sq"/etc/mkinitcpio.conf
	fi

	### Copy over vconsole.conf (sets font at boot) & locale.gen (enables locale(s) for font) & uvesafb.conf
	sudo cp "$aa"/etc/{vconsole.conf,locale.gen} "$sq"/etc
	sudo arch-chroot "$sq" /bin/bash locale-gen

	### Copy over main anarchy config, installer script, and arch-wiki,  make executeable
	sudo cp "$aa"/etc/anarchy.conf "$sq"/etc/
	sudo cp "$aa"/anarchy-installer.sh "$sq"/usr/bin/anarchy
	sudo cp "$aa"/extra/{sysinfo,iptest} "$sq"/usr/bin/
	sudo chmod +x "$sq"/usr/bin/{anarchy,sysinfo,iptest}

	### Create anarchy directory and lang directory copy over all lang files
	sudo mkdir -p "$sq"/usr/share/anarchy/{lang,extra,boot,etc}
	sudo cp "$aa"/lang/* "$sq"/usr/share/anarchy/lang

	### Create shell function library copy to squashfs-root from /lib
	sudo mkdir "$sq"/usr/lib/anarchy
	sudo cp "$aa"/lib/* "$sq"/usr/lib/anarchy

	### Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
	sudo rm "$sq"/root/install.txt
	sudo cp "$aa"/extra/shellrc/.zshrc "$sq"/root
	sudo cp "$aa"/extra/{.help,.dialogrc} "$sq"/root/
	sudo cp "$aa"/extra/shellrc/.zshrc "$sq"/etc/zsh/zshrc
	sudo cp -r "$aa"/extra/shellrc/. "$sq"/usr/share/anarchy/extra/
	sudo cp -r "$aa"/extra/{desktop,wallpapers,fonts,anarchy-icon.png} "$sq"/usr/share/anarchy/extra/
	cat "$aa"/extra/.helprc | sudo tee -a "$sq"/root/.zshrc >/dev/null
	sudo cp "$aa"/etc/{hostname,issue_cli,lsb-release,os-release} "$sq"/etc/
	sudo cp -r "$aa"/boot/{splash.png,loader/} "$sq"/usr/share/anarchy/boot/
	sudo cp "$aa"/etc/nvidia340.xx "$sq"/usr/share/anarchy/etc/

	### Copy over built packages and create repository
	sudo mkdir "$customiso"/arch/"$sys"/squashfs-root/usr/share/anarchy/pkg

	for pkg in $(echo ${builds[@]}); do
		sudo cp /tmp/$pkg/*.pkg.tar.xz "$sq"/usr/share/anarchy/pkg
	done

	cd "$sq"/usr/share/anarchy/pkg || exit
	sudo repo-add anarchy-local.db.tar.gz *.pkg.tar.xz
	echo -e "\n[anarchy-local]\nServer = file:///usr/share/anarchy/pkg\nSigLevel = Never" | sudo tee -a "$sq"/etc/pacman.conf >/dev/null
	cd "$aa" || exit

	if [ "$sys" == "i686" ]; then
		sudo rm -r "$sq"/root/.gnupg
		sudo rm -r "$sq"/etc/pacman.d/gnupg
		sudo linux32 arch-chroot "$sq" dirmngr </dev/null
		sudo linux32 arch-chroot "$sq" pacman-key --init
		sudo linux32 arch-chroot "$sq" pacman-key --populate archlinux32
		sudo linux32 arch-chroot "$sq" pacman-key --refresh-keys
	fi

}

build_sys() {

	### Install fonts, fbterm, fetchmirrors, arch-wiki
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -Sy terminus-font acpi zsh-syntax-highlighting pacman-contrib
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
	### sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -U /tmp/arch-wiki-cli/*.pkg.tar.xz
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.${sys}.txt
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -Scc
	sudo rm -f "$sq"/var/cache/pacman/pkg/*

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

        ## activating mount points needed by this function
        sudo mount -t proc proc "$sq"/proc/
        sudo mount -t sysfs sys "$sq"/sys/
        sudo mount -o bind /dev "$sq"/dev/

	### Blacklist vbox drivers so they are not loaded on non-vbox
	echo 'FILES="/etc/modprobe.d/blacklist.conf"' | sudo tee -a "$sq"/etc/mkinitcpio.conf > /dev/null
	echo 'FILES="/etc/modprobe.d/blacklist.conf"' | sudo tee -a "$sq"/etc/mkinitcpio-archiso.conf > /dev/null
	echo -e 'blacklist vboxguest\nblacklist vboxsf\nblacklist vboxvideo' | sudo tee -a "$sq"/etc/modprobe.d/blacklist.conf > /dev/null

	### Install fonts, fbterm, fetchmirrors, arch-wiki, and uvesafb drivers onto system and cleanup
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -Syu
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm --needed -Sy terminus-font xorg-server xorg-xinit xterm xf86-video-vesa xf86-input-evdev xf86-input-keyboard xf86-input-mouse xf86-input-synaptics vlc galculator file-roller gparted gimp git pulseaudio pulseaudio-alsa alsa-utils \
		zsh-syntax-highlighting pacman-contrib arc-gtk-theme elementary-icon-theme thunar base-devel gvfs xdg-user-dirs xfce4 xfce4-goodies libreoffice-fresh chromium virtualbox-guest-dkms virtualbox-guest-utils linux linux-headers libdvdcss simplescreenrecorder screenfetch htop acpi pavucontrol libutil-linux
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -U /tmp/arch-wiki-cli/*.pkg.tar.xz
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -U /tmp/numix-icon-theme-git/*.pkg.tar.xz
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -U /tmp/numix-circle-icon-theme-git/*.pkg.tar.xz
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.${sys}.txt
	sudo pacman --root "$sq" --cachedir "$sq"/var/cache/pacman/pkg  --config $paconf --noconfirm -Scc
	sudo rm -f "$sq"/var/cache/pacman/pkg/*
	sudo mv "$sq"/etc/mkinitcpio.conf.bak "$sq"/etc/mkinitcpio.conf

        ### Copy new kernel
	sudo rm "$sq"/boot/initramfs-linux-fallback.img
	sudo mv "$sq"/boot/vmlinuz-linux "$customiso"/arch/boot/"$sys"/vmlinuz
	sudo mv "$sq"/boot/initramfs-linux.img "$customiso"/arch/boot/"$sys"/archiso.img
	
	## mount points are not longer needed. They conflict with arch-chroot.
        sudo umount "$sq"/proc/
        sudo umount "$sq"/sys/
        sudo umount "$sq"/dev/

	### Configure desktop
	sudo arch-chroot "$sq" useradd -m -g users -G power,audio,video,storage -s /usr/bin/zsh user
	sudo arch-chroot "$sq" su user -c xdg-user-dirs-update
	sudo sed -i 's/root/user/' "$sq"/etc/systemd/system/getty@tty1.service.d/autologin.conf
	sudo cp -r "$aa"/extra/gui/*.desktop "$sq"/home/user/Desktop
	sudo cp -r "$aa"/extra/gui/*.desktop "$sq"/usr/share/applications
	sudo cp -r "$aa"/extra/gui/{issue,sudoers} "$sq"/etc/
	sudo cp -r "$aa"/extra/anarchy-icon.png "$sq"/usr/share/pixmaps
	sudo cp -r "$aa"/extra/anarchy-icon.png "$sq"/root/.face
	sudo cp -r "$aa"/extra/anarchy-icon.png "$sq"/home/user/.face
	sudo cp -r "$aa"/extra/fonts/ttf-zekton-rg "$sq"/usr/share/fonts
	sudo cp -r "$aa"/extra/gui/{.xinitrc,.automated_script.sh} "$sq"/root
	sudo cp -r "$aa"/extra/gui/{.xinitrc,.automated_script.sh} "$sq"/home/user
	sudo cp -r "$aa"/extra/shellrc/.zshrc "$sq"/home/user/.zshrc
	sudo cp -r "$sq"/root/.zlogin "$sq"/home/user

	### Configure desktop GUI
	sudo cp -r "$aa"/extra/gui/.config "$sq"/home/user/
	sudo cp -r "$aa"/extra/gui/.config "$sq"/root

	### Fix user permissions
	sudo arch-chroot "$sq" chown -R user /home/user/

	### cd back into root system directory, remove old system
	cd "$customiso"/arch/"$sys" || exit
	rm airootfs.sfs

	### Recreate the ISO using compression remove unsquashed system generate checksums
	echo "Recreating $sys..."
	sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	sudo rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5

}

configure_boot() {

	archiso_label=$(<"$customiso"/loader/entries/archiso-x86_64.conf awk 'NR==6{print $NF}' | sed 's/.*=//')
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
	echo -e "- Anarchy Linux is licensed under GPL v2\n- Webpage: http://anarchylinux.org\n- ISO timestamp: $timestamp\n- $version Official Check Sums:
	* md5sum: $md5_sum
	* sha1sum: $sha1_sum" > "$(sed 's/.iso//' <<<"$version")-checksums.txt"

}

usage() {

	echo "Usage options for: anarchy-creator"
	echo "	-a|--all)	create cli and gui iso"
	echo "	-c|--cli)	create anarchy cli iso"
	echo "	-g|--gui)	create anarchy gui iso"
	echo "  --i686)		create i686 iso"
	echo "  --x86_64)	create x86_64 iso (default)"

}

if (<<<$@ grep "\-\-i686" >/dev/null); then
	sys=i686
	paconf=etc/i686-pacman.conf
	sudo wget "https://raw.githubusercontent.com/archlinux32/packages/master/core/pacman-mirrorlist/mirrorlist" -O /etc/pacman.d/mirrorlist32
	sudo sed -i 's/#//' /etc/pacman.d/mirrorlist32
else
	sys=x86_64
	paconf=/etc/pacman.conf
fi

while (true); do
	case "$1" in
		--i686|--x86_64) shift
		;;
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
done

# vim: ai:ts=8:sw=8:sts=8:noet
