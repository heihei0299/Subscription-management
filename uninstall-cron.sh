#!/usr/bin/env bash
#
# uninstall-cron.sh — Remove the clash subscription cron job
#
set -euo pipefail

CRON_LABEL="# clash-subscription-updater"

existing=$(crontab -l 2>/dev/null || true)

if echo "$existing" | grep -qF "$CRON_LABEL"; then
  echo "$existing" | grep -vF "$CRON_LABEL" | crontab -
  echo "✓ Cron job removed."
else
  echo "No clash-subscription cron job found."
fi
