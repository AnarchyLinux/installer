#!/usr/bin/env bash
# A library for running (sub)scripts

source "${ANARCHY_CONFIG_FILE}"

function run() {
    local script="$1"
    source "${ANARCHY_SCRIPTS_DIRECTORY}"/"${script}"
    return $?
}