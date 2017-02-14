#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Install additional software
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

install_software() {

	op_title="$software_op_msg"
	if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$software_msg0" 10 60) then
		
		until "$software_selected"
		  do
			unset software
			err=false
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
						software_selected=true
						err=true
						unset software_menu
					else
						err=true
					fi
				elif [ "$ex" -eq "3" ]; then
					software_menu="$done_msg"
					skip=true
				elif [ "$software_menu" == "$aar" ]; then
					if ! (<"$ARCH"/etc/pacman.conf grep "arch-anywhere"); then
						if (dialog --yes-button "$yes" --no-button "$no" --yesno "\n$aar_add_msg" 10 60) then
							echo -e "\n[arch-anywhere]\nServer = $aa_repo\nSigLevel = Never" >> "$ARCH"/etc/pacman.conf
						fi
					fi
				fi
			else
				skip=false
			fi

			case "$software_menu" in
				"$aar")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 14 60 4 \
						"arch-wiki-cli"		"$aar0" ON \
						"downgrade"		"$aar6" OFF \
						"fetchmirrors"		"$aar1" ON \
						"octopi"		"$aar4" OFF \
						"pacaur"		"$aar2" OFF \
						"pamac-aur"		"$aar5" OFF \
						"yaourt"		"$aar3" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					elif (<<<"$software" grep "octopi" &>/dev/null) && (<<<"$DE" grep "plasma" &>/dev/null); then
						software+=" kdesu"
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
						err=true
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
						"xchat"				"$net10" OFF \
						"hexchat"			"$net11" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					elif "$desktop" ; then
						if (<<<$download grep "networkmanager"); then

							download=$(<<<$download sed 's/networkmanager/networkmanager network-manager-applet/')
						fi
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
						err=true
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
						err=true
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
						err=true
					fi
					
					if [ "$software" == "multimedia-codecs" ]; then
					software="gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly ffmpegthumbnailer gst-libav"
					fi
				;;
				"$office")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 16 63 6 \
						"abiword"               "$office0" OFF \
						"calligra"              "$office1" OFF \
						"calligra-sheets"		"$office2" OFF \
						"gnumeric"				"$office3" OFF \
						"libreoffice-fresh"		"$office4" OFF \
						"libreoffice-still"		"$office5" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi

					if [ "$software" == "libreoffice-fresh" ] || [ "$software" == "libreoffice-still" ]; then
						if [ -n "$lib" ]; then
							software="$software $software-$lib"
						fi
					fi
				;;
				"$terminal")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 18 63 8 \
						"fbterm"			"$term0" OFF \
						"guake"             "$term1" OFF \
						"kmscon"			"$term2" OFF \
						"pantheon-terminal"	"$term3" OFF \
						"rxvt-unicode"      "$term4" OFF \
						"terminator"        "$term5" OFF \
						"xfce4-terminal"    "$term6" OFF \
						"yakuake"           "$term7" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
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
						err=true
					fi
				;;
				"$system")
					software=$(dialog --ok-button "$ok" --cancel-button "$cancel" --checklist "$software_msg1" 20 65 10 \
						"apache"		"$sys1" OFF \
						"conky"			"$sys2" OFF \
						"dmenu"			"$sys19" OFF \
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
						"screenfetch"		"$sys12" ON \
						"scrot"			"$sys13" OFF \
						"tmux"			"$sys14" OFF \
						"tuxcmd"		"$sys15" OFF \
						"virtualbox"		"$sys16" OFF \
						"ufw"			"$sys17" ON \
						"wget"			"$sys18" ON \
						"xfe"			"$sys23" OFF 3>&1 1>&2 2>&3)
					if [ "$?" -gt "0" ]; then
						err=true
					fi
				;;
				"$done_msg")
					if [ -z "$final_software" ]; then
						if (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_warn_msg" 10 60) then
							software_selected=true
							err=true
						fi
					else
						download=$(echo "$final_software" | sed 's/\"//g' | tr ' ' '\n' | nl | sort -u -k2 | sort -n | cut -f2- | sed 's/$/ /g' | tr -d '\n')
						export download_list=$(echo "$download" |  sed -e 's/^[ \t]*//')
						arch-chroot "$ARCH" pacman -Sy --print-format='%s' $(echo "$download") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
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
							tmpfile=$(mktemp)
						    arch-chroot "$ARCH" pacman --noconfirm -Sy $(echo "$download") &> "$tmpfile" &
						    pid=$! pri=$(<<<"$down" sed 's/\..*$//') msg="\n$software_load_var" load_log
	  					    rm "$tmpfile"
	  					    unset final_software
	  					    software_selected=true err=true
						else
							unset final_software
							err=true
						fi
					fi
				;;
			esac
			
			if ! "$err" ; then
				if [ -z "$software" ]; then
					if ! (dialog --yes-button "$yes" --no-button "$no" --defaultno --yesno "\n$software_noconfirm_msg ${software_menu}?" 10 60) then
						skip=true
					fi
				else
					add_software=$(echo "$software" | sed 's/\"//g')
					software_list=$(echo "$add_software" | sed -e 's/^[ \t]*//')
					arch-chroot "$ARCH" pacman -Sy --print-format='%s' $(echo "$add_software") | awk '{s+=$1} END {print s/1024/1024}' >/tmp/size &
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
						final_software="$software $final_software"
					fi
				fi
			fi
		done
		err=false
	fi
	
	if ! "$pac_update" ; then
		if [ -f "$ARCH"/var/lib/pacman/db.lck ]; then
			rm "$ARCH"/var/lib/pacman/db.lck &> /dev/null
		fi

		arch-chroot "$ARCH" pacman -Sy &> /dev/null &
		pid=$! pri=0.8 msg="\n$pacman_load \n\n \Z1> \Z2pacman -Sy\Zn" load
		pac_update=true
	fi

	software_selected=false

}
