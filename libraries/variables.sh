#!/usr/bin/env bash
# A library for interfacing with the configuration file


# A function for updating variables in the config file
# Arguments:
#   $1 - variable's name (key)
#   $2 - variable's value
function update_var {
    local key
    local value

    key="$1"
    value="$2"

    # Use sed to replace value with a new one, without knowing the old value
    sed -i -e 's/^'${key}'=\(.*\)/'${key}'='${value}'/' "${ANARCHY_CONFIG_FILE}"
    return "$?"
}

# A function for reading values from the config file
# Arguments:
#   $1 - variable's name (key)
function read_var {
    local key
    local value

    key="$1"

    # Get the key's value using grep, return only the value using cut
    value="$(grep "${key}" "${ANARCHY_CONFIG_FILE}" | cut -d "=" -f 2)" || return 1

    # Return the  requested value to the parent script
    echo "${value}"
    return 0
}