#!/bin/sh
# backup.sh — reusable DVB snapshot helper.
#
# Usage (source this file, then call run_backup):
#   . ./core/global-hooks/backup.sh
#   run_backup "pre-deploy-myapp-20260408T120000" db-data app-data
#
# Arguments:
#   $1  — backup label (used as filename prefix)
#   $2+ — Docker volume names to include in the snapshot

run_backup() {
  LABEL="${1:?run_backup requires a label as the first argument}"
  shift

  if [ $# -eq 0 ]; then
    echo "[backup] ERROR: at least one volume name is required" >&2
    return 1
  fi

  VOLUME_ARGS=""
  for vol in "$@"; do
    VOLUME_ARGS="${VOLUME_ARGS} -v ${vol}:/backup/${vol}:ro"
  done

  ARCHIVE_DIR="$(pwd)/backups"
  mkdir -p "${ARCHIVE_DIR}"

  echo "[backup] Starting snapshot: ${LABEL} (volumes: $*)"

  # shellcheck disable=SC2086
  docker run --rm \
    ${VOLUME_ARGS} \
    -v "${ARCHIVE_DIR}:/archive" \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -e BACKUP_FILENAME="${LABEL}" \
    offen/docker-volume-backup:v2.47.2

  echo "[backup] Snapshot complete: ${LABEL}"
}
