# Realtek RTL8152/RTL8153 USB Ethernet Driver

## Overview

The RTL8152/RTL8153 is a common USB 2.0/3.0 Gigabit Ethernet adapter.
Modern kernels (4.0+) include the `r8152` driver.

## Checking if Driver is Loaded

```bash
# Check for device
lsusb | grep -i realtek

# Check driver
lsmod | grep r8152

# Check dmesg
dmesg | grep r8152
```

## Installation (if not working)

Usually no installation is needed, but if the adapter isn't working:

### Update Firmware

Some adapters need firmware:

```bash
# Debian/Ubuntu
sudo apt install linux-firmware

# Fedora
sudo dnf install linux-firmware

# Arch
sudo pacman -S linux-firmware
```

### Force Module Load

```bash
sudo modprobe r8152
```

### Check Network Manager

```bash
nmcli device status
```

## Manual Driver Installation

If the built-in driver doesn't work, compile from Realtek source:

```bash
# Install build tools
sudo apt install build-essential linux-headers-$(uname -r)

# Download from Realtek website
# Extract and compile
make clean
make
sudo make install

# Load new module
sudo modprobe r8152
```

## Supported Devices

- RTL8152 (USB 2.0 100Mbps)
- RTL8153 (USB 3.0 Gigabit)
- RTL8153A/B (USB 3.0 Gigabit variants)
- RTL8156 (USB 3.0 2.5Gbps)

## Troubleshooting

- **No connection:** Try different USB port (prefer USB 3.0 for RTL8153)
- **Intermittent connection:** Check USB cable quality
- **Slow speeds:** Ensure using USB 3.0 port for gigabit speeds
