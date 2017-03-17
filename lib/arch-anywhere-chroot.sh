#!/bin/bash

arch_anywhere_chroot() {

	local char=
	local input=
	local -a history=( )
	local -i histindex=0
	trap ctrl_c INT
	working_dir=$(</tmp/chroot_dir.var)

	while (true)
	  do
		echo -n "${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}" ; while IFS= read -r -n 1 -s char
		  do
			if [ "$char" == $'\x1b' ]; then
				while IFS= read -r -n 2 -s rest
				  do
					char+="$rest"
					break
				done
			fi

			if [ "$char" == $'\x1b[D' ]; then
				pos=-1
			elif [ "$char" == $'\x1b[C' ]; then
				pos=1
			elif [[ $char == $'\177' ]];  then
				input="${input%?}"
				echo -ne "\r\033[K${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}${input}"
			## User input up
			elif [ "$char" == $'\x1b[A' ]; then
				if [ $histindex -gt 0 ]; then
					histindex+=-1
					input=$(echo -ne "${history[$histindex]}")
					echo -ne "\r\033[K${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}${history[$histindex]}"
				fi
			## User input down
	        	elif [ "$char" == $'\x1b[B' ]; then
		            	if [ $histindex -lt $((${#history[@]} - 1)) ]; then
					histindex+=1
					input=$(echo -ne "${history[$histindex]}")
					echo -ne "\r\033[K${Yellow}<${Red}root${Yellow}@${Green}${hostname}-chroot${Yellow}>: $working_dir>${Red}# ${ColorOff}${history[$histindex]}"
				fi
			### Newline
	        	elif [ -z "$char" ]; then
				echo
			    	history+=( "$input" )
		            	histindex=${#history[@]}
				break
			else
				echo -n "$char"
				input+="$char"
			fi
		done

		if [ "$input" == "arch-anywhere" ] || [ "$input" == "exit" ]; then
			rm /tmp/chroot_dir.var &> /dev/null
			clear
			break
		elif (<<<"$input" grep "^cd " &> /dev/null); then
			ch_dir=$(<<<$input cut -c4-)
			arch-chroot "$ARCH" /bin/bash -c "cd $working_dir ; cd $ch_dir ; pwd > /etc/chroot_dir.var"
			mv "$ARCH"/etc/chroot_dir.var /tmp/
			working_dir=$(</tmp/chroot_dir.var)
		elif  (<<<"$input" grep "^help" &> /dev/null); then
			echo -e "$arch_chroot_msg"
			else
			arch-chroot "$ARCH" /bin/bash -c "cd $working_dir ; $input"
		fi
		input=
	done

}

ctrl_c() {

	echo
	echo "${Red} Exiting and cleaning up..."
	sleep 0.5
	unset input
	rm /tmp/chroot_dir.var &> /dev/null
	clear
	reboot_system

}
