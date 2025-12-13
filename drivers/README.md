# Driver Vault

This directory contains driver helper scripts and documentation for problematic hardware.

## Structure

```
drivers/
├── broadcom/     - Broadcom WiFi drivers
├── realtek-r8152/ - Realtek USB Ethernet
├── realtek-r8821cu/ - Realtek USB WiFi
├── intel/        - Intel drivers
├── amd/          - AMD GPU drivers
└── nvidia/       - NVIDIA GPU drivers
```

## Usage

Most drivers are installed via the package manager. These directories contain:
- Installation scripts for DKMS drivers
- Documentation for manual installation
- Links to upstream sources

## Adding Drivers

To add a new driver:
1. Create a directory with the driver name
2. Add an `install.sh` script if manual installation is needed
3. Add a `README.md` with documentation
