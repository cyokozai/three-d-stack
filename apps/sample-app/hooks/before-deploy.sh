#!/bin/sh
# before-deploy.sh — triggered by Dewy before every container update.
#
# Captures a point-in-time DVB snapshot of all volumes so that a failed
# deploy can be rolled back by restoring from this archive.
# A non-zero exit code aborts the deploy automatically.
set -eu

APP_NAME="sample-app"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_LABEL="pre-deploy-${APP_NAME}-$(date +%Y%m%dT%H%M%S)"

echo "[before-deploy] Starting pre-deploy snapshot: ${BACKUP_LABEL}"

docker run --rm \
  -v db-data:/backup/db-data:ro \
  -v app-data:/backup/app-data:ro \
  -v "${SCRIPT_DIR}/backups:/archive" \
  -e BACKUP_FILENAME="${BACKUP_LABEL}" \
  offen/docker-volume-backup:latest

echo "[before-deploy] Snapshot complete: ${BACKUP_LABEL}"

# Optional: source and use the shared backup helper instead of the block above.
# . "$(dirname "$0")/../../core/global-hooks/backup.sh"
# run_backup "${BACKUP_LABEL}" db-data app-data
