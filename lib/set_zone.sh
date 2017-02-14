#!/bin/bash
###############################################################
### Arch Linux Anywhere Install Script
###	Set timezone
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

set_zone() {

	op_title="$zone_op_msg"
	ZONE=$(dialog --nocancel --ok-button "$ok" --menu "$zone_msg0" 18 60 11 $zonelist 3>&1 1>&2 2>&3)
	if (find /usr/share/zoneinfo -maxdepth 1 -type d | sed -n -e 's!^.*/!!p' | grep "$ZONE" &> /dev/null); then
		sublist=$(find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g' | grep -v "$ZONE")
		SUBZONE=$(dialog --ok-button "$ok" --cancel-button "$back" --menu "$zone_msg1" 18 60 11 $sublist 3>&1 1>&2 2>&3)
		if [ "$?" -gt "0" ]; then 
			set_zone 
		fi
		if (find /usr/share/zoneinfo/"$ZONE" -maxdepth 1 -type  d | sed -n -e 's!^.*/!!p' | grep "$SUBZONE" &> /dev/null); then
			sublist=$(find /usr/share/zoneinfo/"$ZONE"/"$SUBZONE" -maxdepth 1 | sed -n -e 's!^.*/!!p' | sort | sed 's/$/ -/g' | grep -v "$SUBZONE")
			SUB_SUBZONE=$(dialog --ok-button "$ok" --cancel-button "$back" --menu "$zone_msg1" 15 60 7 $sublist 3>&1 1>&2 2>&3)
			if [ "$?" -gt "0" ]; then
				set_zone 
			fi
			ZONE="${ZONE}/${SUBZONE}/${SUB_SUBZONE}"
		else
			ZONE="${ZONE}/${SUBZONE}"
		fi
	fi

}
