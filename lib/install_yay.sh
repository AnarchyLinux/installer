#!/usr/bin/env bash
# Downloads and installs yay-bin from https://aur.archlinux.org/yay-bin.git

_yay_dir="$(mktemp -d)"

# Install git as a dependency
pacman --noconfirm -Sy git

# Clone and install yay
git clone https://aur.archlinux.org/yay.git "${_yay_dir}"
cd "${_yay_dir}" || exit
makepkg --noconfirm -si