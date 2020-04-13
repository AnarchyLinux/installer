# Changelog

## Release v1.1.0

* Based on archlinux-2020.04.01
* Allow Terabyte-sized partitions
* Add check for `wlan` interface
* Code cleanup
* A bunch of new wallpapers added and old wallpapers removed
* Updated main installer menu with a `-k` option
* Support compiling the iso with docker
* Fix zshrc
* Updated XFCE and Cinnamon desktops
* Fix virtualbox guest packages
* Add `broadcom-wl` wireless drivers

## Release v1.0.10

* Based on Arch Linux's 01/01/2020 release
* Update French and Romanian translations
* Fix iso creation bug
* Fix uppercase username check

## Release v1.0.9

* Updated to December 1st Arch Linux base
* Add options to pacman.conf
* Remove obsolete os-release code

## Release v1.0.8

* Update French and Romanian translations
* Remove Fetchmirrors from the main menu (mirrors can still be updated
normally during the installation)
* New users aren't automatically added to 'users' group, but their respective
username-based groups
* Completely remove i686 code (can be re-added if someone is willing to
support it)
* Add AMDGPU driver (`xf86-video-amdgpu`)
* Retrieve downloads from anarchylinux/brand repository (no change for users,
just in the installation process)
* Fix GRUB errors if `base` package was selected

## Release v1.0.7

* Add additional optional arguments to `iso-generator.sh`
(--no-color, --no-input)
* Allow choosing custom log and output directories
* Finally actually compare checksums for upstream Arch ISOs
(even with preexisting Arch ISOs)
* Lint a few scripts (more lintings are planned in the future)
* Properly generate Anarchy ISO checksum (now only filename,
instead of the absolute path to file)
* French translation updates
* Removal of old, unused Anarchy repo code
* Allow choosing additional DEs/WMs from the optional software menu
* Start using `yay-bin` instead of `yay`
* Remove `go` dependency of yay
* Prepare for removal of i686 code
* Update default installation packages due to Arch's structural changes

### Removal of i686 code/releases

We have decided to completely remove i686 code, since currently the compilation
process did not work properly and nobody was willing to maintain it.

If someone willing to maintain i686 support steps up, we will gladly re-add it.
Please either message us on [Telegram](https://t.me/anarchy_linux)
or using the [contact form](https://www.anarchylinux.org/contact.html)
on our website.

## Release v1.0.6

* Update French, Portuguese, Romanian and Spanish translations
* Move keyboard selection menu to after selecting a language
* Remove `rethinkdb`, `alienarena`, `flightgear` and `urbanterror`
(moved to the AUR)
* Rename `dlang-dmd`, `java-openjfx`
* Add `yay` to custom DE installations
* Remove some Anarchy branding info (`lsb-release` and `os-release`)
* Output generated Anarchy ISO to `out/` directory
* Log iso-generator actions to `log/` directory
* Update error reporting of iso-generator
* Add Qtile Window Manager as an optional DE/WM
* Codebase cleanup
* Fix translations not working

## Release v1.0.5

* Remove GUI installer (doesn't affect DEs and WMs)
* Refactor the `iso-generator` script
* Start using checksums with new releases
* Completely remove `arch-wiki`
* Make iso generation more verbose (easier to debug)
* Remove `GREP_OPTIONS` from `.zshrc`
* Update French translation
* Remove OpenJDK7 in favour of OpenJDK8
* Add `youtue-dl` to package list
* Add `openssh` package to custom server installations
* Fix insertion of modules into `mkinitcpio.conf`
* Fix LUKS-encrypted XFS installations not booting

## Release v1.0.4

* Remove QT4 from package list
* Remove MongoDB from optional software list
* Add timeout to syslinux config
* Remove `arch-wiki-cli` from package list
