#!/bin/bash
###############################################################
### Anarchy Linux Install Script
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

	if [ $(basename "$0") = "anarchy" ]; then
		aa_dir="/usr/share/anarchy" # Anarchy ISO
		aa_conf="/etc/anarchy.conf"
		aa_lib="/usr/lib/anarchy"
	else
		aa_dir=$(dirname $(readlink -f "$0")) # Anarchy git repository
		aa_conf="$aa_dir"/etc/anarchy.conf
		aa_lib="$aa_dir"/lib
	fi

	trap '' 2

	for file in $(ls "$aa_lib") ; do
		source "$aa_lib"/"$file"
	done

	source "$aa_conf"
	language
	source "$lang_file"
	source "$aa_conf"
	export reload=true

}

main() {

	update_mirrors
	check_connection
	set_keys
	set_locale
	set_zone
	prepare_drives
	install_options
	set_hostname
	set_user
	add_software
	install_base
	configure_system
	add_user
	reboot_system

}

dialog() {

	if "$screen_h" ; then
		if "$LAPTOP" ; then
			backtitle="$backtitle $(acpi)"
		fi
		/usr/bin/dialog --colors --backtitle "$backtitle" --title "$op_title" "$@"
	else
		/usr/bin/dialog --colors --title "$title" "$@"
	fi

}

if [ "$UID" -ne "0" ]; then
	echo "Error: anarchy requires root privilege"
	echo "       Use: sudo anarchy"
	exit 1
fi

opt="$1"
init
main

# vim: ai:ts=8:sw=8:sts=8:noet
