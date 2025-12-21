# Package Cascade Installation System

A comprehensive cascade installation system for the Ultimate Linux Suite that implements the "try all installers" pattern. When installing an application, it tries installation methods in priority order (native → flatpak → snap → appimage) and handles failures gracefully.

## Features

### Core Capabilities

1. **Cascade Installation** - Automatically tries multiple installation methods in priority order
2. **Transaction Logging** - Tracks all installation attempts and results
3. **Snapshot System** - Create system snapshots before major changes
4. **AppImage Integration** - Download, install, and manage AppImages with desktop entries
5. **Batch Installation** - Install multiple applications with progress tracking
6. **Installation Verification** - Check installation status across all methods
7. **Flexible Priority** - Customize installation method preference order
8. **Pre-defined Apps** - 29+ common applications with installation methods configured

## Quick Start

```bash
# Source the module
source lib/logging.sh
source lib/pkg.sh
source lib/pkg_cascade.sh

# Install an application (tries all methods until success)
pkg_cascade_install firefox

# Install with preferred method
pkg_cascade_install discord flatpak

# Batch install multiple apps
pkg_cascade_batch firefox vlc gimp telegram
```

## Installation Methods

The system supports five installation methods:

1. **native** - System package manager (apt, dnf, pacman, etc.)
2. **flatpak** - Flatpak with Flathub repository
3. **snap** - Snap packages (with support for --classic)
4. **appimage** - Portable AppImage files
5. **source** - Source compilation (placeholder for future)

Default priority: `native → flatpak → snap → appimage → source`

## Main Functions

### Installation

```bash
# Install application with cascade logic
pkg_cascade_install APP_ID [PREFERRED_METHOD]

# Batch install multiple applications
pkg_cascade_batch APP1 APP2 APP3 ...

# Install AppImage manually
pkg_appimage_install NAME URL [ICON_URL]
```

### Verification

```bash
# Check if app is installed (returns method)
pkg_cascade_verify APP_ID

# Get installed version
pkg_cascade_version APP_ID

# Show available methods for an app
pkg_cascade_show_methods APP_ID
```

### Configuration

```bash
# Set method priority
pkg_set_method_priority flatpak native snap appimage

# Get current priority
pkg_get_method_priority

# Define custom app
pkg_cascade_define APP_ID "native:pkg|flatpak:id|snap:name"

# List all available apps
pkg_cascade_list_apps
```

### Snapshots

```bash
# Create snapshot
pkg_snapshot_create [NAME]

# List snapshots
pkg_snapshot_list

# View snapshot for manual restore
pkg_snapshot_restore NAME

# Prune old snapshots
pkg_snapshot_prune [KEEP_COUNT]
```

### Transaction History

```bash
# View all transaction history
pkg_transaction_history

# View history for specific app
pkg_transaction_history APP_ID

# Clean old transaction logs
pkg_transaction_cleanup
```

### AppImage Management

```bash
# Install AppImage
pkg_appimage_install NAME URL [ICON_URL]

# Remove AppImage
pkg_appimage_remove NAME

# List installed AppImages
pkg_appimage_list
```

## Application Definitions

Applications are defined with installation methods for each source:

```bash
declare -gA APP_INSTALL_METHODS=(
    [firefox]="native:firefox|flatpak:org.mozilla.firefox|snap:firefox"
    [vlc]="native:vlc|flatpak:org.videolan.VLC|snap:vlc"
    [code]="flatpak:com.visualstudio.code|snap:code:--classic"
)
```

### Pre-defined Applications

The module includes 29+ pre-configured applications:

**Web Browsers:** firefox, chromium, brave

**Media Players:** vlc, mpv

**Development:** code, vscode, sublime, atom

**Communication:** discord, telegram, slack, teams, zoom

**Gaming:** steam, lutris

**Music:** spotify

**Graphics:** gimp, inkscape, blender, krita

**Video Editing:** obs, kdenlive

**Office:** libreoffice

**Utilities:** keepassxc, transmission, filezilla

**Terminals:** kitty, alacritty

## Usage Examples

### Example 1: Basic Installation

```bash
# Install Firefox (tries native → flatpak → snap)
pkg_cascade_install firefox

# Check installation method
method=$(pkg_cascade_verify firefox)
echo "Installed via: $method"

# Get version
version=$(pkg_cascade_version firefox)
echo "Version: $version"
```

### Example 2: Batch Installation with Snapshot

```bash
# Create snapshot before installation
pkg_snapshot_create before-dev-tools

# Install development tools
pkg_cascade_batch code sublime atom

# Verify installations
for app in code sublime atom; do
    if pkg_cascade_verify "$app" &>/dev/null; then
        echo "$app installed successfully"
    fi
done
```

### Example 3: Custom Application

```bash
# Define custom application
pkg_cascade_define my-tool "native:mytool|flatpak:com.example.MyTool"

# Show available methods
pkg_cascade_show_methods my-tool

# Install
pkg_cascade_install my-tool
```

### Example 4: Prefer Flatpak for Security

```bash
# Set Flatpak as first priority
pkg_set_method_priority flatpak native snap appimage

# Now all installations prefer Flatpak
pkg_cascade_install firefox
pkg_cascade_install vlc
```

### Example 5: AppImage Installation

```bash
# Install balenaEtcher as AppImage
pkg_appimage_install balena-etcher \
    "https://github.com/balena-io/etcher/releases/download/v1.18.11/balenaEtcher-1.18.11-x64.AppImage" \
    "https://raw.githubusercontent.com/balena-io/etcher/master/assets/icon.png"

# List all AppImages
pkg_appimage_list

# Remove when done
pkg_appimage_remove balena-etcher
```

### Example 6: Safe Installation with Rollback

```bash
# Create safety snapshot
pkg_snapshot_create "safety-$(date +%Y%m%d)"

# Install application
if pkg_cascade_install new-app; then
    echo "Installation successful"
    # Create post-install snapshot
    pkg_snapshot_create "after-new-app-$(date +%Y%m%d)"
else
    echo "Installation failed"
    echo "Review snapshots for rollback:"
    pkg_snapshot_list
fi
```

## File Locations

```
$HOME/.local/state/ultimate-linux-suite/
├── transactions.log           # Installation transaction history
└── snapshots/                 # System snapshots
    └── *.snapshot            # Individual snapshot files

$HOME/.local/bin/
└── *.AppImage                # Installed AppImages

$HOME/.local/share/applications/
└── *.desktop                 # Desktop entries for AppImages
```

## Transaction Log Format

The transaction log uses pipe-delimited format:

```
timestamp|app_id|method|status|version|details
2025-12-22 10:30:45|firefox|native|SUCCESS|123.0|Package: firefox
2025-12-22 10:31:12|discord|flatpak|SUCCESS|0.0.119|ID: com.discordapp.Discord
2025-12-22 10:32:05|test-app|cascade|FAILED|N/A|All methods exhausted
```

## Snapshot Format

Snapshots capture:
- Native packages (via system package manager)
- Flatpak applications
- Snap packages
- AppImage files

Example snapshot:

```
# Snapshot created: 2025-12-22 10:30:00
# Hostname: mycomputer

[NATIVE_PACKAGES]
firefox 123.0-1
vlc 3.0.20-1

[FLATPAK_PACKAGES]
com.discordapp.Discord 0.0.119
org.gimp.GIMP 2.10.34

[SNAP_PACKAGES]
code 1.85.0
```

## Advanced Features

### Method-Specific Flags

Some methods support additional flags:

```bash
# Snap with --classic flag
[code]="snap:code:--classic"

# Flatpak with --user flag
[app]="flatpak:com.example.App:--user"

# AppImage with icon URL
[tool]="appimage:https://url/app.AppImage:https://url/icon.png"
```

### Custom Priority Scenarios

```bash
# Prefer sandboxed apps (Flatpak first)
pkg_set_method_priority flatpak snap native appimage

# Prefer system integration (native first)
pkg_set_method_priority native flatpak snap appimage

# Prefer portable apps (AppImage first)
pkg_set_method_priority appimage flatpak snap native
```

## Error Handling

The system handles errors gracefully:

1. **Method unavailable** - Skips to next method
2. **Installation fails** - Tries next method in priority order
3. **All methods fail** - Logs error and returns failure
4. **Already installed** - Returns success without reinstalling

All operations are logged to the transaction log for auditing.

## Integration with Ultimate Linux Suite

The module integrates seamlessly with existing modules:

- **logging.sh** - All operations use standard logging functions
- **pkg.sh** - Native package management functions
- **os_detect.sh** - Automatically detects system package manager

## Dependencies

Required modules:
- `lib/logging.sh`
- `lib/pkg.sh`

Optional system tools:
- `flatpak` - For Flatpak support
- `snap` - For Snap support
- `wget` or `curl` - For AppImage downloads

## Best Practices

1. **Create snapshots** before major changes
2. **Use batch installation** for multiple apps
3. **Set method priority** based on your needs
4. **Review transaction logs** after installations
5. **Prune old snapshots** regularly
6. **Define custom apps** for consistency
7. **Verify installations** after cascade install

## Troubleshooting

### Issue: Installation fails for all methods

```bash
# Check available methods
pkg_cascade_show_methods APP_ID

# Check transaction history
pkg_transaction_history APP_ID

# Verify method availability
flatpak_available && echo "Flatpak OK"
snap_available && echo "Snap OK"
```

### Issue: AppImage won't run

```bash
# Check executable permission
ls -l ~/.local/bin/*.AppImage

# Make executable if needed
chmod +x ~/.local/bin/APP.AppImage
```

### Issue: Snapshot restore needed

```bash
# List snapshots
pkg_snapshot_list

# View snapshot contents
less ~/.local/state/ultimate-linux-suite/snapshots/SNAPSHOT.snapshot

# Manually restore packages as needed
```

## Examples Script

Run the interactive examples script:

```bash
./lib/pkg_cascade_example.sh
```

This provides 12 interactive examples demonstrating all features.

## License

Part of the Ultimate Linux Suite project.

## Contributing

To add new application definitions, edit the `APP_DEFINITIONS` array in `pkg_cascade.sh`:

```bash
declare -gA APP_DEFINITIONS=(
    [myapp]="native:pkg-name|flatpak:com.example.App|snap:snap-name"
)
```

## Support

For issues or questions:
1. Check transaction logs: `pkg_transaction_history`
2. Review snapshots: `pkg_snapshot_list`
3. Check this README for examples
4. Review the examples script: `./lib/pkg_cascade_example.sh`
