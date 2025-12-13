# Changelog

All notable changes to Ultimate Linux Suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-11

### Added
- Initial release of Ultimate Linux Suite
- **OS Detection** - Automatic distribution detection with support for:
  - Arch Linux, Manjaro, EndeavourOS, Garuda
  - Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS, Zorin OS
  - Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
  - openSUSE Leap, openSUSE Tumbleweed, SLES
  - Kali Linux
  - Parrot OS
  - Generic fallback for unknown distros
- **Hardware Detection** - CPU, GPU, RAM, and disk detection
- **Applications Module** - Install software by category or preset profile:
  - Categories: Essentials, Development, Multimedia, Gaming, Security, Office, Browsers, Utilities
  - Presets: Workstation, Gaming, Developer, Pentest, Server, Minimal
- **Drivers Module** - GPU and WiFi driver management:
  - NVIDIA driver detection and installation
  - AMD mesa/vulkan driver support
  - Intel graphics driver support
  - Broadcom WiFi driver support
  - Realtek WiFi driver guidance
  - DKMS installation and rebuild
- **Optimization Module** - System performance tuning:
  - Quick profiles: Desktop, Gaming, Laptop, Server
  - Manual tuning: Swappiness, VFS cache, I/O scheduler, CPU governor
  - Persistent sysctl configuration
- **Recovery Module** - System repair tools:
  - Fix broken packages
  - Clean package cache
  - Rebuild initramfs
  - Update GRUB bootloader
  - Network reset
  - Disk health check (SMART)
  - Filesystem check scheduling
  - Journal error viewer
  - Package list backup
- **Profile Setup** - Guided system setup wizard
- **Distro Backends** - Per-distribution package name mappings and special handling
- **File Logging** - Session logging to /var/log/ultimate-linux-suite/ or ~/.ultimate-linux-suite/logs/
- **Helper Functions** - Comprehensive utility library with uls_ prefixed functions

### Technical Details
- Pure Bash implementation (requires Bash 4.0+)
- No external dependencies for core functionality
- Modular architecture with separate lib/, modules/, menus/, backends/ directories
- Safe error handling without aggressive `set -e`
- Non-interactive mode for CI testing (--non-interactive flag)

### Notes
- This is a clone-and-run toolkit - no build steps required
- Packaging (.deb/.rpm) is NOT required for normal usage
- Run with `sudo ./suite.sh` for full functionality

## [Unreleased]

### Planned
- Flatpak/Snap integration
- System backup and restore
- Network configuration module
- Firewall management
- Service management module
- Theme and appearance settings
