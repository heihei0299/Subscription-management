#!/usr/bin/env bash
#
# install.sh — Install update-clash-config.sh and its config
#
set -euo pipefail

SCRIPT_SRC="./update-clash-config.sh"
CONF_SRC="./clash-subscription.conf"
SCRIPT_DST="/etc/clash-subscription/update-clash-config"
CONF_DST="/etc/clash-subscription/clash-subscription.conf"

echo "=== Clash Subscription Updater — Install ==="
echo ""

# Check source files exist
if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "ERROR: $SCRIPT_SRC not found in current directory." >&2
  exit 1
fi

# --- Install main script ---
echo "[1/3] Installing script to $SCRIPT_DST ..."
mkdir -p "$(dirname "$SCRIPT_DST")"
cp "$SCRIPT_SRC" "$SCRIPT_DST"
chmod 755 "$SCRIPT_DST"
echo "  ✓ $SCRIPT_DST"

# --- Install config (never overwrite existing) ---
echo "[2/3] Installing config to $CONF_DST ..."
if [[ -f "$CONF_DST" ]]; then
  echo "  • $CONF_DST already exists — skipped (not overwritten)"
  echo "  • Edit it directly or use: sudo nano $CONF_DST"
else
  if [[ -f "$CONF_SRC" ]]; then
    cp "$CONF_SRC" "$CONF_DST"
    chmod 644 "$CONF_DST"
    echo "  ✓ $CONF_DST"
    echo "  • Don't forget to edit it and set SUBSCRIPTION_URL"
  else
    echo "  • $CONF_SRC not found — skipping config install"
  fi
fi

# --- Optional cron setup ---
echo "[3/3] Cron setup..."
if [[ -f "./install-cron.sh" ]]; then
  read -r -p "  Register a cron job for periodic updates? (y/N): " ans
  if [[ "$ans" =~ ^[Yy] ]]; then
    bash "./install-cron.sh" || echo "  ⚠ cron setup failed, continuing..."
  else
    echo "  • Skipped. Run 'sudo ./install-cron.sh' later if needed."
  fi
else
  echo "  • install-cron.sh not found — skipping."
fi

echo ""
echo "=== Install complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit $CONF_DST and set SUBSCRIPTION_URL"
echo "     (if you modify the project-local clash-subscription.conf instead,"
echo "      copy it to $CONF_DST or use: sudo bash /etc/clash-subscription/update-clash-config -c ./clash-subscription.conf)"
echo "  2. Run: sudo bash /etc/clash-subscription/update-clash-config"
echo "  3. Verify: cat $(grep '^OUTPUT_DIR=' "$CONF_DST" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"'"'" || echo '/etc/clash')/config.yaml"
echo ""
