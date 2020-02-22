#!/usr/bin/env bash
# Copyright (C) 2017 Dylan Schacht
# Main script for the installation,
# which calls all other scripts

ANARCHY_INSTALL_PATH="/root"

init() {
    anarchy_directory="/usr/share/anarchy"
    anarchy_config="/etc/anarchy.conf"
    anarchy_scripts="/usr/lib/anarchy"

    trap '' 2

    # Source the config file
    . "${anarchy_config}"

    # Define log file
    ANARCHY_LOG_FILE="${ANARCHY_LOG_PATH}/anarchy-$(date '+%Y-%m-%d')".log

    # Source libraries
    for library in "${ANARCHY_LIBRARIES_PATH}"/*; do
        . "${library}"
    done

    for script in "${anarchy_scripts}"/*.sh ; do
        [[ -e "${script}" ]] || break
        # shellcheck source=/usr/lib/anarchy/*.sh
        source "${script}"
    done

    language
    # shellcheck source=/usr/share/anarchy/lang
    source "${lang_file}" # /lib/language.sh:43-60
    export reload=true
}

main() {
    log "Starting installation"
    set_keys
    update_mirrors
    check_connection
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