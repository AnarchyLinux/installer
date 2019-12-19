#!/usr/bin/env bash
###############################################################
### Anarchy Linux Install Script
### configure_boot.sh
###
### Copyright (C) 2017 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: https://anarchylinux.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0
###############################################################

grub_config() {

    if "$crypted" ; then
        sed -i 's!quiet!cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root!' "$CHROOT_MOUNT_POINT"/etc/default/grub
    else
        sed -i 's/quiet//' "$CHROOT_MOUNT_POINT"/etc/default/grub
    fi

    if "$drm" ; then
        sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/ s/.$/ nvidia-drm.modeset=1"/;s/" /"/' "$CHROOT_MOUNT_POINT"/etc/default/grub
    fi

    if "$uefi" ; then
        (arch-chroot "$CHROOT_MOUNT_POINT" grub-install --efi-directory="$esp_mnt" --target=x86_64-efi --bootloader-id=boot
        cp "$CHROOT_MOUNT_POINT"/"$esp_mnt"/EFI/boot/grubx64.efi "$CHROOT_MOUNT_POINT"/"$esp_mnt"/EFI/boot/bootx64.efi) &> /dev/null &
        pid=$! pri=0.1 msg="\n$grub_load1 \n\n \Z1> \Z2grub-install --efi-directory="$esp_mnt"\Zn" load

        if ! "$crypted" ; then
            arch-chroot "$CHROOT_MOUNT_POINT" mkinitcpio -p "$kernel" &>/dev/null &
            pid=$! pri=1 msg="\n$uefi_config_load \n\n \Z1> \Z2mkinitcpio -p $kernel\Zn" load
        fi
    else
        arch-chroot "$CHROOT_MOUNT_POINT" grub-install /dev/"$DRIVE" &> /dev/null &
        pid=$! pri=0.1 msg="\n$grub_load1 \n\n \Z1> \Z2grub-install /dev/$DRIVE\Zn" load
    fi
    arch-chroot "$CHROOT_MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null &
    pid=$! pri=0.1 msg="\n$grub_load2 \n\n \Z1> \Z2grub-mkconfig -o /boot/grub/grub.cfg\Zn" load

}

syslinux_config() {

    if "$uefi" ; then
        esp_part_int=$(<<<"$esp_part" grep -o "[0-9]")
        esp_part=$(<<<"$esp_part" grep -o "sd[a-z]")
        esp_mnt=$(<<<$esp_mnt sed "s!$CHROOT_MOUNT_POINT!!")
        (mkdir -p ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux
        cp -r "$CHROOT_MOUNT_POINT"/usr/lib/syslinux/efi64/* ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/
        cp "${anarchy_directory}"/boot/loader/syslinux/syslinux_efi.cfg ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        cp "${anarchy_directory}"/boot/splash.png ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux

        if [ "$kernel" == "linux-lts" ]; then
            sed -i 's/vmlinuz-linux/vmlinuz-linux-lts/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux.img/initramfs-linux-lts.img/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux-fallback.img/initramfs-linux-lts-fallback.img/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        elif [ "$kernel" == "linux-hardened" ]; then
            sed -i 's/vmlinuz-linux/vmlinuz-linux-hardened/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux.img/initramfs-linux-hardened.img/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux-fallback.img/initramfs-linux-hardened-fallback.img/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        elif [ "$kernel" == "linux-zen" ]; then
            sed -i 's/vmlinuz-linux/vmlinuz-linux-zen/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux.img/initramfs-linux-zen.img/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux-fallback.img/initramfs-linux-zen-fallback.img/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        fi

        arch-chroot "$CHROOT_MOUNT_POINT" efibootmgr -c -d /dev/"$esp_part" -p "$esp_part_int" -l /EFI/syslinux/syslinux.efi -L "Syslinux") &> /dev/null &
        pid=$! pri=0.1 msg="\n$syslinux_load \n\n \Z1> \Z2syslinux install efi mode...\Zn" load

        if "$crypted" ; then
            sed -i "s|APPEND.*$|APPEND root=/dev/mapper/root cryptdevice=/dev/lvm/lvroot:root rw|" ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        else
            sed -i "s|APPEND.*$|APPEND root=/dev/$ROOT|" ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        fi

        if "$drm" ; then
            sed -i '/APPEND/ s/$/ nvidia-drm.modeset=1/' ${CHROOT_MOUNT_POINT}${esp_mnt}/EFI/syslinux/syslinux.cfg
        fi

    else
        (syslinux-install_update -i -a -m -c "$CHROOT_MOUNT_POINT"
        cp "${anarchy_directory}"/boot/loader/syslinux/syslinux.cfg "$CHROOT_MOUNT_POINT"/boot/syslinux/
        cp "${anarchy_directory}"/boot/splash.png "$CHROOT_MOUNT_POINT"/boot/syslinux/) &> /dev/null &
        pid=$! pri=0.1 msg="\n$syslinux_load \n\n \Z1> \Z2syslinux-install_update -i -a -m -c $CHROOT_MOUNT_POINT\Zn" load

        if [ "$kernel" == "linux-lts" ]; then
            sed -i 's/vmlinuz-linux/vmlinuz-linux-lts/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux.img/initramfs-linux-lts.img/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux-fallback.img/initramfs-linux-lts-fallback.img/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
        elif [ "$kernel" == "linux-hardened" ]; then
            sed -i 's/vmlinuz-linux/vmlinuz-linux-hardened/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux.img/initramfs-linux-hardened.img/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux-fallback.img/initramfs-linux-hardened-fallback.img/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
        elif [ "$kernel" == "linux-zen" ]; then
            sed -i 's/vmlinuz-linux/vmlinuz-linux-zen/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux.img/initramfs-linux-zen.img/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
            sed -i 's/initramfs-linux-fallback.img/initramfs-linux-zen-fallback.img/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
        fi

        if "$crypted" ; then
            sed -i "s|APPEND.*$|APPEND root=/dev/mapper/root cryptdevice=/dev/lvm/lvroot:root rw|" "$CHROOT_MOUNT_POINT"/boot/syslinux/syslinux.cfg
        else
            sed -i "s|APPEND.*$|APPEND root=/dev/$ROOT|" "$CHROOT_MOUNT_POINT"/boot/syslinux/syslinux.cfg
        fi

        if "$drm" ; then
            sed -i '/APPEND/ s/$/ nvidia-drm.modeset=1/' ${CHROOT_MOUNT_POINT}/boot/syslinux/syslinux.cfg
        fi
    fi

}

systemd_config() {

    esp_mnt=$(<<<$esp_mnt sed "s!$CHROOT_MOUNT_POINT!!")
    (arch-chroot "$CHROOT_MOUNT_POINT" bootctl --path="$esp_mnt" install
    cp /usr/share/systemd/bootctl/loader.conf ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/
    echo "timeout 4" >> ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/loader.conf) &> /dev/null &
    pid=$! pri=0.1 msg="\n$syslinux_load \n\n \Z1> \Z2bootctl --path="$esp_mnt" install\Zn" load

    if [ "$kernel" == "linux" ]; then
        echo -e "title          Arch Linux\nlinux          /vmlinuz-linux\ninitrd         /initramfs-linux.img" > ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    elif [ "$kernel" == "linux-lts" ]; then
        echo -e "title          Arch Linux\nlinux          /vmlinuz-linux-lts\ninitrd         /initramfs-linux-lts.img" > ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    elif [ "$kernel" == "linux-hardened" ]; then
        echo -e "title          Arch Linux\nlinux          /vmlinuz-linux-hardened\ninitrd         /initramfs-linux-hardened.img" > ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    elif [ "$kernel" == "linux-zen" ]; then
        echo -e "title          Arch Linux\nlinux          /vmlinuz-linux-zen\ninitrd         /initramfs-linux-zen.img" > ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    fi

    if "$crypted" ; then
        echo "options		cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root quiet rw" >> ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    else
        echo "options		root=PARTUUID=$(blkid -s PARTUUID -o value $(df | grep -m1 "$CHROOT_MOUNT_POINT" | awk '{print $1}')) rw" >> ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    fi

    if "$drm" ; then
        sed -i '/options/ s/$/ nvidia-drm.modeset=1/' ${CHROOT_MOUNT_POINT}${esp_mnt}/loader/entries/arch.conf
    fi

}

efistub_config() {

    initramfs="initramfs-linux.img"
    if [ "$kernel" == "linux-lts" ]; then
        initramfs="initramfs-linux-lts.img"
    elif [ "$kernel" == "linux-hardened" ]; then
        initramfs="initramfs-linux-hardened.img"
    elif [ "$kernel" == "linux-zen" ]; then
        initramfs="initramfs-linux-zen.img"
    fi

    efi_root="root=/dev/$ROOT"
    if "$crypted" ; then
        efi_root="cryptdevice=/dev/lvm/lvroot:root root=/dev/mapper/root"
    fi

    efi_drm=""
    if "$drm" ; then
        efi_drm="nvidia-drm.modeset=1"
    fi

    # -p: boot partition number (is always "1")
    efibootmgr -d /dev/$DRIVE -p 1 -c -L "Arch Linux" -l \vmlinuz-linux -u "$efi_root rw initrd=/$initramfs $drm"

}

# vim: ai:ts=4:sw=4:et
