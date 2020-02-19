<html lang="en">
<p align="center">
    <img src="https://user-images.githubusercontent.com/10241434/43771874-12ff77d8-9a73-11e8-99af-dc067a07dcd7.png" alt="Anarchy logo">
</p>
<h2 align="center">Anarchy Linux</h2>

<p align="center">
    A simple and intuitive Arch Linux installer, following the KISS principle.
</p>

<p align="center">
    <a href="https://www.anarchylinux.org/">Website</a> | 
    <a href="https://github.com/AnarchyLinux/installer/releases">Download</a> |
    <a href="https://t.me/anarchy_linux">Telegram group</a>
</p>
</html>

# About

Anarchy Linux is an Arch Linux installer (**not a distro!**) providing a
hassle-free installation and polished user experience.
Every aspect of the install is taken into account from partitioning and general
system configuration, to installing your favorite DE/WM and additional software
from the official Arch Linux repos.

The Anarchy installer intends to provide both novice and experienced Linux users
a simple and pain free way to install Arch Linux.
Install when you want it, where you want it, and however you want it.
That is the Anarchy philosophy.

# Installation

## Verifying the checksum

It's recommended that you verify the checksum before using Anarchy.

On Linux, this is a very simple thing to do.
Run the following command in a terminal:

`sha256sum -c anarchy-(version)-(architecture).iso.sha256sum`

If the image (ISO file) was fully and correctly downloaded you should see
something like this:

`anarchy-1.0.10-x86_64.iso: OK`

On Windows you have to get some external tools.
An example is [sha256sum.exe](http://www.labtestproject.com/files/win/sha256sum/sha256sum.exe),
which you can run in cmd like so:

`sha256sum.exe anarchy-(version)-(architecture).iso`

Note that unlike its Linux counterpart, it will only display the sha256 checksum
of the image, not compare it with the generated checksums as well.
So make sure to open the .sha256sum file in a text editor and compare the
hashes yourself.

## Flashing to a USB

### Windows

The best tool to flash Anarchy Linux to a USB is
[Win32DiskImager](https://sourceforge.net/projects/win32diskimager/).
Download it, choose the Anarchy image (ISO), select the wanted USB and
press write.

### **Linux**

The fastest method, although not the easiest for most beginners, is to use `dd`.

Replace `x` with your USB device's letter (use `lsblk` to check which letter
it was assigned, usually it's 'b'):

`sudo dd if=<anarchy-image.iso> of=/dev/sdx status=progress oflag=sync`

You can also use GUI based software such as
[Etcher](https://www.balena.io/etcher/).

# Contributing

We're always looking for new contributors to the project,
so check out our [contributing guide](CONTRIBUTING.md) for more info.

# License

The project is licensed under the [GNU GPLv2 license](LICENSE).