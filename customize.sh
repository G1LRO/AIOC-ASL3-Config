#!/bin/bash
# Asterisk / AllStar customization script
# Run as root (or with sudo)

set -euo pipefail

CONF_DIR="/etc/asterisk"
NODE="58175"   # Your AllStar node number
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Helper: back up a file with a timestamp suffix
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.${TIMESTAMP}"
        echo "  Backed up $(basename "$file") → $(basename "$file").bak.${TIMESTAMP}"
    else
        echo "  NOTICE: $(basename "$file") not found, skipping backup"
    fi
}

# Helper: set a key=value within a node's stanza in a config file.
# If the key already exists (anywhere in the file), replaces it.
# If the key is absent, inserts it on the line after the stanza header.
set_conf() {
    local file="$1"
    local key="$2"
    local value="$3"
    local section="$4"

    if grep -qE "^${key}\s*=" "$file"; then
        # Key exists — replace it
        sed -i "s|^${key}\s*=.*|${key} = ${value}|" "$file"
    else
        # Key absent — insert after the stanza header
        sed -i "/^\[${section}\]/a ${key} = ${value}" "$file"
    fi
}

# Check whether the node stanza exists in a given file
node_stanza_exists() {
    grep -qE "^\[${NODE}\]" "$1"
}

# ---------------------------------------------------------------------------

echo "=== Backing up config files ==="

backup_file "$CONF_DIR/res_usbradio.conf"
backup_file "$CONF_DIR/simpleusb.conf"
backup_file "$CONF_DIR/rpt.conf"

# ---------------------------------------------------------------------------

echo ""
echo "=== Step 1: Enable AIOC USB device in res_usbradio.conf ==="

FILE="$CONF_DIR/res_usbradio.conf"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found" >&2
    exit 1
fi

# Uncomment the usb_devices line (remove leading semicolon + optional space)
sed -i 's/^;usb_devices/usb_devices/' "$FILE"

echo "Done — usb_devices line uncommented in $FILE"

# ---------------------------------------------------------------------------

echo ""
echo "=== Step 2: Restart Asterisk to recognize the AIOC USB device ==="

systemctl restart asterisk

echo "Done — Asterisk restarted"

# ---------------------------------------------------------------------------

echo ""
echo "=== Step 3: Configure simpleusb.conf and rpt.conf for AIOC hotspot ==="

SIMPLEUSB="$CONF_DIR/simpleusb.conf"
RPTCONF="$CONF_DIR/rpt.conf"

if [ ! -f "$SIMPLEUSB" ] || [ ! -f "$RPTCONF" ]; then
    echo "SKIPPED — simpleusb.conf or rpt.conf not found yet."
    echo "          Re-run this script after completing node setup in asl-menu."
elif ! node_stanza_exists "$SIMPLEUSB" || ! node_stanza_exists "$RPTCONF"; then
    echo "SKIPPED — Node [${NODE}] stanza not found in one or both config files."
    echo "          Re-run this script after completing node setup in asl-menu."
else
    # PTT = ground (invertptt = no)
    set_conf "$SIMPLEUSB" "invertptt" "no" "${NODE}"
    echo "  invertptt set to 'no' (ground to transmit)"

    # Carrier from = usbinvert
    set_conf "$SIMPLEUSB" "carrierfrom" "usbinvert" "${NODE}"
    echo "  carrierfrom set to 'usbinvert'"

    # CTCSS from = no (hotspot, no external CTCSS)
    set_conf "$SIMPLEUSB" "ctcssfrom" "no" "${NODE}"
    echo "  ctcssfrom set to 'no'"

    # Duplex = 1 — half duplex with telemetry (hotspot mode)
    set_conf "$RPTCONF" "duplex" "1" "${NODE}"
    echo "  duplex set to '1' in rpt.conf"

    echo "Done — simpleusb.conf and rpt.conf updated"
fi

# More steps to follow...
