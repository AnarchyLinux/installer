#!/bin/bash

# Set the version here
export version="arch-anywhere-1.7-dual.iso"

# Set the ISO label here
export iso_label="ARCH_ANYWHERE_201512"

# Location variables all directories must exist
export aa=~/arch-anywhere
export repodir=~/arch-anywhere/base
export customiso=~/arch-anywhere/customiso
export mntdir=~/arch-anywhere/mnt

# Link to the iso used to create Arch Anywhere
export archiso_link="http://arch.localmsp.org/arch/iso/2015.12.01/archlinux-2015.12.01-dual.iso"

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

	if [ ! -f /usr/bin/mksquashfs ] || [ ! -f /usr/bin/xorriso ]; then
		depends=false
		until "$depends"
		  do
			echo
			echo -n "ISO creation requires mksquashfs-tools, would you like to install it now? [y/N]: "
			read input

			case "$input" in
				y|Y|yes|Yes|yY|Yy|yy|YY)
					if [ ! -f /usr/bin/xorriso ]; then
						sudo pacman -S mksquashfs-tools libisoburn
					else
						sudo pacman -S mksquashfs-tools
					fi
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

	update_repos

}

update_repos() {

	ready=false
	correct=false
	echo -en "How would you like to fetch the packages?\n\n1.) Local dh-repo packages (At home only)\n2.) Offical repo packages (If online)\n\n[1 or 2]: "
	read input

	until "$ready"
	  do
		case "$input" in
			2|2.)
				if [ ! -d /opt/arch64 ]; then
					sudo mkdir /opt/arch64
					sudo mkdir -p /opt/arch64/var/{cache/pacman/pkg,lib/pacman}
				fi

				if [ ! -f /opt/arch64/pacman.conf ]; then
					sudo cp "$aa"/etc/x86_64-pacman.conf /opt/arch64
					sudo cp "$aa"/etc/x86_64-mirrorlist /opt/arch64
				fi
			
				if [ ! -d /opt/arch32 ]; then
					sudo mkdir /opt/arch32
					sudo mkdir -p /opt/arch32/var/{cache/pacman/pkg,lib/pacman}
				fi

				if [ ! -f /opt/arch32/pacman.conf ]; then
					sudo cp "$aa"/etc/i686-pacman.conf /opt/arch32
					sudo cp "$aa"/etc/i686-mirrorlist /opt/arch32
				fi
				
				ready=true
			;;
			1|1.)
				if [ ! -d /opt/arch64 ] || [ ! -f /opt/arch64/pacman.conf ]; then
					until "$correct"
					  do
						echo "Error: This option requires a custom repository to be setup and 64 bit + 32 bit install roots to be setup at /opt/arch64 and /opt/arch32"
						echo -n "Would you like to use the official repos instead? [y/N]: "
						read input

						case "$input" in
							y|Y|yes|Yes|yY|Yy|yy|YY)
								correct=true
								input="2"
							;;
							n|N|no|No|nN|Nn|nn|NN)
								echo "Error: creation of the ISO requires access to a package repo, exiting."
								exit 1
							;;
						esac
					done
				else
					ready=true
				fi
			;;
		esac
	done

	sudo pacman --root /opt/arch64 --cachedir /opt/arch64/var/cache/pacman/pkg --config /opt/arch64/pacman.conf -Syyy
	sudo pacman --root /opt/arch32 --cachedir /opt/arch32/var/cache/pacman/pkg --config /opt/arch32/pacman.conf -Syyy
	sudo pacman --root /opt/arch64 --cachedir /opt/arch64/var/cache/pacman/pkg --config /opt/arch64/pacman.conf -Sp base base-devel libnewt grub os-prober wget xorg-server xorg-server-utils xorg-xinit xterm awesome openbox i3 dwm screenfetch openssh lynx htop wireless_tools wpa_supplicant netctl xfce4 xf86-video-ati nvidia nvidia-340xx nvidia-304xx xf86-video-intel lightdm lightdm-gtk-greeter zsh conky htop firefox pulseaudio cmus virtualbox-guest-utils efibootmgr dialog wpa_actiond vim xf86-input-synaptics > "$aa"/etc/x86_64-package.list
	sudo pacman --root /opt/arch32 --cachedir /opt/arch32/var/cache/pacman/pkg --config /opt/arch32/pacman.conf -Sp base base-devel libnewt grub os-prober wget xorg-server xorg-server-utils xorg-xinit xterm awesome openbox i3 dwm screenfetch openssh lynx htop wireless_tools wpa_supplicant netctl xfce4 xf86-video-ati nvidia nvidia-340xx nvidia-304xx xf86-video-intel lightdm lightdm-gtk-greeter zsh conky htop firefox pulseaudio cmus virtualbox-guest-utils efibootmgr dialog wpa_actiond vim xf86-input-synaptics > "$aa"/etc/i686-package.list
	prepare_x86_64

}

prepare_x86_64() {
	
	echo "Preparing x86_64..."
	cd "$customiso"/arch/x86_64
	sudo unsquashfs airootfs.sfs
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/repo/
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/repo/install-repo
	cd "$customiso"/arch/x86_64/squashfs-root/repo/install-repo
	sudo wget -i "$aa"/etc/x86_64-package.list
	sudo repo-add "$customiso"/arch/x86_64/squashfs-root/repo/install-repo/install-repo.db.tar.gz "$customiso"/arch/x86_64/squashfs-root/repo/install-repo/*.pkg.tar.xz
	sudo cp "$aa"/etc/local-pacman.conf "$customiso"/arch/x86_64/squashfs-root/root
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/x86_64/squashfs-root/etc/
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-anywhere
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-english.conf "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-german.conf "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-portuguese.conf "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-romanian.conf "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/extra/arch-wiki "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-wiki
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-wiki
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.simple-guide.html "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.guide.html "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.help "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/boot/issue "$customiso"/arch/x86_64/squashfs-root/etc/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/x86_64/squashfs-root/etc/
	cd "$customiso"/arch/x86_64	
	rm airootfs.sfs
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
	sudo mkdir "$customiso"/arch/i686/squashfs-root/repo/
	sudo mkdir "$customiso"/arch/i686/squashfs-root/repo/install-repo
	cd "$customiso"/arch/i686/squashfs-root/repo/install-repo
	sudo wget -i "$aa"/etc/i686-package.list
	sudo repo-add "$customiso"/arch/i686/squashfs-root/repo/install-repo/install-repo.db.tar.gz "$customiso"/arch/i686/squashfs-root/repo/install-repo/*.pkg.tar.xz
	sudo cp "$aa"/etc/local-pacman.conf "$customiso"/arch/i686/squashfs-root/root
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/i686/squashfs-root/etc/
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/i686/squashfs-root/usr/bin/arch-anywhere
	sudo mkdir "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-english.conf "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-german.conf "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-portuguese.conf "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-romanian.conf "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/extra/arch-wiki "$customiso"/arch/i686/squashfs-root/usr/bin/arch-wiki
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/arch-wiki	
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.simple-guide.html "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.guide.html "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.help "$customiso"/arch/i686/squashfs-root/root/
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

	xorriso -as mkisofs iso-level 3 \
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
				exit
			;;
			n|N|no|No|nN|Nn|nn|NN)
				exit
			;;
		esac
	else
		echo "Error: ISO creation failed, please email the developer: deadhead3492@gmail.com"
		exit 1
	fi

}

init
