# Universal Package Manager Reference

## Overview

The `pkg_universal.sh` module provides comprehensive support for installing and managing universal package managers across all supported Linux distributions.

## Supported Package Managers

- **Flatpak** - Universal Linux application distribution system
- **Snap** - Canonical's universal package format
- **Nix** - Purely functional package manager
- **Homebrew** - The missing package manager for Linux (and macOS)
- **AppImage** - Portable Linux application format
- **AUR** - Arch User Repository helpers (paru/yay) for Arch-based systems

## Quick Start

```bash
# Source the module
source lib/logging.sh
source lib/os_detect.sh
source lib/pkg.sh
source lib/pkg_universal.sh

# Detect all available managers
universal_detect_all

# Show status
universal_status

# Install a manager
universal_install flatpak
universal_install snap
universal_install nix
```

## Detection Functions

### universal_detect_all()
Detects all available universal package managers and sets global flags.

```bash
universal_detect_all
echo $UNIVERSAL_HAS_FLATPAK  # 1 if installed, 0 otherwise
```

### Individual Detection

```bash
universal_has_flatpak           # Check if Flatpak is available
universal_has_snap              # Check if Snap is available
universal_has_nix               # Check if Nix is available
universal_has_homebrew          # Check if Homebrew is available
universal_has_appimage_support  # Check if AppImage support is available
universal_has_aur_helper        # Check if AUR helper is available (Arch only)
universal_get_aur_helper        # Returns name of AUR helper (paru/yay)
```

## Installation Functions

### universal_install(manager)
Unified installation interface for all managers.

```bash
universal_install flatpak
universal_install snap
universal_install nix
universal_install homebrew
universal_install appimage
universal_install aur  # Arch-based only
```

### Flatpak

```bash
# Install Flatpak and setup Flathub
universal_install_flatpak

# Configure additional remotes
universal_setup_flatpak_remotes

# Install Flatseal (permission manager)
universal_install_flatseal

# Enable beta repository
universal_config_set FLATPAK_ENABLE_BETA 1
universal_setup_flatpak_remotes
```

### Snap

```bash
# Install Snap
universal_install_snap

# Wait for snapd to be ready (automatic after install)
universal_snap_wait_ready
```

### Nix

```bash
# Install Nix (multi-user mode by default)
universal_install_nix

# Install in single-user mode
universal_config_set NIX_MULTI_USER 0
universal_install_nix

# Setup channels
universal_setup_nix_channels

# Install a package
universal_nix_install firefox
universal_nix_install htop
```

### Homebrew

```bash
# Install Homebrew
universal_install_homebrew

# Setup PATH (usually automatic)
universal_homebrew_setup_path

# Install a package
universal_brew_install neofetch
universal_brew_install git
```

### AppImage

```bash
# Install AppImage support
universal_install_appimage_support

# Setup AppImage directory
universal_setup_appimage_dir

# AppImages will be stored in ~/Applications
```

### AUR (Arch-based only)

```bash
# Install AUR helper (paru by default)
universal_install_aur_helper

# Install specific helper
universal_install_aur_helper yay

# Install package from AUR
universal_aur_install google-chrome
universal_aur_install visual-studio-code-bin
```

## Configuration Functions

Configuration is stored in `~/.config/ultimate-linux-suite/universal-pkg.conf`

### universal_config_get(key, default)
Get configuration value.

```bash
value=$(universal_config_get FLATPAK_ENABLE_BETA 0)
aur_helper=$(universal_config_get AUR_HELPER paru)
```

### universal_config_set(key, value)
Set configuration value.

```bash
universal_config_set FLATPAK_ENABLE_BETA 1
universal_config_set NIX_ENABLE_FLAKES 1
universal_config_set AUR_HELPER paru
universal_config_set HOMEBREW_NO_ANALYTICS 1
```

### Available Configuration Options

- `FLATPAK_AUTO_UPDATE` - Auto-update Flatpak apps (default: 1)
- `FLATPAK_ENABLE_BETA` - Enable Flathub-beta remote (default: 0)
- `FLATPAK_ENABLE_GNOME_NIGHTLY` - Enable GNOME Nightly remote (default: 0)
- `SNAP_AUTO_REFRESH` - Auto-refresh Snap packages (default: 1)
- `NIX_ENABLE_FLAKES` - Enable Nix flakes (default: 1)
- `NIX_MULTI_USER` - Install Nix in multi-user mode (default: 1)
- `HOMEBREW_NO_ANALYTICS` - Disable Homebrew analytics (default: 1)
- `HOMEBREW_AUTO_UPDATE` - Auto-update Homebrew (default: 1)
- `AUR_HELPER` - Preferred AUR helper (default: paru)

## Status and Information

### universal_status()
Display comprehensive status of all universal managers.

```bash
universal_status
```

Output includes:
- Installation status
- Version information
- Package counts
- Configured remotes (for Flatpak)

### universal_package_counts()
Show package counts for all managers.

```bash
universal_package_counts
```

## Package Mappings

The module automatically maps package names across distributions:

```bash
# Flatpak packages
FLATPAK_PKG_NAMES[apt]="flatpak gnome-software-plugin-flatpak"
FLATPAK_PKG_NAMES[dnf]="flatpak"
FLATPAK_PKG_NAMES[pacman]="flatpak"

# Snap packages
SNAP_PKG_NAMES[apt]="snapd"
SNAP_PKG_NAMES[dnf]="snapd"
SNAP_PKG_NAMES[pacman]="snapd"
```

## Global Variables

After calling `universal_detect_all()`, these variables are set:

- `UNIVERSAL_HAS_FLATPAK` - 1 if Flatpak is installed
- `UNIVERSAL_HAS_SNAP` - 1 if Snap is installed
- `UNIVERSAL_HAS_NIX` - 1 if Nix is installed
- `UNIVERSAL_HAS_HOMEBREW` - 1 if Homebrew is installed
- `UNIVERSAL_HAS_APPIMAGE` - 1 if AppImage support is installed
- `UNIVERSAL_HAS_AUR` - 1 if AUR helper is installed

## Examples

### Install and Setup Flatpak

```bash
# Install Flatpak
universal_install_flatpak

# Enable beta repository
universal_config_set FLATPAK_ENABLE_BETA 1
universal_setup_flatpak_remotes

# Install Flatseal for managing permissions
universal_install_flatseal

# Install applications using standard flatpak commands
flatpak install flathub org.mozilla.firefox
flatpak install flathub com.spotify.Client
```

### Install and Setup Nix

```bash
# Install Nix with flakes enabled
universal_install_nix

# Install packages
universal_nix_install firefox
universal_nix_install htop
universal_nix_install ripgrep

# Or use nix-env directly
nix-env -iA nixpkgs.neofetch
```

### Install AUR Helper (Arch only)

```bash
# Set preference
universal_config_set AUR_HELPER paru

# Install the helper
universal_install_aur_helper

# Install AUR packages
universal_aur_install google-chrome
universal_aur_install spotify
universal_aur_install visual-studio-code-bin
```

### Complete Setup Example

```bash
#!/bin/bash
source lib/logging.sh
source lib/os_detect.sh
source lib/pkg.sh
source lib/pkg_universal.sh

# Initialize
logging_init
detect_os

# Detect current state
universal_detect_all

# Install Flatpak if not present
if [[ $UNIVERSAL_HAS_FLATPAK -eq 0 ]]; then
    universal_install_flatpak
    universal_install_flatseal
fi

# Install Homebrew if not present
if [[ $UNIVERSAL_HAS_HOMEBREW -eq 0 ]]; then
    universal_install_homebrew
fi

# Install AUR helper on Arch
if is_arch && [[ $UNIVERSAL_HAS_AUR -eq 0 ]]; then
    universal_install_aur_helper paru
fi

# Show final status
universal_status
```

## Error Handling

All functions return appropriate exit codes:
- `0` - Success
- `1` - Error

Check return values:

```bash
if universal_install_flatpak; then
    log_success "Flatpak installed successfully"
else
    log_error "Failed to install Flatpak"
fi
```

## Logging

The module uses the logging.sh module for all output:

- `log_info` - Informational messages
- `log_success` - Success messages
- `log_warn` - Warnings
- `log_error` - Errors
- `log_debug` - Debug messages (when LOG_LEVEL=DEBUG)

Set log level for verbose output:

```bash
export LOG_LEVEL=DEBUG
universal_install_flatpak
```

## Distribution Support

Tested and supported on:
- Ubuntu/Debian family (apt)
- Fedora/RHEL family (dnf/yum)
- Arch Linux family (pacman)
- openSUSE (zypper)
- Alpine Linux (apk)
- Void Linux (xbps)

## Notes

### Nix Installation
- Requires internet connection
- Multi-user installation requires sudo/root access
- May require logout/login for PATH to be properly set

### Snap Installation
- Requires systemd on most distributions
- May require reboot for proper initialization
- Classic snaps require `/snap` symlink (created automatically)

### Homebrew Installation
- Installs to `/home/linuxbrew/.linuxbrew` or `~/.linuxbrew`
- Requires build tools (gcc, make, etc.)
- May require logout/login for PATH to be properly set

### AUR Helpers
- Only available on Arch-based distributions
- Requires base-devel package group
- User must have sudo privileges for package installation

## See Also

- `lib/pkg.sh` - Base package management
- `lib/os_detect.sh` - OS detection
- `lib/logging.sh` - Logging functions
