# Ultimate Linux Suite

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-orange.svg)](https://kernel.org)

A comprehensive, multi-distribution Linux system management toolkit. One script to rule them all.

## Quick Start

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
sudo ./ultimate.sh
```

**That's it.** Clone and run - no build steps, no packages required.

## Key Features

- **Queue-Based Operations** - Review all changes before execution
- **Multi-Distro Support** - Works on Debian, Ubuntu, Fedora, Arch, openSUSE, and more
- **60+ Applications** - Curated app database with cross-distro package mapping
- **System Optimization** - ZRAM, swappiness, I/O schedulers, kernel tuning
- **Driver Management** - NVIDIA, AMD, Intel, Broadcom WiFi, VM guest tools
- **Recovery Tools** - DNS reset, orphan cleanup, package repair, bootloader fix

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

### Option 3: Package Install

| Distribution | Package | Install Command |
|--------------|---------|-----------------|
| Debian/Ubuntu/Mint | `.deb` | `sudo dpkg -i ultimate-linux-suite_1.0.0-1_all.deb` |
| Fedora/RHEL/CentOS | `.rpm` | `sudo dnf install ultimate-linux-suite-1.0.0-1.noarch.rpm` |
| Arch Linux | `.pkg.tar.zst` | `sudo pacman -U ultimate-linux-suite-1.0.0-1-any.pkg.tar.zst` |
| openSUSE | `.rpm` | `sudo zypper install ultimate-linux-suite-1.0.0-0.noarch.rpm` |

Build packages yourself:
```bash
make deb        # Debian/Ubuntu/Mint/Kali/Parrot
make rpm        # Fedora/RHEL/CentOS
make arch       # Arch Linux
make opensuse   # openSUSE
make all-pkgs   # All formats
```

## Modules

| Module | Description |
|--------|-------------|
| **Applications** | Browse 60+ apps by category, search, or use preset profiles |
| **Optimization** | System tuning with profiles (Desktop, Gaming, Laptop, Server) |
| **Drivers** | GPU drivers, WiFi firmware, VirtualBox/VMware guest tools |
| **Recovery** | Fix packages, reset DNS, clean orphans, repair bootloader |
| **Queue** | Review and execute all pending operations |

## Queue System

Nothing executes immediately. All operations are queued for review:

```
┌─────────────────────────────────────────┐
│         Installation Queue              │
├─────────────────────────────────────────┤
│  1. [pkg] firefox - Install Firefox     │
│  2. [pkg] vlc - Install VLC             │
│  3. [cmd] Configure ZRAM                │
├─────────────────────────────────────────┤
│  e) Execute All    c) Clear    0) Back  │
└─────────────────────────────────────────┘
```

## Supported Distributions

| Family | Distributions |
|--------|---------------|
| **Debian** | Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS, Zorin OS |
| **Fedora** | Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux |
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, Artix |
| **openSUSE** | openSUSE Leap, openSUSE Tumbleweed, SLES |
| **Security** | Kali Linux, Parrot OS |

Unknown distributions fall back to generic mode with basic functionality.

## Application Presets

| Preset | Contents |
|--------|----------|
| `workstation` | LibreOffice, Firefox, Thunderbird, GIMP, VLC |
| `gaming` | Steam, Lutris, Wine, MangoHud, ProtonUp-Qt |
| `developer` | Git, Docker, VS Code, Node.js, Python, Go, Rust |
| `pentest` | Nmap, Wireshark, Metasploit, Burp Suite |
| `server` | htop, tmux, ncdu, fail2ban, nginx |
| `minimal` | Essential CLI utilities only |

## Optimization Options

| Category | Options |
|----------|---------|
| **Memory** | Swappiness, ZRAM, cache pressure, THP |
| **I/O** | Scheduler selection, readahead tuning |
| **Network** | BBR congestion control, TCP buffers, IPv6 toggle |
| **Power** | CPU governor, laptop mode, USB autosuspend |
| **Desktop** | Compositor tweaks, animation speed |

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
- `pciutils` - GPU/hardware detection
- `usbutils` - USB device detection
- `dmidecode` - System information
- `smartmontools` - Disk health monitoring

## Project Structure

```
ultimate-linux-suite/
├── ultimate.sh           # Main entry point
├── Makefile              # Build & install targets
├── lib/                  # Core libraries
│   ├── logging.sh        # Logging with file output
│   ├── utils.sh          # Utility functions
│   ├── os_detect.sh      # OS/distro detection
│   ├── hardware_detect.sh # Hardware detection
│   ├── pkg.sh            # Package manager abstraction
│   ├── queue.sh          # Queue system
│   └── menu.sh           # Interactive menus
├── modules/              # Feature modules
│   ├── apps.sh           # Application installer
│   ├── optimize.sh       # System optimization
│   ├── drivers.sh        # Driver management
│   └── recovery.sh       # Recovery tools
├── apps/                 # Application database
│   └── database.sh       # 60+ app definitions
├── backends/             # Distro-specific mappings
│   ├── debian.sh, ubuntu.sh, mint.sh
│   ├── fedora.sh, arch.sh, opensuse.sh
│   └── kali.sh, parrot.sh, generic.sh
├── configs/              # Configuration files
│   ├── optimization_profiles.conf
│   └── app_presets/      # Preset definitions
└── packaging/            # Distribution packages
    ├── debian/           # .deb packaging
    ├── rpm/              # Fedora .rpm
    ├── opensuse/         # openSUSE .rpm
    ├── arch/             # PKGBUILD
    └── scripts/          # Build scripts
```

## Development

### Syntax Check
```bash
make test
# or
./scripts/dev-check.sh
```

### Adding a Module
1. Create `modules/mymodule.sh` with `mymodule_init()` and `mymodule_main()`
2. Source it in `ultimate.sh`
3. Add menu entry in `menus/main_menu.sh`

### Adding Distro Support
1. Create `backends/distroname.sh`
2. Define `backend_pkg_name()` for package mappings
3. Add detection in `lib/os_detect.sh`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on at least one supported distribution
4. Run `make test` to verify syntax
5. Submit a pull request

## Known Limitations

- Some pentest tools require Kali/Parrot repositories
- NVIDIA drivers may need additional repo setup on some distros
- AUR packages require yay/paru (not installed by default)
- Some kernel changes require reboot

## License

MIT License - see [LICENSE](LICENSE) file.

## Links

- **Repository:** https://github.com/Nerds489/ultimate-linux-suite
- **Issues:** https://github.com/Nerds489/ultimate-linux-suite/issues
