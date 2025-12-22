# Ultimate Linux Suite

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-orange.svg)](https://kernel.org)

A comprehensive, multi-distribution Linux system management toolkit. One script to rule them all.

## What's New in v3.0

### Core Improvements
- **First-Run Wizard** - Automated setup with multi-phase execution and reboot handling
- **Modern TUI** - Beautiful Dracula-themed interface using gum/fzf with fallback to whiptail/dialog
- **Cascade Installation** - Try native → Flatpak → Snap → AppImage automatically
- **Smart Hardware Detection** - Deep system profiling with JSON output and optimization recommendations

### System Optimization
- **System Tuning Engine** - Auto-optimized sysctl based on your hardware
- **Blueprint Algorithms** - Scientific parameter selection (ZRAM sizing, swappiness, I/O schedulers)
- **Multi-Stage Installation** - System-level systemd service for installations that survive reboots

### Developer Experience
- **Package Checkpoints** - Snapshot and rollback your package state
- **Utility Matrix** - Install modern CLI tools (ripgrep, bat, eza, etc.) easily
- **Profile Aliases** - Automatic shell aliases for modern CLI tools in `/etc/profile.d/`
- **Testing Framework** - Built-in test suite
- **Navigation System** - Hierarchical menus with breadcrumb navigation

## Quick Start

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo ./ultimate.sh
```

**That's it.** Clone and run - no build steps required.

### First-Run Experience

New installations can use the automated first-run wizard:

```bash
./modules/first_run.sh
```

This wizard will:
1. Scan your hardware
2. Apply system optimizations
3. Install package managers (Flatpak, Snap, Nix)
4. Install essential utilities
5. Handle reboots and resume automatically

## Key Features

### Core Features
- **Queue-Based Operations** - Review all changes before execution
- **Multi-Distro Support** - Works on 20+ distributions
- **60+ Applications** - Curated app database with cross-distro package mapping
- **Cascade Installation** - Automatically tries multiple install methods

### System Management
- **System Optimization** - ZRAM, swappiness, I/O schedulers, CPU governors
- **Driver Management** - NVIDIA, AMD, Intel, Broadcom WiFi, VM guest tools
- **Service Management** - Start, stop, enable, disable services (systemd/OpenRC)
- **Firewall Management** - Unified interface for ufw, firewalld, and iptables

### Recovery & Maintenance
- **Package Checkpoints** - Save and restore package state
- **Recovery Tools** - DNS reset, orphan cleanup, package repair, bootloader fix
- **Health Checks** - Verify package manager and system health

### Modern CLI Tools
Install modern replacements for classic Unix tools:

| Classic | Modern | Description |
|---------|--------|-------------|
| `find` | `fd` | User-friendly find alternative |
| `grep` | `ripgrep` | Blazingly fast search |
| `cat` | `bat` | Cat with syntax highlighting |
| `ls` | `eza` | Modern ls with git integration |
| `top` | `btop` | Beautiful resource monitor |
| `du` | `dust` | Intuitive disk usage |

## Installation

### Option 1: Clone & Run (Recommended)

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo ./ultimate.sh
```

### Option 2: System Install

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo make install
ultimate-linux-suite  # Run from anywhere
```

## Module Reference

### Core Libraries (`lib/`)

| Module | Description |
|--------|-------------|
| `logging.sh` | Multi-level logging with file output and colors |
| `os_detect.sh` | OS/distro detection with family grouping |
| `hardware_detect.sh` | CPU, GPU, RAM, disk, WiFi, battery detection |
| `pkg.sh` | Package manager abstraction (apt/dnf/pacman/zypper/apk/xbps) |
| `queue.sh` | Queue system for batched operations |
| `menu.sh` | Interactive menu rendering |

### Advanced Libraries (`lib/`)

| Module | Description |
|--------|-------------|
| `tui.sh` | Modern TUI with gum/fzf/whiptail backends |
| `tui_advanced.sh` | Complex UI components (wizards, multi-select) |
| `scan.sh` | Deep hardware scanning with JSON output |
| `tune.sh` | Sysctl configuration generator |
| `state.sh` | JSON-based state management with locking |
| `error_handling.sh` | Robust error handling and recovery |

### Package Management (`lib/`)

| Module | Description |
|--------|-------------|
| `pkg_cascade.sh` | Cascade installation (native→flatpak→snap→appimage) |
| `pkg_universal.sh` | Install Flatpak, Snap, Nix, Homebrew, AUR helpers |
| `pkg_aur.sh` | Complete AUR support for Arch-based systems |
| `pkg_verify.sh` | Package verification, health checks, checkpoints |
| `utilities.sh` | Utility installation matrix (modern CLI tools) |

### System Optimization (`lib/`)

| Module | Description |
|--------|-------------|
| `zram.sh` | ZRAM compressed swap configuration |
| `cpu_governor.sh` | CPU frequency scaling management |
| `io_scheduler.sh` | I/O scheduler optimization |
| `autostart.sh` | Autostart and multi-phase resume system |
| `systemd_service.sh` | System-level systemd service for multi-stage install |
| `profile_aliases.sh` | Modern CLI tool alias management |

### Feature Modules (`modules/`)

| Module | Description |
|--------|-------------|
| `apps.sh` | Application installer with categories |
| `drivers.sh` | GPU, WiFi, and VM guest driver management |
| `optimize.sh` | System optimization with profiles |
| `recovery.sh` | System recovery and repair tools |
| `services.sh` | Service management (systemd/OpenRC) |
| `firewall.sh` | Firewall management (ufw/firewalld/iptables) |
| `setup_profiles.sh` | Quick setup profiles |
| `first_run.sh` | First-run wizard with multi-phase execution |

## Cascade Installation System

When you install an app, the cascade system tries multiple methods:

```
1. Native package (apt/dnf/pacman/etc.)
   ↓ if not available
2. Flatpak from Flathub
   ↓ if not available
3. Snap from Snapcraft
   ↓ if not available
4. AppImage download
   ↓ if not available
5. Build from source
```

### Usage

```bash
# Source the module
source lib/pkg_cascade.sh

# Install with automatic method selection
cascade_install firefox

# Install with specific method preference
cascade_install_with_method discord flatpak

# Batch install
cascade_batch_install firefox vlc gimp
```

## Package Checkpoints

Save your package state and roll back if needed:

```bash
source lib/pkg_verify.sh

# Create a checkpoint before making changes
pkg_checkpoint_create "before-gaming-setup"

# List available checkpoints
pkg_checkpoint_list

# See what changed since checkpoint
pkg_checkpoint_diff "before-gaming-setup"

# Roll back to checkpoint (dry run)
pkg_checkpoint_rollback "before-gaming-setup"

# Roll back for real
pkg_checkpoint_rollback "before-gaming-setup" 0
```

## Utility Installation

Install modern CLI tools by category:

```bash
source lib/utilities.sh

# Install essential utilities
util_install_essentials

# Install developer tools
util_install_developer

# Install sysadmin tools
util_install_sysadmin

# Install modern CLI replacements
util_install_modern_cli

# Install Rust-based tools (auto-installs Rust if needed)
util_install_rust_tools

# Install specific utility
util_install ripgrep

# Check what's installed
util_status
```

### Available Categories

| Category | Tools |
|----------|-------|
| `essential` | curl, wget, git, vim, htop, tree, fzf, jq, rsync, tmux |
| `modern-cli` | htop, btop, ncdu, fd, ripgrep, bat, eza, fzf, jq, yq, tldr |
| `developer` | git, vim, neovim, make, cmake, jq, fd, ripgrep, bat, fzf, tmux |
| `sysadmin` | htop, iotop, lsof, strace, nmap, tcpdump, rsync, tmux |
| `rust-tools` | fd, ripgrep, bat, eza, dust, procs, bottom, zoxide, starship, delta |
| `network` | nmap, netcat, socat, tcpdump, mtr, iperf3, httpie |
| `compression` | tar, gzip, bzip2, xz, zip, 7z, zstd, pigz |

## Hardware Scanning

Deep hardware detection with JSON output:

```bash
source lib/scan.sh

# Get CPU info as JSON
detect_cpu

# Get full hardware scan
perform_full_scan

# Output saved to: ~/.local/state/ultimate-suite/hardware_scan.json

# Save hardware profile with optimization recommendations
save_hardware_profile

# Print optimization recommendations
print_optimization_recommendations
```

## Optimization Algorithms

The suite uses research-backed algorithms for automatic optimization:

| Parameter | Algorithm | Rationale |
|-----------|-----------|-----------|
| **ZRAM Size** | `min(RAM/2, 8GB)` | Conservative sizing prevents over-commitment |
| **Swappiness** | RAM < 8GB: 60; 8-16GB: 40; 32GB+: 10-20 | Balances RAM utilization with swap overhead |
| **Swappiness (ZRAM)** | 100-180 based on RAM | Higher values since ZRAM is faster than disk |
| **I/O Scheduler** | NVMe → `none`, SSD → `mq-deadline`, HDD → `bfq` | Matches scheduler complexity to device needs |
| **CPU Governor** | Desktop: `performance`, Laptop: `schedutil` | Optimizes for use case expectations |

```bash
source lib/scan.sh

# Generate recommendations based on your hardware
generate_optimization_recommendations
```

## Profile Aliases

Install modern CLI tool aliases system-wide or per-user:

```bash
source lib/profile_aliases.sh

# Install aliases (auto-detects root vs user)
install_aliases

# Or explicitly choose level
install_system_aliases  # Requires root, installs to /etc/profile.d/
install_user_aliases    # User level, updates ~/.bashrc

# Show status
show_alias_status

# List available aliases
list_aliases
```

Installed aliases (when tools are available):
- `ls` → `eza --icons --group-directories-first`
- `cat` → `bat --style=plain`
- `grep` → `rg --color=auto`
- `du` → `dust`
- `top` → `btop`
- `help` → `tldr`

## Multi-Stage Installation

For installations that require reboots, use the systemd service:

```bash
source lib/systemd_service.sh

# Setup multi-stage installation (requires root)
sudo setup_multi_stage_installation /path/to/ultimate-linux-suite

# Check status
show_system_service_status

# Mark installation complete (disables service)
sudo mark_installation_complete

# Reset to run again
sudo reset_installation_state
```

The service uses a state machine in `/var/lib/linux-suite/state.json` with:
- Automatic retry (up to 3 attempts per stage)
- Boot ID tracking for reboot detection
- Completion flag to prevent re-running

## System Tuning

Generate optimized sysctl configuration:

```bash
source lib/tune.sh

# Generate configuration for your hardware
tune_generate_sysctl balanced

# Available profiles: minimal, balanced, performance, gaming, server

# Apply the configuration
tune_apply

# Restore from backup
tune_restore
```

## TUI System

The suite uses a modern TUI with automatic backend selection:

**Priority:** gum → fzf → whiptail → dialog → basic

```bash
source lib/tui.sh

# Show a menu
tui_menu "Choose an option" "Option 1" "Option 2" "Option 3"

# Show a checklist
tui_checklist "Select items" "Item 1" "Item 2" "Item 3"

# Get user input
result=$(tui_input "Enter your name")

# Show confirmation
tui_confirm "Are you sure?" && echo "Yes" || echo "No"

# Show a spinner while working
long_running_command &
tui_spinner $! "Processing..."
```

## State Management

Track state across sessions and reboots:

```bash
source lib/state.sh

# Initialize state system
init_state_system

# Update state
update_state '.phase.current = 2 | .phase.name = "OPTIMIZE"'

# Query state
current_phase=$(get_state '.phase.name')

# Record events
record_event "package_installed" '{"name": "firefox", "method": "native"}'
```

## First-Run Wizard

The first-run wizard provides an automated setup experience:

```bash
# Run the wizard
./modules/first_run.sh

# Check status
./modules/first_run.sh --status

# Reset and start over
./modules/first_run.sh --reset

# Resume from specific phase
./modules/first_run.sh --resume SCAN
```

### Phases

| Phase | Description |
|-------|-------------|
| INIT | Check prerequisites and display welcome |
| SCAN | Hardware and system detection |
| OPTIMIZE | Apply system optimizations |
| REBOOT_REQUIRED | Prompt for reboot (auto-resume after) |
| VERIFY | Post-reboot verification |
| PKG_MANAGERS | Install Flatpak, Snap, Nix |
| UTILITIES | Install essential utilities |
| REBOOT_OPTIONAL | Offer optional reboot |
| VERIFY_FINAL | Final system verification |
| APPS_READY | Ready for application installation |
| COMPLETE | First-run complete |

## Supported Distributions

| Family | Distributions |
|--------|---------------|
| **Debian** | Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS, Zorin OS, MX Linux |
| **Fedora** | Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, Oracle Linux |
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, Artix, ArcoLinux, CachyOS |
| **openSUSE** | openSUSE Leap, openSUSE Tumbleweed, SLES |
| **Alpine** | Alpine Linux |
| **Void** | Void Linux |
| **Immutable** | Fedora Silverblue/Kinoite, Universal Blue (Bazzite, Bluefin) |
| **Security** | Kali Linux, Parrot OS |

Unknown distributions fall back to generic mode with basic functionality.

## Project Structure

```
ultimate-linux-suite/
├── ultimate.sh              # Main entry point
├── Makefile                 # Build & install targets
│
├── lib/                     # Core libraries
│   ├── logging.sh           # Multi-level logging with file output
│   ├── os_detect.sh         # OS/distro detection
│   ├── hardware_detect.sh   # Hardware detection
│   ├── pkg.sh               # Package manager abstraction
│   ├── queue.sh             # Queue system
│   ├── menu.sh              # Interactive menus
│   ├── utils.sh             # Utility functions
│   ├── error_handling.sh    # Error handling and recovery
│   │
│   ├── tui.sh               # Modern TUI (gum/fzf/whiptail) - Dracula theme
│   ├── tui_advanced.sh      # Advanced UI + navigation/breadcrumbs
│   │
│   ├── scan.sh              # Deep hardware scanning + optimization recs
│   ├── tune.sh              # Sysctl configuration generator
│   ├── state.sh             # State management (root/user paths)
│   ├── state_advanced.sh    # Advanced state features
│   │
│   ├── pkg_cascade.sh       # Cascade installation system
│   ├── pkg_universal.sh     # Universal package managers
│   ├── pkg_aur.sh           # AUR support for Arch
│   ├── pkg_verify.sh        # Package verification & checkpoints
│   ├── utilities.sh         # Utility installation matrix
│   │
│   ├── zram.sh              # ZRAM configuration (zram-generator)
│   ├── cpu_governor.sh      # CPU governor management
│   ├── io_scheduler.sh      # I/O scheduler optimization
│   ├── autostart.sh         # Autostart management
│   ├── systemd_service.sh   # System-level systemd service
│   └── profile_aliases.sh   # Modern CLI alias management
│
├── modules/                 # Feature modules
│   ├── apps.sh              # Application installer
│   ├── drivers.sh           # Driver management
│   ├── optimize.sh          # System optimization
│   ├── recovery.sh          # Recovery tools
│   ├── services.sh          # Service management
│   ├── firewall.sh          # Firewall management
│   ├── setup_profiles.sh    # Quick setup profiles
│   └── first_run.sh         # First-run wizard
│
├── tests/                   # Testing framework
│   ├── framework.sh         # Test framework
│   └── test_*.sh            # Test files
│
├── apps/                    # Application database
│   └── database.sh          # 60+ app definitions
│
├── backends/                # Distro-specific mappings
│   ├── debian.sh, ubuntu.sh, mint.sh
│   ├── fedora.sh, arch.sh, opensuse.sh
│   └── kali.sh, parrot.sh, generic.sh
│
├── configs/                 # Configuration files
│   ├── optimization_profiles.conf
│   ├── modern-cli.sh        # Profile.d alias template
│   └── app_presets/
│
├── menus/                   # Menu definitions
│   ├── main_menu.sh
│   ├── apps_menu.sh
│   ├── drivers_menu.sh
│   ├── optimize_menu.sh
│   └── recovery_menu.sh
│
├── drivers/                 # Hardware driver scripts
│   ├── amd/, nvidia/, intel/
│   ├── broadcom/, realtek-*/
│   └── README.md
│
└── docs/                    # Documentation
    └── *.md
```

## Testing

Run the test suite:

```bash
# Run all tests
./tests/framework.sh

# Run specific test file
source tests/framework.sh
run_tests tests/test_logging.sh

# Run test suite
run_test_suite tests/
```

### Writing Tests

```bash
#!/usr/bin/env bash
source tests/framework.sh

TEST_SUITE_NAME="My Tests"

test_example() {
    assert_equals "expected" "actual" "Values should match"
    assert_true "1" "Should be truthy"
    assert_file_exists "/etc/passwd" "File should exist"
    assert_command_exists "bash" "Bash should be available"
}

run_tests
```

## Command Line Options

```bash
sudo ./ultimate.sh              # Interactive menu
./ultimate.sh --help            # Show help
./ultimate.sh --version         # Show version
sudo ./ultimate.sh --debug      # Enable debug output
./ultimate.sh --non-interactive # CI/testing mode
```

## Requirements

**Required:**
- Bash 4.0+ (standard on all modern Linux)
- Root/sudo access for system modifications

**Recommended:**
- `jq` - JSON processing (for state management)
- `pciutils` - GPU/hardware detection
- `usbutils` - USB device detection
- `dmidecode` - System information
- `smartmontools` - Disk health monitoring

**Optional (for enhanced TUI):**
- `gum` - Modern TUI toolkit (best experience)
- `fzf` - Fuzzy finder (good fallback)

## Development

### Syntax Check
```bash
make test
# or
bash -n lib/*.sh modules/*.sh
```

### Run Tests
```bash
source tests/framework.sh
run_test_suite tests/
```

### Adding a Module
1. Create `lib/mymodule.sh` with proper guards and dependencies
2. Follow the dependency pattern:
```bash
# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        # ... fallbacks
    }
fi
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on at least one supported distribution
4. Run syntax checks: `bash -n lib/*.sh modules/*.sh`
5. Run tests: `source tests/framework.sh && run_test_suite tests/`
6. Submit a pull request

## Known Limitations

- Some pentest tools require Kali/Parrot repositories
- NVIDIA drivers may need additional repo setup on some distros
- AUR packages require yay/paru (can be auto-installed)
- Some kernel changes require reboot
- Immutable distros have limited native package support (use Flatpak)

## License

MIT License - see [LICENSE](LICENSE) file.

## Links

- **Repository:** https://github.com/Nerds489/ultimate-linux-suite
- **Issues:** https://github.com/Nerds489/ultimate-linux-suite/issues
