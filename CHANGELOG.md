# Changelog

## Release v1.0.6

* Update French, Portuguese, Romanian and Spanish translations
* Move keyboard selection menu to after selecting a language
* Remove `rethinkdb`, `alienarena`, `flightgear` and `urbanterror` (moved to the AUR)
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
* Remove GREP_OPTIONS from `.zshrc`
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