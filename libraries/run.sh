# A library for running (sub)scripts
run() {
    local script="$1"
    local return_value
    log "Running script \'${script}\'"
    return_value="$("${ANARCHY_SCRIPTS_DIRECTORY}/${script}")"
    log "Finished running script \'${script}\'"

    # Return output of subprocess to parent process
    echo "${return_value}"
}