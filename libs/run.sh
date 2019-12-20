#!/usr/bin/env bash
# A library for running (sub)scripts

source "${ANARCHY_CONFIG_FILE}"

function run() {
    local SCRIPT="$1"
    local OUTPUT
    OUTPUT=$("${ANARCHY_SCRIPTS_DIRECTORY}/${SCRIPT}")

    # Return output of subprocess to parent process
    echo "${OUTPUT}"
}