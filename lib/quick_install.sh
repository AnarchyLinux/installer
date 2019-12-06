#!/usr/bin/env bash

case "${install_opt}" in
    1)
        kernel="linux"
        sh="/usr/bin/zsh"
        shrc="${default}"
        bootloader="grub"
        net_util="networkmanager"
        enable_nm=true
        multilib=true
        dhcp=true
        desktop=true
        base_install=(
            'base-devel'
            'linux'
            'linux-headers'
            'zsh'
            'zsh-syntax-highlighting'
            'grub'
            'dialog'
            'networkmanager'
            'wireless_tools'
            'wpa_supplicant'
            'os-prober'
        )

        if "${bluetooth}" ; then
            base_install+=(
                'bluez'
                'bluez-utils'
                'pulseaudio-bluetooth'
            )
            enable_bt=true
        fi

        if "${enable_f2fs}" ; then
            base_install+=('f2fs-tools')
        fi

        if "${UEFI}" ; then
            base_install+=('efibootmgr')
        fi

        source "${anarchy_scripts}"/select_desktop.sh
        base_install+=("${DE}")
    ;;

    2)
        kernel="linux-lts"
        sh="/usr/bin/zsh"
        shrc="${default}"
        bootloader="grub"
        net_util="networkmanager"
        enable_nm=true
        multilib=true
        dhcp=true
        desktop=true
        base_install=(
            'base-devel'
            'linux-lts'
            'linux-lts-headers'
            'zsh'
            'zsh-syntax-highlighting'
            'grub'
            'dialog'
            'networkmanager'
            'wireless_tools'
            'wpa_supplicant'
            'os-prober'
        )

        if "${bluetooth}" ; then
            base_install+=(
                'bluez'
                'bluez-utils'
                'pulseaudio-bluetooth'
            )
            enable_bt=true
        fi

        if "${enable_f2fs}" ; then
             base_install+=('f2fs-tools')
        fi

        if "${UEFI}" ; then
            base_install+=('efibootmgr')
        fi

        source "${anarchy_scripts}"/select_desktop.sh
        base_install+=("${DE}")
    ;;

    3)
        kernel="linux"
        sh="/usr/bin/zsh"
        shrc="${default}"
        bootloader="grub"
        net_util="networkmanager"
        enable_nm=true
        multilib=true
        dhcp=true
        base_install=(
            'base-devel'
            'linux'
            'openssh'
            'linux-headers'
            'zsh'
            'zsh-syntax-highlighting'
            'grub'
            'dialog'
            'wireless_tools'
            'wpa_supplicant'
            'os-prober'
        )

        if "${bluetooth}" ; then
            base_install+=(
                'bluez'
                'bluez-utils'
                'pulseaudio-bluetooth'
            )
            enable_bt=true
        fi

        if "${enable_f2fs}" ; then
            base_install+=('f2fs-tools')
        fi

        if "${UEFI}" ; then
            base_install+=('efibootmgr')
        fi
    ;;

    4)
        kernel="linux-lts"
        sh="/usr/bin/zsh"
        shrc="${default}"
        bootloader="grub"
        net_util="networkmanager"
        enable_nm=true
        multilib=true
        dhcp=true
        base_install=(
            'base-devel'
            'openssh'
            'linux-lts'
            'linux-lts-headers'
            'zsh'
            'zsh-syntax-highlighting'
            'grub'
            'dialog'
            'wireless_tools'
            'wpa_supplicant'
            'os-prober'
        )

        if "${bluetooth}" ; then
            base_install+=(
                'bluez'
                'bluez-utils'
                'pulseaudio-bluetooth'
            )
            enable_bt=true
        fi

        if "${enable_f2fs}" ; then
             base_install+=('f2fs-tools')
        fi

        if "${UEFI}" ; then
            base_install+=('efibootmgr')
        fi
    ;;
esac

# Append the selected packages to the packages file
for package in "${base_install[@]}"; do
    echo -e "${package}" >> packages_file
done