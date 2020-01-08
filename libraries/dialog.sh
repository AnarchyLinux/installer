#!/usr/bin/env bash
# Anarchy's custom dialog library

# Early access to 'variables.sh' is needed, so we need to source the file
source ./variables.sh

if [[ "$(tput lines)" -gt 25 ]]; then
    # Run the function 'update_var' from 'variables.sh'
    update_var 'sufficient_screen_size' 'true'
fi

# Defines a custom dialog based on system properties
function dialog {
    local sufficient_screen_size
    local uses_laptop

    sufficient_screen_size="$(get_var 'sufficient_screen_size')"
    uses_laptop="$(get_var 'uses_laptop')"

    # If terminal height is more than 25 lines add a heading with
    # a batter percentage
    if "${sufficient_screen_size}" ; then
        if "${uses_laptop}" ; then
            # Show battery life next to Anarchy's header
            backtitle="${backtitle} $(acpi)"
        fi
        # menu_title is the current menu's title
        /usr/bin/dialog --colors --backtitle "${backtitle}" --title "${menu_title}" "$@"
    else
        /usr/bin/dialog --colors --title "${anarchy_title}" "$@"
    fi
}