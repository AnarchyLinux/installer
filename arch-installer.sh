#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
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
###
### This program is free software; you can redistribute it and/or
### modify it under the terms of the GNU General Public License
### as published by the Free Software Foundation; either version 2
### of the License, or (at your option) any later version.
###
### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License for more details.
###
### You should have received a copy of the GNU General Public License
### along with this program; if not, write to the Free Software
### Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
################################################################

init() {

	if [ $(basename "$0") = "arch-anywhere" ]; then
		aa_dir="/usr/share/arch-anywhere" # Arch Anywhere iso
		aa_conf="/etc/arch-anywhere.conf"
		aa_lib="/usr/lib/arch-anywhere"
	else
		aa_dir=$(dirname $(readlink -f "$0")) # Arch Anywhere git repository
		aa_conf="$aa_dir"/etc/arch-anywhere.conf
		aa_lib="$aa_dir"/lib
	fi

	trap '' 2
	
	for file in $(ls "$aa_lib") ; do
		source "$aa_lib"/"$file"
	done

	source "$aa_conf"
	language
	source "$lang_file"
	export reload=true

}

main() {

	update_mirrors
	check_connection
	set_keys
	set_locale
	set_zone
	prepare_drives
	prepare_base
	graphics
	add_software
	install_base
	configure_systen
	set_hostname
	add_user
	reboot_system
}

dialog() {

	if "$screen_h" ; then
		/usr/bin/dialog --colors --backtitle "$backtitle" --title "$op_title" "$@"
	else
		/usr/bin/dialog --colors --title "$title" "$@"
	fi

}


opt="$1"
init
main

# vim: ai:ts=8:sw=8:sts=8:noet
