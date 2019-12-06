#!/usr/bin/env bash
# Copyright (C) 2017 Dylan Schacht

init() {
    if [[ $(basename "$0") = "anarchy" ]]; then
        export anarchy_directory="/usr/share/anarchy"
        export anarchy_config="/etc/anarchy.conf"
        export anarchy_scripts="/usr/lib/anarchy"
    else
        export anarchy_directory=$(dirname "$(readlink -f "$0")") # Anarchy git repository
        export anarchy_config="${anarchy_directory}"/etc/anarchy.conf
        export anarchy_scripts="${anarchy_directory}"/lib
    fi

    trap '' 2

    updated_scripts=('check_connection.sh' 'choose_base.sh' 'install_yay.sh' 'language.sh')

    # Until all the scripts are updated, we have to only source the ones that aren't
    for script in "${anarchy_scripts}"/*.sh; do
        for elem in "${updated_scripts[@]}"; do
            if [[ "${elem}" != "${script}" ]]; then
                source "${script}" || break
            fi
        done
    done

    source "${anarchy_config}"
    source "${anarchy_scripts}"/language.sh
    source "${lang_file}"
}

# A wrapper for running scripts
run() {
    source "${anarchy_scripts}/$1"
}

main() {
    set_keys # configure_locale.sh

    run check_connection.sh

    # Continue only if we have an active internet connection
    #if [[ $? -eq 0 ]]; then
    update_mirrors # configure_connection.sh
    test_connection # configure_connection.sh
    run install_yay.sh
    set_locale # configure_locale.sh
    set_zone # configure_locale.sh
    prepare_drives
    install_options
    set_hostname
    set_user
    add_software
    install_base
    configure_system
    add_user
    reboot_system
    #fi
}

dialog() {
    # If terminal height is more than 25 lines add a backtitle
    if "${screen_h}" ; then # /etc/anarchy.conf:62
        if "${LAPTOP}" ; then # /etc/anarchy.conf:75
            # Show battery life next to Anarchy heading
            backtitle="${backtitle} $(acpi)"
        fi
        # op_title is the current menu title
        /usr/bin/dialog --colors --backtitle "${backtitle}" --title "${op_title}" "$@"
    else
        # title is the main title (Anarchy)
        /usr/bin/dialog --colors --title "${title}" "$@"
    fi
}

update_anarchy() {
    tmp_dir="$(mktemp -d)"
    wallpaper_dir="$(mktemp -d)"

    echo -ne "\n${Yellow}*> Anarchy: Downloading files and scripts..."
    wget -q -4 --no-check-certificate -O ${tmp_dir}/master.tar.gz https://github.com/AnarchyLinux/installer/archive/master.tar.gz

    if [[ $? -gt 0 ]]; then
        echo -e "${Red}*> Error: ${Yellow}Active network connection not detected - Please connect to the internet and try again. Exiting..."
        exit 2
    fi

    wget -q -4 --no-check-certificate -O ${wallpaper_dir}/master.tar.gz https://github.com/AnarchyLinux/brand/archive/master.tar.gz

    if [[ $? -gt 0 ]]; then
        echo -e "${Red}*> Error: ${Yellow}Active network connection not detected - Please connect to the internet and try again. Exiting..."
        exit 2
    fi

    echo -e "${Green}Done"

    echo -ne "\n${Yellow}*> Anarchy: Extracting and moving files..."
    tar zxf ${tmp_dir}/master.tar.gz -C ${tmp_dir} &> /dev/null
    tar zxf ${wallpaper_dir}/master.tar.gz -C ${wallpaper_dir} &> /dev/null
    cp ${tmp_dir}/installer-master/anarchy-installer.sh /usr/bin/anarchy
    cp ${tmp_dir}/installer-master/etc/anarchy.conf /etc/anarchy.conf
    cp ${tmp_dir}/installer-master/lib/* /usr/lib/anarchy/
    cp ${tmp_dir}/installer-master/lang/* /usr/share/anarchy/lang/
    cp "${wallpaper_dir}"/brand-master/wallpapers/official/* /usr/share/anarchy/extra/wallpapers/
    cp -f ${tmp_dir}/installer-master/extra/sysinfo /installer-master/extra/iptest /usr/bin/
    cp -r ${tmp_dir}/installer-master/extra/* /usr/share/anarchy/extra/
    echo -e "${Green}Done"

    echo -e "\n${Green}*> ${Yellow}Anarchy updated successfully, you may now run anarchy${ColorOff}"
    exit 0
}

update_keys() {
    echo -e "${Yellow}*> Anarchy: Updating pacman keys..."
    pacman-db-upgrade
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --refresh-keys

    if [[ $? -gt 0 ]]; then
        echo -e "${Red}*> Error: ${Yellow}Failed to update pacman keys, exiting..."
        exit 1
    else
        echo -e "${Green}*> Updated: ${Yellow}Updated pacman keys successfully."
        exit 0
    fi
}

if [[ ${UID} -ne 0 ]]; then
    echo "Error: anarchy requires root privilege"
    echo "       Use: sudo anarchy"
    exit 1
fi

# Installer colors
Green=$'\e[0;32m';
Yellow=$'\e[0;33m';
Red=$'\e[0;31m';
ColorOff=$'\e[0m';

usage() {
    clear
    echo -e "Usage: ${Green} anarchy [options]${ColorOff}"
    echo -e "${Green}   -h | --help         ${Yellow}Display this help message${ColorOff}"
    echo -e "${Green}   -k | --keys         ${Yellow}Update pacman keys${ColorOff}"
    echo -e "${Green}   -n | --no-style     ${Yellow}Disable installer style${ColorOff}"
    echo -e "${Green}   -u | --update       ${Yellow}Update anarchy scripts${ColorOff}"
    echo -e ""
    exit 0
}

# Get options
case "$1" in
    -h|--help)
        usage
    ;;
    -n|--no-style)
        colors=false
    ;;
    -k|--keys)
        update_keys
    ;;
    -u|--update)
        update_anarchy
    ;;
esac

init
main

# vim: ai:ts=4:sw=4:et