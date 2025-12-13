# AMD GPU Driver Guide

## Overview

AMD GPUs use the open-source `amdgpu` kernel driver, which is included in the Linux kernel.
Most AMD GPUs work out-of-the-box with no additional driver installation.

## Enhancing Performance

### Mesa Vulkan Drivers

For gaming and GPU-accelerated applications, install Vulkan drivers:

#### Debian/Ubuntu/Mint
```bash
sudo apt install mesa-vulkan-drivers libvulkan1 vulkan-tools
```

#### Fedora
```bash
sudo dnf install mesa-vulkan-drivers vulkan-loader vulkan-tools
```

#### Arch Linux
```bash
sudo pacman -S mesa vulkan-radeon lib32-vulkan-radeon
```

#### openSUSE
```bash
sudo zypper install Mesa-vulkan-drivers
```

## Video Acceleration (VA-API)

For hardware video decoding:

#### Debian/Ubuntu
```bash
sudo apt install mesa-va-drivers vainfo
```

#### Fedora
```bash
sudo dnf install mesa-va-drivers libva-utils
```

#### Arch
```bash
sudo pacman -S libva-mesa-driver
```

## AMD PRO Driver (Optional)

For professional workloads, AMD provides a proprietary driver:
- Download from: https://www.amd.com/en/support

Note: The open-source driver is recommended for most users.

## Checking Installation

```bash
# Check Vulkan
vulkaninfo | head -20

# Check VA-API
vainfo

# Check driver in use
glxinfo | grep "OpenGL renderer"
```

## Supported Cards

- Radeon RX 7000/6000/5000 series
- Radeon RX Vega
- Radeon RX 500/400 series

Older cards use the `radeon` driver instead of `amdgpu`.
