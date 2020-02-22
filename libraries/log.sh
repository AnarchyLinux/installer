# A library used for logging

# Create the log directory if it doesn't exist
if [ ! -d "${ANARCHY_LOG_PATH}" ]; then
    mkdir -p "${ANARCHY_LOG_PATH}"
fi

log() {
    local message="$1"
    echo "[$(date '+%H:%M:%S')]: ${message}" >> "${ANARCHY_LOG_FILE}"
}