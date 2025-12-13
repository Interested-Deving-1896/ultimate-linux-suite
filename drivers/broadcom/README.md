# Broadcom WiFi Driver Guide

## Overview

Broadcom WiFi chipsets often require proprietary drivers not included in the Linux kernel.

## Identifying Your Chipset

```bash
lspci | grep -i broadcom
# or
lspci -nn | grep -i network
```

## Driver Options

### Option 1: broadcom-sta (wl driver)
Best for: BCM4311, BCM4312, BCM4313, BCM4321, BCM4322, BCM43224, BCM43225, BCM43227, BCM43228

### Option 2: b43 driver with firmware
Best for: BCM4306, BCM4311, BCM4318, BCM4320

### Option 3: brcmfmac (open source)
Best for: Newer chips (BCM43602, BCM4356, etc.)

## Installation

### Debian/Ubuntu/Mint (broadcom-sta)

```bash
sudo apt update
sudo apt install broadcom-sta-dkms

# If that fails, try:
sudo apt install bcmwl-kernel-source
```

### Debian/Ubuntu (b43 firmware)

```bash
sudo apt install firmware-b43-installer
```

### Fedora (requires RPM Fusion)

```bash
sudo dnf install broadcom-wl
```

### Arch Linux

```bash
# From AUR
yay -S broadcom-wl-dkms
```

## Post-Installation

```bash
# Unload conflicting modules
sudo modprobe -r b43 ssb bcma wl

# Load the correct driver
sudo modprobe wl  # for broadcom-sta
# or
sudo modprobe b43  # for b43 firmware

# Reboot for best results
sudo reboot
```

## Troubleshooting

- **No WiFi after install:** Check `dmesg | grep -i broad` for errors
- **Conflicts:** Ensure only ONE Broadcom driver is loaded
- **Secure Boot:** May need to sign DKMS modules or disable Secure Boot

## Blacklisting Conflicting Modules

Create `/etc/modprobe.d/broadcom.conf`:
```
blacklist b43
blacklist ssb
blacklist bcma
```

Or if using b43:
```
blacklist wl
```
