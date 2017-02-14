#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Set locale
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

set_locale() {

	op_title="$locale_op_msg"
	LOCALE=$(dialog --nocancel --ok-button "$ok" --menu "$locale_msg" 18 60 11 \
	"en_US.UTF-8" "United States" \
	"en_AU.UTF-8" "Australia" \
	"en_CA.UTF-8" "Canada" \
	"es_ES.UTF-8" "Spanish" \
	"fr_FR.UTF-8" "French" \
	"de_DE.UTF-8" "German" \
	"en_GB.UTF-8" "Great Britain" \
	"en_MX.UTF-8" "Mexico" \
	"pt_PT.UTF-8" "Portugal" \
	"ro_RO.UTF-8" "Romanian" \
	"ru_RU.UTF-8" "Russian" \
	"sv_SE.UTF-8" "Swedish" \
	"$other"       "$other-locale"		 3>&1 1>&2 2>&3)

	if [ "$LOCALE" = "$other" ]; then
		LOCALE=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$locale_msg" 18 60 11 $localelist 3>&1 1>&2 2>&3)

		if [ "$?" -gt "0" ]; then 
			set_locale
		fi
	fi

}
