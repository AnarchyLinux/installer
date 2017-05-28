#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
### configure_desktop.sh
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

graphics() {

	op_title="$de_op_msg"
	if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_msg" 10 60) then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then
			return
		fi
	fi

	while (true)
	  do
		de=$(dialog --separate-output --ok-button "$done_msg" --cancel-button "$cancel" --checklist "$environment_msg" 24 60 15 \
			"AA-Xfce"			"$de15" OFF \
			"AA-Openbox"		"$de18" OFF \
			"budgie"			"$de17" OFF \
			"cinnamon"      	"$de5" OFF \
			"deepin"			"$de14" OFF \
			"gnome"         	"$de4" OFF \
			"gnome-flashback"	"$de19" OFF \
			"KDE plasma"    	"$de6" OFF \
			"lxde"          	"$de2" OFF \
			"lxqt"          	"$de3" OFF \
			"mate"          	"$de1" OFF \
			"xfce4"         	"$de0" OFF \
			"awesome"       	"$de9" OFF \
			"bspwm"				"$de13" OFF \
			"dwm"           	"$de12" OFF \
			"enlightenment" 	"$de7" OFF \
			"fluxbox"       	"$de11" OFF \
			"i3"            	"$de10" OFF \
			"openbox"       	"$de8" OFF \
			"xmonad"			"$de16" OFF 3>&1 1>&2 2>&3)
		if [ -z "$de" ]; then
			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then
				return
			fi
		elif (grep "AA-Xfce" <<<"$de" &>/dev/null) && (grep "AA-Openbox" <<<"$de" &>/dev/null); then
			de=$(sed 's/AA-Xfce//' <<<"$de")
			break
		else
			break
		fi
	done

	source "$lang_file"

	while read env
	  do
		case "$env" in
			"AA-Xfce") 	config_DE+="$env "
						DE+="xfce4 xfce4-goodies gvfs zsh zsh-syntax-highlighting arc-icon-theme arc-gtk-theme elementary-icon-theme htop xscreensaver arch-wiki-cli lynx fetchmirrors fetchpkg "
						sed -i -e '$a\\n[arch-anywhere]\nServer = http://arch-anywhere.org/repo/$arch\nSigLevel = Never' /etc/pacman.conf
						start_term="exec startxfce4"
			;;
			"AA-Openbox")	config_DE+="$env "
							DE+="openbox thunar thunar-volman xfce4-terminal xfce4-panel xfce4-whiskermenu-plugin arc-icon-theme arc-gtk-theme elementary-icon-theme xcompmgr transset-df obconf lxappearance-obconf wmctrl gxmessage xfce4-pulseaudio-plugin xfdesktop xdotool htop xscreensaver opensnap ristretto arch-wiki-cli lynx fetchmirrors fetchpkg "
							sed -i -e '$a\\n[arch-anywhere]\nServer = http://arch-anywhere.org/repo/$arch\nSigLevel = Never' /etc/pacman.conf
							start_term="exec openbox-session"
			;;
			"xfce4") 	DE+="xfce4 "
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg0" 10 60) then
							DE+="xfce4-goodies "
						fi
						start_term="exec startxfce4"
			;;
			"budgie")	DE+="budgie-desktop arc-icon-theme arc-gtk-theme elementary-icon-theme "
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg6" 10 60) then
							DE+="gnome "
						fi
						start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
			;;
			"gnome")	DE+="gnome "
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg1" 10 60) then
							DE+="gnome-extra "
						fi
						 start_term="exec gnome-session"
			;;
			"gnome-flashback")	DE+="gnome-flashback "
								if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg1" 10 60) then
									DE+="gnome-backgrounds gnome-control-center gnome-screensaver gnome-applets sensors-applet "
								fi
								start_term="export XDG_CURRENT_DESKTOP=GNOME-Flashback:GNOME ; exec gnome-session --session=gnome-flashback-metacity"
			;;
			"mate")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg2" 10 60) then
						DE+="mate mate-extra gtk-engine-murrine "
					else
						DE+="mate gtk-engine-murrine "
					fi
					start_term="exec mate-session"
			;;
			"KDE plasma")	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg3" 10 60) then
								DE+="plasma-desktop sddm konsole dolphin plasma-nm plasma-pa libxshmfence kscreen "
    
								if "$LAPTOP" ; then
									DE+="powerdevil "
								fi
							else
								DE+="plasma kde-applications "
							fi
    
							if [ -n "$kdel" ]; then
								DE+="kde-l10n-$kdel "
							fi
    
							start_term="exec startkde"
			;;
			"deepin")	DE+="deepin "
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg4" 10 60) then
							DE+="deepin-extra "
						fi
 	 					start_term="exec startdde"
 	 		;;
 	 		"xmonad")	DE+="xmonad "
 	 					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg5" 10 60) then
                       		DE="xmonad-contrib "
                        fi
                        start_term="exec xmonad"
			;;
			"cinnamon")	DE+="cinnamon gnome-terminal file-roller p7zip zip unrar "
						start_term="exec cinnamon-session"
			;;
			"lxde") if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$gtk3_var" 10 60) then
						DE+="lxde-gtk3 "
						GTK3=true
					else
						DE+="lxde "
					fi
					start_term="exec startlxde"
			;;
			"lxqt") start_term="exec startlxqt"
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
			"dwm") 		start_term="exec dwm"
						DE+="dwm "
			;;
			"i3") 		start_term="exec i3"
						DE+="i3 "
			;;
		esac
	done <<< $de

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
				"xf86-video-nouveau" "$gr9" \
				"xf86-video-vesa"	 "$gr1" \
				"NVIDIA"             "$gr2 ->" 3>&1 1>&2 2>&3)
			ex="$?"
		else
			GPU=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$graphics_msg" 17 60 5 \
				"$default"			 "$gr0" \
				"xf86-video-ati"     "$gr4" \
				"xf86-video-intel"   "$gr5" \
				"xf86-video-nouveau" "$gr9" \
				"xf86-video-vesa"	 "$gr1" 3>&1 1>&2 2>&3)
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
				"nvidia-340xx" "$gr7" \
				"nvidia-304xx" "$gr8" 3>&1 1>&2 2>&3)

			if [ "$?" -eq "0" ]; then
				if [ "$GPU" == "$gr0" ]; then
					pci_id=$(lspci -nn | grep "VGA" | egrep -o '\[.*\]' | awk '{print $NF}' | sed 's/.*://;s/]//')
			        if (<"$aa_dir"/etc/nvidia340.xx grep "$pci_id" &>/dev/null); then
        			    if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_340msg" 10 60); then
        			    	if [ "$kernel" == "lts" ]; then
								GPU="nvidia-340xx-lts"
        			    	else
        			    		GPU="nvidia-340xx"
        			    	fi
        			    	GPU+=" nvidia-340xx-libgl nvidia-340xx-utils"
        			    	break
        			    fi
					elif (<"$aa_dir"/etc/nvidia304.xx grep "$pci_id" &>/dev/null); then
           				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_304msg" 10 60); then
           					if [ "$kernel" == "lts" ]; then
								GPU="nvidia-304xx-lts"
           					else
           						GPU="nvidia-304xx"
           					fi
           					GPU+=" nvidia-304xx-libgl nvidia-304xx-utils"
           					break
			        	fi
			        else
            			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_curmsg" 10 60); then
            				if [ "$kernel" == "lts" ]; then
								GPU="nvidia-lts"
            				else
            					GPU="nvidia"
							fi

							if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
								drm=true
							fi
							GPU+=" nvidia-libgl nvidia-utils"
            				break
            			fi
			        fi
				elif [ "$GPU" == "nvidia" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
						drm=true
					fi

					if [ "$kernel" == "lts" ]; then
						GPU="nvidia-lts nvidia-libgl nvidia-utils"
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

	DE+="$GPU xdg-user-dirs xorg-server xorg-apps xorg-xinit xterm ttf-dejavu gvfs gvfs-smb gvfs-mtp pulseaudio pavucontrol pulseaudio-alsa alsa-utils unzip "
	
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
				DE+="$DM lightdm-gtk-greeter "
			elif [ "$DM" == "lxdm" ] && "$GTK3"; then
				DE+="${DM}-gtk3 "
			else
				DE+="$DM "
			fi
			enable_dm=true
		fi
	else
		dialog --ok-button "$ok" --msgbox "\n$startx_msg" 10 60
	fi

	base_install+="$DE "
	desktop=true

}

config_env() {

	sh="/usr/bin/zsh"
	arch-chroot "$ARCH" chsh -s /usr/bin/zsh &> /dev/null
	cp -r "$aa_dir"/extra/desktop/ttf-zekton-rg "$ARCH"/usr/share/fonts
	cp "$aa_dir"/extra/.zshrc "$ARCH"/root/
	cp "$aa_dir"/extra/.zshrc "$ARCH"/etc/skel/
	cp "$aa_dir"/extra/desktop/arch-anywhere-icon.png "$ARCH"/root/.face
	cp "$aa_dir"/extra/desktop/arch-anywhere-icon.png "$ARCH"/etc/skel/.face
	cp -r "$aa_dir"/extra/desktop/{arch-anywhere-wallpaper.png,arch-anywhere-icon.png} "$ARCH"/usr/share/pixmaps

	if (grep "AA-Xfce" <<<"$config_DE" &>/dev/null); then
		for file in $(ls -A "$aa_dir/extra/desktop/xfce4"); do
			cp -r "$aa_dir/extra/desktop/xfce4/$file" "$ARCH"/root/
			cp -r "$aa_dir/extra/desktop/xfce4/$file" "$ARCH"/etc/skel/
		done
		cp -r "$aa_dir"/extra/desktop/arch-anywhere-wallpaper.png "$ARCH"/usr/share/backgrounds/xfce/
		cp "$ARCH"/usr/share/backgrounds/xfce/arch-anywhere-wallpaper.png "$ARCH"/usr/share/backgrounds/xfce/xfce-teal.jpg
	fi

	if (grep "AA-Openbox" <<<"$config_DE" &>/dev/null); then
		for file in $(ls -A "$aa_dir/extra/desktop/openbox"); do
			cp -r "$aa_dir/extra/desktop/openbox/$file" "$ARCH"/root/
			cp -r "$aa_dir/extra/desktop/openbox/$file" "$ARCH"/etc/skel/
		done
		cp -r "$aa_dir"/extra/desktop/Arc/openbox-3 "$ARCH"/usr/share/themes/Arc
		cp -r "$aa_dir"/extra/desktop/Arc-Dark/openbox-3 "$ARCH"/usr/share/themes/Arc-Dark
		cp -r "$aa_dir"/extra/desktop/Arc-Darker/openbox-3 "$ARCH"/usr/share/themes/Arc-Darker
		cp -r "$aa_dir"/extra/desktop/obpower.sh "$ARCH"/usr/bin/obpower
		chmod +x "$ARCH"/usr/bin/obpower
		if [ "$virt" == "vbox" ]; then
			echo "VBoxClient-all &" >> "$ARCH"/etc/skel/.config/openbox/autostart
			echo "VBoxClient-all &" >> "$ARCH"/root/.config/openbox/autostart
		fi
	fi

	echo "$(date -u "+%F %H:%M") : Configured: $config_DE" >> "$log"
	arch-chroot "$ARCH" fc-cache -f

}
