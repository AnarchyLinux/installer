#!/bin/bash
###############################################################
### Anarchy Linux Install Script
### configure_locale.sh
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

set_keys() {

	op_title="$key_op_msg"
	while (true)
	  do
		keyboard=$(dialog --nocancel --ok-button "$ok" --menu "$keys_msg" 18 60 10 \
		"us" "United States" \
		"de" "German" \
		"el" "Greek" \
		"hu" "Hungarian" \
		"es" "Spanish" \
		"fr" "French" \
		"it" "Italian" \
		"pt-latin9" "Portugal" \
		"ro" "Romanian" \
		"ru" "Russian" \
		"sv" "Swedish" \
		"uk" "United Kingdom" \
		"$other"       "$other-keymaps"		 3>&1 1>&2 2>&3)
		source "$lang_file"

		if [ "$keyboard" = "$other" ]; then
			keyboard=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$keys_msg" 19 60 10  $key_maps 3>&1 1>&2 2>&3)
			if [ "$?" -eq "0" ]; then
				break
			fi
		else
			break
		fi
	done

	if "$GUI" ; then
		setxkbmap "$keyboard"
	fi

	localectl set-keymap "$keyboard"
	echo "$(date -u "+%F %H:%M") : Set keymap to: $keyboard" >> "$log"

}

set_locale() {

	op_title="$locale_op_msg"
	while (true)
	  do
		LOCALE=$(dialog --nocancel --ok-button "$ok" --menu "$locale_msg" 18 60 11 \
		"en_US.UTF-8" "United States" \
		"en_AU.UTF-8" "Australia" \
		"pt_BR.UTF-8" "Brazil" \
		"en_CA.UTF-8" "Canada" \
		"es_ES.UTF-8" "Spanish" \
		"fr_FR.UTF-8" "French" \
		"de_DE.UTF-8" "German" \
		"el_GR.UTF-8" "Greek" \
		"en_GB.UTF-8" "Great Britain" \
		"hu_HU.UTF-8" "Hungary" \
		"it_IT.UTF-8" "Italian" \
		"lv_LV.UTF-8" "Latvian" \
		"es_MX.UTF-8" "Mexico" \
		"pt_PT.UTF-8" "Portugal" \
		"ro_RO.UTF-8" "Romanian" \
		"ru_RU.UTF-8" "Russian" \
		"es_ES.UTF-8" "Spanish" \
		"sv_SE.UTF-8" "Swedish" \
		"$other"       "$other-locale"		 3>&1 1>&2 2>&3)

		if [ "$LOCALE" = "$other" ]; then
			LOCALE=$(dialog --ok-button "$ok" --cancel-button "$cancel" --menu "$locale_msg" 18 60 11 $localelist 3>&1 1>&2 2>&3)
			if [ "$?" -eq "0" ]; then
				break
			fi
		else
			break
		fi
	done

	echo "$(date -u "+%F %H:%M") : Set locale to: $LOCALE" >> "$log"

}


set_zone() {

	op_title="$zone_op_msg"
	while (true)
	  do
		ZONE=$(dialog --nocancel --ok-button "$ok" --menu "$zone_msg0" 18 60 11 $zonelist 3>&1 1>&2 2>&3)
		if (find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE" &> /dev/null); then
			sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g' | grep -v "$ZONE")
			SUBZONE=$(dialog --ok-button "$ok" --cancel-button "$back" --menu "$zone_msg1" 18 60 11 $sublist 3>&1 1>&2 2>&3)
			if [ "$?" -eq "0" ]; then
				if (find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE" &> /dev/null); then
					sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g' | grep -v "$SUBZONE")
					SUB_SUBZONE=$(dialog --ok-button "$ok" --cancel-button "$back" --menu "$zone_msg1" 15 60 7 $sublist 3>&1 1>&2 2>&3)
					if [ "$?" -eq "0" ]; then
						ZONE="${ZONE}/${SUBZONE}/${SUB_SUBZONE}"
						break
					fi
				else
					ZONE="${ZONE}/${SUBZONE}"
					break
				fi
			fi
		else
			break
		fi
	done

	echo "$(date -u "+%F %H:%M") : Set timezone to: $ZONE" >> "$log"

}

# vim: ai:ts=8:sw=8:sts=8:noet
