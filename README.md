<p align="center">
  <img src="https://img.shields.io/badge/Version-4.0.0-blue?style=for-the-badge" alt="Version"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
  <img src="https://img.shields.io/badge/Bash-4.0%2B-orange?style=for-the-badge" alt="Bash"/>
  <img src="https://img.shields.io/badge/Platform-Linux-purple?style=for-the-badge" alt="Platform"/>
</p>

<h1 align="center">Unified Linux Suite</h1>

<p align="center">
  <strong>Sovereign Optimization Protocol</strong><br/>
  <em>A comprehensive Linux system management platform combining power, security, and simplicity</em>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#features">Features</a> •
  <a href="#commands">Commands</a> •
  <a href="#modules">Modules</a> •
  <a href="#supported-distributions">Distributions</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## What is This?

**Unified Linux Suite** is the merger of two powerful projects:

- **Ultimate Linux Suite** — A multi-distribution system management toolkit with modern TUI, cascade installation, and deep hardware optimization
- **OffTrack Suite** — A security-focused toolkit with pentest tools, encrypted vaults, malware analysis labs, and MacBook hardware support

The result is a single, comprehensive platform that handles everything from system optimization to security lab deployment—across 20+ Linux distributions.

---

## What's New in v4.0.0

### The Unified Release

This release merges two codebases into one cohesive toolkit:

| Component | Origin | Description |
|-----------|--------|-------------|
| **Security Lab** | OffTrack | KVM setup, malware analysis, Windows VM deployment |
| **Pentest Tools** | OffTrack | Metasploit, SQLMap, Nikto, Wifite, ExploitDB |
| **Encrypted Vault** | OffTrack | LUKS-encrypted secure storage |
| **MacBook Support** | OffTrack | Cirrus audio, Broadcom WiFi, SPI keyboard drivers |
| **Firewall Manager** | OffTrack | UFW/firewalld/iptables unified interface |
| **System Optimization** | Ultimate | CPU/RAM optimizers, performance profiles |
| **Cascade Install** | Ultimate | Native → Flatpak → Snap → AppImage fallback |
| **Modern TUI** | Ultimate | gum/fzf/whiptail with Dracula theme |
| **Hardware Detection** | Ultimate | Deep scanning with JSON output |

### New Entry Point

```bash
./unified.sh          # New unified entry point
./ultimate.sh         # Legacy entry point (still works)
```

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite

# Launch the interactive menu
sudo ./unified.sh

# Or run specific commands
./unified.sh status              # System overview
./unified.sh optimize            # Optimization wizard
./unified.sh profile gaming      # Apply gaming profile
./unified.sh pentest             # Pentest tools installer
./unified.sh security            # Security lab menu
./unified.sh macbook fix-all     # Fix MacBook hardware (if applicable)
```

**That's it.** Clone and run—no build steps, no dependencies to install first.

---

## Features

### System Optimization

| Feature | Description |
|---------|-------------|
| **RAM Optimizer** | Intelligent swappiness, cache pressure, ZRAM configuration |
| **CPU Optimizer** | Governor selection, P-State tuning, boost control |
| **Performance Profiles** | Gaming, Server, Laptop, Desktop, Balanced presets |
| **I/O Scheduler** | Device-aware scheduler selection (none/mq-deadline/bfq) |
| **Sysctl Tuning** | Auto-generated kernel parameters based on hardware |

### Security & Pentest

| Feature | Description |
|---------|-------------|
| **Pentest Tools** | One-click install: Metasploit, SQLMap, Nikto, Wifite, ExploitDB |
| **Security Lab** | Isolated KVM environment for malware analysis |
| **Windows VM** | Automated Windows VM deployment for testing |
| **Encrypted Vault** | LUKS-encrypted storage for sensitive data |
| **Firewall Manager** | Unified interface for ufw, firewalld, iptables |
| **Voidwave Integration** | Advanced wireless security tools |

### Hardware Support

| Feature | Description |
|---------|-------------|
| **MacBook Detection** | Automatic identification of MacBook generation |
| **Cirrus Audio** | Fix MacBook Pro audio with Cirrus Logic chips |
| **Broadcom WiFi** | Configure Broadcom wireless on MacBooks |
| **SPI Keyboard** | Apple SPI keyboard/trackpad driver installation |
| **NVIDIA/AMD/Intel** | GPU driver management across distributions |
| **VM Guest Tools** | VirtualBox, VMware, QEMU/KVM additions |

### Package Management

| Feature | Description |
|---------|-------------|
| **Cascade Installation** | Auto-fallback: Native → Flatpak → Snap → AppImage |
| **60+ Applications** | Cross-distro package database with mappings |
| **AUR Support** | Full Arch User Repository integration |
| **Package Checkpoints** | Snapshot and rollback package state |
| **Modern CLI Tools** | Install fd, ripgrep, bat, eza, btop, and more |

### User Experience

| Feature | Description |
|---------|-------------|
| **Modern TUI** | Beautiful interface with gum/fzf, Dracula theme |
| **Dry-Run Mode** | Preview changes without applying them |
| **Snapshot System** | Create restore points before changes |
| **Breadcrumb Navigation** | Hierarchical menu system |
| **JSON State** | Persistent state across sessions and reboots |

---

## Commands

### Command Line Interface

```
unified.sh [OPTIONS] COMMAND [ARGS]

Options:
  -h, --help        Show help
  -v, --version     Show version
  -n, --dry-run     Simulate without making changes
  -y, --yes         Auto-confirm all prompts
  -d, --debug       Enable debug output
  -q, --quiet       Suppress non-essential output

Commands:
  menu              Launch interactive TUI menu (default)
  status            Show system status
  health            Full system health report
```

### Optimization Commands

```bash
./unified.sh optimize              # Run optimization wizard
./unified.sh profile gaming        # Apply gaming profile
./unified.sh profile server        # Apply server profile
./unified.sh profile laptop        # Apply laptop profile
./unified.sh ram                   # RAM optimization wizard
./unified.sh cpu                   # CPU optimization wizard
```

### Security Commands

```bash
./unified.sh security              # Security lab menu
./unified.sh pentest               # Pentest tools installer
./unified.sh vault create          # Create encrypted vault
./unified.sh vault open            # Open vault
./unified.sh vault close           # Close vault
./unified.sh firewall              # Firewall configuration
```

### Hardware Commands

```bash
./unified.sh hardware              # Show hardware info
./unified.sh macbook status        # MacBook driver status
./unified.sh macbook fix-all       # Fix all MacBook hardware
```

### System Commands

```bash
./unified.sh apps                  # Application installer
./unified.sh update                # Update system packages
./unified.sh bootstrap             # System bootstrap wizard
./unified.sh snapshot create NAME  # Create snapshot
./unified.sh snapshot list         # List snapshots
./unified.sh snapshot restore NAME # Restore snapshot
```

---

## Modules

### Core Libraries (`lib/`)

| Module | Description |
|--------|-------------|
| `init.sh` | Suite initialization and library loading |
| `core.sh` | Core functions and utilities |
| `colors.sh` | Terminal color definitions (Dracula theme) |
| `config.sh` | Configuration management |
| `logging.sh` | Multi-level logging with file output |
| `os_detect.sh` | OS/distro detection with family grouping |
| `hardware.sh` | Hardware detection utilities |
| `macbook_detect.sh` | MacBook generation identification |
| `pkg.sh` | Package manager abstraction |
| `tui.sh` | Modern TUI with multiple backends |
| `safety.sh` | Snapshot and rollback system |
| `deps.sh` | Dependency management |
| `monitor.sh` | System monitoring functions |
| `optimization.sh` | Optimization algorithms and helpers |

### Optimization Modules (`modules/optimization/`)

| Module | Description |
|--------|-------------|
| `ram_optimizer.sh` | Memory optimization (swappiness, cache, ZRAM) |
| `cpu_optimizer.sh` | CPU frequency and governor management |
| `profiles.sh` | Performance profile definitions and application |

### Security Modules (`modules/security/`)

| Module | Description |
|--------|-------------|
| `firewall.sh` | Unified firewall management (ufw/firewalld/iptables) |
| `vault.sh` | LUKS-encrypted vault creation and management |
| `lab_setup.sh` | Security lab environment configuration |
| `kvm_setup.sh` | KVM virtualization setup for isolated testing |
| `malware_lab.sh` | Malware analysis environment |
| `windows_vm.sh` | Automated Windows VM deployment |

### Pentest Modules (`modules/pentest/`)

| Module | Description |
|--------|-------------|
| `tools_installer.sh` | Bulk pentest tool installation |
| `voidwave.sh` | Voidwave wireless security integration |
| `individual/` | Individual tool installers |

**Individual Tools:**
- `metasploit.sh` — Metasploit Framework
- `sqlmap.sh` — SQL injection automation
- `nikto.sh` — Web server scanner
- `wifite.sh` — Wireless attack automation
- `exploitdb.sh` — Exploit database search

### Application Modules (`modules/apps/`)

| Module | Description |
|--------|-------------|
| `app_installer.sh` | Category-based application installer |

### Bootstrap & Installer Modules (`modules/bootstrap/`, `modules/installers/`)

| Module | Description |
|--------|-------------|
| `bootstrap.sh` | Full system bootstrap wizard |
| `arch_guided.sh` | Guided Arch Linux installation |
| `mint_recovery.sh` | Linux Mint recovery tools |
| `parrot_lab.sh` | Parrot OS lab setup |
| `disk_partition.sh` | Disk partitioning utilities |

### Hardware Drivers (`drivers/`)

| Directory | Description |
|-----------|-------------|
| `macbook/` | MacBook-specific drivers and fixes |
| `nvidia/` | NVIDIA GPU drivers |
| `amd/` | AMD GPU drivers |
| `intel/` | Intel GPU drivers |
| `broadcom/` | Broadcom WiFi drivers |
| `realtek-*/` | Realtek WiFi and Ethernet drivers |

**MacBook Drivers:**
- `audio_cirrus.sh` — Cirrus Logic audio driver
- `wifi_broadcom.sh` — Broadcom WiFi configuration
- `spi_driver.sh` — Apple SPI keyboard/trackpad
- `fix_all.sh` — Run all MacBook fixes

---

## Project Structure

```
ultimate-linux-suite/
├── unified.sh               # New unified entry point
├── ultimate.sh              # Legacy entry point
├── suite.sh -> ultimate.sh  # Symlink for compatibility
├── VERSION                  # Version file (4.0.0)
├── LICENSE                  # GPL-3.0 License
├── Makefile                 # Build & install targets
│
├── lib/                     # Core libraries
│   ├── init.sh              # Initialization
│   ├── core.sh              # Core functions
│   ├── colors.sh            # Color definitions
│   ├── config.sh            # Configuration
│   ├── logging.sh           # Logging system
│   ├── os_detect.sh         # OS detection
│   ├── hardware.sh          # Hardware utilities
│   ├── macbook_detect.sh    # MacBook detection
│   ├── pkg.sh               # Package management
│   ├── tui.sh               # Terminal UI
│   ├── safety.sh            # Snapshots/rollback
│   ├── deps.sh              # Dependencies
│   ├── monitor.sh           # System monitoring
│   ├── optimization.sh      # Optimization helpers
│   └── ...                  # Additional libraries
│
├── modules/                 # Feature modules
│   ├── optimization/        # CPU, RAM, profiles
│   ├── security/            # Firewall, vault, labs
│   ├── pentest/             # Security tools
│   │   └── individual/      # Individual installers
│   ├── apps/                # Application installer
│   ├── bootstrap/           # System bootstrap
│   └── installers/          # Distro installers
│
├── drivers/                 # Hardware drivers
│   ├── macbook/             # MacBook support
│   ├── nvidia/              # NVIDIA GPU
│   ├── amd/                 # AMD GPU
│   └── ...                  # Other drivers
│
├── menus/                   # Menu definitions
│   ├── main_menu.sh         # Main navigation
│   ├── apps_menu.sh         # Applications
│   ├── optimize_menu.sh     # Optimization
│   ├── drivers_menu.sh      # Drivers
│   └── recovery_menu.sh     # Recovery
│
├── scripts/                 # Utility scripts
│   ├── askpass_setup.sh     # SSH askpass config
│   └── update-all.sh        # System update script
│
├── tests/                   # Test suite
│   ├── framework.sh         # Test framework
│   ├── run_all_tests.sh     # Test runner
│   └── test_*.sh            # Test files
│
├── apps/                    # Application database
├── backends/                # Distro-specific mappings
├── configs/                 # Configuration files
└── docs/                    # Documentation
```

---

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

---

## Installation Methods

### Option 1: Clone & Run (Recommended)

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo ./unified.sh
```

### Option 2: System Install

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo make install
unified-linux-suite  # Run from anywhere
```

### Option 3: One-Liner

```bash
curl -fsSL https://raw.githubusercontent.com/Nerds489/ultimate-linux-suite/main/unified.sh | sudo bash
```

---

## Examples

### Optimize a Gaming System

```bash
# Apply gaming profile (performance governor, optimized swappiness)
sudo ./unified.sh profile gaming

# Or use the interactive wizard
sudo ./unified.sh optimize
```

### Set Up a Security Lab

```bash
# Launch security lab menu
sudo ./unified.sh security

# Install KVM and create isolated environment
# Deploy Windows VM for malware testing
# Configure network isolation
```

### Install Pentest Tools

```bash
# Install common pentest tools
sudo ./unified.sh pentest

# Individual tools available:
# - Metasploit Framework
# - SQLMap
# - Nikto
# - Wifite
# - ExploitDB
```

### Fix MacBook Hardware

```bash
# Check if running on MacBook
./unified.sh macbook status

# Fix all hardware issues (audio, wifi, keyboard)
sudo ./unified.sh macbook fix-all
```

### Create Encrypted Vault

```bash
# Create a new encrypted vault
sudo ./unified.sh vault create

# Open existing vault
sudo ./unified.sh vault open

# Check vault status
./unified.sh vault status
```

### Manage Firewall

```bash
# Open firewall menu
sudo ./unified.sh firewall

# Works with ufw, firewalld, or iptables
# Automatically detects installed firewall
```

---

## Requirements

### Required
- Bash 4.0+ (standard on all modern Linux distributions)
- Root/sudo access for system modifications

### Recommended
- `jq` — JSON processing (for state management)
- `pciutils` — GPU/hardware detection (`lspci`)
- `usbutils` — USB device detection (`lsusb`)
- `dmidecode` — System information
- `smartmontools` — Disk health monitoring

### Optional (Enhanced TUI)
- `gum` — Modern TUI toolkit (best experience)
- `fzf` — Fuzzy finder (good fallback)
- `whiptail` — ncurses dialogs (basic fallback)

### Security Lab Requirements
- `qemu-kvm` — Virtualization
- `libvirt` — VM management
- `virt-manager` — GUI for VMs
- `cryptsetup` — LUKS encryption

---

## Configuration

### Suite Configuration

Configuration is stored in `~/.config/unified-suite/` or `/etc/unified-suite/`:

```bash
~/.config/unified-suite/
├── config.sh        # User preferences
├── profiles/        # Custom optimization profiles
└── state.json       # Session state
```

### State Management

The suite maintains state across sessions:

```bash
# User state
~/.local/state/ultimate-suite/

# System state (when running as root)
/var/lib/linux-suite/
```

---

## Development

### Running Tests

```bash
# Run all tests
./tests/run_all_tests.sh

# Run with framework
source tests/framework.sh
run_test_suite tests/

# Syntax check
make test
# or
bash -n lib/*.sh modules/**/*.sh
```

### Adding a Module

1. Create your module in the appropriate directory
2. Follow the dependency pattern:

```bash
#!/usr/bin/env bash
# modules/mymodule/feature.sh

# Source dependencies with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SUITE_ROOT}/lib/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_error() { echo "[ERROR] $*" >&2; }
    }
fi

# Your module code here
my_feature() {
    log_info "Running my feature..."
    # ...
}
```

3. Add menu integration if needed
4. Update documentation

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test on at least one supported distribution
4. Run syntax checks: `bash -n lib/*.sh modules/**/*.sh`
5. Run tests: `./tests/run_all_tests.sh`
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## Security

For security-related issues, please see [SECURITY.md](SECURITY.md).

**Note:** The pentest tools module is intended for authorized security testing, CTF challenges, and educational purposes only. Always obtain proper authorization before testing systems you do not own.

---

## License

This project is licensed under the **MIT** License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- **Ultimate Linux Suite** contributors
- **OffTrack Suite** contributors
- The Linux community for distribution-specific guidance
- [Charm.sh](https://charm.sh) for the amazing `gum` TUI toolkit
- [Dracula Theme](https://draculatheme.com) for the color palette

---

## Links

- **Repository:** https://github.com/Nerds489/ultimate-linux-suite
- **Issues:** https://github.com/Nerds489/ultimate-linux-suite/issues
- **Discussions:** https://github.com/Nerds489/ultimate-linux-suite/discussions

---

<p align="center">
  <strong>Unified Linux Suite v4.0.0</strong><br/>
  <em>"Sovereign Optimization Protocol"</em>
</p>
