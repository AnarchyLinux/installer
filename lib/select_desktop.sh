#!/usr/bin/env bash

while (true); do
    de=$(dialog --ok-button "${done_msg}" --cancel-button "${cancel}" --menu "${environment_msg}" 14 60 5 \
        1 "${de15}" \
        2 "${de22}" \
        3 "${de23}" \
        4 "${de18}" \
        5 "${de24}" 3>&1 1>&2 2>&3)

    if [[ -z "${de}" ]]; then
        if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n${desktop_cancel_msg}" 10 60); then
            return
        fi
    else
        break
    fi
done

case "${de}" in
    1) # XFCE4
        config_env="${de}"
        start_term="exec startxfce4"
        DE+=('xfce4' 'xfce4-goodies' "${extras}")
    ;;

    2) # Gnome
        config_env="${de}"
        start_term="exec gnome-session"
        DE+=('gnome' 'gnome-extra' 'terminator' "${extras}")
    ;;

    3) # Cinnamon
        config_env="${de}"
        start_term="exec cinnamon-session"
        DE+=(
            'cinnamon'
            'cinnamon-translations'
            'gnome-terminal'
            'file-roller'
            'p7zip'
            'zip'
            'unrar'
            'terminator'
            "${extras}"
        )
    ;;

    4) # Openbox
        config_env="${de}"
        start_term="exec openbox-session"
        DE+=(
            'openbox'
            'thunar'
            'thunar-volman'
            'xfce4-terminal'
            'xfce4-panel'
            'xfce4-whiskermenu-plugin'
            'xcompmgr'
            'transset-df'
            'obconf'
            'lxappearance-obconf'
            'wmctrl'
            'gxmessage'
            'xfce4-pulseaudio-plugin'
            'xfdesktop'
            'xdotool'
            'opensnap'
            'ristretto'
            'oblogout'
            'obmenu-generator'
            'polkit-gnome'
            "${extras}"
        )
    ;;

    5) # Budgie
        config_env="${de}"
        start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
        DE+=(
            'budgie-desktop'
            'mousepad'
            'terminator'
            'nautilus'
            'gnome-backgrounds'
            'gnome-control-center'
            "${extras}"
        )
    ;;
esac

while (true); do
    if "${VM}"; then
        case "${virt}" in
            vbox)
                GPU=('virtualbox-guest-utils')

                if [[ "${kernel}" == "linux" ]]; then
                    GPU+=('virtualbox-guest-modules-arch')
                else
                    GPU+=('virtualbox-guest-dkms')
                fi
            ;;

            vmware)
                GPU=(
                    'xf86-video-vmware'
                    'xf86-input-vmmouse'
                    'open-vm-tools'
                    'net-tools'
                    'gtkmm'
                    'mesa'
                    'mesa-libgl'
                )
            ;;

            hyper-v) GPU=('xf86-video-fbdev' 'mesa-libgl') ;;
            *) GPU=('xf86-video-fbdev' 'mesa-libgl') ;;
        esac

        break
    else
        GPU=("${default_GPU}" 'mesa-libgl')
        break
    fi
done

DE+=(
    "${GPU}"
    'xdg-user-dirs'
    'xorg-server'
    'xorg-apps'
    'xorg-xinit'
    'xterm'
    'ttf-dejavu'
    'gvfs'
    'gvfs-smb'
    'gvfs-mtp'
    'pulseaudio'
    'pavucontrol'
    'pulseaudio-alsa'
    'alsa-utils'
    'unzip'
    'xf86-input-libinput'
    'lightdm-gtk-greeter'
    'lightdm-gtk-greeter-settings'
)

if [[ "${net_util}" == "networkmanager" ]] ; then
    if (<<<"${DE}" grep "plasma" &> /dev/null); then
        DE+=('plasma-nm')
    else
        DE+=('network-manager-applet')
    fi
fi

if "${enable_bt}" ; then
    DE+=('blueman')
fi

DM="lightdm"
enable_dm=true
