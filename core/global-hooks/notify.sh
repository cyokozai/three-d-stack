#!/bin/sh
# notify.sh — reusable notification helper.
#
# Usage (source this file, then call notify_slack):
#   . ./core/global-hooks/notify.sh
#   notify_slack "Deploy complete: myapp at 2026-04-08T12:00:00"
#
# Required environment variable:
#   NOTIFY_SLACK_WEBHOOK — incoming webhook URL for your Slack channel

notify_slack() {
  MESSAGE="${1:?notify_slack requires a message as the first argument}"

  if [ -z "${NOTIFY_SLACK_WEBHOOK:-}" ]; then
    echo "[notify] NOTIFY_SLACK_WEBHOOK not set — skipping Slack notification"
    return 0
  fi

  # Escape MESSAGE to a valid JSON string (handles quotes, backslashes, newlines)
  ESCAPED=$(printf '%s' "${MESSAGE}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    --max-time 10 \
    -X POST "${NOTIFY_SLACK_WEBHOOK}" \
    -H "Content-Type: application/json" \
    --data "{\"text\": ${ESCAPED}}")

  if [ "${STATUS}" != "200" ]; then
    echo "[notify] WARNING: Slack webhook returned HTTP ${STATUS}" >&2
  fi
}
