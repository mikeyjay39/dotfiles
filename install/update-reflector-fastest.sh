#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/xdg/reflector/reflector.conf"
SAVE_PATH="/etc/pacman.d/mirrorlist"
PROTOCOL="https"
FASTEST_COUNT="${1:-20}"

if ! [[ "$FASTEST_COUNT" =~ ^[0-9]+$ ]] || [ "$FASTEST_COUNT" -le 0 ]; then
  echo "Usage: $0 [positive-fastest-count]" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${CONFIG_FILE}.bak.${TIMESTAMP}"
cp "$CONFIG_FILE" "$BACKUP_FILE"

echo "Backup created: $BACKUP_FILE"

TMP_FILE="$(mktemp)"
cat > "$TMP_FILE" <<CONFIG
# Reflector configuration file for the systemd service.
# Updated by update-reflector-fastest.sh on ${TIMESTAMP}.
--save ${SAVE_PATH}
--protocol ${PROTOCOL}
--fastest ${FASTEST_COUNT}
--sort rate
CONFIG

install -m 0644 "$TMP_FILE" "$CONFIG_FILE"
rm -f "$TMP_FILE"

echo "Updated $CONFIG_FILE"
echo "New settings: --protocol ${PROTOCOL} --fastest ${FASTEST_COUNT} --sort rate"
