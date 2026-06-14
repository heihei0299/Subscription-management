#!/usr/bin/env bash
#
# uninstall.sh — Remove clash-subscription-updater from the system
#
# Usage:
#   sudo ./uninstall.sh
#   sudo ./uninstall.sh -c /etc/clash-subscription.conf   # specify config path
#
set -euo pipefail

SCRIPT_DST="/usr/local/bin/update-clash-config"
CONF_DST="/etc/clash-subscription.conf"
OUTPUT_DIR="/etc/clash"
LOG_FILE="/var/log/clash-subscription.log"

# Parse CLI flags for custom config
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--conf) CONF_DST="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-c <conf>]"
      echo ""
      echo "Remove clash-subscription-updater and optionally its data."
      echo "Options:"
      echo "  -c, --conf FILE   Config file path (default: $CONF_DST)"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────

removed=0
skipped=0

mark_removed() {
  echo "  [REMOVED] $1"
  ((removed++)) || true
}

mark_skipped() {
  echo "  [SKIP] $1 — $2"
  ((skipped++)) || true
}

confirm() {
  local prompt="$1"
  read -r -p "  $prompt (y/N): " ans
  [[ "$ans" =~ ^[Yy] ]]
}

# ─── Load config to discover data paths ───────────────────────────────────────

if [[ -r "$CONF_DST" ]]; then
  # shellcheck source=/dev/null
  source "$CONF_DST"
  echo "Loaded config: $CONF_DST"
else
  echo "Config not found at $CONF_DST — using defaults for data paths."
fi

echo ""
echo "=== Clash Subscription Updater — Uninstall ==="
echo ""

# ─── Step 1: Remove cron job ─────────────────────────────────────────────────

echo "[1/4] Cron job..."
if [[ -f "./uninstall-cron.sh" ]]; then
  if crontab -l 2>/dev/null | grep -qF "# clash-subscription-updater"; then
    if confirm "Cron job found. Remove it?"; then
      if bash "./uninstall-cron.sh"; then
        mark_removed "cron job"
      else
        mark_skipped "cron job" "removal failed"
      fi
    else
      mark_skipped "cron job" "kept by request"
    fi
  else
    echo "  • No cron job found."
    mark_skipped "cron job" "not present"
  fi
else
  echo "  • uninstall-cron.sh not found in current directory."
  mark_skipped "cron job" "helper script missing"
fi

# ─── Step 2: Remove main script ──────────────────────────────────────────────

echo "[2/4] Main script ($SCRIPT_DST)..."
if [[ -f "$SCRIPT_DST" ]]; then
  rm -f "$SCRIPT_DST"
  mark_removed "$SCRIPT_DST"
else
  mark_skipped "$SCRIPT_DST" "not found"
fi

# ─── Step 3: Remove config file ──────────────────────────────────────────────

echo "[3/4] Config file ($CONF_DST)..."
if [[ -f "$CONF_DST" ]]; then
  if confirm "Remove $CONF_DST?"; then
    rm -f "$CONF_DST"
    mark_removed "$CONF_DST"
  else
    mark_skipped "$CONF_DST" "kept by request"
  fi
else
  mark_skipped "$CONF_DST" "not found"
fi

# ─── Step 4: Remove data (subscription config + log) ─────────────────────────

echo "[4/4] Data files..."
config_file="${OUTPUT_DIR}/config.yaml"
backup_file="${OUTPUT_DIR}/config.yaml.bak"

if [[ -f "$config_file" || -f "$backup_file" ]]; then
  if confirm "Remove downloaded config files?"; then
    [[ -f "$config_file" ]] && { rm -f "$config_file"; mark_removed "$config_file"; }
    [[ -f "$backup_file" ]] && { rm -f "$backup_file"; mark_removed "$backup_file"; }
    # Remove output directory if empty
    if [[ -d "$OUTPUT_DIR" ]] && [[ -z "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]]; then
      rmdir "$OUTPUT_DIR" 2>/dev/null && mark_removed "${OUTPUT_DIR}/"
    fi
  else
    mark_skipped "config files in $OUTPUT_DIR" "kept by request"
  fi
else
  echo "  • No config files in $OUTPUT_DIR."
  mark_skipped "config files" "not found"
fi

if [[ -f "$LOG_FILE" ]]; then
  if confirm "Remove log file ($LOG_FILE)?"; then
    rm -f "$LOG_FILE"
    mark_removed "$LOG_FILE"
  else
    mark_skipped "$LOG_FILE" "kept by request"
  fi
else
  mark_skipped "$LOG_FILE" "not found"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Done: $removed removed, $skipped skipped ==="
