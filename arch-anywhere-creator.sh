#!/bin/bash

# Set the version here
export version=arch-anywhere-1.4-dual.iso

# Set the ISO label here
export iso_label=ARCH_ANYWHERE_201510

# Location variables all directories must exist
export aa=~/arch-anywhere
export repodir=~/arch-anywhere/base
export customiso=~/arch-anywhere/customiso
export mntdir=~/arch-anywhere/mnt

init() {
	if [ -d "$mntdir"/arch ]; then
		cp -a "$mntdir" "$customiso"
	else
		echo "ISO not mounted. [Press enter to mount, any other key to cancel]"
		read input
		if [ "$input" == "" ]; then
			if [ -f "$aa"/archlinux-*.iso ]; then
				sudo mount -t iso9660 -o loop "$aa"/archlinux-*.iso "$mntdir"
				cp -a "$mntdir" "$customiso"
			else
				echo "No archiso found under "$aa" exiting..."
				exit 1
			fi
		else
			exit
		fi
	fi
	update_repos
}

update_repos() {
	echo "Update repo packages first? [Press enter to update, any other key to continue without update]"
	read input
	if [ "$input" == "" ]; then
		cd "$repodir"/x86_64
		sudo pacstrap "$falsepart" -p base base-devel libnewt grub os-prober xorg-server xorg-server-utils xorg-xinit xterm awesome openbox i3 dwm screenfetch openssh lynx htop wireless_tools wpa_supplicant netctl xfce4 xf86-video-ati nvidia nvidia-340xx nvidia-304xx xf86-video-intel lightdm lightdm-gtk-greeter zsh conky htop firefox pulseaudio cmus virtualbox-guest-utils efibootmgr dialog wpa_actiond vim | sed -e '1,9d' > x86_64-package.list
		wget -Ni x86_64-package.list
		repo-add -R x86_64-repo.db.tar.gz *.pkg.tar.xz
		cd "$aa"
		sudo pacstrap "$falsepart" --config "$aa"/update-pacman.conf -p base base-devel libnewt grub os-prober xorg-server xorg-server-utils xorg-xinit xterm awesome openbox i3 dwm screenfetch openssh lynx htop wireless_tools wpa_supplicant netctl xfce4 xf86-video-ati nvidia nvidia-340xx nvidia-304xx xf86-video-intel lightdm lightdm-gtk-greeter zsh conky htop firefox pulseaudio cmus virtualbox-guest-utils efibootmgr dialog wpa_actiond vim | sed -e '1,9d' | sed 's!file://!!g' > x86_64-package.list
	fi
	prepare_x86_64
}

prepare_x86_64() {
	echo "Preparing x86_64..."
	cd "$customiso"/arch/x86_64
	sudo unsquashfs airootfs.sfs
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/repo/
	sudo mkdir "$customiso"/arch/x86_64/squashfs-root/repo/install-repo
	sudo xargs -a "$aa"/etc/x86_64-package.list cp -t "$customiso"/arch/x86_64/squashfs-root/repo/install-repo
	sudo repo-add "$customiso"/arch/x86_64/squashfs-root/repo/install-repo/install-repo.db.tar.gz "$customiso"/arch/x86_64/squashfs-root/repo/install-repo/*.pkg.tar.xz
	sudo cp "$aa"/etc/local-pacman.conf "$customiso"/arch/x86_64/squashfs-root/root
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/x86_64/squashfs-root/etc/
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-english.conf "$customiso"/arch/x86_64/squashfs-root/usr/share/arch-anywhere
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/arch-wiki "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-wiki
	sudo chmod +x "$customiso"/arch/x86_64/squashfs-root/usr/bin/arch-wiki
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.simple-guide.html "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.guide.html "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/extra/.help "$customiso"/arch/x86_64/squashfs-root/root/
	sudo cp "$aa"/boot/issue "$customiso"/arch/x86_64/squashfs-root/etc/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/x86_64/squashfs-root/etc/
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
	sudo xargs -a "$aa"/etc/i686-package.list cp -t "$customiso"/arch/i686/squashfs-root/repo/install-repo
	sudo repo-add "$customiso"/arch/i686/squashfs-root/repo/install-repo/install-repo.db.tar.gz "$customiso"/arch/i686/squashfs-root/repo/install-repo/*.pkg.tar.xz
	sudo cp "$aa"/etc/local-pacman.conf "$customiso"/arch/i686/squashfs-root/root
	sudo cp "$aa"/etc/arch-anywhere.conf "$customiso"/arch/i686/squashfs-root/etc/
	sudo cp "$aa"/arch-installer.sh "$customiso"/arch/i686/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/lang/arch-installer-english.conf "$customiso"/arch/i686/squashfs-root/usr/share/arch-anywhere
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/arch-anywhere
	sudo cp "$aa"/arch-wiki "$customiso"/arch/i686/squashfs-root/usr/bin/arch-wiki
	sudo chmod +x "$customiso"/arch/i686/squashfs-root/usr/bin/arch-wiki	
	sudo cp "$aa"/extra/.zshrc "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.simple-guide.html "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.guide.html "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/extra/.help "$customiso"/arch/i686/squashfs-root/root/
	sudo cp "$aa"/boot/issue "$customiso"/arch/i686/squashfs-root/etc/
	sudo cp "$aa"/boot/hostname "$customiso"/arch/i686/squashfs-root/etc/
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
	sed -ie "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso-x86_64.CD.conf
	sed -ie "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso-x86_64.conf
	sed -ie "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso_sys64.cfg 
	sed -ie "s/archisolabel=.*/archisolabel=$iso_label/" "$aa"/boot/archiso_sys32.cfg
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
}
init
