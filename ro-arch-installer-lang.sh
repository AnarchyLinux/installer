main_msg() {
msg0="Bine ati venit la Arch Linux Anywhere! \n\n *Doriti sa incepeti procesul de instalare"

msg1="Retea Wifi detectata, doriti sa va conectati?"

msg2="Imposibil de conectat la reteaua Wifi, continuati instalarea offline?"

msg3="Conexiune detectata. Doriti sa instalati din depozitele oficiale? \n\n *Yes va asigura ultimele pachete \n *No va asigura o instalare rapida."

msg4="Conexiunea dvs este foarte lenta, ar putea sa dureze ceva timp...\n\n *Continuati instalarea?"

msg5="Please select your desired locale:"

msg6="Please enter your Time Zone:"

msg7="Please enter your sub-zone:"

msg8="Set key-map: \n\n *If unsure leave default"

msg9="Select the drive you would like to install arch onto:"

msg10="Select your desired method of partitioning: \n\n *NOTE Auto Partitioning will format the selected drive \n *Press cancel to return to drive selection"

msg11="Return To Menu"

msg12="Select your desired filesystem type: \n *Default is ext4"

msg13="Would you like to create SWAP space?"

msg14="Specify your desired swap size: \n *(Align to M or G):"

msg15="Error not enough space on drive!"

msg16="Error setting swap! Be sure it is a number ending in 'M' or 'G'"

msg17="Would you like to enable UEFI bios? \n\n *May not work on some systems \n *Enable with caution"

msg18="Note you must create a UEFI bios partition! \n\n *Size of 512M-1024M type of EF00 \n *Partition scheme must be GPT!"

msg19="System will not boot if you don't setup UEFI partition properly! \n\n *Are you sure you want to continue? \n *Only proceed if you know what you're doing."

msg20="Would you like to use GPT partitioning?"

msg21="Please select your desired partitioning tool:"

msg22="Passwords do not match, please try again."

msg24="An error was detected during partitioning \n\n *Returing partitioning menu"

msg25="Please select your EFI boot partition: \n\n *Generally the first partition size of 512M-1024M"

msg26="This will create a fat32 formatted EFI partition. \n\n *Are you sure you want to do this?"

msg27="Please select your desired root partition: \n\n *This is the main partition all others will be under"

msg28="This will create a new filesystem on the partition. \n\n *Are you sure you want to do this?"

msg29="Select a partition to create a mount point: \n\n *Select done when finished*"

msg30="An error was detected during partitioning \n\n *Returing to drive partitioning"

msg31="Done"

msg32="Would you like to update your mirrorlist now?"

msg33="Please select your country code:"

msg34="Install wireless tools, netctl, and WPA supplicant? Provides wifi-menu command. \n\n *Necessary for connecting to wifi \n *Select yes if using wifi"

msg35="Install GRUB bootloader? \n\n *Required to make system bootable"

msg36="Install os-prober first? \n\n *Required for multiboot \n *If dualbooting select yes"

msg37="Warning! System will not be bootable! \n\n *You will need to configure a bootloader yourself \n *Continue without a bootloader?"

msg38="After install is complete choose not to reboot, you may choose to keep the system mounted at /mnt allowing you to arch-chroot into it and configure your own bootloader."

msg39="Ready to install system \n\n *Are you sure you want to exit to menu?"

msg40="Error root filesystem already installed \n\n *Continuing to menu."

msg41="Error no filesystem mounted \n\n *Return to drive partitioning?"

msg42="Error no filesystem mounted \n\n *Continuing to menu."

msg43="The system has already been configured. \n\n *Continuing to menu..."

msg44="64 bit architecture detected.\n\n *Add multilib repos to pacman.conf?"

msg45="Enable DHCP at boot? \n\n *Automatic IP configuration."

msg46="Set your system hostname:"

msg47="Please enter a new root password \n\n *Set a strong password here"

msg48="Enter new root password again"

msg49="User already added \n\n *Continuing to menu."

msg50="Create a new user account now?"

msg51="Set username: \n\n *Letters and numbers only \n *No spaces or special characters!"

msg52="Error username must begin with letter and cannot contain special characters. \n\n *Please try again."

msg53="Please enter a new password for"

msg54="Enter new password again"

msg55="Would you like to install xorg-server now? \n\n *Select yes for a graphical interface"

msg56="Select your desired graphics driver: \n\n *If unsure use mesa-libgl or default \n *If installing in VirtualBox select guest-utils"

msg57="Are you sure you dont want xorg-server? \n\n *You will be booted into command line only."

msg58="Select your desired Nvidia driver: \n\n *Cancel if none"

msg59="Would you like to install a desktop or window manager?"

msg60="Would you like to install LightDM display manager? \n\n *Graphical login manager"

msg61="Select your desired enviornment:"

mag62="After login use the command 'startx' to access your desktop."

msg63="Would you like to install some common software? \n\n *Select yes for a list of additional software"

msg64="Choose your desired software: \n\n *Use spacebar to check/uncheck software \n *Press enter when finished"

msg65="Install process complete! \n\n *You did not configure a bootloader \n *Return to the command line to configure?"

msg66="Install process complete! Reboot now? \n\n *Select yes to reboot now \n *No to return to command line"

msg67="System fully installed \n\n *Would you like to unmount?"

msg68="Install not complete, are you sure you want to reboot?"

msg69="The system hasn't been installed yet \n *returning to menu"

msg70="Menu Items:"

msg71="Locale already set, returning to menu"

msg72="Timezone already set, returning to menu"

msg73="Keymap already set, returning to menu"

msg74="Drive already mounted, try install base system \n returning to menu"

msg75="System installed \n\n Exiting arch installer..."

msg76="System not installed yet... \n\n Are you sure you want to exit?"
}

load_msg() {
load0="Please wait while we test your connection..."

load1="Fetching latest installer..."

load2="Creating efi boot partition..."

load3="Creating boot partition..."

load4="Encrypting drive..."

load5="Retreiving new mirrorlist..."

load6="Please wait while ranking mirrors..."

load7="Please wait while we install Arch Linux... \n\n *This may take awhile..."

load8="Installing os-prober..."

load9="Installing grub..."

load10="Installing efibootmgr..."

load11="Installing grub to drive..."

load12="Configuring grub..."

load13="Please wait while configuring kernel for uEFI..."

load14="Please wait while configuring kernel for encryption..."

load15="Setting timezone..."

load16="Enabling DHCP..."

load17="Please wait while installing xorg-server..."

load18="Please wait while installing LightDM..."

load19="Please wait while installing desktop... \n\n *This may take awhile..."

load20="Please wait while installing software..."

load21="Updating pacman databases..."
}

tool_msg() {
tool0="Best tool For beginners"

tool1="CLI Partitioning"

tool2="GPT Partitioning"

tool3="GNU Parted CLI"
}

part_msg() {
method0="Auto Partition Drive"

method1="Auto partition encrypted LVM"

method2="Manual Partition Drive"
}

fs_msg() {
fs0="4th extended file system"

fs1="3rd extended file system"

fs2="2nd extended file system"

fs3="B-Tree File System"

fs4="Journaled File System"

fs5="Reiser File System"
}

grp_msg() {
gr0="Auto Detect Drivers"

gr1="Mesa OpenSource Drivers"

gr2="NVIDIA Graphics Drivers"

gr3="VirtualBox Graphics Drivers"

gr4="AMD/ATI Graphics Drivers"

gr5="Intel Graphics Drivers"

gr6="Latest stable nvidia drivers"

gr7="Legacy 340xx drivers branch"

gr8="Legaxy 304xx drivers branch"
}

de_msg() {
de0="Xfce4 Light Desktop"

de1="Mate Light Desktop"

de2="Lxde Light Desktop"

de3="Lxqt Light Desktop"

de4="Gnome Modern Desktop"

de5="Cinnamon Desktop"

de6="Kde Plasma Desktop"

de7="Enlightenment Desktop"

de8="Openbox Window Manager"

de9="Awesome Window Manager"

de10="i3 Tiling Window Manager"

de11="Fluxbox Window Manager"

de12="Dynamic Window Manager"
}

soft_msg() {
m0="Arch wiki from the CLI"

m1="Secure Shell Deamon"

m2="Popular sound server"

m3="Display System Info"

m4="Popular Text Editor"

m5="CLI web downloader"

m6="Apache Web Server"

m7="Audio editing program"

m8="Graphical Web Browser"

m9="CLI music player"

m10="Light system monitor for X"

m11="Cloud file sharing"

m12="OS in a text editor"

m13="Firefox Web Browser"

m14="GNU Image Manipulation"

m15="Source control managment"

m16="Source control managment"

m17="CLI process Info"

m18="Open source word processing"

m19="Linux MultiMedia Studio"

m20="Terminal Web Browser"

m21="Music Player Daemon"

m22="Media Player"

m23="GUI client for MPD"

m24="CLI network analyzer"

m25="Video editing software"

m26="Music visuliaztions"

m27="GNU Screen"

m28="Screen capture software"

m29="Multi-platform gaming"

m30="Terminal multiplxer"

m31="CLI torrent client"

m32="Graphical torrent client"

m33="Desktop virtuialization"

m34="GUI media player"

m35="Uncomplicated Firewall"

m36="The Z-Shell"
}

menu_msg() {
menu0="Set Locale"

menu1="Set Timezone"

menu2="Set Keymap"

menu3="Partition Drive"

menu4="Update Mirrors"

menu5="Install Base System"

menu6="Configure System"

menu7="Set Hostname"

menu8="Add User"

menu9="Install Graphics"

menu10="Install Software"

menu11="Reboot System"

menu12="Exit Installer"
}

var_msg() {
var0="WARNING! Will erase all data on drive /dev/$DRIVE! \n\n *Would you like to contunue?"

var1="Warning this will encrypt /dev/$DRIVE \n\n *Continue?"

var2="Please enter a new password for /dev/$DRIVE \n\n *Note this password is used to unencrypt your drive at boot"

var3="New /dev/$DRIVE password again"

var4="Select a mount point for /dev/$new_mnt"

var5="Will create a swap space on /dev/$new_mnt \n\n *Continue?"

var6="Will create mount point $MNT with /dev/$new_mnt \n\n *Continue?"

var7="Begin installing Arch Linux base onto /dev/$DRIVE?"

var8="Enable sudo privelege for $user? \n\n *Enables administrative privelege for $user."
}

load_var_msg() {
load_var0="Partitioning /dev/$DRIVE..."

load_var1="Please wait while creating $FS filesystem"

load_var2="Generating $LOCALE locale..."

load_var3="Loading $keyboard keymap..."
}

####################################################
##                                         END TRANSLATION                                                          ##
## DO NOT TRANSLATE BELOW THIS LINE! PROGRAM VARIABLES ##
####################################################

prog_var() {
ARCH=/mnt

connection=false

wifi=false

UEFI=false

mounted=false

INSTALLED=false

bootloader=false

system_configured=false

hostname_set=false

user_added=false

arch=$(uname -a | grep -o "x86_64\|i386\|i686")

drive=$(lsblk | grep "disk" | grep -v "rom" | awk '{print $1   " "   $4}')

zonelist=$(find /usr/share/zoneinfo -maxdepth 1 | sed -n -e 's!^.*/!!p' | grep -v "posix\|right\|zoneinfo\|zone.tab\|zone1970.tab\|W-SU\|WET\|posixrules\|MST7MDT\|iso3166.tab\|CST6CDT" | sort | sed 's/$/ -/g')

countries=$(echo -e "AT Austria\n AU  Australia\n BE Belgium\n BG Bulgaria\n BR Brazil\n BY Belarus\n CA Canada\n CL Chile \n CN China\n CO Columbia\n CZ Czech-Republic\n DK Denmark\n EE Estonia\n ES Spain\n FI Finland\n FR France\n GB United-Kingdom\n HU Hungary\n IE Ireland\n IL Isreal\n IN India\n IT Italy\n JP Japan\n KR Korea\n KZ Kazakhstan\n LK Sri-Lanka\n LU Luxembourg\n LV Lativia\n MK Macedonia\n NC New-Caledonia\n NL Netherlands\n NO Norway\n NZ New-Zealand\n PL Poland\n PT Portugal\n RO Romania\n RS Serbia\n RU Russia\n SE Sweden\n SG Singapore\n SK Slovakia\n TR Turkey\n TW Taiwan\n UA Ukraine\n US United-States\n UZ Uzbekistan\n VN Viet-Nam\n ZA South-Africa")
}

main_msg
load_msg
tool_msg
part_msg
fs_msg
grp_msg
de_msg
grp_msg
menu_msg
prog_var
