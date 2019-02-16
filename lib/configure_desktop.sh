#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### configure_desktop.sh
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

graphics() {

	op_title="$de_op_msg"
	if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_msg" 10 60) then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then
			return
		fi
	fi

	while (true)
	  do
		de=$(dialog --ok-button "$done_msg" --cancel-button "$cancel" --menu "$environment_msg" 13 75 3 \
			"$customized_de"	"$customized_de_msg" \
			"$more_de"		"$more_de_msg" \
			"$more_wm"		"$more_wm_msg" 3>&1 1>&2 2>&3)

		if [ -z "$de" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then
				return
			fi
		elif [ "$de" == "$customized_de" ]; then
			de=$(dialog --ok-button "$done_msg" --cancel-button "$back" --menu "$environment_msg" 15 60 5 \
				"Anarchy-budgie"	"$de24" \
				"Anarchy-cinnamon"     	"$de23" \
				"Anarchy-gnome"		"$de22" \
				"Anarchy-openbox"      	"$de18" \
				"Anarchy-xfce4"       	"$de15" 3>&1 1>&2 2>&3)

			if [ -n "$de" ]; then
				break
			fi
		elif [ "$de" == "$more_de" ]; then
			de=$(dialog --separate-output --ok-button "$done_msg" --cancel-button "$back" --checklist "$environment_msg" 19 60 10 \
				"budgie"		"$de17" OFF \
				"cinnamon"      	"$de5" OFF \
				"deepin"		"$de14" OFF \
				"gnome"         	"$de4" OFF \
				"gnome-flashback"	"$de19" OFF \
				"KDE plasma"    	"$de6" OFF \
				"lxde"          	"$de2" OFF \
				"lxqt"          	"$de3" OFF \
				"mate"          	"$de1" OFF \
				"xfce4"         	"$de0" OFF 3>&1 1>&2 2>&3)

			if [ -n "$de" ]; then
				break
			fi
		elif [ "$de" == "$more_wm" ]; then
			de=$(dialog --separate-output --ok-button "$done_msg" --cancel-button "$back" --checklist "$environment_msg" 19 60 10 \
				"awesome"               "$de9" OFF \
				"bspwm"                 "$de13" OFF \
				"enlightenment"         "$de7" OFF \
				"fluxbox"               "$de11" OFF \
				"i3"                    "$de10" OFF \
				"openbox"               "$de8" OFF \
				"sway"                  "$de21" OFF \
				"xmonad"                "$de16" OFF 3>&1 1>&2 2>&3)

			if [ -n "$de" ]; then
                                 break
                         fi
		else
			break
		fi
	done

	if ! (</etc/pacman.conf grep "anarchy-local"); then
		sed -i -e '$a\\n[anarchy-local]\nServer = file:///usr/share/anarchy/pkg\nSigLevel = Never' /etc/pacman.conf
	fi

	source "$lang_file"

	while read env
	  do
		case "$env" in
			"Anarchy-xfce4")	config_env="$env"
						start_term="exec startxfce4"
						DE+="xfce4 xfce4-goodies $extras "
			;;
			"Anarchy-budgie")	config_env="$env"
						start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
						DE+="budgie-desktop mousepad terminator nautilus gnome-backgrounds gnome-control-center $extras "
			;;
			"Anarchy-cinnamon")	config_env="$env"
						DE+="cinnamon cinnamon-translations gnome-terminal file-roller p7zip zip unrar terminator $extras "
						start_term="exec cinnamon-session"
			;;
			"Anarchy-gnome")	config_env="$env"
						start_term="exec gnome-session"
						DE+="gnome gnome-extra terminator $extras "
			;;
			"Anarchy-openbox")	config_env="$env"
						start_term="exec openbox-session"
						DE+="openbox thunar thunar-volman xfce4-terminal xfce4-panel xfce4-whiskermenu-plugin xcompmgr transset-df obconf lxappearance-obconf wmctrl gxmessage xfce4-pulseaudio-plugin xfdesktop xdotool opensnap ristretto oblogout obmenu-generator openbox-themes polkit-gnome tumbler $extras "
			;;
			"xfce4") 	start_term="exec startxfce4"
					DE+="xfce4 "

					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg0" 10 60) then
						DE+="xfce4-goodies "
					fi
			;;
			"budgie")	start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
					DE+="budgie-desktop arc-icon-theme arc-gtk-theme elementary-icon-theme "

					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg6" 10 60) then
						DE+="gnome "
					fi
			;;
			"gnome")	start_term="exec gnome-session"
					DE+="gnome "

					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg1" 10 60) then
						DE+="gnome-extra "
					fi
			;;
			"gnome-flashback")	start_term="export XDG_CURRENT_DESKTOP=GNOME-Flashback:GNOME ; exec gnome-session --session=gnome-flashback-metacity"
						DE+="gnome-flashback "

						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg1" 10 60) then
							DE+="gnome-backgrounds gnome-control-center gnome-screensaver gnome-applets sensors-applet "
						fi
			;;
			"mate")		start_term="exec mate-session"

					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg2" 10 60) then
						DE+="mate mate-extra gtk-engine-murrine "
					else
						DE+="mate gtk-engine-murrine "
					fi
			;;
			"KDE plasma")	start_term="exec startkde"

					if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg3" 10 60) then
						DE+="plasma-desktop konsole dolphin plasma-nm plasma-pa libxshmfence kscreen "

						if "$LAPTOP" ; then
							DE+="powerdevil "
						fi
					else
						DE+="plasma ark aspell-en cdrdao clementine dolphin dolphin-plugins ffmpegthumbs gwenview k3b kate kcalc kdialog kfind kdeconnect kdegraphics-thumbnailers kdenetwork-filesharing kdesu kdelibs4support kipi-plugins khelpcenter konsole kwalletmanager okular spectacle transmission-qt krita kolourpaint korganizer knetattach falkon kdenlive "
					fi
			;;
			"deepin")	start_term="exec startdde"
					DE+="deepin "

					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg4" 10 60) then
						DE+="deepin-extra $kernel-headers "
					fi
 	 		;;
 	 		"xmonad")	start_term="exec xmonad"
					DE+="xmonad "

 	 				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg5" 10 60) then
						DE+="xmonad-contrib "
		                        fi
			;;
			"cinnamon")	DE+="cinnamon cinnamon-translations gnome-terminal file-roller p7zip zip unrar "
					start_term="exec cinnamon-session"
			;;
			"lxde")		start_term="exec startlxde"

					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$gtk3_var" 10 60) then
						DE+="lxde-gtk3 "
						GTK3=true
					else
						DE+="lxde "
					fi
			;;
			"lxqt")		start_term="exec startlxqt"
					DE+="lxqt oxygen-icons breeze-icons "
			;;
			"enlightenment") 	start_term="exec enlightenment_start"
						DE+="enlightenment terminology "
			;;
			"bspwm")	start_term="sxhkd & ; exec bspwm"
					DE+="bspwm sxhkd "
			;;
			"fluxbox")	start_term="exec startfluxbox"
					DE+="fluxbox "
			;;
			"openbox")	start_term="exec openbox-session"
					DE+="openbox "
			;;
			"awesome") 	start_term="exec awesome"
					DE+="awesome "
			;;
			"i3") 		start_term="exec i3"
					DE+="i3 "
			;;
			"sway")		start_term="sway"
					DE+="sway "
			;;
		esac
	done <<< "$de"

	while (true)
	  do
	  	if "$VM" ; then
	  		case "$virt" in
	  			vbox)	dialog --ok-button "$ok" --msgbox "\n$vbox_msg" 10 60
						GPU="virtualbox-guest-utils "
						if [ "$kernel" == "linux" ]; then
							GPU+="virtualbox-guest-modules-arch "
						else
							GPU+="virtualbox-guest-dkms "
						fi
	  			;;
	  			vmware)	dialog --ok-button "$ok" --msgbox "\n$vmware_msg" 10 60
						GPU="xf86-video-vmware xf86-input-vmmouse open-vm-tools net-tools gtkmm mesa mesa-libgl"
	  			;;
	  			hyper-v) dialog --ok-button "$ok" --msgbox "\n$hyperv_msg" 10 60
						 GPU="xf86-video-fbdev mesa-libgl"
	  			;;
	  			*) 		dialog --ok-button "$ok" --msgbox "\n$vm_msg" 10 60
						GPU="xf86-video-fbdev mesa-libgl"
	  			;;
	  		esac
	  		break
	  	fi

	  	if "$NVIDIA" ; then
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 18 60 6 \
				"$default"			 "$gr0" \
				"xf86-video-ati"     "$gr4" \
				"xf86-video-intel"   "$gr5" \
				"xf86-video-nouveau" "$gr8" \
				"xf86-video-vesa"	 "$gr1" \
				"NVIDIA"             "$gr2 ->" 3>&1 1>&2 2>&3)
			ex="$?"
		else
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 17 60 5 \
				"$default"	     "$gr0" \
				"xf86-video-ati"     "$gr4" \
				"xf86-video-intel"   "$gr5" \
				"xf86-video-nouveau" "$gr8" \
				"xf86-video-vesa"    "$gr1" 3>&1 1>&2 2>&3)
			ex="$?"
		fi

		if [ "$ex" -gt "0" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "$desktop_cancel_msg" 10 60) then
				return
			fi
		elif [ "$GPU" == "NVIDIA" ]; then
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$nvidia_msg" 15 60 4 \
				"$gr0"		   "->"	  \
				"nvidia"       "$gr6" \
				"nvidia-390xx" "$gr9" \
				"nvidia-340xx" "$gr7" 3>&1 1>&2 2>&3)

			if [ "$?" -eq "0" ]; then
				if [ "$GPU" == "$gr0" ]; then
					pci_id=$(lspci -nn | grep "VGA" | egrep -o '\[.*\]' | awk '{print $NF}' | sed 's/.*://;s/]//')
					if (<"$aa_dir"/etc/nvidia390.xx grep "$pci_id" &>/dev/null); then
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_390msg" 10 60); then
							if [ "$kernel" == "lts" ]; then
								GPU="nvidia-390xx-lts"
							else
								GPU="nvidia-390xx"
							fi
							GPU+=" nvidia-390xx-libgl nvidia-390xx-utils nvidia-settings"
							break
						fi
					elif (<"$aa_dir"/etc/nvidia340.xx grep "$pci_id" &>/dev/null); then
                                                 if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_340msg" 10 60); then
                                                         if [ "$kernel" == "lts" ]; then
                                                                 GPU="nvidia-340xx-lts"
                                                         else
                                                                 GPU="nvidia-340xx"
                                                         fi
                                                         GPU+=" nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings"
                                                         break
                                                 fi
					elif (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_curmsg" 10 60); then
						if [ "$kernel" == "lts" ]; then
							GPU="nvidia-lts"
						else
							GPU="nvidia"
						fi

						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
							drm=true
						fi
						GPU+=" nvidia-libgl nvidia-utils nvidia-settings"
						break
					fi
				elif [ "$GPU" == "nvidia" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
						drm=true
					fi

					if [ "$kernel" == "lts" ]; then
						GPU="nvidia-lts nvidia-libgl nvidia-utils nvidia-settings"
					else
						GPU+=" ${GPU}-libgl ${GPU}-utils"
					fi
					break
				else
					if [ "$kernel" == "lts" ]; then
						GPU="${GPU}-lts ${GPU}-libgl ${GPU}-utils"
					else
						GPU+=" ${GPU}-libgl ${GPU}-utils"
					fi
					break
				fi
			fi
		elif [ "$GPU" == "$default" ]; then
			GPU="$default_GPU mesa-libgl"
			break
		else
			GPU+=" mesa-libgl"
			break
		fi
	done

	DE+="$GPU $de_defaults "

	if [ "$net_util" == "networkmanager" ] ; then
		if (<<<"$DE" grep "plasma" &> /dev/null); then
			DE+="plasma-nm "
		else
			DE+="network-manager-applet "
		fi
	fi

	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$touchpad_msg" 10 60) then
		if (<<<"$DE" grep "gnome" &> /dev/null); then
			DE+="xf86-input-libinput "
		else
			DE+="xf86-input-synaptics "
		fi
	fi

	if "$enable_bt" ; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$blueman_msg" 10 60) then
			DE+="blueman "
		fi
	fi

	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$dm_msg" 10 60) then
		DM=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$dm_msg1" 13 64 4 \
			"lightdm"	"$dm1" \
			"gdm"		"$dm0" \
			"lxdm"		"$dm2" \
			"sddm"		"$dm3" 3>&1 1>&2 2>&3)
		if [ "$?" -eq "0" ]; then
			if [ "$DM" == "lightdm" ]; then
				DE+="$DM lightdm-gtk-greeter lightdm-gtk-greeter-settings "
			elif [ "$DM" == "lxdm" ] && "$GTK3"; then
				DE+="${DM}-gtk3 "
			else
				DE+="$DM "
			fi
			enable_dm=true
		else
			dialog --ok-button "$ok" --msgbox "\n$startx_msg" 10 60
		fi
	else
		dialog --ok-button "$ok" --msgbox "\n$startx_msg" 10 60
	fi

	base_install+="$DE "
	desktop=true

}

config_env() {

	cp -r "$aa_dir"/extra/fonts/ttf-zekton-rg "$ARCH"/usr/share/fonts
	chmod -R 755 "$ARCH"/usr/share/fonts/ttf-zekton-rg
	arch-chroot "$ARCH" fc-cache -f
	cp "$aa_dir"/extra/fonts/unifont/unifont-11.0.02.ttf "$ARCH"/usr/share/fonts/TTF
	cp "$aa_dir"/extra/anarchy-icon.png "$ARCH"/root/.face
	cp "$aa_dir"/extra/anarchy-icon.png "$ARCH"/etc/skel/.face
	cp "$aa_dir"/extra/anarchy-icon.png "$ARCH"/usr/share/pixmaps
	mkdir "$ARCH"/usr/share/backgrounds/anarchy
	cp -r "$aa_dir"/extra/wallpapers/* "$ARCH"/usr/share/backgrounds/anarchy/

	if [ -n "$config_env" ]; then
		tar -xf "$aa_dir/extra/desktop/$config_env/config.tar.gz" -C "$ARCH"/root
		tar -xf "$aa_dir/extra/desktop/$config_env/config.tar.gz" -C "$ARCH"/etc/skel
	fi

	case "$config_env" in
		"Anarchy-gnome"|"Anarchy-budgie")	cp -r "$aa_dir/extra/desktop/Anarchy-gnome/gnome-backgrounds.xml" "$ARCH"/usr/share/gnome-background-properties
		;;
		"Anarchy-openbox")	if [ "$virt" == "vbox" ]; then
						echo "VBoxClient-all &" >> "$ARCH"/etc/skel/.config/openbox/autostart
						echo "VBoxClient-all &" >> "$ARCH"/root/.config/openbox/autostart
					fi

					if [ "$net_util" == "networkmanager" ]; then
						echo "nm-applet &" >> "$ARCH"/etc/skel/.config/openbox/autostart
						echo "nm-applet &" >> "$ARCH"/root/.config/openbox/autostart
					fi
		;;
	esac

	echo "$(date -u "+%F %H:%M") : Configured: $config_env" >> "$log"

}

# vim: ai:ts=8:sw=8:sts=8:noet
