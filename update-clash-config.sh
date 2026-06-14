#!/usr/bin/env bash
#
# update-clash-config.sh — Fetch Clash subscription and save as config.yaml
#
# Usage:
#   update-clash-config.sh [-c <conf>] [-u <url>] [-d <dir>] [--daemon]
#
# Configuration priority:
#   1. Command-line flags  (-u, -d, -c, --daemon)
#   2. Environment variables
#   3. Config file (default: /etc/clash-subscription/clash-subscription.conf)
#

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
DEFAULT_CONF="/etc/clash-subscription/clash-subscription.conf"
DEFAULT_URL=""
DEFAULT_OUTPUT_DIR="/etc/clash"
DEFAULT_UA="ClashForAndroid/3.0.8"
DEFAULT_INTERVAL=21600        # seconds (6 hours)
DEFAULT_LOG_FILE="/var/log/clash-subscription.log"
DEFAULT_RETRY=3
DEFAULT_RETRY_DELAY=5
DEFAULT_TIMEOUT=15

# ─── Resolve config file path ────────────────────────────────────────────────
CONF="${CLASH_CONF:-$DEFAULT_CONF}"

# Parse CLI flags before loading config, so -c can take effect early
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--conf)
      CONF="$2"; shift 2 ;;
    --daemon)
      DAEMON=1; shift ;;
    -u|--url)
      CLI_URL="$2"; shift 2 ;;
    -d|--output-dir)
      CLI_OUTPUT_DIR="$2"; shift 2 ;;
    --ua|--user-agent)
      CLI_UA="$2"; shift 2 ;;
    --interval)
      CLI_INTERVAL="$2"; shift 2 ;;
    --log-file)
      CLI_LOG_FILE="$2"; shift 2 ;;
    --retry)
      CLI_RETRY="$2"; shift 2 ;;
    --retry-delay)
      CLI_RETRY_DELAY="$2"; shift 2 ;;
    --timeout)
      CLI_TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-c <conf>] [-u <url>] [-d <dir>] [--daemon]"
      echo ""
      echo "Options:"
      echo "  -c, --conf FILE       Config file path (default: $DEFAULT_CONF)"
      echo "  -u, --url URL         Subscription URL (overrides config/env)"
      echo "  -d, --output-dir DIR  Output directory (overrides config/env)"
      echo "  --ua, --user-agent    User-Agent string for curl"
      echo "  --interval SECONDS    Poll interval for --daemon mode"
      echo "  --log-file FILE       Log file path"
      echo "  --retry N             Max retry attempts (default: $DEFAULT_RETRY)"
      echo "  --retry-delay SECONDS Retry interval (default: ${DEFAULT_RETRY_DELAY}s)"
      echo "  --timeout SECONDS     curl connect timeout (default: $DEFAULT_TIMEOUT)"
      echo "  --daemon              Run in continuous polling loop"
      echo "  -h, --help           Show this help"
      echo ""
      echo "Environment variables (override config file, overridden by flags):"
      echo "  CLASH_URL             Subscription URL"
      echo "  CLASH_OUTPUT_DIR      Output directory"
      echo "  CLASH_UA              User-Agent string"
      echo "  CLASH_INTERVAL        Daemon poll interval (seconds)"
      echo "  CLASH_LOG_FILE        Log file path"
      echo "  CLASH_RETRY           Max retry attempts"
      echo "  CLASH_RETRY_DELAY     Retry interval (seconds)"
      echo "  CLASH_TIMEOUT         curl connect timeout (seconds)"
      echo "  CLASH_CONF            Config file path"
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Load config file (if exists) ─────────────────────────────────────────────
if [[ -r "$CONF" ]]; then
  # shellcheck source=/dev/null
  source "$CONF"
fi

# ─── Final values: CLI > env > config file > defaults ─────────────────────────
SUBSCRIPTION_URL="${CLI_URL:-${CLASH_URL:-${SUBSCRIPTION_URL:-$DEFAULT_URL}}}"
OUTPUT_DIR="${CLI_OUTPUT_DIR:-${CLASH_OUTPUT_DIR:-${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}}}"
USER_AGENT="${CLI_UA:-${CLASH_UA:-${USER_AGENT:-$DEFAULT_UA}}}"
INTERVAL="${CLI_INTERVAL:-${CLASH_INTERVAL:-${INTERVAL:-$DEFAULT_INTERVAL}}}"
LOG_FILE="${CLI_LOG_FILE:-${CLASH_LOG_FILE:-${LOG_FILE:-$DEFAULT_LOG_FILE}}}"
RETRY="${CLI_RETRY:-${CLASH_RETRY:-${RETRY:-$DEFAULT_RETRY}}}"
RETRY_DELAY="${CLI_RETRY_DELAY:-${CLASH_RETRY_DELAY:-${RETRY_DELAY:-$DEFAULT_RETRY_DELAY}}}"
TIMEOUT="${CLI_TIMEOUT:-${CLASH_TIMEOUT:-${TIMEOUT:-$DEFAULT_TIMEOUT}}}"

# ─── Helpers ──────────────────────────────────────────────────────────────────

log() {
  local level="$1"; shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

validate_config() {
  local errors=0

  if [[ -z "$SUBSCRIPTION_URL" ]]; then
    echo "ERROR: SUBSCRIPTION_URL is not set." >&2
    echo "       Set it in $CONF, export CLASH_URL, or pass -u <url>" >&2
    ((errors++))
  fi

  if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is not installed." >&2
    ((errors++))
  fi

  # Validate URL format (basic)
  if [[ -n "$SUBSCRIPTION_URL" && ! "$SUBSCRIPTION_URL" =~ ^https?:// ]]; then
    echo "ERROR: SUBSCRIPTION_URL does not look like a valid HTTP(S) URL." >&2
    ((errors++))
  fi

  return "$errors"
}

fetch_and_save() {
  local url="$1"
  local outdir="$2"
  local output_file="${outdir}/config.yaml"
  local backup_file="${output_file}.bak"

  # Ensure output directory exists
  mkdir -p "$outdir"

  # Backup existing config
  if [[ -f "$output_file" ]]; then
    cp "$output_file" "$backup_file"
    log "OK" "Backed up existing config to $backup_file"
  fi

  local tmpfile
  tmpfile=$(mktemp /tmp/clash-config.XXXXXX)
  # Ensure cleanup on exit
  trap 'rm -f "$tmpfile"' RETURN

  local http_code
  local attempt=0
  local success=0

  while [[ $attempt -lt $RETRY ]]; do
    attempt=$((attempt + 1))

    http_code=$(curl --silent --location \
      --max-time "$((TIMEOUT * 2))" \
      --connect-timeout "$TIMEOUT" \
      --user-agent "$USER_AGENT" \
      --write-out '%{http_code}' \
      --output "$tmpfile" \
      "$url" 2>>"$LOG_FILE") || true

    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
      success=1
      break
    fi

    if [[ $attempt -lt $RETRY ]]; then
      log "WARN" "Attempt $attempt/$RETRY — HTTP $http_code, retrying in ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
    fi
  done

  if [[ $success -eq 0 ]]; then
    log "FAIL" "Failed to fetch subscription after $RETRY attempts (last HTTP ${http_code:-N/A})"
    echo "FAIL: fetch failed after $RETRY attempts" >&2
    return 1
  fi

  # Validate: file must be non-empty
  if [[ ! -s "$tmpfile" ]]; then
    log "FAIL" "Downloaded file is empty (HTTP $http_code)"
    echo "FAIL: empty response" >&2
    return 1
  fi

  # Validate: file must not be an HTML error page (common with CDN blocks)
  if grep -qiE '<!DOCTYPE|<html|<head|<body' "$tmpfile"; then
    log "FAIL" "Downloaded content appears to be HTML (proxy/CDN block page)"
    echo "FAIL: response is HTML, not YAML" >&2
    return 1
  fi

  # Save to final destination
  mv "$tmpfile" "$output_file"
  log "OK" "Subscription saved to $output_file (size: $(wc -c < "$output_file") bytes, HTTP $http_code)"
  echo "OK: config updated -> $output_file"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

if ! validate_config; then
  exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Diagnostic: show which config file was loaded and where output goes
echo "[Config] $CONF"
echo "[Output] $OUTPUT_DIR"
log "OK" "Config: $CONF, Output: $OUTPUT_DIR"

if [[ -n "${DAEMON:-}" ]]; then
  log "OK" "Starting daemon mode (interval: ${INTERVAL}s)"
  echo "Daemon mode — polling every ${INTERVAL}s, logging to $LOG_FILE"

  while true; do
    fetch_and_save "$SUBSCRIPTION_URL" "$OUTPUT_DIR"
    sleep "$INTERVAL"
  done
else
  fetch_and_save "$SUBSCRIPTION_URL" "$OUTPUT_DIR"
fi
