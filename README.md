# Ultimate Linux Suite

A comprehensive Linux system optimization and management toolkit.

## LOCAL USAGE

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
chmod +x suite.sh
sudo ./suite.sh
```

**That's it.** Clone and run - no build steps, no packages required.

## Features

| Module | Description |
|--------|-------------|
| **Applications** | Install software by category or preset profile |
| **Drivers** | GPU, WiFi, and hardware driver management |
| **Optimization** | System performance tuning profiles |
| **Recovery** | Package repair, bootloader, network reset tools |
| **Profiles** | Guided setup wizard for quick system configuration |

## Supported Distributions

| Family | Distributions |
|--------|---------------|
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, Artix |
| **Debian** | Debian, Ubuntu, Linux Mint, Pop!_OS, elementary, Zorin |
| **Fedora** | Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux |
| **openSUSE** | openSUSE Leap, openSUSE Tumbleweed, SLES |
| **Security** | Kali Linux, Parrot OS |

Unknown distributions fall back to "generic" mode with basic functionality.

## Requirements

- **Bash 4.0+** (standard on modern Linux)
- **Root/sudo access** for system modifications
- Standard Linux utilities (grep, sed, awk)

**Optional for full functionality:**
- `lspci` (pciutils) - hardware detection
- `lsblk` (util-linux) - disk detection
- `smartctl` (smartmontools) - disk health
- `lsusb` (usbutils) - USB device detection

## Command Line Options

```bash
# Launch interactive menu
sudo ./suite.sh

# Show help
./suite.sh --help

# Show version
./suite.sh --version

# Enable debug output
sudo ./suite.sh --debug

# Non-interactive mode (for CI testing)
./suite.sh --non-interactive
```

## Application Presets

| Preset | Description |
|--------|-------------|
| `workstation` | General desktop productivity |
| `gaming` | Gaming-optimized with Steam, Lutris, Wine |
| `developer` | Development tools and languages |
| `pentest` | Security testing tools (best on Kali/Parrot) |
| `server` | Server-oriented packages |
| `minimal` | Essential utilities only |

## Optimization Profiles

| Profile | Use Case |
|---------|----------|
| **Desktop** | General desktop responsiveness |
| **Gaming** | Maximum performance for games |
| **Laptop** | Battery optimization |
| **Server** | High-load server workloads |

## Project Structure

```
ultimate-linux-suite/
├── suite.sh              # Main entry point
├── LICENSE               # MIT License
├── README.md             # This file
├── CHANGELOG.md          # Version history
├── lib/                  # Core libraries
│   ├── logging.sh        # Logging functions + file logging
│   ├── utils.sh          # Utility functions (uls_*)
│   ├── os_detect.sh      # OS detection (ULS_DISTRO)
│   ├── hardware_detect.sh # Hardware detection
│   ├── pkg.sh            # Package management abstraction
│   └── menu.sh           # Menu system
├── modules/              # Feature modules
│   ├── apps.sh           # Application installer
│   ├── drivers.sh        # Driver management
│   ├── optimize.sh       # System optimization
│   ├── recovery.sh       # Recovery tools
│   └── setup_profiles.sh # Profile setup wizard
├── menus/                # Menu implementations
│   ├── main_menu.sh
│   ├── apps_menu.sh
│   ├── drivers_menu.sh
│   ├── optimize_menu.sh
│   └── recovery_menu.sh
├── backends/             # Per-distro package mappings
│   ├── arch.sh
│   ├── debian.sh
│   ├── ubuntu.sh
│   ├── mint.sh
│   ├── fedora.sh
│   ├── opensuse.sh
│   ├── kali.sh
│   ├── parrot.sh
│   └── generic.sh
├── configs/              # Configuration files
│   ├── optimization_profiles.conf
│   └── app_presets/      # Application presets
│       ├── workstation.conf
│       ├── gaming.conf
│       ├── developer.conf
│       ├── pentest.conf
│       ├── server.conf
│       └── minimal.conf
├── drivers/              # Driver documentation
│   ├── nvidia/
│   ├── amd/
│   ├── intel/
│   ├── broadcom/
│   ├── realtek-r8152/
│   └── realtek-r8821cu/
└── scripts/              # Development scripts
    └── dev-check.sh      # Syntax/lint checker
```

## Important Notes

### No Packaging Required

This toolkit is designed for **direct execution**. You do NOT need to:
- Build .deb or .rpm packages
- Run any build scripts
- Install any packaging tools

Just clone and run.

### Packaging (Optional)

If you want to create distribution packages, that's a separate optional process not covered by this toolkit. The main `suite.sh` script will **never** invoke dpkg-buildpackage, rpmbuild, or any packaging tools.

### Error Handling

The suite uses careful error handling:
- Operations that fail will show clear error messages
- Failed operations won't crash the entire script
- You can continue using other features even if one fails
- All operations are logged to `/var/log/ultimate-linux-suite/` (root) or `~/.ultimate-linux-suite/logs/` (user)

### Unsupported Features

If a feature isn't available on your distribution:
- The menu option will still appear
- You'll get a clear message explaining why it's unavailable
- The script will return to the menu gracefully

## Development

### Running Checks

```bash
./scripts/dev-check.sh
```

This runs:
- Bash syntax check on all scripts
- ShellCheck (if installed)

### Adding a New Module

1. Create `modules/mymodule.sh` with:
   - A `mymodule_init()` function
   - A `mymodule_main()` function
2. Source it in `suite.sh`
3. Add menu entry in `menus/main_menu.sh`

### Adding a New Backend

1. Create `backends/distroname.sh`
2. Define `backend_pkg_name()` for package mappings
3. Add detection in `_load_backend()` in `suite.sh`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on at least one supported distribution
4. Run `./scripts/dev-check.sh` to verify syntax
5. Submit a pull request

## Known Limitations

- Some security tools in the pentest preset require Kali/Parrot
- NVIDIA driver installation may require additional repository setup on some distros
- AUR packages on Arch require yay/paru (not installed by default)
- Some operations require a reboot to take effect

## License

MIT License - see [LICENSE](LICENSE) file.

## Links

- **Repository:** https://github.com/Nerds489/ultimate-linux-suite
- **Issues:** https://github.com/Nerds489/ultimate-linux-suite/issues
