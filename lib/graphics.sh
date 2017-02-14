#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Select graphics and DE/WM
###
### Copyright (C) 2017  Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: http://arch-anywhere.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0

graphics() {

	op_title="$de_op_msg"
	if ! (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_msg" 10 60) then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then	
			x="17" ; install_base
		fi	
	fi
	
	DE=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$environment_msg" 18 60 11 \
		"Arch-Anywhere-Xfce" "$de15" \
		"budgie"		"$de17" \
		"cinnamon"      "$de5" \
		"deepin"		"$de14" \
		"gnome"         "$de4" \
		"KDE plasma"    "$de6" \
		"lxde"          "$de2" \
		"lxqt"          "$de3" \
		"mate"          "$de1" \
		"xfce4"         "$de0" \
		"awesome"       "$de9" \
		"bspwm"			"$de13" \
		"dwm"           "$de12" \
		"enlightenment" "$de7" \
		"fluxbox"       "$de11" \
		"i3"            "$de10" \
		"openbox"       "$de8" \
		"xmonad"		"$de16"  3>&1 1>&2 2>&3)
	if [ "$?" -gt "0" ]; then 
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$desktop_cancel_msg" 10 60) then	
			install_base
		fi
	fi

	source "$lang_file"

	case "$DE" in
		"Arch-Anywhere-Xfce") 	DE="xfce4 xfce4-goodies gvfs zsh zsh-syntax-highlighting"
								start_term="exec startxfce4" de_config=true
		;;
		"xfce4") 	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg0" 10 60) then
						DE="xfce4 xfce4-goodies"
					fi
					start_term="exec startxfce4"
		;;
		"budgie")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg6" 10 60) then
						DE="budgie-desktop gnome"
					else
						DE="budgie-desktop"
					fi
					start_term="export XDG_CURRENT_DESKTOP=Budgie:GNOME ; exec budgie-desktop"
		;;
		"gnome")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg1" 10 60) then
						DE="gnome gnome-extra"
					fi
					 start_term="exec gnome-session"
		;;
		"mate")		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$gtk3_var" 10 60) then 
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg2" 10 60) then
							DE="mate-gtk3 mate-extra-gtk3 gtk3-print-backends"
						else
							DE="mate-gtk3"
						fi
						GTK3=true
					else
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg2" 10 60) then
							DE="mate mate-extra gtk-engine-murrine"
						else
							DE="mate gtk-engine-murrine"
						fi
					fi
					 start_term="exec mate-session"
		;;
		"KDE plasma")	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg3" 10 60) then
							DE="plasma-desktop sddm konsole dolphin plasma-nm plasma-pa libxshmfence kscreen powerdevil"
						else
							DE="plasma kde-applications"
						fi
						
						DM="sddm"
						enable_dm=true
						start_term="exec startkde"
		;;
		"deepin")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg4" 10 60) then
						DE="deepin deepin-extra"
					fi
 					start_term="exec startdde"
 		;;
 		"xmonad")	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$extra_msg5" 10 60) then 
                        			DE="xmonad xmonad-contrib"
                    			fi
                    			start_term="exec xmonad"
		;;	
		"cinnamon") start_term="exec cinnamon-session" 
		;;
		"lxde") 	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$gtk3_var" 10 60) then 
                        DE="lxde-gtk3"
                    	GTK3=true
                    fi
					start_term="exec startlxde" 
		;;
		"lxqt") 	start_term="exec startlxqt" 
					DE="lxqt oxygen-icons"
		;;
		"enlightenment") 	start_term="exec enlightenment_start"
							DE="enlightenment terminology"
		;;
		"bspwm")	start_term="sxhkd & ; exec bspwm"
					DE="bspwm sxhkd"
		;;
		"fluxbox")	start_term="exec startfluxbox" 
		;;
		"openbox")	start_term="exec openbox-session"
		;;
		"awesome") 	start_term="exec awesome" 
		;;	
		"dwm") 		start_term="exec dwm" 
		;;
		"i3") 		start_term="exec i3" 
		;;
	esac

	env=$(<<<"$DE" awk '{print $1,$2}')

	while (true)
	  do
	  	if "$VM" ; then
	  		case "$virt" in
	  			vbox)	dialog --ok-button "$ok" --msgbox "\n$vbox_msg" 10 60
						GPU="virtualbox-guest-utils"
						if [ "$kernel" == "linux" ]; then
							GPU+=" virtualbox-guest-modules-arch"
						else
							GPU+=" virtualbox-guest-dkms"
						fi
	  			;;
	  			vmware)	dialog --ok-button "$ok" --msgbox "\n$vmware_msg" 10 60
						GPU="xf86-video-vmware xf86-input-vmmouse open-vm-tools gtkmm mesa mesa-libgl"
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
				install_base
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
        			    	GPU="nvidia-340xx nvidia-340xx-libgl"
        			    	break
        			    fi
				elif (<"$aa_dir"/etc/nvidia304.xx grep "$pci_id" &>/dev/null); then
           				if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_304msg" 10 60); then
           					GPU="nvidia-304xx nvidia 304xx-libgl"
           					break
			        	fi
			        else
            			if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_curmsg" 10 60); then
            				GPU="nvidia nvidia-libgl"
							if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
								drm=true
							fi
            				break
            			fi
			        fi
				elif [ "$GPU" == "nvidia" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$nvidia_modeset_msg" 10 60) then
						drm=true
					fi
					GPU+=" ${GPU}-libgl"
					break
				else
					GPU+=" ${GPU}-libgl"
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
	
	DE="$DE xdg-user-dirs xorg-server xorg-server-utils xorg-xinit xterm ttf-dejavu gvfs pulseaudio pulseaudio-alsa alsa-utils $GPU"
		
	if [ "$net_util" == "networkmanager" ] ; then
		if (<<<"$DE" grep "plasma" &> /dev/null); then
			DE+=" plasma-nm"
		else
			DE+=" network-manager-applet"
		fi
	fi

	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$touchpad_msg" 10 60) then
		if (<<<"$DE" grep "gnome" &> /dev/null); then
			DE+=" xf86-input-libinput"
		else
			DE+=" xf86-input-synaptics"
		fi
	fi

	if "$enable_bt" ; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$blueman_msg" 10 60) then
			DE+=" blueman"
		fi
	fi
	
	if ! "$enable_dm" ; then
		if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$dm_msg" 10 60) then
			DM=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$dm_msg1" 13 64 4 \
				"lightdm"	"$dm1" \
				"gdm"		"$dm0" \
				"lxdm"		"$dm2" \
				"sddm"		"$dm3" 3>&1 1>&2 2>&3)
			if [ "$?" -eq "0" ]; then
				if [ "$DM" == "lightdm" ]; then
					DE+=" $DM lightdm-gtk-greeter"
				elif [ "$DM" == "lxdm" ] && "$GTK3"; then
					DE+=" ${DM}-gtk3"
				else
					DE+=" $DM"
				fi
				
				enable_dm=true
			fi
		else
			dialog --ok-button "$ok" --msgbox "\n$startx_msg" 10 60
		fi
	fi
	
	base_install+=" $DE"
	desktop=true x=19

}
