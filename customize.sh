#!/bin/bash
# Asterisk / AllStar customization script
# Run as root (or with sudo)

set -euo pipefail

CONF_DIR="/etc/asterisk"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Auto-detect node number from rpt.conf (first numeric stanza, excluding default 1999)
detect_node() {
    local nodes
    nodes=$(grep -oP '^\[\K[0-9]{4,6}(?=\])' "$CONF_DIR/rpt.conf" 2>/dev/null || echo "")
    echo "$nodes" | grep -v '^1999$' | head -1 || echo ""
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
        sed -i "s|^${key}\s*=.*|${key} = ${value}|" "$file"
    else
        sed -i "/^\[${section}\]/a ${key} = ${value}" "$file"
    fi
}

# Check whether the node stanza exists in a given file
node_stanza_exists() {
    grep -qE "^\[${NODE}\]" "$1"
}

# ---------------------------------------------------------------------------

echo "=== Checking node configuration ==="

NODE=$(detect_node)

if [ -z "$NODE" ] || ! node_stanza_exists "$CONF_DIR/simpleusb.conf" || ! node_stanza_exists "$CONF_DIR/rpt.conf"; then
    echo ""
    echo "  *****************************************************"
    echo "  *                                                   *"
    echo "  *      YOUR NODE HAS NOT BEEN SET UP YET           *"
    echo "  *                                                   *"
    echo "  *  Please run 'sudo asl-menu' to set up your node  *"
    echo "  *  and then re-run this script.                    *"
    echo "  *                                                   *"
    echo "  *****************************************************"
    echo ""
    exit 1
fi

echo "  Detected node: $NODE"

# ---------------------------------------------------------------------------

echo ""
echo "=== Backing up config files ==="

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.${TIMESTAMP}"
        echo "  Backed up $(basename "$file") → $(basename "$file").bak.${TIMESTAMP}"
    else
        echo "  NOTICE: $(basename "$file") not found, skipping backup"
    fi
}

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

# More steps to follow...
