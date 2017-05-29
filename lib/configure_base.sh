#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
### configure_base.sh
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

prepare_base() {

	op_title="$install_op_msg"
	while (true)
	  do
		install_menu=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$install_type_msg" 14 64 5 \
			"Arch-Linux-Base" 		"$base_msg0" \
			"Arch-Linux-Base-Devel" 	"$base_msg1" \
			"Arch-Linux-Hardened"		"$hardened_msg0" \
			"Arch-Linux-Hardened-Devel"	"$hardened_msg1" \
			"Arch-Linux-LTS-Base" 		"$LTS_msg0" \
			"Arch-Linux-LTS-Base-Devel"	"$LTS_msg1" \
			"Arch-Linux-Zen"		"$zen_msg0" \
			"Arch-Linux-Zen-Devel"		"$zen_msg1" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
				main_menu
			fi
		else
			break
		fi
	done

	case "$install_menu" in
		"Arch-Linux-Base")
			base_install="linux-headers sudo " kernel="linux"
		;;
		"Arch-Linux-Base-Devel")
			base_install="base-devel linux-headers " kernel="linux"
		;;
		"Arch-Linux-Hardened")
			base_install="linux-hardened linux-hardened-headers sudo " kernel="linux-hardened"
		;;
		"Arch-Linux-Hardened-Devel")
			base_install="base-devel linux-hardened linux-hardened-headers " kernel="linux-hardened"
		;;
		"Arch-Linux-LTS-Base")
			base_install="linux-lts linux-lts-headers sudo " kernel="linux-lts"
		;;
		"Arch-Linux-LTS-Base-Devel")
			base_install="base-devel linux-lts linux-lts-headers " kernel="linux-lts"
		;;
		"Arch-Linux-Zen")
			base_install="linux-zen linux-zen-headers sudo " kernel="linux-zen"
		;;
		"Arch-Linux-Zen-Devel")
			base_install="base-devel linux-zen linux-zen-headers " kernel="linux-zen"
		;;
	esac

	while (true)
	  do
		shell=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$shell_msg" 16 64 6 \
			"bash"  "$shell5" \
			"dash"	"$shell0" \
			"fish"	"$shell1" \
			"mksh"	"$shell2" \
			"tcsh"	"$shell3" \
			"zsh"	"$shell4" 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
				main_menu
			fi
		else
			case "$shell" in
                bash) sh="/bin/bash" shell="bash-completion"
                ;;
				fish) 	sh="/bin/bash"
				;;
				zsh) sh="/usr/bin/$shell" shell="zsh zsh-syntax-highlighting"
				;;
				*) sh="/bin/$shell"
				;;
			esac

			base_install+="$shell "
			break
		fi
	done

	while (true)
	  do
		if "$UEFI" ; then
			bootloader=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$loader_type_msg" 13 64 4 \
				"grub"			"$loader_msg" \
				"syslinux"		"$loader_msg1" \
				"systemd-boot"	"$loader_msg2" \
				"efistub"	    "$loader_msg3" \
				"$none" "-" 3>&1 1>&2 2>&3)
			ex="$?"
		else
			bootloader=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$loader_type_msg" 12 64 3 \
				"grub"			"$loader_msg" \
				"syslinux"		"$loader_msg1" \
				"$none" "-" 3>&1 1>&2 2>&3)
			ex="$?"
		fi

		if [ "$ex" -gt "0" ]; then
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
				main_menu
			fi
		elif [ "$bootloader" == "systemd-boot" ]; then
			break
		elif [ "$bootloader" == "efistub" ]; then
			break
		elif [ "$bootloader" == "syslinux" ]; then
			if ! "$UEFI" ; then
				if (tune2fs -l /dev/"$BOOT" | grep "64bit" &> /dev/null); then
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$syslinux_warn_msg" 11 60) then
						mnt=$(df | grep -w "$BOOT" | awk '{print $6}')
						(umount "$mnt"
						wipefs -a /dev/"$BOOT"
						mkfs.ext4 -O \^64bit /dev/"$BOOT"
						mount /dev/"$BOOT" "$mnt") &> /dev/null &
						pid=$! pri=0.1 msg="\n$boot_load \n\n \Z1> \Z2mkfs.ext4 -O ^64bit /dev/$BOOT\Zn" load
						base_install+="$bootloader "
						break
					fi
				else
					base_install+="$bootloader "
					break
				fi
			else
				base_install+="$bootloader "
				break
			fi
		elif [ "$bootloader" == "grub" ]; then
			base_install+="$bootloader "
			break
		else
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$grub_warn_msg0" 10 60) then
				dialog --ok-button "$ok" --msgbox "\n$grub_warn_msg1" 10 60
				break
			fi
		fi
	done

	while (true)
	  do
		net_util=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$wifi_util_msg" 14 64 3 \
			"networkmanager" 		"$net_util_msg1" \
			"netctl"			"$net_util_msg0" \
			"$none" "-" 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then
			if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$exit_msg" 10 60) then
				main_menu
			fi
		else
			if [ "$net_util" == "netctl" ] || [ "$net_util" == "networkmanager" ]; then
				base_install+="$net_util dialog " enable_nm=true
			fi
			break
		fi
	done

	if [ "$arch" == "x86_64" ]; then
        if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n\n$multilib_msg" 11 60) then
            multilib=true
            echo "$(date -u "+%F %H:%M") : Include multilib" >> "$log"
        fi
    fi

    if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n\n$dhcp_msg" 11 60) then
        dhcp=true
        echo "$(date -u "+%F %H:%M") : Enable dhcp" >> "$log"
    fi

	if "$wifi" ; then
		base_install+="wireless_tools wpa_supplicant wpa_actiond "
	else
		if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$wifi_option_msg" 10 60) then
			base_install+="wireless_tools wpa_supplicant wpa_actiond "
		fi
	fi
	
	if "$bluetooth" ; then
		if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$bluetooth_msg" 10 60) then
			base_install+="bluez bluez-utils pulseaudio-bluetooth "
			enable_bt=true
		fi
	fi

	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$pppoe_msg" 10 60) then
		base_install+="rp-pppoe "
	fi

	if (dialog --defaultno --yes-button "$yes" --no-button "$no" --yesno "\n$os_prober_msg" 10 60) then
		base_install+="os-prober "
	fi

	if "$enable_f2fs" ; then
		base_install+="f2fs-tools "
	fi

	if "$UEFI" ; then
		base_install+="efibootmgr "
	fi

}

add_software() {

	op_title="$software_op_msg"
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$software_msg0" 10 60) then

		while (true)
		  do
			unset software
			add_soft=true
			if ! "$skip" ; then
				software_menu=$(dialog --extra-button --extra-label "$install" --ok-button "$select" --cancel-button "$cancel" --menu "$software_type_msg" 20 63 11 \
					"$aar" "$aar_msg" \
					"$audio" "$audio_msg" \
					"$games" "$games_msg" \
					"$graphic" "$graphic_msg" \
					"$internet" "$internet_msg" \
					"$multimedia" "$multimedia_msg" \
					"$office" "$office_msg" \
					"$terminal" "$terminal_msg" \
					"$text_editor" "$text_editor_msg" \
					"$system" "$system_msg" \
					"$done_msg" "$install \Z2============>\Zn" 3>&1 1>&2 2>&3)
				ex="$?"

				if [ "$ex" -eq "1" ]; then
					if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_warn_msg" 10 60) then
						break
					else
						add_soft=false
					fi
				elif [ "$ex" -eq "3" ]; then
					software_menu="$done_msg"
				elif [ "$software_menu" == "$aar" ] && ! "$aa_repo" ; then
					if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$aar_add_msg" 10 60) then
						sed -i -e '$a\\n[arch-anywhere]\nServer = http://arch-anywhere.org/repo/$arch\nSigLevel = Never' /etc/pacman.conf
						aa_repo=true

					else
						continue
					fi
				fi
			else
				skip=false
			fi

			case "$software_menu" in
				"$aar")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 60 7 \
						"arch-wiki-cli"	"$aar0" ON \
						"downgrade"		"$aar6" OFF \
						"dolphin-libre"	"$aar7" OFF \
						"fetchmirrors"	"$aar1" ON \
						"fetchpkg"		"$aar8" ON \
						"octopi"		"$aar4" OFF \
						"pacaur"		"$aar2" OFF \
						"pamac-aur"		"$aar5" OFF \
						"yaourt"		"$aar3" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi

					if (<<<"$software" grep "dolphin-libre") then
						software=$(<<<"$software" sed 's/dolphin-libre/dolphin-libreoffice-templates/')
					fi
				;;
				"$audio")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 60 10 \
						"audacity"		"$audio0" OFF \
						"audacious"		"$audio1" OFF \
						"cmus"			"$audio2" OFF \
						"jack2"         "$audio3" OFF \
						"projectm"		"$audio4" OFF \
						"lmms"			"$audio5" OFF \
						"mpd"			"$audio6" OFF \
						"ncmpcpp"		"$audio7" OFF \
						"pianobar"		"$audio9" OFF \
						"pavucontrol"	"$audio8" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$internet")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 19 60 9 \
						"chromium"			"$net0" OFF \
						"elinks"			"$net3" OFF \
						"filezilla"			"$net1" OFF \
						"firefox"			"$net2" OFF \
						"irssi"				"$net9" OFF \
						"lynx"				"$net3" OFF \
						"minitube"			"$net4" OFF \
						"opera"				"$net5" OFF \
						"thunderbird"			"$net6" OFF \
						"transmission-cli" 		"$net7" OFF \
						"transmission-gtk"		"$net8" OFF \
						"hexchat"			"$net11" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi

					if (<<<"$software" grep "firefox" &>/dev/null) && [ -n "$bro" ]; then
						software+=" firefox-i18n-$bro"
					fi

					if (<<<"$software" grep "thunderbird" &>/dev/null) && [ -n "$bro" ] && [ "$bro" != "lv" ]; then
							software+=" thunderbird-i18n-$bro"
					fi
				;;
				"$games")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 70 10 \
						"alienarena"	"$game0" OFF \
						"bsd-games"		"$game1" OFF \
						"bzflag"		"$game2" OFF \
						"flightgear"	"$game3" OFF \
						"gnuchess"      "$game4" OFF \
						"supertux"		"$game5" OFF \
						"supertuxkart"	"$game6" OFF \
						"urbanterror"	"$game7" OFF \
						"warsow"		"$game8" OFF \
						"xonotic"		"$game9" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$graphic")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 63 7 \
						"blender"		"$graphic0" OFF \
						"darktable"		"$graphic1" OFF \
						"feh"			"$graphic6" OFF \
						"gimp"			"$graphic2" OFF \
						"graphviz"		"$graphic3" OFF \
						"imagemagick"	"$graphic4" OFF \
						"pinta"			"$graphic5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$multimedia")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 17 63 7 \
						"handbrake"				"$media0" OFF \
						"mplayer"				"$media1" OFF \
						"mpv"					"$media7" OFF \
						"multimedia-codecs"			"$media8" OFF \
						"pitivi"				"$media2" OFF \
						"simplescreenrecorder"			"$media3" OFF \
						"smplayer"				"$media4" OFF \
						"totem"					"$media5" OFF \
						"vlc"         	   			"$media6" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi

					if (<<<"$software" grep "multimedia-codecs") then
						software=$(<<<"$software" sed 's/multimedia-codecs/gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly ffmpegthumbnailer gst-libav/')
					fi
				;;
				"$office")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 16 63 6 \
						"abiword"               "$office0" OFF \
						"calligra"              "$office1" OFF \
						"gnumeric"				"$office3" OFF \
						"libreoffice-fresh"		"$office4" OFF \
						"libreoffice-still"		"$office5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi

					if (<<<"$software" grep "libreoffice-fresh" &>/dev/null) && [ -n "$lib" ]; then
						software+=" libreoffice-fresh-$lib"
					fi

					if (<<<"$software" grep "libreoffice-still" &>/dev/null) && [ -n "$lib" ]; then
						software+=" libreoffice-still-$lib"
					fi
				;;
				"$terminal")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 18 63 8 \
						"guake"             "$term1" OFF \
						"kmscon"			"$term2" OFF \
						"pantheon-terminal"	"$term3" OFF \
						"rxvt-unicode"      "$term4" OFF \
						"terminator"        "$term5" OFF \
						"xfce4-terminal"    "$term6" OFF \
						"yakuake"           "$term7" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$text_editor")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 18 60 8 \
						"atom"			"$edit7" OFF \
						"emacs"			"$edit0" OFF \
						"geany"			"$edit1" OFF \
						"gedit"			"$edit2" OFF \
						"gvim"			"$edit3" OFF \
						"mousepad"		"$edit4" OFF \
						"neovim"		"$edit5" OFF \
						"vim"			"$edit6" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$system")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 65 10 \
						"apache"		"$sys1" OFF \
						"bc"			"$sys25" OFF \
						"bleachbit"		"$sys22" OFF \
						"conky"			"$sys2" OFF \
						"dmenu"			"$sys19" OFF \
						"galculator"	"$sys24" OFF \
						"git"			"$sys3" OFF \
						"gparted"		"$sys4" OFF \
						"gpm"			"$sys5" OFF \
						"htop"			"$sys6" OFF \
						"inxi"			"$sys7" OFF \
						"k3b"			"$sys8" OFF \
						"nmap"			"$sys9" OFF \
						"openssh"		"$sys10" OFF \
						"pcmanfm"		"$sys21" OFF \
						"ranger"		"$sys20" OFF \
						"screen"		"$sys11" OFF \
						"screenfetch"	"$sys12" ON \
						"scrot"			"$sys13" OFF \
						"tmux"			"$sys14" OFF \
						"tuxcmd"		"$sys15" OFF \
						"virtualbox"	"$sys16" OFF \
						"ufw"			"$sys17" ON \
						"wget"			"$sys18" ON \
						"xfe"			"$sys23" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						add_soft=false
					fi
				;;
				"$done_msg")
					if [ -z "$final_software" ]; then
						if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_warn_msg" 10 60) then
							break
						else
							add_soft=false
						fi
					else
						download=$(echo "$final_software" | sed 's/\"//g' | tr ' ' '\n' | nl | sort -u -k2 | sort -n | cut -f2- | sed 's/$/ /g' | tr -d '\n')
						download_list=$(echo "$download" |  sed -e 's/^[ \t]*//')

						if ! "$menu_enter" ; then
							echo "$(date -u "+%F %H:%M") : Add software list: $download" >> "$log"
							base_install+="$download_list "
							unset final_software
							break
						else
							pacman -Sy --print-format='%s' $(echo "$download") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
							pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2pacman -S --print-format\Zn" load
							download_size=$(</tmp/size) ; rm /tmp/size
							export software_size=$(echo "$download_size Mib")
							export software_int=$(echo "$download" | wc -w)
							cal_rate

							if [ "$software_int" -lt "20" ]; then
								height=17
							else
								height=20
							fi

							if (dialog --yes-button "$install" --no-button "$cancel" --yesno "\n$software_confirm_var1" "$height" 65) then
								arch-chroot "$ARCH" pacman --noconfirm -Sy $(echo "$download") &>>"$log" &
								pid=$! pri=$(<<<"$down" sed 's/\..*$//') msg="\n$software_load_var" load_log
								echo "$(date -u "+%F %H:%M") : Finished installing software" >> "$log"
								unset final_software
								break
							else
								unset final_software
								add_soft=false
							fi
						fi

					fi
				;;
			esac

			if "$add_soft" ; then
				if [ -z "$software" ]; then
					if ! (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_noconfirm_msg ${software_menu}?" 10 60) then
						skip=true
					fi
				else
					add_software=$(echo "$software" | sed 's/\"//g')
					software_list=$(echo "$add_software" | sed -e 's/^[ \t]*//')
					pacman -Sy --print-format='%s' $(echo "$add_software") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
					pid=$! pri=0.1 msg="$wait_load \n\n \Z1> \Z2pacman -Sy --print-format\Zn" load

					download_size=$(</tmp/size) ; rm /tmp/size
					software_size=$(echo "$download_size Mib")
					software_int=$(echo "$add_software" | wc -w)
					source "$lang_file"

					if [ "$software_int" -lt "15" ]; then
						height=14
					else
						height=16
					fi

					if (dialog --yes-button "$add" --no-button "$cancel" --yesno "\n$software_confirm_var0" "$height" 60) then
						final_software+="$software "
					fi
				fi
			fi
		done
	fi

}
