# AIOC-ASL3-Config

Customisation script to configure an [AIOC (All-In-One-Cable)](https://github.com/skuep/AIOC) USB device for use with [AllStarLink 3 (ASL3)](https://allstarlink.org/) / Asterisk.

## TL;DR

1. Complete node setup in `asl-menu`
2. Run:
```bash
wget https://raw.githubusercontent.com/G1LRO/AIOC-ASL3-Config/main/customize.sh
sudo bash customize.sh
```

---

## Overview

`customize.sh` automates the configuration changes required after a base ASL3 install to get the AIOC working as a half-duplex hotspot. **Run this script after completing node setup in `asl-menu`.** If run beforehand, the node configuration steps will be skipped with a clear message and no harm will be done — but you will need to run it again after `asl-menu` to apply them.

> ⚠️ **The script will error and exit if no node has been configured yet. Run `asl-menu` to set up your node before running this script.**

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

## Install and run

```bash
wget https://raw.githubusercontent.com/G1LRO/AIOC-ASL3-Config/main/customize.sh
sudo bash customize.sh
```

### Recommended workflow

```
sudo asl-menu              # Configure your node first
sudo bash customize.sh     # Then run this script
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
