#!/usr/bin/env bash
# A bash library used for logging

source "${ANARCHY_CONFIG_FILE}"

LOG_FILE="${ANARCHY_LOG_DIRECTORY}"/"$(date "+%d-%m-%Y")".log
export LOG_FILE

function log() {
    local message="$1"
    echo -e "[$(date "+%H:%M:%S")]: ${message}" >> "${LOG_FILE}"
}