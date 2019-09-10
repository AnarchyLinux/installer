<html lang="en">
<p align="center">
    <img src="https://user-images.githubusercontent.com/10241434/43771874-12ff77d8-9a73-11e8-99af-dc067a07dcd7.png" alt="Anarchy logo">
</p>
<h2 align="center">Anarchy Linux</h2>

<p align="center">
    A simple and intuitive Arch Linux installer.
    <br>
    Anarchy: quick, easy, and straight forward, following the "Keep it simple stupid" principle.
</p>

<p align="center">
    <a href="https://www.anarchylinux.org/">Home page</a> | 
    <a href="https://github.com/deadhead420/anarchy-linux/releases">Download</a> |
    <a href="https://matrix.to/#/+anarchy-linux:matrix.org">Matrix Chat</a>
</p>
</html>

## About

Anarchy Linux is an Arch Linux installer providing a hassle-free pure installation and polished user experience.
Every aspect of the install is taken into account from partitioning and general system configuration,
to installing your favorite DE/WM and additional software from the official Arch Linux repos.

The Anarchy installer is intended to provide both novice and experienced Linux users a simple and pain free way to install Arch Linux.
Install when you want it, where you want it, and how you want it.
That is the Anarchy philosophy.

Anarchy aims to provide a polished and pure Arch install while leaving open every possible configuration avenue for the user to choose from.


## Screenshots

About three main screenshots coming...


## Features

### Large selection of kernels

* `base` or `base-devel` system installation
* **default** linux kernel
* **hardened** linux kernel
* **LTS** (Long Term Support) linux kernel
* **zen** linux kernel

### Multiple partitioning methods

* Automatic partitioning (optional swap)
* Automatic LUKS-encrypted partitioning on LVM (optional encrypted swap)
* Manual partitioning

### A whole bunch of optional DEs and WMs

(*Desktop Environments and Window Managers*)

#### Completely customized

* Anarchy Cinnamon edition
* Anarchy GNOME edition
* Anarchy OpenboxWM edition
* Anarchy XFCE edition
* Anarchy Budgie edition

#### Not customized

* AwesomeWM
* Bspwm
* Cinnamon
* Deepin
* Enlightenment
* Fluxbox
* GNOME
* GNOME Flashback
* i3
* KDE/Plasma
* LXDE
* LXQT
* Mate
* Openbox
* Sway
* XFCE
* Xmonad

### A selection of graphics drivers

* ATI/AMD `xf86-video-ati` open source drivers
* Intel `xf86-video-intel` open source drivers
* NVIDIA `xf86-video-nouveau` open source drivers
* NVIDIA `stable`, `390xx`, `340xx` proprietary drivers
* VirtualBox Guest Utilities Drivers

### Your choice of bootloaders

* GRUB2
* Syslinux
* Systemd-boot

With support for UEFI and os-prober (for dual booting)

### Network utilities

* Netctl
* NetworkManager + its applet
* WPA Supplicant
* WPA ActionD
* Wireless Tools

### Additional optional software

The installer features a long list of optional software from the following categories:

* Audio
* Games
* Graphics
* Internet
* Multimedia
* Office
* Terminal
* Text editors
* Shells
* System

### AUR support

The installer has [AUR](https://aur.archlinux.org/) support enabled by default using the [yay](https://github.com/Jguer/yay) AUR helper.


## Installation

### **Verifying the checksums**

It's recommended that you verify the checksums before using Anarchy.

On Linux, this is a very simple thing to do.
Run the following command in a terminal:

`sha256sum -c anarchy-(version)-(architecture).iso.sha256sum`

If the image (ISO file) was fully and correctly downloaded you should see something like this:

`anarchy-1.0.5-x86_64.iso: OK`

On Windows you have to get some external tools.
An example is [sha256sum.exe](http://www.labtestproject.com/files/win/sha256sum/sha256sum.exe), which you can run in cmd like so:

`sha256sum.exe anarchy-(version)-(architecture).iso`

Note that unlike its Linux counterpart, it will only display the sha256 checksum of the image,
not compare it with the generated checksums as well.
So make sure to open the .sha256sum file in a text editor and compare the hashes yourself.

### **Windows**

The best tool to flash Anarchy Linux to a USB is [Win32DiskImager](https://sourceforge.net/projects/win32diskimager/).
Download it, choose the Anarchy image (ISO), select the wanted USB and press write.

THIS WILL COMPLETELY WIPE YOUR USB! YOU HAVE BEEN WARNED.

### **Linux**

The fastest method, although not the safest or easiest for most beginners is to use `dd`.

DON'T COPY AND PASTE THE TEXT BELOW AS ANY DISK YOU SELECT WILL BE COMPLETELY WIPED!

Replace `x` with your USB device's letter (use `lsblk` to check which letter it was assigned, usually it's "b"):

```
sudo dd if=./<anarchy-image.iso> of=/dev/sdx bs=4M status=progress && sync
```

You can also use GUI based software such as [Etcher](https://www.balena.io/etcher/).


## Contributing

We're always looking for new contributors to the project,
so check out our [contributing guide](CONTRIBUTING.md) for more info.


## License

The project is licensed under the [GNU GPLv2 license](LICENSE).
