# A function for updating variables in the config file
# Arguments:
#   $1 - variable's name (key)
#   $2 - variable's value
update_var() {
    local key
    local value

    key="$1"
    value="$2"

    log "Setting variable \'${key}\' to \'${value}\'"

    # Use sed to replace value with a new one, without knowing the old value
    # The first part ( /^#/! ) prevents sed from changing comments
    # (lines starting with a #)
    # The second part ( s/^${key}=\(.*\)/${key}=${value}/ ) replaces the first
    # usage of key=some_value to a specified value
    sed -i -e "/^#/! s/^${key}=\(.*\)/${key}=${value}/" "${ANARCHY_CONFIG_FILE}"
    return "$?"
}

# A function for reading values from the config file
# Arguments:
#   $1 - variable's name (key)
# Error codes:
#   1 - could not read variable's value from config file
read_var() {
    local key
    local value

    key="$1"

    log "Reading variable \'${key}\'"

    # Get the key's value using grep, return only the value using cut
    # The first command returns all lines, besides comments
    # The second command returns only lines matching the key
    # (there should be only one - [ key=value ] )
    # Cut then removes the key= part, so only the value is saved
    value="$(grep "^[^#;]" "${ANARCHY_CONFIG_FILE}" | grep "${key}" | \
            cut -d "=" -f 2)" || return 1

    # Return the  requested value to the parent script
    echo "${value}"
    return 0
}