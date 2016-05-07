# arch-linux-anywhere

Arch Anywhere is a modified version of the official archiso providing users with a hassle free pure Arch Linux install from start to finish. Arch Anywhere contains a set of shell scripts intended to simplify the install process. This includes a whiptail automated installer enabling you to install Arch Linux from the cli in semi graphical install mode. Simply boot up and type 'arch-anywhere' to invoke the installer script, every aspect of the install is taken into account from partitioning and general system configuration, to installing your favorite desktop/wm and additional software from the official Arch Linux repos. The installer is intended to allow novice Linux users a simple and pain free way to install Arch Linux regardless of their previous experience. It is also intended to allow advanced users with a way to deploy an Arch system while still providing the flexibility and freedom of choice of a traditional Arch Linux install.

The installer includes options for automatic or manual partitioning, partition encryption (lukas on LVM), latest Arch Linux kernel, Linux GreSec security hardened kernel, Linux LTS kernel, choose from 14 different default desktop/window manager options and 1 custom Arch Anywhere XFCE4 desktop (install as many as you desire), over 70 options for additional software (audio, games, multimedia, web, office, system...), support for all graphics cards (amd, intel, nvidia), virtualbox support, support for UEFI and dual booting, support for laptop touchpads, support for wifi and bluetooth, 10 different installer languages to choose from. This is a dual ISO containing support for both 32 bit and 64 bit systems.

### Official Arch Linux Anywhere ISO:

	https://arch-anywhere.org

<p align="center">
  <img src="http://arch-anywhere.org/images/installer/issue.png" width="350"/>
</p>
![alt tag](http://arch-anywhere.org/images/installer/issue.png)

### Features:

* Supported partitioning methods include:

    Full drive automatic partitioning with optional SWAP partition <br />
    Full drive automatic partitioning with luks on LVM encryption for root and tmp partition with optional enctypted SWAP partition <br />
    Manual partition (advanced users) uses cfdisk for partitioning, or you may partition your drive before the install and simply select all your mountpoints <br />

* Supported Desktop Environments + Window Managers:

    Arch Anywhere XFCE4 (developers custom xfce4 desktop) <br />
    AwesomeWM <br />
    Cinnamon Desktop <br />
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
    NVIDIA: Stable, 340xx, 304xx closed source drivers <br />
    VirtualBox Guest Utilities Drivers <br />

* Bootloader support:

    Grub (Grand Unified Bootloader) <br />
    Support for UEFI boot <br />
    OsProber (Dual-Boot Support) <br />

* Network Utilities:

    NetworkManager + applet <br />
    WPA Supplicant <br />
    WPA ActionD <br />
    Wireless Tools <br />

Also contains a long list of optional additional software (games, browsers, media players, cli utils, text editors, servers, etc...) all from the Official Arch repos.

Arch Linux, quick, easy, and straight forward, "Keep it simple stupid".

You can find the latest version of Arch Anywhere on the Download page.

![alt tag](http://arch-anywhere.org/images/arch-anywhere-splash.png)

![alt tag](http://arch-anywhere.org/images/installer/install2.png)

![alt tag](http://arch-anywhere.org/images/installer/chroot.png)
