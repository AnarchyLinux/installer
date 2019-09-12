#!/usr/bin/env bash
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

	if [[ $(basename "$0") = "anarchy" ]]; then
		anarchy_directory="/usr/share/anarchy" # prev: aa_dir
		anarchy_config="/etc/anarchy.conf" # prev: aa_conf
		anarchy_scripts="/usr/lib/anarchy" # prev: aa_lib
	else
		anarchy_directory=$(dirname "$(readlink -f "$0")") # Anarchy git repository
		anarchy_config="${anarchy_directory}"/etc/anarchy.conf
		anarchy_scripts="${anarchy_directory}"/lib
	fi

	trap '' 2

	for script in "${anarchy_scripts}"/*.sh ; do
	    [[ -e "${script}" ]] || break
	    # shellcheck source=/usr/lib/anarchy/*.sh
		source "${script}"
	done

    # shellcheck source=/etc/anarchy.conf
	source "${anarchy_config}"
	language
	# shellcheck source=/usr/share/anarchy/lang/
	source "${lang_file}"
	# shellcheck source=/etc/anarchy.conf
	source "${anarchy_config}"
	export reload=true

}

main() {

    set_keys
	update_mirrors
	check_connection
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

if [[ "$UID" -ne "0" ]]; then
	echo "Error: anarchy requires root privilege"
	echo "       Use: sudo anarchy"
	exit 1
fi

opt="$1"
init
main

# vim: ai:ts=4:sw=4:et