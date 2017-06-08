#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
### arch-anywhere-creator.sh
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
export version="arch-anywhere-2.2.8-x86_64.iso"

# Set the ISO label here
export iso_label="ARCH_ANY228"

# Location variables all directories must exist
export aa=$(pwd)
export customiso="$aa/customiso"
export iso=$(ls "$aa"/archlinux-* | tail -n1 | sed 's!.*/!!')
update=false

# Check depends

if [ ! -f /usr/bin/7z ] || [ ! -f /usr/bin/mksquashfs ] || [ ! -f /usr/bin/xorriso ] || [ ! -f /usr/bin/wget ] || [ ! -f /usr/bin/arch-chroot ] || [ ! -f /usr/bin/xxd ]; then
	depends=false
	until "$depends"
	  do
		echo
		echo -n "ISO creation requires arch-install-scripts, lynx, mksquashfs-tools, libisoburn, and wget, would you like to install missing dependencies now? [y/N]: "
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


# Link to the iso used to create Arch Anywhere
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

	if [ ! -d /tmp/arc-openbox-master ]; then
		### Build Arc Openbox theme
		cd /tmp
		wget "https://github.com/dglava/arc-openbox/archive/master.zip"
		unzip master.zip
	fi

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

### Install fonts, fbterm, fetchmirrors, arch-wiki, and uvesafb drivers onto system and cleanup
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Syyy terminus-font
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/arch-wiki-cli/*.pkg.tar.xz
#	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -U /tmp/v86d/*.pkg.tar.xz
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.${sys}.txt
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Scc
	sudo rm -f "$customiso"/arch/"$sys"/squashfs-root/var/cache/pacman/pkg/*

### Copy over vconsole.conf (sets font at boot) & locale.gen (enables locale(s) for font) & uvesafb.conf
	sudo cp "$aa"/etc/{vconsole.conf,locale.gen} "$customiso"/arch/"$sys"/squashfs-root/etc
#	sudo cp "$aa"/etc/uvesafb.conf "$customiso"/arch/"$sys"/squashfs-root/etc/modules-load.d/
	sudo arch-chroot squashfs-root /bin/bash locale-gen

### Copy over main arch anywhere config, installer script, and arch-wiki,  make executeable
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/"$sys"/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/extra/{sysinfo,iptest} "$customiso"/arch/"$sys"/squashfs-root/usr/bin/
	sudo chmod +x "$customiso"/arch/"$sys"/squashfs-root/usr/bin/{arch-anywhere,sysinfo,iptest}

### Create arch-anywhere directory and lang directory copy over all lang files
	sudo mkdir -p "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/{lang,extra,boot,etc}
	sudo cp "$aa"/lang/* "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/lang

### Create shell function library
	sudo mkdir "$customiso"/arch/"$sys"/squashfs-root/usr/lib/arch-anywhere
	sudo cp "$aa"/lib/* "$customiso"/arch/"$sys"/squashfs-root/usr/lib/arch-anywhere

### Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
	sudo cp "$aa"/extra/{.zshrc,.help,.dialogrc} "$customiso"/arch/"$sys"/squashfs-root/root/
	sudo cp "$aa"/extra/{.bashrc,.bashrc-root,.tcshrc,.tcshrc.conf,.mkshrc} "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/extra/
	sudo cp "$aa"/extra/.zshrc-sys "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/extra/.zshrc
	sudo cp -r "$aa"/extra/desktop "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/extra/
	sudo cp -r /tmp/arc-openbox-master/{Arc,Arc-Dark,Arc-Darker} "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/extra/desktop
	sudo cp "$aa"/boot/{hostname,issue} "$customiso"/arch/"$sys"/squashfs-root/etc/
	sudo cp -r "$aa"/boot/loader/ "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/boot/
	sudo cp "$aa"/boot/splash.png "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/boot/
	sudo cp "$aa"/etc/{nvidia340.xx,nvidia304.xx} "$customiso"/arch/"$sys"/squashfs-root/usr/share/arch-anywhere/etc/

### cd back into root system directory, remove old system
	cd "$customiso"/arch/"$sys"
	rm airootfs.sfs

### Recreate the ISO using compression remove unsquashed system generate checksums and continue to i686
	echo "Recreating $sys..."
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
	sed -i "s/$archiso_label/$iso_label/" "$customiso"/loader/entries/archiso-x86_64.conf
	sed -i "s/$archiso_label/$iso_label/" "$customiso"/arch/boot/syslinux/archiso_sys.cfg 
	sed -i "s/$archiso_label/$iso_label/" "$customiso"/arch/boot/syslinux/archiso_pxe.cfg
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
echo "Checksums generated. Saved to arch-anywhere-checksums.txt"
echo -e "- Arch Anywhere is licensed under GPL v2\n- Developer: Dylan Schacht (deadhead3492@gmail.com)\n- Webpage: http://arch-anywhere.org\n- ISO timestamp: $timestamp\n- $version Official Check Sums:\n\n* md5sum: $md5_sum\n* sha1sum: $sha1_sum" > arch-anywhere-checksums.txt
echo
echo "$version ISO generated successfully! Exiting ISO creator."
echo
exit

}

init
