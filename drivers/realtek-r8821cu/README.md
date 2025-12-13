# Realtek RTL8821CU WiFi Driver

## Overview

The RTL8821CU is a USB WiFi adapter that supports 802.11ac (WiFi 5).
This chipset requires out-of-tree drivers on most Linux distributions.

## Checking Your Device

```bash
lsusb | grep -i realtek
# Look for: 0bda:c811 or similar
```

## Driver Installation

### Option 1: DKMS Package (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install realtek-rtl88xxau-dkms
```

Note: This package may not include RTL8821CU specifically.

### Option 2: Community Driver (Recommended)

The best driver is maintained by the community:

```bash
# Install dependencies
sudo apt install build-essential dkms git linux-headers-$(uname -r)

# Clone driver
git clone https://github.com/morrownr/8821cu-20210916.git
cd 8821cu-20210916

# Install
sudo ./install-driver.sh
```

For other distributions, adjust the package names for build tools.

### Option 3: lwfinger Drivers

Another community source:
```bash
git clone https://github.com/lwfinger/rtl8821cu.git
cd rtl8821cu
make
sudo make install
sudo modprobe 8821cu
```

## Post-Installation

```bash
# Reboot
sudo reboot

# Verify
lsmod | grep 8821cu
iwconfig
```

## Monitor Mode (for security testing)

```bash
# Put interface in monitor mode
sudo ip link set wlan0 down
sudo iw wlan0 set monitor control
sudo ip link set wlan0 up
```

Note: Monitor mode support depends on driver version.

## Troubleshooting

- **Driver not loading:** Check `dmesg | tail -50` for errors
- **Compilation errors:** Ensure correct kernel headers installed
- **No networks visible:** Try `sudo systemctl restart NetworkManager`
- **Kernel updates:** Reinstall driver after kernel updates (DKMS should handle this)

## Supported Chipsets

- RTL8821CU
- RTL8811CU
- RTL8731AU

## Resources

- morrownr's drivers: https://github.com/morrownr/8821cu-20210916
- lwfinger's drivers: https://github.com/lwfinger/rtl8821cu
