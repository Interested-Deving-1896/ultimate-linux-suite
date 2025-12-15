# Changelog

All notable changes to Ultimate Linux Suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2025-12-15

### Added
- GitHub Actions CI/CD pipeline for all package formats
- Automated builds for Debian, Fedora, openSUSE, and Arch Linux
- Multi-distro testing in CI (Debian, Fedora, Arch, openSUSE, Alpine)
- ShellCheck linting in CI

### Fixed
- All package versions synchronized to 2.2.0
- Version string now correctly displays in application

## [2.1.0] - 2025-12-15

### Fixed
- Version string display fix

## [2.0.0] - 2025-12-15

### Added
- **Queue System** - Stage operations before execution for review
  - Queue packages for install/remove
  - Queue sysctl settings
  - Queue service actions
  - Queue arbitrary commands
  - Review, modify, and execute queued operations
- **Application Database** - Comprehensive cross-distro package mapping
  - 60+ applications with APT, DNF, Pacman, Zypper, and Flatpak mappings
  - Categories: Browsers, Development, Gaming, Media, Communication, Productivity, Utilities
  - Automatic package name translation across distributions
- **Enhanced Hardware Detection**
  - WiFi chipset detection (Intel, Broadcom, Realtek, Atheros, MediaTek)
  - WiFi driver identification
  - Battery detection for laptops
  - Form factor detection (desktop/laptop)
  - CPU vendor and flags detection
  - Available RAM tracking
  - Filesystem type detection
- **Enhanced OS Detection**
  - Init system detection (systemd, openrc, sysvinit, runit)
  - Desktop environment detection
  - Display server detection (X11/Wayland)
- **Debian Packaging Compliance**
  - Full manpage for /usr/bin/ultimate-linux-suite
  - Lintian clean (0 errors, 0 warnings)
  - Removed essential package dependencies
  - Added debian/watch for upstream monitoring

### Fixed
- Silent failures on Debian-based distros (Kali, Ubuntu, Parrot)
- Package and repo structure sync issues
- Proper debian packaging with correct file paths

### Changed
- Restructured codebase to match packaged version
- Improved module initialization error handling

## [1.0.0] - 2024-12-14

### Added

#### Core Features
- **Queue System** - All operations are staged for review before execution
  - Package installations queued with descriptions
  - System commands queued with previews
  - Execute all, clear, or remove individual items
- **OS Detection** - Comprehensive system identification
  - Distribution and version detection
  - Package manager detection (apt, dnf, pacman, zypper)
  - Init system detection (systemd, openrc, sysvinit, runit)
  - Desktop environment detection (GNOME, KDE, XFCE, etc.)
  - Session type detection (Wayland, X11, TTY)
- **Hardware Detection** - Complete hardware profiling
  - CPU vendor, model, cores, and feature flags
  - GPU vendor and model (NVIDIA, AMD, Intel)
  - WiFi chipset detection (Intel, Broadcom, Realtek, Atheros)
  - Battery status for laptops
  - Form factor detection (desktop, laptop, VM)

#### Application Installer
- 60+ applications with cross-distro package mapping
- Categories: Browsers, Development, Gaming, Media, Communication, Productivity, Utilities, Security
- Preset profiles: Workstation, Gaming, Developer, Pentest, Server, Minimal
- Flatpak integration with Flathub search
- Package format: `APP|CATEGORY|DESC|APT|DNF|PACMAN|ZYPPER|FLATPAK|CHECK_CMD`

#### System Optimization
- **Memory**: Swappiness, VFS cache pressure, ZRAM, Transparent Huge Pages
- **I/O**: Scheduler selection (mq-deadline, bfq, kyber, none)
- **Network**: BBR congestion control, TCP buffer tuning, IPv6 toggle, DNS caching
- **Power**: CPU governor, laptop mode
- **Desktop**: Compositor tweaks, animation settings
- Quick profiles: Desktop, Gaming, Laptop, Server

#### Driver Management
- NVIDIA proprietary driver installation
- AMD mesa/Vulkan drivers
- Intel media drivers
- Broadcom WiFi (broadcom-sta, b43)
- Realtek WiFi guidance
- VirtualBox Guest Additions
- VMware Tools (open-vm-tools)
- QEMU Guest Agent
- DKMS support and module rebuild

#### Recovery Tools
- Fix broken packages (dpkg --configure, apt -f install, etc.)
- Clean package cache
- Remove orphan packages
- Clear temporary files (/tmp, /var/tmp, ~/.cache)
- Rebuild initramfs
- Update GRUB bootloader
- Reset network (NetworkManager, systemd-networkd)
- Reset DNS (Cloudflare, Google, Quad9, DHCP restore)
- Check disk health (SMART)
- Schedule filesystem check
- View journal errors
- Backup installed package list

#### Distribution Packages
- `.deb` for Debian, Ubuntu, Linux Mint, Kali, Parrot OS
- `.rpm` for Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
- `.rpm` for openSUSE Leap/Tumbleweed
- `.pkg.tar.zst` for Arch Linux (+ AUR -git version)
- Makefile with install/uninstall/test targets
- Build scripts for all formats

### Supported Distributions
- **Debian Family**: Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS, Zorin OS
- **Fedora Family**: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
- **Arch Family**: Arch Linux, Manjaro, EndeavourOS, Garuda, Artix
- **openSUSE Family**: openSUSE Leap, openSUSE Tumbleweed, SLES
- **Security**: Kali Linux, Parrot OS
- **Generic**: Fallback for unknown distributions

### Technical Details
- Pure Bash implementation (requires Bash 4.0+)
- Modular architecture: lib/, modules/, menus/, backends/, apps/
- Source guards prevent multiple inclusion
- Safe error handling (no aggressive `set -e`)
- File logging to /var/log/ultimate-linux-suite/ or ~/.ultimate-linux-suite/logs/
- Non-interactive mode for CI/testing

### Usage
```bash
# Clone and run
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo ./ultimate.sh

# Or install system-wide
sudo make install
ultimate-linux-suite
```

## [Unreleased]

### Planned
- System backup and restore
- Firewall management (ufw, firewalld)
- Service management module
- Theme and appearance settings
- Snap integration
- AUR helper installation (yay/paru)
