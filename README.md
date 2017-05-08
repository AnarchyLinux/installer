# arch-linux-anywhere

Arch Anywhere is a modified version of the official archiso providing a hassle free pure Arch Linux install from start to finish. Arch Anywhere contains a set of shell scripts intended to simplify the install process. This includes a dialog automated installer enabling you to install Arch Linux from the cli in semi graphical install mode. Simply boot up and type 'arch-anywhere' to invoke the installer script, every aspect of the install is taken into account from partitioning and general system configuration, to installing your favorite desktop/wm and additional software from the official Arch Linux repos.

The Arch Anywhere installer is intended to allow novice Linux users a simple and pain free way to install Arch Linux regardless of their previous experience. It is also intended to allow advanced users with a way to deploy an Arch system while still providing the flexibility and freedom of choice of a traditional Arch Linux install. Install Arch Linux when you want it, where you want it, how you want it, that is the Arch Anywhere philosophy.

The Arch Anywhere ISO also contains a built in Arch Wiki allowing users to browse the official Arch Linux Wiki from the cli. Simply invoke the 'arch-wiki' command at anytime to search the arch wiki (search args may be passed ex: 'arch-wiki beginners guide'). A utility to update and rank the latest Arch Linux mirrorlist is also included in the ISO it can be invoked by running 'fetchmirrors'. These included utilities make it easy for new users to install Arch from the command line without using the installer and provide a way to learn how Arch really works by learning the install process. 

Arch Anywhere aims to provide a polished Arch Linux install experience while leaving open every possible install avenue for the user to choose from.

This is a ISO containing support only for x86_64 (64 bit) systems.

### Official Arch Linux Anywhere ISO:

http://arch-anywhere.org/

<p>
  <img src="http://arch-anywhere.org/images/arch-anywhere-splash.png" width="350"/>
  <img src="http://arch-anywhere.org/images/installer/1-issue.png" width="350"/>
</p>

### Features:

* Supported Linux installs:
	Choose from base or base-devel Arch Linux install <br />
	Latest Arch Linux kernel <br />
	LTS Linux kernel (long term support) <br />
	GreSec Linux kernel (security hardened Linux) <br />

* Supported partitioning methods include:

    Full drive automatic partitioning with optional SWAP partition <br />
    Full drive automatic partitioning with luks on LVM encryption for root and tmp partition with optional encrypted SWAP partition <br />
    Manual partition (advanced users) uses cfdisk for partitioning select custom mount points <br />

* Supported Desktop Environments + Window Managers:

    Arch Anywhere XFCE4 (developers custom xfce4 desktop) <br />
    AwesomeWM <br />
    Budgie <br />
    Bspwm <br />
    Cinnamon Desktop <br />
    Deepin <br />
    DWM DynamicWM <br />
    EnlightenmentWM <br />
    FluxboxWM <br />
    Gnome Desktop <br />
    I3 i3WM <br />
    KDE/Plasma Desktop <br />
    LXDE Desktop <br />
    LXQT Desktop <br />
    Mate Desktop <br />
    OpenboxWM <br />
    XFCE4 Desktop <br />

* Supported Graphics Drivers:

    ATI/AMD xf86-video-ati open source drivers <br />
    Intel xf86-video-intel open source drivers <br />
    NVIDIA: xf86-video-nouveau open source drivers <br />
    NVIDIA: Stable, 340xx, 304xx closed source drivers <br />
    VirtualBox Guest Utilities Drivers <br />

* Bootloader support:

    Grub (Grand Unified Bootloader) <br />
    Syslinux (SysLinux Bootloader) <br />
    Systemd-boot (Systemd Bootloader) <br />
    Support for UEFI boot <br />
    OsProber (Dual-Boot Support) <br />

* Network Utilities:

    Netctl <br />
    NetworkManager + applet <br />
    WPA Supplicant <br />
    WPA ActionD <br />
    Wireless Tools <br />

Also contains a long list of optional additional software (audio, games, browsers, media players, cli utils, text editors, servers, etc...) from the Official Arch repos.

Arch Anywhere, quick, easy, and straight forward, "Keep it simple stupid".

You can find the latest version of Arch Anywhere on the Download page:

http://arch-anywhere.org/download


<p>
  <img src="http://arch-anywhere.org/images/installer/2-languages.png" width="350"/>
  <img src="http://arch-anywhere.org/images/installer/7-partition.png" width="350">
  <img src="http://arch-anywhere.org/images/installer/18-base_install.png" width="350"/>
  <img src="http://arch-anywhere.org/images/installer/25-install2.png" width="350"/>
</p>
