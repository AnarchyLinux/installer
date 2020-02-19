# A library used for logging
log() {
    local message="$1"
    echo "[$(date '+%H:%M:%S')]: ${message}" >> "${ANARCHY_LOG_FILE}"
}