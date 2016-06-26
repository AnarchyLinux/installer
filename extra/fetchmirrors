#!/bin/bash
### fetchmirrors.sh pacman mirrorlist update utility
### By: Dylan Schacht (deadhead) deadhead3492@gmail.com
### Website: http://arch-anywhere.org
#######################################################

usage() {

	echo "${Yellow} Usage:${Green} $this <opts> <args> ${Yellow}Ex: ${Green}${this} -s 4 -v -c US" # Display help / usage options menu
	echo
	echo "${Yellow} Updates pacman mirrorlist directly from archlinux.org"
	echo
	echo " Options:"
	echo "${Green}   -c --country"
	echo "${Yellow}   Specify your country code:${Green} $this -c US"
	echo "${Green}   -d --nocolor"
	echo "${Yellow}   Disable color prompts"
	echo "${Green}   -h --help"
	echo "${Yellow}   Display this help message"
	echo "${Green}   -l --list"
	echo "${Yellow}   Display list of country codes"
	echo "${Green}   -q --noconfirm"
	echo "${Yellow}   Disable confirmation messages (Run $this automatically without confirm)"
	echo "${Green}   -s --servers"
	echo "${Yellow}   Number of servers to add to ranked list (default is 6)"
	echo "${Green}   -v --verbose"
	echo "${Yellow}   Verbose output"
	echo
	echo "${Yellow}Use${Green} $this ${Yellow}without any option to prompt for country code${ColorOff}"
}

get_opts() {
		
	this=${0##*/} # Set 'this', 'rank_int', 'confirm', 'countries', and color variables
	rank_int="6"
	confirm=true
	countries=( "1) AT Austria - 2) AU  Australia - 3) BE Belgium\n4) BG Bulgaria - 5) BR Brazil - 6) BY Belarus\n7) CA Canada - 8) CL Chile - 9) CN China \n10) CO Columbia - 11) CZ Czech-Republic - 12) DE Germany\n13) DK Denmark - 14) EE Estonia - 15) ES Spain\n16) FI Finland - 17) FR France - 18) GB United-Kingdom\n19) HU Hungary - 20) IE Ireland - 21) IL Isreal\n22) IN India - 23) IT Italy - 24) JP Japan\n25) KR Korea - 26) KZ Kazakhstan - 27) LK Sri-Lanka\n28) LU Luxembourg - 29) LV Lativia - 30) MK Macedonia\n31) NC New-Caledonia - 32) NL Netherlands - 33) NO Norway\n34) NZ New-Zealand - 35) PL Poland - 36) PT Portugal\n37) RO Romania - 38) RS Serbia - 39) RU Russia\n40) SE Sweden - 41) SG Singapore - 42) SK Slovakia\n43) TR Turkey - 44) TW Taiwan - 45) UA Ukraine\n46) US United-States - 47) UZ Uzbekistan - 48) VN Viet-Nam\n49) ZA South-Africa - 50) AM All-Mirrors - 51) AS All-Https" )
	Green=$'\e[0;32m';
	Yellow=$'\e[0;33m';
	Red=$'\e[0;31m';
	ColorOff=$'\e[0m';

	while (true) # Loop case statement on 1 parameter until something happens (break || exit 1)
	  do
		case "$1" in
			-d|--nocolor) # Disable color prompts
				unset Green Yellow Red ColorOff ; shift
			;;
			-q|--noconfirm) # Disable confirmation messages
				confirm=false ; shift
			;;
			-s|--server) # Specify number of servers to add to rank list output
				rank_int="$2"
				if ! (<<<"$rank_int" grep "^-\?[0-9]*$" &> /dev/null) || [ -z "$rank_int" ]; then
					echo "${Red}Error: ${Yellow} invalid number of servers specified ${rank_int}${ColorOff}"
					exit 1
				fi
				shift ; shift
			;;
			-v|--verbose) # Set verbose switch on
				rank_int="$rank_int -v" ; shift
			;;
			-l|--list) # Display a list of country codes to the user
				echo "${Yellow}Country codes:${ColorOff}"
				echo -e "$countries" | column -t
				echo "${Yellow}Note: Use only the upercase two character code in your command ex:${Green} $this -c US"
				echo "${Yellow}Or simply use:${Green} ${this}${ColorOff}"
				break
			;;
			-h|--help) # Display usage message
				usage ; break
			;;
			-c|--country) # Country parameter allows user to input country code (ex: US)
				if [ -z "$2" ]; then
					echo "${Red}Error: ${Yellow}You must enter a country code."
				elif (<<<"$countries" grep -w "$2" &> /dev/null); then
					country_code="$2"
					query="https://www.archlinux.org/mirrorlist/?country=${country_code}"
					get_list
				else
					echo "${Red}Error: ${Yellow}country code: $2 not found."
					echo "To view a list of country codes run:${Green} $this -l${ColorOff}"
				fi
				break
			;;
			"") # Empty 1 parameter means search for country code
				search ; break
			;;
			*) # Take anything else as invalid input
				echo "${Red}Error: ${Yellow}unknown input $1 exiting...${ColorOff}"
				exit 1
		esac
	done # End case options loop
	exit

}

search() {
	
	while (true)
	  do
		echo "${Yellow}Country codes:${ColorOff}"
		echo -e "$countries" | column -t
		echo -n "${Yellow}Enter the number corresponding to your country code ${Green}[1,2,3...]${Yellow}:${ColorOff} "
		read input

		if ! (<<<$input grep "^-\?[0-9]*$" &>/dev/null) || [ "$input" -gt "51" ]; then
			echo "${Red}Error: ${Yellow}please select a number from the list.${ColorOff}"
		else
			break
		fi
	done
			
	if [ "$input" -eq "50" ]; then
		country_code="All"
		query="https://www.archlinux.org/mirrorlist/all/"
	elif [ "$input" -eq "51" ]; then
		country_code="All HTTPS"
		query="https://www.archlinux.org/mirrorlist/all/https"
	else
		country_code=$(echo "$countries" | grep -o "$input...." | awk 'NR==1 {print $2}')
		query="https://www.archlinux.org/mirrorlist/?country=${country_code}"
	fi

	if "$confirm" ; then
		echo -n "${Yellow}You have selected the country code:${Green} $country_code ${Yellow}- is this correct ${Green}[y/n]:${ColorOff} "
		read input
		case "$input" in
			y|Y|yes|Yes|yY|Yy|yy|YY|"")
				get_list
			;;
			*)
				search
			;;
		esac
	else
		get_list
	fi

}

get_list() {

	echo "${Yellow}Fetching new mirrorlist from:${Green} ${query}${ColorOff}"
	
	if [ -f /usr/bin/wget ]; then wget -O /tmp/mirrorlist "$query" &> /dev/null
	else curl -o /tmp/mirrorlist "$query" &> /dev/null
	fi
	
	sed -i 's/#//' /tmp/mirrorlist
	echo "${Yellow}Please wait while ranking${Green} $country_code ${Yellow}mirrors...${ColorOff}"
	rankmirrors -n "$rank_int" /tmp/mirrorlist > /tmp/mirrorlist.ranked
	
	if [ "$?" -gt "0" ]; then
		echo "${Red}Error: ${Yellow}an error occured in ranking mirrorlist exiting..."
		rm /tmp/{mirrorlist,mirrorlist.ranked} &> /dev/null
		exit 1
	fi

	if "$confirm" ; then
		echo -n "${Yellow}Would you like to view new mirrorlist? ${Green}[y/n]: ${ColorOff}"
		read input

		case "$input" in
			y|Y|yes|Yes|yY|Yy|yy|YY|"")
				echo ; cat /tmp/mirrorlist.ranked
			;;
		esac

		echo
		echo -n "${Yellow}Would you like to install the new mirrorlist backing up existing? ${Green}[y/n]:${ColorOff} "
		read input
	else
		input=""
	fi
		
	case "$input" in
		y|Y|yes|Yes|yY|Yy|yy|YY|"")
			sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
			sudo mv /tmp/mirrorlist.ranked /etc/pacman.d/mirrorlist
			echo "${Green}New mirrorlist installed ${Yellow}- Old mirrorlist backed up to /etc/pacman.d/mirrorlist.bak${ColorOff}"
			rm /tmp/mirrorlist &> /dev/null
		;;
		*)
			echo "${Yellow}Mirrorlist was not installed - exiting...${ColorOff}"
			rm /tmp/{mirrorlist,mirrorlist.ranked} &> /dev/null
		;;
	esac

}

get_opts "$@"
