# Intel Graphics Driver Guide

## Overview

Intel integrated graphics use the `i915` kernel driver, which is built into the Linux kernel.
Intel GPUs work out-of-the-box with no additional driver installation.

## Hardware Video Acceleration

For hardware video encoding/decoding:

### Debian/Ubuntu/Mint
```bash
sudo apt install intel-media-va-driver vainfo
# For older hardware (pre-Broadwell):
sudo apt install i965-va-driver
```

### Fedora
```bash
sudo dnf install intel-media-driver libva-intel-driver libva-utils
```

### Arch Linux
```bash
sudo pacman -S intel-media-driver libva-utils
# For older hardware:
sudo pacman -S libva-intel-driver
```

### openSUSE
```bash
sudo zypper install intel-media-driver
```

## Vulkan Support

### Debian/Ubuntu
```bash
sudo apt install mesa-vulkan-drivers
```

### Fedora
```bash
sudo dnf install mesa-vulkan-drivers vulkan-loader
```

### Arch
```bash
sudo pacman -S vulkan-intel
```

## Checking Installation

```bash
# Check VA-API
vainfo

# Check Vulkan
vulkaninfo | head -20

# Check driver
glxinfo | grep "OpenGL renderer"
```

## Power Management

Intel GPUs support power management through kernel parameters:
- `i915.enable_psr=1` - Panel Self Refresh (laptops)
- `i915.enable_fbc=1` - Framebuffer Compression

Add to GRUB_CMDLINE_LINUX in `/etc/default/grub`, then run `update-grub`.

## Supported Hardware

- Intel Arc (DG2)
- Intel Iris Xe (Gen12)
- Intel UHD Graphics (Gen9-11)
- Intel HD Graphics (Gen7-8)
