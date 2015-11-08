# arch-linux-anywhere

Arch Linux Anywhere is an Arch Linux ISO, and installer, which allows you to install Arch regardless of the status of your network connection. I have remastered the official archiso to include local package repos for both respective arcitectures (x86_64 and i686).

All packages needed for a full Arch Linux install are contained within the ISO, effectively allowing you to install Arch Linux Anywhere.

My ISO also contains a built in installer script I've written in shell. This sctipt can be invoked by simply typing:

	arch-anywhere

My script determines the status of your network connection. If you do not have an active connection to the interent it will automatically install the packages from the local repo. However if you do have an active connection it asks to download all the packages from the official repos, while still giving you the choice of downloading locally.

The local package repos allow you to proform a full base / base-devel install directly from the ISO. Not only that but it allows you the option to install a list of additional software and desktops for both arcitectures. More software options and desktops are available if you select the online install. All packages are from the official arch sync repos.

- You can find the official Arch Linux Anywhere ISO at:
https://sourceforge.net/projects/arch-anywhere/

- Graphics and desktops / window managers:

	xorg-server xorg-server-utils xorg-xinit xterm

	xfce4

	awesome

	openbox

	i3

	dwm

	xf86-video-ati

	nvidia nvidia-340xx nvidia-304xx

	xf86-video-intel

	virtualbox-guest-utils

	lightdm

	lightdm-gtk-greeter


- Bootloader:

	grub

	os-prober


- Network Utils:

	wireless_tools

	wpa_supplicant
	
	netctl

	wpa_actiond


- Additional optional programs:

	arch-wiki

	screenfetch

	openssh

	firefox

	htop

	zsh

	conky

	htop

	lynx

	pulseaudio

	cmus


- Online only desktops:

	mate

	lxde

	lxqt

	cinnamon

	gnome

	kde plasma

	enlightenment

	fluxbox
