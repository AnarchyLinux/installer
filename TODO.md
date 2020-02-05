# Todo

## Refactoring

* [ ] **Copy dotfiles instead of symlinking them (compile.sh)**
* [ ] Add comments to the config file explaining what each variable does
* [ ] Update anarchy's startup script to mention where files are saved and to
change them if needed
* [ ] Add comments to script mentioning which libraries they use and which
functions from those libraries + which arguments they require
* [ ] Try to make scripts/libraries POSIX compliant
* [ ] Update confusing code in scripts (e.g. disk partitioning ...)
* [ ] All script should be independent of one another, by writing to the config
and/or other files and not by exporting variables
* [ ] The update option should move the needed folders to the home directory
and merging them
* [ ] Update code for setting wallpapers ?
* [ ] Update and test pacman package installation code


## Improvements

* [ ] Add a dialog after connecting to wifi asking if the user wants to update
anarchy (YES - default)
* [ ] Automatically update keys if user updates anarchy
* [ ] Automatically start the installer by asking if the user wants to start
the installation (if no, do the same thing as `start`, if yes ask for wifi)
* [ ] Auto upload logs to [termbin](https://termbin.com) if an error occurs
and show the link in the error report message
* [ ] Only install official packages by default (not from AUR as well), warning
the user if AUR packages will be installed
* [ ] Add a separate optional software category for AUR packages
* [ ] Enable un-selecting of optional software
* [ ] Unify translation files
* [ ] Remove unused variables from translation files (e.g. `aa_` variables)
* [ ] Add laptop-specific software (e.g. `tlp`)
* [ ] Check if packages marked for installation exist in the repositories
(maybe fallback to the AUR if they're not in the official repo)


## Long-term features

* [ ] Add a library function for adding packages to the packages list
* [ ] Replace all arrays with direct changes to files (for POSIX compliance)
* [ ] Make most/all scripts and libraries POSIX compliant
* [ ] Add support for other Arch-based distros by accepting custom isos in
`compile.sh` (e.g. `-i` flag)
* [ ] Port translations to `gettext` and update the code to accomodate those
* [ ] Upload the translation files to [Weblate](https://weblate.org)
* [ ] Option to use a custom config file and just install the system based on
that (restructure the config file to have the configurable options at the top
and system options (e.g. screen size) on the bottom)
* [ ] Implement moving back through the menus
* [ ] Add advanced locale selection (e.g. changing LC_MESSAGES, LC_MONETARY ...)
* [ ] Download and "install" custom dot files (e.g. those based on GNU Stow ?)
* [ ] Enable a pure Arch installation (no Anarchy-related files at all)
* [ ] Make variables more universal (remove ANARCHY in declarations)
* [ ] Make scripts more modular (don't assume global variables exist)

## Documentation

* [ ] Add instructions for cloning the repo (git submodules ...)
