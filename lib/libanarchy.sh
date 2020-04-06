# Anarchy's main library (used by all the scripts)
# Copyright (C) 2020 Erazem Kokot <contact@erazem.eu>

# Includes the following functions:
#	- log

# Global variables
LOG_FILE="${HOME}/anarchy-$(date '+%Y-%m-%d').log"

# Logging library, that appends its arguments (log messages) to the LOG_FILE
# Args:
#	$1 - message to log
log() {
    local message="$1"
    echo "[$(date '+%H:%M:%S')]: ${message}" >> "${LOG_FILE}"
}
