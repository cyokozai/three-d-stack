#!/bin/sh
# after-deploy.sh — triggered by Dewy after a successful container update.
#
# Add any post-deploy tasks here: database migrations, cache warming,
# notifications, audit logging, etc.
set -eu

APP_NAME="sample-app"
TIMESTAMP="$(date +%Y-%m-%dT%H:%M:%S)"

echo "[after-deploy] Deploy complete: ${APP_NAME} at ${TIMESTAMP}"

# --- Database migration (example) ---
# Run migrations inside the newly started container.
# Adjust the container name and migration command to match your app.
#
# docker exec "${APP_NAME}" your-app migrate

# --- Notification via global helper (example) ---
# Reads NOTIFY_SLACK_WEBHOOK from the environment.
#
# . "$(dirname "$0")/../../../../core/global-hooks/notify.sh"
# notify_slack "Deploy complete: ${APP_NAME} at ${TIMESTAMP}"
