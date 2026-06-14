#!/usr/bin/env bash
#
# install-cron.sh — Add a cron job for periodic clash config updates
#
# Reads the interval from /etc/clash-subscription/clash-subscription.conf (INTERVAL in seconds)
# and converts it to a cron expression. If the config doesn't exist,
# defaults to every 6 hours.
#
set -euo pipefail

CONF="/etc/clash-subscription/clash-subscription.conf"
SCRIPT="/etc/clash-subscription/update-clash-config"
CRON_LABEL="# clash-subscription-updater"

# --- Resolve interval ---
INTERVAL=21600  # default 6h
if [[ -r "$CONF" ]]; then
  # shellcheck source=/dev/null
  source "$CONF"
  # INTERVAL is already set from sourcing the config
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: $SCRIPT not found. Run install.sh first." >&2
  exit 1
fi

# Convert seconds to cron frequency
#   interval < 3600  → every N minutes
#   interval < 86400 → every N hours
#   otherwise        → daily at midnight
if [[ $INTERVAL -lt 3600 ]]; then
  minutes=$(( INTERVAL / 60 ))
  [[ $minutes -lt 1 ]] && minutes=1
  cron_expr="*/${minutes} * * * *"
  desc="every ${minutes} minute(s)"
elif [[ $INTERVAL -lt 86400 ]]; then
  hours=$(( INTERVAL / 3600 ))
  cron_expr="0 */${hours} * * *"
  desc="every ${hours} hour(s)"
else
  days=$(( INTERVAL / 86400 ))
  cron_expr="0 0 */${days} * *"
  desc="every ${days} day(s) at midnight"
fi

# --- Register cron job ---
cron_job="${cron_expr} ${SCRIPT} >/dev/null 2>&1"

# Get existing crontab (handle empty case)
existing=$(crontab -l 2>/dev/null || true)

if echo "$existing" | grep -qF "$CRON_LABEL"; then
  echo "Cron job already registered. Updating..."
  # Remove old entry, add new one
  echo "$existing" | grep -vF "$CRON_LABEL" | { cat; echo "$cron_job  $CRON_LABEL"; } | crontab -
else
  { echo "$existing"; echo "$cron_job  $CRON_LABEL"; } | crontab -
fi

echo "✓ Cron job installed: $cron_expr  $desc"
echo "  Job: $SCRIPT >/dev/null 2>&1"
echo ""
echo "To verify:  crontab -l | grep clash"
echo "To remove:  sudo ./uninstall-cron.sh"
