#!/usr/bin/env bash
# Anarchy's custom dialog library

dialog() {
    # If terminal height is more than 25 lines add a heading with
    # a batter percentage
    if "${ok_screen_size}" ; then
        if "${uses_laptop}" ; then
            # Show battery life next to Anarchy's header
            installer_title="${installer_title} $(acpi)"
        fi
        # menu_title is the current menu title
        /usr/bin/dialog --colors --backtitle "${installer_title}" --title "${menu_title}" "$@"
    else
        /usr/bin/dialog --colors --title "${anarchy_title}" "$@"
    fi
}