#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Set keymap
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

set_keys() {
	
	op_title="$key_op_msg"
	keyboard=$(dialog --nocancel --ok-button "$ok" --menu "$keys_msg" 18 60 10 \
	"$default" "$default Keymap" \
	"us" "United States" \
	"de" "German" \
	"es" "Spanish" \
	"fr" "French" \
	"pt-latin9" "Portugal" \
	"ro" "Romanian" \
	"ru" "Russian" \
	"uk" "United Kingdom" \
	"$other"       "$other-keymaps"		 3>&1 1>&2 2>&3)
	source "$lang_file"

	if [ "$keyboard" = "$other" ]; then
		keyboard=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$keys_msg" 19 60 10  $key_maps 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then
			set_keys
		fi
	fi
	
	export keyboard
	localectl set-keymap "$keyboard"

}
