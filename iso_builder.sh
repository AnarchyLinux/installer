#!/bin/bash
export customiso=~/archiso/customiso
export archiso=~/archiso
init() {
	if [ -d /mnt/archiso/arch ]; then
		cp -a /mnt/archiso "$customiso"
	else
		echo "ISO not mounted, press enter to mount, any other key to cancel"
		read input
		if [ "$input" == "" ]; then
			if [ -f "$archiso"/archlinux*.iso ]; then
				sudo mount -t iso9660 -o loop "$archiso"/archlinux*.iso /mnt/archiso
				cp -a /mnt/archiso "$customiso"
			else
				echo "No ISO found at ~/archiso exiting..."
				exit 1
			fi
		else
			exit
		fi
	fi
	prepare_x86_64
}

prepare_x86_64() {
	echo "Preparing x86_64..."
	cd "$customiso"/arch/x86_64
	unsquashfs airootfs.sfs
	mkdir "$customiso"/arch/x86_64/mnt
	sudo mount -o loop "$customiso"/arch/x86_64/squashfs-root/airootfs.img "$customiso"/arch/x86_64/mnt
	sudo mkdir "$customiso"/arch/x86_64/mnt/repo/
	sudo mkdir "$customiso"/arch/x86_64/mnt/repo/install-repo
	sudo cp "$archiso"/base/x86_64/*.pkg.tar.xz "$customiso"/arch/x86_64/mnt/repo/install-repo/
	sudo repo-add "$customiso"/arch/x86_64/mnt/repo/install-repo/install-repo.db.tar.gz "$customiso"/arch/x86_64/mnt/repo/install-repo/*.pkg.tar.xz
	sudo cp "$archiso"/local-pacman.conf "$customiso"/arch/x86_64/mnt/root
	sudo cp "$archiso"/arch-installer.sh "$customiso"/arch/x86_64/mnt/usr/bin/arch-anywhere
	sudo chmod +x "$customiso"/arch/x86_64/mnt/usr/bin/arch-anywhere
	sudo cp "$archiso"/issue "$customiso"/arch/x86_64/mnt/etc/
	sudo cp "$archiso"/hostname "$customiso"/arch/x86_64/mnt/etc/
	sudo umount mnt
	rm airootfs.sfs
	echo "Recreating x86_64..."
	mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	rmdir mnt
	rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5
	prepare_i686
}

prepare_i686() {
	echo "Preparing i686..."
	cd "$customiso"/arch/i686
	unsquashfs airootfs.sfs
	mkdir "$customiso"/arch/i686/mnt
	sudo mount -o loop "$customiso"/arch/i686/squashfs-root/airootfs.img "$customiso"/arch/i686/mnt
	sudo mkdir "$customiso"/arch/i686/mnt/repo/
	sudo mkdir "$customiso"/arch/i686/mnt/repo/install-repo
	sudo cp "$archiso"/base/i686/*.pkg.tar.xz "$customiso"/arch/i686/mnt/repo/install-repo/
	sudo repo-add "$customiso"/arch/i686/mnt/repo/install-repo/install-repo.db.tar.gz "$customiso"/arch/i686/mnt/repo/install-repo/*.pkg.tar.xz
	sudo cp "$archiso"/local-pacman.conf "$customiso"/arch/i686/mnt/root
	sudo cp "$archiso"/arch-installer.sh "$customiso"/arch/i686/mnt/usr/bin/arch-anywhere
	sudo chmod +x "$customiso"/arch/i686/mnt/usr/bin/arch-anywhere
	sudo cp "$archiso"/issue "$customiso"/arch/i686/mnt/etc/
	sudo cp "$archiso"/hostname "$customiso"/arch/i686/mnt/etc/
	sudo umount mnt
	rm airootfs.sfs
	echo "Recreating i686..."
	mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
	rmdir mnt
	rm -r squashfs-root
	md5sum airootfs.sfs > airootfs.md5
	configure_boot
}

configure_boot() {
	cp "$archiso"/splash.png "$customiso"/arch/boot/syslinux
	cp "$archiso"/archiso_head.cfg "$customiso"/arch/boot/syslinux
	cp "$archiso"/archiso_sys64.cfg "$customiso"/arch/boot/syslinux
	cp "$archiso"/archiso_sys32.cfg "$customiso"/arch/boot/syslinux
	export iso_label=$(file "$archiso"/archlinux*.iso | awk '{print $13}' | sed "s/'//g")
}
init
