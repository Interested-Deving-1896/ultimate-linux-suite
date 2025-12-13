# NVIDIA Driver Installation Guide

## Automatic Detection

The Ultimate Linux Suite will detect your NVIDIA GPU automatically using `lspci`.

## Per-Distribution Installation

### Debian/Ubuntu/Mint

```bash
# Update packages
sudo apt update

# Install driver (auto-detect version)
sudo apt install nvidia-driver

# Or specific version
sudo apt install nvidia-driver-535
```

### Fedora

Requires RPM Fusion repository:
```bash
# Enable RPM Fusion
sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install NVIDIA driver
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia

# Wait for kernel module to build
sudo akmods --force
```

### Arch Linux

```bash
# Latest driver
sudo pacman -S nvidia nvidia-utils nvidia-settings

# For LTS kernel
sudo pacman -S nvidia-lts

# DKMS version (any kernel)
sudo pacman -S nvidia-dkms
```

### openSUSE

Use YaST Hardware > NVIDIA Configuration, or:
```bash
# Add NVIDIA repo and install
sudo zypper addrepo --refresh https://download.nvidia.com/opensuse/leap/15.5 nvidia
sudo zypper install nvidia-driver
```

## Post-Installation

1. Reboot your system
2. Verify installation: `nvidia-smi`
3. Configure with: `nvidia-settings`

## Troubleshooting

- **Black screen after install:** Boot with `nomodeset` kernel parameter, then reinstall
- **Driver not loading:** Check `/var/log/Xorg.0.log` for errors
- **Secure Boot issues:** Either disable Secure Boot or sign the kernel module

## Supported Cards

- GeForce RTX 40/30/20 series
- GeForce GTX 16/10 series
- Quadro/Tesla workstation cards

For legacy cards (older than GTX 600), use nvidia-390xx or nouveau open-source driver.
