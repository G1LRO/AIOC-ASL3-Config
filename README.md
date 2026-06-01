# AIOC-ASL3-Config

Customisation script to configure an [AIOC (All-In-One-Cable)](https://github.com/skuep/AIOC) USB device for use with [AllStarLink 3 (ASL3)](https://allstarlink.org/) / Asterisk.

## Overview

`customize.sh` automates the configuration changes required after a base ASL3 install to get the AIOC working as a half-duplex hotspot. It is safe to run both **before** and **after** running the node setup wizard in `asl-menu` — steps that depend on the node being configured will be skipped with a clear message if the node stanza is not yet present.

## What the script does

| Step | File | Change |
|------|------|--------|
| 1 | `/etc/asterisk/res_usbradio.conf` | Uncomments `usb_devices = 1209:7388` to allow the AIOC USB device |
| 2 | systemd | Restarts Asterisk so it recognises the AIOC |
| 3 | `/etc/asterisk/simpleusb.conf` | Sets `invertptt = no`, `carrierfrom = usbinvert`, `ctcssfrom = no` |
| 3 | `/etc/asterisk/rpt.conf` | Sets `duplex = 1` (half duplex with telemetry — hotspot mode) |

A timestamped backup of each config file is created at the start of every run, e.g.:

```
/etc/asterisk/res_usbradio.conf.bak.20260601_120000
```

## Requirements

- AllStarLink 3 / Asterisk installed
- AIOC USB device
- Run as root (or with `sudo`)

## Usage

### 1. Download the script

```bash
wget https://raw.githubusercontent.com/G1LRO/AIOC-ASL3-Config/main/customize.sh
```

### 2. Set your node number

Edit the `NODE` variable near the top of the script:

```bash
NODE="58175"   # Your AllStar node number
```

### 3. Make it executable

```bash
chmod +x customize.sh
```

### 4. Run it

```bash
sudo ./customize.sh
```

### Recommended workflow

```
sudo ./customize.sh        # Run before node setup — steps 1 & 2 apply
sudo asl-menu              # Configure your node
sudo ./customize.sh        # Run again — step 3 now applies
```

## AIOC USB identifiers

| Field | Value |
|-------|-------|
| Vendor ID | `1209` |
| Product ID | `7388` |

## Hotspot configuration summary

| Setting | Value | Notes |
|---------|-------|-------|
| `duplex` | `1` | Half duplex with telemetry |
| `invertptt` | `no` | Ground to transmit |
| `carrierfrom` | `usbinvert` | COR from USB, active low |
| `ctcssfrom` | `no` | No external CTCSS |

## References

- [AIOC project](https://github.com/skuep/AIOC)
- [AllStarLink documentation](https://allstarlink.github.io/)
- [simpleusb.conf reference](https://allstarlink.github.io/config/simpleusb_conf/)
