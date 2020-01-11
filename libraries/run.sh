# A library for running (sub)scripts

function run() {
    source "${ANARCHY_CONFIG_FILE}"
    local SCRIPT="$1"
    local OUTPUT
    OUTPUT=$("${ANARCHY_SCRIPTS_DIRECTORY}/${SCRIPT}")

    # Return output of subprocess to parent process
    echo "${OUTPUT}"
}