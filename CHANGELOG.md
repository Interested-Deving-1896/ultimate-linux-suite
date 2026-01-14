# Changelog

All notable changes to Unified Linux Suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2026-01-14

### The Unified Release

**Major release merging Ultimate Linux Suite with OffTrack Suite** — combining system management, optimization, security tools, and hardware support into a single comprehensive platform.

### Added

#### New Entry Point
- **`unified.sh`** — New primary entry point with enhanced CLI
  - Full command structure: `unified.sh [OPTIONS] COMMAND [ARGS]`
  - Dry-run mode (`-n, --dry-run`) for previewing changes
  - Auto-confirm mode (`-y, --yes`) for scripting
  - Debug mode (`-d, --debug`) for troubleshooting
  - Quiet mode (`-q, --quiet`) for minimal output

#### Security Modules (`modules/security/`)
- **Firewall Manager** (`firewall.sh`) — Unified interface for ufw, firewalld, and iptables
  - Automatic detection of installed firewall
  - Common operations across all backends
  - Status, enable, disable, rule management
- **Encrypted Vault** (`vault.sh`) — LUKS-encrypted secure storage
  - Create, open, close vault operations
  - Status reporting
  - Secure key management
- **Security Lab Setup** (`lab_setup.sh`) — Isolated testing environment
  - Network isolation configuration
  - Snapshot management for experiments
- **KVM Setup** (`kvm_setup.sh`) — Virtualization for security testing
  - QEMU/KVM installation and configuration
  - libvirt integration
  - virt-manager setup
- **Malware Lab** (`malware_lab.sh`) — Malware analysis environment
  - Isolated VM configuration
  - Analysis tool setup
- **Windows VM** (`windows_vm.sh`) — Automated Windows deployment
  - Windows VM creation for testing
  - Driver and tool installation

#### Pentest Modules (`modules/pentest/`)
- **Tools Installer** (`tools_installer.sh`) — Bulk pentest tool installation
  - One-click installation of common tools
  - Progress tracking
  - Dependency management
- **Voidwave Integration** (`voidwave.sh`) — Wireless security tools
- **Individual Tool Installers** (`individual/`)
  - `metasploit.sh` — Metasploit Framework
  - `sqlmap.sh` — SQL injection automation
  - `nikto.sh` — Web server scanner
  - `wifite.sh` — Wireless attack automation
  - `exploitdb.sh` — Exploit database search

#### Optimization Modules (`modules/optimization/`)
- **RAM Optimizer** (`ram_optimizer.sh`)
  - Swappiness optimization based on RAM size
  - Cache pressure tuning
  - ZRAM configuration
  - Interactive wizard mode
- **CPU Optimizer** (`cpu_optimizer.sh`)
  - Governor selection (performance, powersave, schedutil)
  - P-State configuration
  - Boost control
  - Interactive wizard mode
- **Performance Profiles** (`profiles.sh`)
  - Gaming profile — Maximum performance
  - Server profile — Balanced for services
  - Laptop profile — Power efficiency
  - Desktop profile — General use
  - Balanced profile — Default

#### MacBook Support (`drivers/macbook/`)
- **MacBook Detection** (`lib/macbook_detect.sh`)
  - Automatic MacBook generation identification
  - Model-specific configuration
- **Audio Driver** (`audio_cirrus.sh`) — Cirrus Logic audio fix
  - MacBook Pro audio driver installation
  - ALSA configuration
- **WiFi Driver** (`wifi_broadcom.sh`) — Broadcom wireless
  - Broadcom WiFi configuration
  - Firmware management
- **SPI Driver** (`spi_driver.sh`) — Apple SPI keyboard/trackpad
  - Kernel module installation
  - DKMS configuration
- **Fix All** (`fix_all.sh`) — Run all MacBook fixes in sequence

#### Bootstrap & Installers (`modules/bootstrap/`, `modules/installers/`)
- **Bootstrap Wizard** (`bootstrap.sh`) — Full system bootstrap
  - System assessment
  - Optimization recommendations
  - Guided setup
- **Arch Guided** (`arch_guided.sh`) — Arch Linux installation helper
- **Mint Recovery** (`mint_recovery.sh`) — Linux Mint recovery tools
- **Parrot Lab** (`parrot_lab.sh`) — Parrot OS lab setup
- **Disk Partition** (`disk_partition.sh`) — Partitioning utilities

#### Application Management (`modules/apps/`)
- **App Installer** (`app_installer.sh`) — Category-based installation
  - Browser, development, gaming, media categories
  - Cross-distro package mapping
  - Cascade installation support

#### New Core Libraries (`lib/`)
- **Colors** (`colors.sh`) — Terminal color definitions (Dracula theme)
- **Config** (`config.sh`) — Configuration management
- **Core** (`core.sh`) — Core functions and utilities
- **Deps** (`deps.sh`) — Dependency management
- **Hardware** (`hardware.sh`) — Hardware detection utilities
- **Init** (`init.sh`) — Suite initialization
- **Monitor** (`monitor.sh`) — System monitoring functions
- **Optimization** (`optimization.sh`) — Optimization algorithms
- **Safety** (`safety.sh`) — Snapshot and rollback system

#### Utility Scripts (`scripts/`)
- **Askpass Setup** (`askpass_setup.sh`) — SSH askpass configuration
- **Update All** (`update-all.sh`) — System update script

#### Test Suite (`tests/`)
- **Run All Tests** (`run_all_tests.sh`) — Comprehensive test runner
- **Swappiness Test** (`test_swappiness.sh`) — Optimization validation

### Changed

- **Primary entry point** is now `unified.sh` (legacy `ultimate.sh` still works)
- **Project name** updated to "Unified Linux Suite"
- **Codename** is now "Sovereign Optimization Protocol"
- **License** remains MIT (unchanged)
- **README** completely rewritten for v4.0.0

### Enhanced

- **Main menu** expanded with security, pentest, and MacBook options
- **Logging** improved with additional levels and formatting
- **OS detection** enhanced with more distribution support
- **Package management** improved with better error handling
- **TUI** updated with additional dialog types

### Migration from v3.x

No breaking changes. All v3.x functionality preserved:
- `ultimate.sh` continues to work as before
- All existing commands and options unchanged
- Configuration files remain compatible

To use new features:
```bash
# New unified entry point (recommended)
./unified.sh

# Or continue using legacy entry point
./ultimate.sh
```

---

## [3.0.0] - 2024-12-22

### Added

#### Blueprint Implementation (Research-Backed Features)
- **Dracula Color Theme** - Optimized terminal color palette for readability
  - Purple (#bd93f9), Cyan (#8be9fd), Pink (#ff79c6), Green (#50fa7b), Red (#ff5555)
  - GUM environment variable exports for consistent theming
- **System Systemd Service** (`lib/systemd_service.sh`) - Multi-stage installation persistence
  - Oneshot service at `/etc/systemd/system/linux-suite.service`
  - State machine with retry limits (3 attempts per stage)
  - Boot ID tracking for reboot detection
  - Automatic cleanup after completion
- **Optimization Recommendations** - Scientific parameter selection
  - ZRAM sizing: `min(RAM/2, 8GB)`
  - Swappiness: RAM-based with ZRAM-aware values (100-180)
  - I/O schedulers: Device-type based (none/mq-deadline/bfq)
  - CPU governors: Form-factor based (performance/schedutil)
- **Profile Aliases** (`lib/profile_aliases.sh`) - Modern CLI tool aliases
  - System-wide installation to `/etc/profile.d/modern-cli.sh`
  - User-level installation to `~/.config/`
  - Transparent aliases: ls→eza, cat→bat, grep→rg, du→dust, top→btop
- **Hardware Profile Output** - JSON output with recommendations
  - `save_hardware_profile()` - Save to `/var/lib/linux-suite/hardware-profile.json`
  - Combined hardware scan with optimization recommendations
- **Navigation System** - Hierarchical menus with breadcrumbs
  - `nav_to()`, `nav_back()`, `nav_reset()` - Stack-based navigation
  - `nav_show_breadcrumb()` - Visual breadcrumb display
  - `nav_menu()` - Auto-navigation menus with back button
- **Local Testing** (`make test`)
  - Bash syntax checking for all scripts
  - Test framework in `tests/framework.sh`
- **Conditional State Paths** - Root vs user operation separation
  - Root: `/var/lib/linux-suite/` (system-level)
  - User: `~/.local/state/ultimate-suite/` (user-level)

#### First-Run Experience
- **First-Run Wizard** (`modules/first_run.sh`) - Automated multi-phase setup wizard
  - 11-phase execution flow with automatic progress tracking
  - Handles reboots and resumes automatically
  - Hardware scanning and optimization
  - Package manager installation (Flatpak, Snap, Nix)
  - Essential utility installation
  - Status checking and reset capabilities

#### Modern TUI System
- **TUI Abstraction Layer** (`lib/tui.sh`) - Modern terminal UI with multiple backends
  - Primary: gum (Charm.sh) for beautiful modern interfaces
  - Fallback chain: fzf → whiptail → dialog → basic
  - Menus, checklists, inputs, confirmations, spinners
  - Terminal-aware responsive layouts
  - Customizable color theming

- **Advanced TUI Components** (`lib/tui_advanced.sh`)
  - Complex wizard dialogs
  - Multi-select with search
  - Progress tracking UI
  - State management for dialogs

#### Cascade Installation System
- **Cascade Installer** (`lib/pkg_cascade.sh`) - Try all installation methods automatically
  - Automatic fallback: native → Flatpak → Snap → AppImage → source
  - Transaction logging with rollback support
  - Snapshot creation before major changes
  - AppImage management with desktop integration
  - Batch installation with detailed reporting
  - Pre-defined application database with multi-method support

#### Package Management Enhancements
- **Universal Package Managers** (`lib/pkg_universal.sh`)
  - Install/configure Flatpak with Flathub
  - Install/configure Snap with classic support
  - Install Nix Package Manager with flakes
  - Install Homebrew/Linuxbrew
  - AppImage support setup (AppImageLauncher/Gear Lever)
  - AUR helper installation (paru/yay)

- **AUR Support** (`lib/pkg_aur.sh`) - Complete Arch User Repository integration
  - Detect and use installed AUR helpers
  - Install AUR helpers from source
  - Package search, install, update, remove
  - PKGBUILD viewing and downloading
  - Orphan package management
  - Build configuration options

- **Package Verification** (`lib/pkg_verify.sh`)
  - Multi-method package verification (native, flatpak, snap, command)
  - Dependency checking and auto-install
  - Package manager health checks and repair
  - **Package Checkpoints** - Snapshot and rollback package state
  - Package diff and comparison tools
  - Package file listing and integrity verification
  - Package statistics

- **Utility Matrix** (`lib/utilities.sh`) - Modern CLI tool installation
  - Categorized utility definitions (download, compression, vcs, build, modern-cli, network, editors, shell, disk, monitoring, backup, media)
  - Multi-distro package name mappings (apt, dnf, pacman, zypper)
  - Cascade installation (native → cargo → pip → npm → go → binary)
  - Preset bundles: essential, developer, sysadmin, modern-cli, rust-tools
  - Installation history tracking

#### Hardware Detection & Optimization
- **Deep Hardware Scanning** (`lib/scan.sh`)
  - CPU detection with feature flags (AES, AVX, AVX2, SSE4.2)
  - CPU frequency and governor information
  - GPU vendor and model detection
  - RAM analysis with memory-based recommendations
  - Disk type detection (NVMe, SSD, HDD, VM)
  - Network interface enumeration
  - WiFi chipset identification with driver detection
  - Battery status and capacity
  - Chassis/form factor detection
  - JSON output for programmatic use

- **System Tuning Engine** (`lib/tune.sh`)
  - Automatic sysctl configuration generation
  - Hardware-aware parameter selection
  - Multiple profiles: minimal, balanced, performance, gaming, server
  - Memory, network, filesystem, and security tuning
  - Automatic backup before changes
  - Safe rollback capability
  - Parameter validation with timeout

- **ZRAM Configuration** (`lib/zram.sh`)
  - Automatic ZRAM size calculation based on RAM
  - Compression algorithm selection (zstd, lz4, lzo-rle, lzo)
  - systemd-zram-generator integration
  - Manual configuration fallback
  - ZRAM status and statistics

- **CPU Governor Management** (`lib/cpu_governor.sh`)
  - Intel P-State and AMD P-State support
  - Governor detection and configuration
  - Energy Performance Preference (EPP) support
  - Boost control
  - Persistence via systemd/TLP/cpufrequtils

- **I/O Scheduler Optimization** (`lib/io_scheduler.sh`)
  - Device type detection (NVMe, SSD, HDD, VM)
  - Optimal scheduler selection per device type
  - udev rules for persistence
  - Scheduler availability detection

#### State Management
- **State System** (`lib/state.sh`)
  - JSON-based state storage with jq
  - Atomic file operations with fsync
  - Process-safe locking with stale lock detection
  - Event history recording
  - Boot ID tracking for reboot detection

- **Advanced State** (`lib/state_advanced.sh`)
  - Checkpoint system for state snapshots
  - Phase transition management
  - Cross-reboot persistence

- **Autostart System** (`lib/autostart.sh`)
  - Systemd user service support
  - XDG autostart fallback
  - Boot ID tracking
  - Multi-phase resume capability
  - Linger support for background services
  - Resume script generation

#### Testing Framework
- **Test Framework** (`tests/framework.sh`)
  - 20+ assertion functions (equals, contains, matches, file_exists, command_exists, etc.)
  - Test discovery and execution
  - Setup/teardown hooks (per-test and per-suite)
  - Command mocking with restore
  - Test suite runner for directories
  - Verbose and quiet modes
  - Colored output with pass/fail/skip indicators

#### Error Handling
- **Error Handling** (`lib/error_handling.sh`)
  - Robust trap handlers for ERR signal
  - Error stack tracking
  - Critical section support
  - Automatic recovery attempts
  - Cleanup handlers
  - JSON error logging

### Changed

- **All modules now have fallback dependencies** - Modules can be sourced standalone without crashing
- **PKG_MANAGER auto-detection** - No longer requires os_detect.sh to be pre-loaded
- **Logging functions always available** - Fallback functions prevent undefined function errors
- **Improved cross-module compatibility** - Consistent dependency loading pattern across all modules
- **Graceful degradation** - Features work with reduced functionality when dependencies are missing

### Fixed

- Fixed `exit 1` on dependency failures - now uses graceful fallbacks
- Fixed undefined variable errors when modules sourced standalone
- Fixed logging function availability in all modules
- Fixed PKG_MANAGER detection when os_detect.sh not loaded
- Fixed hardware_detect.sh log_debug calls without logging.sh

### Documentation

- Completely rewritten README.md with v3.0 features
- Added comprehensive usage examples for all new modules
- Added module reference tables
- Added testing documentation
- Added development guidelines with dependency pattern
- Added CHANGELOG entries for all new features

---

## [2.3.0] - 2025-12-15

### Fixed
- Fixed unbound variable error in queue_execute() when called without arguments
- Script now properly handles `set -u` mode for queue execution after deb install

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
- **OS Detection** - Comprehensive system identification
- **Hardware Detection** - Complete hardware profiling

#### Application Installer
- 60+ applications with cross-distro package mapping
- Categories: Browsers, Development, Gaming, Media, Communication, Productivity, Utilities, Security
- Preset profiles: Workstation, Gaming, Developer, Pentest, Server, Minimal
- Flatpak integration with Flathub search

#### System Optimization
- Memory, I/O, Network, Power, and Desktop optimization
- Quick profiles: Desktop, Gaming, Laptop, Server

#### Driver Management
- NVIDIA, AMD, Intel drivers
- Broadcom and Realtek WiFi
- VM guest tools (VirtualBox, VMware, QEMU)

#### Recovery Tools
- Fix broken packages
- Clean caches
- Reset network and DNS
- Disk health checking

#### Distribution Packages
- `.deb` for Debian family
- `.rpm` for Fedora and openSUSE
- `.pkg.tar.zst` for Arch Linux

### Supported Distributions
- Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS, Zorin OS
- Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
- Arch Linux, Manjaro, EndeavourOS, Garuda, Artix
- openSUSE Leap, openSUSE Tumbleweed, SLES
- Kali Linux, Parrot OS

---

## Upgrade Guide

### From v2.x to v3.0

1. **Pull the latest version:**
   ```bash
   cd ultimate-linux-suite
   git pull origin main
   ```

2. **Run the first-run wizard (optional but recommended):**
   ```bash
   ./modules/first_run.sh
   ```

3. **Or continue using the main script:**
   ```bash
   sudo ./ultimate.sh
   ```

### New Optional Dependencies

For the best experience, install these optional tools:

```bash
# Modern TUI (highly recommended)
go install github.com/charmbracelet/gum@latest
# or: brew install gum

# Fuzzy finder (good fallback)
sudo apt install fzf  # Debian/Ubuntu
sudo dnf install fzf  # Fedora
sudo pacman -S fzf    # Arch

# JSON processing (for state management)
sudo apt install jq   # Debian/Ubuntu
sudo dnf install jq   # Fedora
sudo pacman -S jq     # Arch
```

### Breaking Changes

None. All v2.x functionality is preserved.
