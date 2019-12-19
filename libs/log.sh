#!/usr/bin/env bash
# A bash library used for logging

LOG_FILE="$(date "+%d-%m-%Y")".log

log() {
    local message="$1"
    echo -e "[$(date "+%H:%M:%S")]: ${message}" >> "${LOG_FILE}"
}