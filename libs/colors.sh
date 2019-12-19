#!/usr/bin/env bash
# Anarchy's color library

# Define colors
color_green=$'\e[0;32m';
color_yellow=$'\e[0;33m';
color_red=$'\e[0;31m';
color_none=$'\e[0m'

tput civis
echo -en "\e]P0073642" ; clear # Black
echo -en "\e]P8002B36" ; clear # Dark Grey
echo -en "\e]P1DC322F" ; clear # Dark Red
echo -en "\e]P9CB4B16" ; clear # Red
echo -en "\e]P2859900" ; clear # Dark Green
echo -en "\e]PA586E75" ; clear # Green
echo -en "\e]P3B58900" ; clear # Brown
echo -en "\e]PB657B83" ; clear # Yellow
echo -en "\e]P4268BD2" ; clear # Dark Blue
echo -en "\e]PC839496" ; clear # Blue
echo -en "\e]P5D33682" ; clear # Dark Magenta
echo -en "\e]PD6C71C4" ; clear # Magenta
echo -en "\e]P62AA198" ; clear # Dark Cyan
echo -en "\e]PE93A1A1" ; clear # Cyan
echo -en "\e]P7EEE8D5" ; clear # Light Grey
echo -en "\e]PFFDF6E3" ; clear # White
setterm -background black
setterm -foreground white
tput cnorm