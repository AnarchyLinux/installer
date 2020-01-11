# A bash library used for logging
function log() {
    local message="$1"
    echo -e "[$(date "+%H:%M:%S")]: ${message}" >> "${LOG_FILE}"
}