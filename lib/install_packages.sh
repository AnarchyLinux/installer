#!/usr/bin/env bash
# Installs all the requested packages

packages="/usr/lib/anarchy/extra/packages"
aur_packages="/usr/lib/anarchy/extra/aur-packages"

# Update package repositories
pacman --noconfirm -Sy
yay --noconfirm -Sy

for package in $(cat ${packages}); do
    pacman --noconfirm -S "${package}" || continue
done

for aur_package in $(cat ${aur_packages}); do
    yay --noconfirm -S "${aur_package}" || continue
done