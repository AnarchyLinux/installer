#!/usr/bin/env bash

# Credit: https://github.com/greyltc/docker-archlinux-aur/blob/master/add-aur.sh

# this script sets up unattended aur access via yay for a user given as the first argument
set -o pipefail -e

[[ -z "$1" ]] && echo "You must specify a user name" && exit 1
AUR_USER=$1

# install yay deps
pacman -Syyu git sudo pacman go --needed --noprogressbar --noconfirm

# create the user
useradd -m $AUR_USER

# set the user's password to blank
echo "${AUR_USER}:" | chpasswd -e

# install devel packages (without systemd)
pkgs=$(pacman -S base-devel --print-format '%n ');pkgs=${pkgs//systemd/};pkgs=${pkgs//$'\n'/}
pacman -S --needed --noprogressbar --noconfirm $pkgs vi

# give the aur user passwordless sudo powers
echo "$AUR_USER      ALL = NOPASSWD: ALL" >> /etc/sudoers

# use all possible cores for subsequent package builds
sed -i 's,#MAKEFLAGS="-j2",MAKEFLAGS="-j$(nproc)",g' /etc/makepkg.conf

# don't compress the packages built here
sed -i "s,PKGEXT='.pkg.tar.xz',PKGEXT='.pkg.tar',g" /etc/makepkg.conf

# install yay
su $AUR_USER -c 'cd; git clone https://aur.archlinux.org/yay.git'
su $AUR_USER -c 'cd; cd yay; makepkg'
pushd /home/$AUR_USER/yay/
pacman -U *.pkg.tar --noprogressbar --noconfirm
popd
rm -rf /home/$AUR_USER/yay

# do a yay system update
su $AUR_USER -c 'yay -Syyu --noprogressbar --noconfirm --needed'

echo "Packages from the AUR can now be installed like this:"
echo "su $AUR_USER -c 'yay -S --needed --noprogressbar --needed --noconfirm PACKAGE'"
echo ""
echo "Please wait..."
echo ""