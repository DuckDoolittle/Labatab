#!/bin/bash
#
# ClamAV daily scan wrapper
# Runs at 00:01 via cron as the ansible user
#

set -euo pipefail

LOG_FILE="/var/log/clamav/daily_scan.log"
SCAN_DIR="/home/ansible"
WEB_DIR="/var/www"

mkdir -p "$(dirname "$LOG_FILE")"

echo "=== ClamAV Daily Scan $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"

# Scan home directory
if [ -d "$SCAN_DIR" ]; then
    echo "Scanning $SCAN_DIR..." >> "$LOG_FILE"
    clamscan -r --log=yes --log=error="$LOG_FILE" "$SCAN_DIR" 2>&1 >> "$LOG_FILE" || true
fi

# Scan web directory if it exists
if [ -d "$WEB_DIR" ]; then
    echo "Scanning $WEB_DIR..." >> "$LOG_FILE"
    clamscan -r --log=yes --log=error="$LOG_FILE" "$WEB_DIR" 2>&1 >> "$LOG_FILE" || true
fi

echo "=== Scan complete ===" >> "$LOG_FILE"