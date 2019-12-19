#!/usr/bin/env bash
# Anarchy's custom dialog library

if [[ "$(tput lines)" -lt 25 ]]; then
        ok_screen_size=false
fi

function dialog() {
    # If terminal height is more than 25 lines add a heading with
    # a batter percentage
    if "${ok_screen_size}" ; then
        if "${uses_laptop}" ; then
            # Show battery life next to Anarchy's header
            backtitle="${backtitle} $(acpi)"
        fi
        # menu_title is the current menu title
        /usr/bin/dialog --colors --backtitle "${backtitle}" --title "${menu_title}" "$@"
    else
        /usr/bin/dialog --colors --title "${anarchy_title}" "$@"
    fi
}