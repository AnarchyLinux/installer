# liblog.sh
# A library used for logging text into a file

_LOG_FILE="/home/${USER}/anarchy-$(date '+%Y-%m-%d').log"

# Appends the message, along with a timestamp, to the file
# Args:
#	$1 - message to log
log() {
    local message="$1"
    echo "[$(date '+%H:%M:%S')]: ${message}" >> "${_LOG_FILE}"
}