#!/bin/bash

# Set the version here
export version="arch-anywhere-2.1.6-dual.iso"

# Set the ISO label here
export iso_label="ARCH_ANYWHERE_2.1.6"

# Location variables all directories must exist
export aa=~/arch-linux-anywhere
export customiso=~/arch-linux-anywhere/customiso
export mntdir=~/arch-linux-anywhere/mnt

# Link to the iso used to create Arch Anywhere
export archiso_link="http://arch.localmsp.org/arch/iso/2016.04.01/archlinux-2016.04.01-dual.iso"

init() {
	
	if [ -d "$customiso" ]; then
		sudo rm -rf "$customiso"
	fi

	if [ ! -d "$mntdir" ]; then
		mkdir "$mntdir"
	fi
	
	if [ -d "$mntdir"/arch ]; then
		cp -a "$mntdir" "$customiso"
	else
		mounted=false
		echo -n "ISO not mounted would you like to mount it now? [y/n]: "
		read input
		
		until "$mounted"
		  do
			case "$input" in
				y|Y|yes|Yes|yY|Yy|yy|YY)
					if [ -f "$aa"/archlinux-*.iso ]; then
						sudo mount -t iso9660 -o loop "$aa"/archlinux-*.iso "$mntdir"
						if [ "$?" -eq "0" ]; then
							mounted=true
						else
							echo "Error: failed mounting the archiso, exiting."
							exit 1
						fi
						cp -a "$mntdir" "$customiso"
					else
						echo
						echo -n "No archiso found under $aa would you like to download now? [y/N]"
						read input
    
						case "$input" in
							y|Y|yes|Yes|yY|Yy|yy|YY)
								cd "$aa"
								wget "$archiso_link"
								if [ "$?" -gt "0" ]; then
									echo "Error: requires wget, exiting"
									exit 1
								fi
							;;
							n|N|no|No|nN|Nn|nn|NN)
								echo "Error: Creating the ISO requires the official archiso to be located at $aa, exiting."
								exit 1
							;;
						esac
					fi
				;;
				n|N|no|No|nN|Nn|nn|NN)
					echo "Error: archiso must be mounted at $mntdir, exiting."
					exit1
				;;
			esac
		done
	fi

# Check depends

	if [ ! -f /usr/bin/mksquashfs ] || [ ! -f /usr/bin/xorriso ] || [ ! -f /usr/bin/wget ] || [ ! -f /usr/bin/arch-chroot ]; then
		depends=false
		until "$depends"
		  do
			echo
			echo -n "ISO creation requires arch-install-scripts, mksquashfs-tools, libisoburn, and wget, would you like to install missing dependencies now? [y/N]: "
			read input

			case "$input" in
				y|Y|yes|Yes|yY|Yy|yy|YY)
					if [ ! -f "/usr/bin/wget" ]; then query="wget"; fi
					if [ ! -f /usr/bin/xorriso ]; then query="$query libisoburn"; fi
					if [ ! -f /usr/bin/mksquashfs ]; then query="$query squashfs-tools"; fi
					if [ ! -f /usr/bin/arch-chroot ]; then query="$query arch-install-scripts"; fi
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
	prepare_x86_64

}

prepare_x86_64() {
	
### Change directory into the ISO where the filesystem is stored.
### Unsquash root filesystem 'airootfs.sfs' this creates a directory 'squashfs-root' containing the entire system
	echo "Preparing x86_64..."
	cd "$customiso"/arch/x86_64
	sudo unsquashfs airootfs.sfs
	
### Install fonts onto system and cleanup
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Syyy terminus-font
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.x86_64.txt
	sudo pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Scc
	sudo rm -f "$customiso"/arch/x86_64/squashfs-root/var/cache/pacman/pkg/*
	
### Copy over vconsole.conf (sets font at boot) & locale.gen (enables locale(s) for font)
	sudo cp "$aa"/etc/vconsole.conf "$customiso"/arch/x86_64/squashfs-root/etc
	sudo cp "$aa"/etc/locale.gen "$customiso"/arch/x86_64/squashfs-root/etc
	sudo arch-chroot squashfs-root /bin/bash locale-gen
	
### Copy over main arch anywhere config, installer script, and arch-wiki,  make executeable
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/x86_64/squashfs-root/etc/
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/extra/arch-wiki "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-wiki
	sudo cp "$aa"/extra/fetchmirrors "$customiso"/arch/x86_64/squashfs-root/usr/bin/fetchmirrors
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-anywhere
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-wiki
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/fetchmirrors
	
### Create arch-anywhere directory and lang directory copy over all lang files
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/{lang,pkg}
	sudo cp "$aa"/lang/* "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/lang
	sudo cp /tmp/fetchmirrors/*.pkg.tar.xz "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/pkg
	sudo cp /tmp/arch-wiki-cli/*.pkg.tar.xz "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/pkg

### Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.help "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.bashrc "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/extra/.zshrc-sys "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/.zshrc
	sudo cp "$aa"/extra/.bashrc-root "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
#	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/pkg
#	sudo mv /tmp/*.pkg.tar.xz "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/pkg
	sudo cp -r "$aa"/extra/desktop "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere/
	sudo cp "$aa"/boot/issue "$customiso"/arch/x86_64/squashfs-root/etc/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/x86_64/squashfs-root/etc/
	
### cd back into root system directory, remove old system
	cd "$customiso"/arch/x86_64
	rm airootfs.sfs

### Recreate the ISO using compression remove unsquashed system generate checksums and continue to i686
	echo "Recreating x86_64..."
	sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	sudo rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5
	prepare_i686

}

prepare_i686() {
	
	echo "Preparing i686..."
	cd "$customiso"/arch/i686
	sudo unsquashfs airootfs.sfs
	sudo sed -i 's/\$arch/i686/g' squashfs-root/etc/pacman.d/mirrorlist
	sudo sed -i 's/auto/i686/' squashfs-root/etc/pacman.conf
	sudo setarch i686 pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Syyy terminus-font
	sudo setarch i686 pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "$customiso"/arch/pkglist.i686.txt
	sudo setarch i686 pacman --root squashfs-root --cachedir squashfs-root/var/cache/pacman/pkg  --config squashfs-root/etc/pacman.conf --noconfirm -Scc
	sudo rm -f "$customiso"/arch/i686/squashfs-root//var/cache/pacman/pkg/*
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/i686/squashfs-root/etc/
	sudo cp "$aa"/etc/locale.gen "$customiso"/arch/i686/squashfs-root/etc
	sudo arch-chroot squashfs-root /bin/bash locale-gen
	sudo cp "$aa"/etc/vconsole.conf "$customiso"/arch/i686/squashfs-root/etc
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/i686/squashfs-root/usr/bin/arch-anywhere
	sudo mkdir "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo mkdir "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere/{lang,pkg}
	sudo cp "$aa"/lang/* "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere/lang
	sudo cp /tmp/fetchmirrors/*.pkg.tar.xz "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere/pkg
	sudo cp /tmp/arch-wiki-cli/*.pkg.tar.xz "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere/pkg
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/extra/arch-wiki "$customiso"/arch/i686/squashfs-root/usr/bin/arch-wiki
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/arch-wiki	
	sudo cp "$aa"/extra/fetchmirrors "$customiso"/arch/i686/squashfs-root/usr/bin/fetchmirrors
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/fetchmirrors
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.help "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.bashrc "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/extra/.bashrc-root "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp -r "$aa"/extra/desktop "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere/
	sudo cp "$aa"/boot/issue "$customiso"/arch/i686/squashfs-root/etc/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/i686/squashfs-root/etc/
	cd "$customiso"/arch/i686
	rm airootfs.sfs
	echo "Recreating i686..."
	sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	sudo rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5
	configure_boot

}

configure_boot() {
	
	sudo mkdir "$customiso"/EFI/archiso/mnt
	sudo mount -o loop "$customiso"/EFI/archiso/efiboot.img "$customiso"/EFI/archiso/mnt
	sed -i "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso-x86_64.CD.conf
	sed -i "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso-x86_64.conf
	sed -i "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso_sys64.cfg 
	sed -i "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso_sys32.cfg
	sudo cp "$aa"/boot/archiso-x86_64.CD.conf "$customiso"/EFI/archiso/mnt/loader/entries/archiso-x86_64.conf
	sudo umount "$customiso"/EFI/archiso/mnt
	sudo rmdir "$customiso"/EFI/archiso/mnt
	cp "$aa"/boot/archiso-x86_64.conf "$customiso"/loader/entries/
	cp "$aa"/boot/splash.png "$customiso"/arch/boot/syslinux
	cp "$aa"/boot/archiso_head.cfg "$customiso"/arch/boot/syslinux
	cp "$aa"/boot/archiso_sys64.cfg "$customiso"/arch/boot/syslinux
	cp "$aa"/boot/archiso_sys32.cfg "$customiso"/arch/boot/syslinux
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
				sudo umount "$mntdir"
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
