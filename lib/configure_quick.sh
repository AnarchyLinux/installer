#!/usr/bin/env bash

quick_install() {
    case "${install_opt}" in
        Anarchy-Desktop)    kernel="linux"
                            desktop=true
		            base_install="base-devel linux linux-headers ${base_defaults} ${base_defaults_ex} "
                            quick_desktop
                            base_install+="${DE} "
        ;;
        Anarchy-Desktop-LTS)    kernel="linux-lts"
                                desktop=true
                                base_install="base-devel linux-lts linux-lts-headers ${base_defaults} ${base_defaults_ex} "
                                quick_desktop
                                base_install+="${DE} "
        ;;
        Anarchy-Server)     kernel="linux"
                            base_install="base-devel linux linux-headers ${base_defaults} ${base_defaults_ex} "
        ;;
        Anarchy-Server-LTS)     kernel="linux-lts"
                                base_install="base-devel linux-lts linux-lts-headers ${base_defaults} ${base_defaults_ex} "

        ;;
    esac
    
    sh="/usr/bin/zsh"
    shrc="${default}"
    bootloader="grub"
    net_util="networkmanager"
    enable_nm=true
    multilib=true
    dhcp=true

    if "${bluetooth}" ; then
        base_install+="bluez bluez-utils pulseaudio-bluetooth "
        enable_bt=true
    fi

    if "${enable_f2fs}" ; then
        base_install+="f2fs-tools "
    fi

    if "${UEFI}" ; then
        base_install+="efibootmgr "
    fi

}

quick_desktop() {

    while (true) ; do
        de=$(dialog --ok-button "${done_msg}" --cancel-button "${cancel}" --menu "${environment_msg}" 14 60 5 \
            "Anarchy-budgie"        "${de24}" \
            "Anarchy-cinnamon"      "${de23}" \
            "Anarchy-gnome"         "${de22}" \
            "Anarchy-openbox"       "${de18}" \
            "Anarchy-xfce4"         "${de15}" 3>&1 1>&2 2>&3)

        if [ -z "${de}" ]; then
            if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n${desktop_cancel_msg}" 10 60) then
                return
            fi
        else
	    if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n${desktop_suite_msg}" 10 60) then
		suite=true
	    fi
	
	    if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n${aur_help_msg}" 10 60) then
	        aur_helper=true
	    fi
	    break
        fi
    done

    if ! (</etc/pacman.conf grep "anarchy-local"); then
                 sed -i -e '$a\\n[anarchy-local]\nServer = file:///usr/share/anarchy/pkg\nSigLevel = Never' /etc/pacman.conf
    fi

    case "${de}" in
        "Anarchy-xfce4")    config_env="${de}"
                            start_term="exec startxfce4"
                            DE+="xfce4 xfce4-goodies ${desktop_extras} "
        ;;
        "Anarchy-budgie")       config_env="${de}"
                                start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
                                DE+="budgie-desktop mousepad terminator nautilus gnome-backgrounds gnome-control-center ${desktop_extras} "
        ;;
        "Anarchy-cinnamon")     config_env="${de}"
                                DE+="cinnamon cinnamon-translations gnome-terminal file-roller p7zip zip unrar terminator ${desktop_extras} "
                                start_term="exec cinnamon-session"
        ;;
        "Anarchy-gnome")        config_env="${de}"
                                start_term="exec gnome-session"
                                DE+="gnome gnome-extra terminator ${desktop_extras} "
        ;;
        "Anarchy-openbox")      config_env="${de}"
                                start_term="exec openbox-session"
                                DE+="openbox thunar thunar-volman xfce4-terminal xfce4-panel xfce4-whiskermenu-plugin xcompmgr transset-df obconf lxappearance-obconf wmctrl gxmessage xfce4-pulseaudio-plugin xfdesktop xdotool opensnap ristretto oblogout obmenu-generator polkit-gnome ${desktop_extras} "
        ;;
    esac

    if "${suite}" ; then
	DE+="${user_extras} "
    fi

    if "${aur_helper}"; then
	DE+="yay "
    fi

    while (true) ; do
        if "${VM}" ; then
            case "${virt}" in
                vbox)   GPU="virtualbox-guest-utils "
                        if [ "${kernel}" == "linux" ]; then
                            GPU+="virtualbox-guest-modules-arch "
                        else
                            GPU+="virtualbox-guest-dkms "
                        fi
               ;;
               vmware)  GPU="xf86-video-vmware xf86-input-vmmouse open-vm-tools net-tools gtkmm mesa mesa-libgl"
               ;;
               hyper-v) GPU="xf86-video-fbdev mesa-libgl"
               ;;
               *)       GPU="xf86-video-fbdev mesa-libgl"
               ;;
            esac
            break
        else
            GPU="${default_GPU} mesa-libgl"
            break
        fi
    done

    DE+="${GPU} xdg-user-dirs xorg-server xorg-apps xorg-xinit xterm ttf-dejavu gvfs gvfs-smb gvfs-mtp pulseaudio pavucontrol pulseaudio-alsa alsa-utils unzip xf86-input-libinput lightdm-gtk-greeter lightdm-gtk-greeter-settings "

    if [ "${net_util}" == "networkmanager" ] ; then
        if (<<<"${DE}" grep "plasma" &> /dev/null); then
            DE+="plasma-nm "
        else
            DE+="network-manager-applet "
        fi
    fi

    if "${enable_bt}" ; then
        DE+="blueman "
    fi

    DM="lightdm"
    enable_dm=true

}
