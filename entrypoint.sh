#!/bin/sh

DATE_FMT="+%Y/%m/%d %H:%M:%S"
CMD_NAME="$0"

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$(date "$DATE_FMT")" "$CMD_NAME:" "$@"
    fi
}

fail() {
    entrypoint_log "$@"
    entrypoint_log "Cannot start nginx! Exiting."
    exit 1
}

entrypoint_log "Starting Nginx for MiniK8s"

# Check and adjust log directory permissions

LOG_DIR="/var/log/nginx"

if [ ! -d "$LOG_DIR" ]; then
    entrypoint_log "$LOG_DIR does not exist. Creating it..."
    mkdir -p "$LOG_DIR" 2>/dev/null || fail "Cannot create directory as user '$(whoami)'."
fi
if [ ! -w "$LOG_DIR" ]; then
    entrypoint_log "$LOG_DIR is not writable. Adding write permissions..."
    chmod u+w "$LOG_DIR" 2>/dev/null || fail "Cannot modify directory permissions as user '$(whoami)'."
fi
entrypoint_log "$(ls -ld $LOG_DIR)"

# Warn about using a non-nginx command

if [ ! "$1" = "nginx" ] && [ ! "$1" = "nginx-debug" ]; then
    entrypoint_log "You're not running the 'nginx' CMD. Make sure you know what you're doing."
fi

exec "$@"
