# arch-linux-anywhere
You can find Arch Anywhere at:
https://sourceforge.net/projects/arch-anywhere/

Arch Linux Anywhere allows you to install Arch regardless of the status of your network connection. Arch Anywhere is simply a remastered version of the official dual archiso. Difference is Arch Anywhere contains 100% local package repos on the ISO for both respective arcitectures (x86_64 and i686).

These local package repos allow you to proform a full base / base-devel install directly from the ISO. Not only is it a base / base-devel repo, but it also contains all of the following packages for both arcitectures:

base base-devel
libnewt
grub
os-prober
xorg-server xorg-server-utils xorg-xinit xterm
xfce4
awesome
openbox
i3
dwm
screenfetch
openssh
lynx
htop
wireless_tools
wpa_supplicant
netctl
xf86-video-ati
nvidia nvidia-340xx nvidia-304xx
xf86-video-intel
lightdm
lightdm-gtk-greeter
zsh
conky
htop
midori
pulseaudio
cmus
virtualbox-guest-utils

All of these packages are contained within the ISO, effectively allowing you to install Arch Linux Anywhere, without being connected to the internet.

My ISO also contains a built in installer script I've written in shell. This sctipt can be invoked by simply typing arch-installer after booting into the Arch Anywhere ISO.

My script determines the status of your network connection. If you do not have an active connection to the interent it will automatically install the packages from the local repo. However if you do have an active connection it asks to download all the packages from the official repos, while still giving you the choice of downloading locally.

All this and the installer comes in at only 1.5G for a dual installer containing all packages needed to install Arch Linux, with the desktop of your choice, and a whole list of other additional packages.
