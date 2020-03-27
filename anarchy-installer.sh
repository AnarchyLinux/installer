#!/usr/bin/env bash
# Main installation script
# Copyright (C) 2017 Dylan Schacht

init() {
    anarchy_directory="/usr/share/anarchy"
    anarchy_config="/etc/anarchy.conf"
    anarchy_scripts="/usr/lib/anarchy"

    trap '' 2

    # Source the config file
    . "${anarchy_config}"

    for script in "${anarchy_scripts}"/*.sh ; do
        [ -e "${script}" ] || break
        . "${script}"
    done

    language
    . "${lang_file}"
    export reload=true
}

main() {
    # Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: anarchy requires root privileges"
        echo "       Use: sudo anarchy"
        exit 1
    fi

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
    if "${screen_h}" ; then
        if "${LAPTOP}" ; then
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

# Read optional arguments
opt="$1"
init
main
