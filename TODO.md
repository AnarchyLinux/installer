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

## Long-term features
* [ ] Add support for other Arch-based distros by accepting custom isos in
`compile.sh` (e.g. `-i` flag)
* [ ] Port translations to `gettext` and update the code to accomodate those
* [ ] Upload the translation files to [Weblate](https://weblate.org)
* [ ] Option to use a custom config file and just install the system based on
that (restructure the config file to have the configurable options at the top
and system options (e.g. screen size) on the bottom)

## Documentation
* [ ] Add instructions for cloning the repo (git submodules ...)