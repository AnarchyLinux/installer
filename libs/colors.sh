#!/usr/bin/env bash
# Anarchy's color library

# Define colors
Green=$'\e[0;32m';
Yellow=$'\e[0;33m';
Red=$'\e[0;31m';
ColorOff=$'\e[0m'

function colors() {
    if "${colors}" ; then
        # Set default color scheme for installer
        tput civis
        echo -en "\e]P0073642" ; clear #black
        echo -en "\e]P8002B36" ; clear #darkgrey
        echo -en "\e]P1DC322F" ; clear #darkred
        echo -en "\e]P9CB4B16" ; clear #red
        echo -en "\e]P2859900" ; clear #darkgreen
        echo -en "\e]PA586E75" ; clear #green
        echo -en "\e]P3B58900" ; clear #brown
        echo -en "\e]PB657B83" ; clear #yellow
        echo -en "\e]P4268BD2" ; clear #darkblue
        echo -en "\e]PC839496" ; clear #blue
        echo -en "\e]P5D33682" ; clear #darkmagenta
        echo -en "\e]PD6C71C4" ; clear #magenta
        echo -en "\e]P62AA198" ; clear #darkcyan
        echo -en "\e]PE93A1A1" ; clear #cyan
        echo -en "\e]P7EEE8D5" ; clear #lightgrey
        echo -en "\e]PFFDF6E3" ; clear #white
        setterm -background black
        setterm -foreground white
        tput cnorm
    else
        mv /root/.dialogrc /root/.dialogrc-disabled
    fi
}