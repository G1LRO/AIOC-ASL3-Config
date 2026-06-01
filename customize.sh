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

# Helper: set a key=value within a specific node stanza in a config file.
# Only looks within the target stanza — ignores template sections.
# If the key exists in the stanza, replaces it. If absent, inserts after the stanza header.
set_conf() {
    local file="$1"
    local key="$2"
    local value="$3"
    local section="$4"

    # Check if key exists within the specific stanza (not the whole file)
    local in_stanza=0
    local found=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[${section}\] ]]; then
            in_stanza=1
        elif [[ "$line" =~ ^\[ ]]; then
            in_stanza=0
        fi
        if [[ $in_stanza -eq 1 ]] && [[ "$line" =~ ^${key}[[:space:]]*= ]]; then
            found=1
            break
        fi
    done < "$file"

    if [[ $found -eq 1 ]]; then
        # Key exists in stanza — replace it using awk scoped to the stanza
        awk -v section="$section" -v key="$key" -v value="$value" '
            /^\[/ { in_section = ($0 ~ "^\\[" section "\\]") }
            in_section && $0 ~ "^" key "[[:space:]]*=" { print key " = " value; next }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
        # Key absent in stanza — insert after the stanza header
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

echo ""
echo "=== Step 4: Restarting Asterisk to apply configuration ==="
systemctl restart asterisk
echo "Done — Asterisk restarted"

# More steps to follow...
