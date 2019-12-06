#!/usr/bin/env bash
# Copyright (C) 2017 Dylan Schacht

# shellcheck disable=1090
# shellcheck disable=2154

init() {
    if [[ $(basename "$0") = "anarchy" ]]; then
        anarchy_directory="/usr/share/anarchy"
        anarchy_config="/etc/anarchy.conf"
        anarchy_scripts="/usr/lib/anarchy"
    else
        # Anarchy git repository
        anarchy_directory=$(dirname "$(readlink -f "$0")")
        anarchy_config="${anarchy_directory}"/etc/anarchy.conf
        anarchy_scripts="${anarchy_directory}"/lib
    fi

    trap '' 2

    for script in "${anarchy_scripts}"/*.sh ; do
        [[ -e "${script}" ]] || break
        source "${script}"
    done

    source "${anarchy_config}"
    language
    source "${lang_file}"
    export reload=true
}

main() {
    set_keys # configure_locale.sh
    update_mirrors # configure_connection.sh
    test_connection

    source "${anarchy_scripts}"/check_connection.sh

    # If we have an internet connection (exit code 0), then install yay
    if [[ ! $? ]]; then
        source "${anarchy_scripts}"/install_yay.sh
    fi

    set_locale
    set_zone
    prepare_drives
    install_options
    set_hostname
    set_user
    add_software
    install_base
    configure_system
    add_user
    reboot_system
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

if [[ "${UID}" -ne "0" ]]; then
    echo "Error: anarchy requires root privilege"
    echo "       Use: sudo anarchy"
    exit 1
fi

# Read optional arguments
opt="$1" # /etc/anarchy.conf:105
init
main

# vim: ai:ts=4:sw=4:et