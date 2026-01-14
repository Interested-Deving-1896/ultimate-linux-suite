#!/usr/bin/env bash
# OffTrack Suite - MacBook Broadcom WiFi Configuration
# Configures BCM43602 and other Broadcom WiFi adapters
# License: GPL-3.0-or-later

[[ -n "${_MACBOOK_WIFI_LOADED:-}" ]] && return 0
readonly _MACBOOK_WIFI_LOADED=1

# Configuration
FIRMWARE_DIR="/lib/firmware/brcm"
BACKUP_FIRMWARE_DIR="$SUITE_ROOT/data/firmware/brcmfmac"

# Configure Broadcom WiFi
macbook_wifi_configure() {
    log_section "Configuring Broadcom WiFi"

    require_root

    # Create safety snapshot
    safety_checkpoint "macbook-wifi"

    # Detect WiFi chip
    macbook_detect_wifi

    if [[ -z "$MACBOOK_WIFI_CHIP" ]]; then
        log_error "No Broadcom WiFi chip detected"
        return 1
    fi

    log_info "Detected WiFi chip: $MACBOOK_WIFI_CHIP"

    # Install firmware packages
    log_info "Installing WiFi firmware packages..."
    case "$OS_FAMILY" in
        fedora)
            # Enable RPM Fusion for firmware
            safe_exec dnf install -y \
                https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
                2>/dev/null || true
            pkg_install broadcom-wl linux-firmware
            ;;
        debian)
            # Add non-free repository
            pkg_install firmware-brcm80211 firmware-b43-installer
            ;;
        arch)
            pkg_install linux-firmware broadcom-wl-dkms
            ;;
    esac

    # Ensure firmware directory exists
    safe_exec mkdir -p "$FIRMWARE_DIR"

    # Copy backup firmware if available
    if [[ -d "$BACKUP_FIRMWARE_DIR" ]]; then
        log_info "Copying backup firmware files..."
        safe_exec cp -n "$BACKUP_FIRMWARE_DIR"/* "$FIRMWARE_DIR/" 2>/dev/null || true
    fi

    # Configure firmware for specific chips
    case "$MACBOOK_WIFI_CHIP" in
        bcm43602)
            configure_bcm43602
            ;;
        bcm4350)
            configure_bcm4350
            ;;
        *)
            log_info "Using default firmware configuration"
            ;;
    esac

    # Reload WiFi driver
    log_info "Reloading WiFi driver..."
    safe_exec modprobe -r brcmfmac 2>/dev/null || true
    sleep 1
    safe_exec modprobe brcmfmac

    # Check status
    sleep 2
    if ip link show | grep -q "wlan\|wlp"; then
        log_success "WiFi interface detected"
        ip link show | grep -E "wlan|wlp"
    else
        log_warn "WiFi interface not detected - may need reboot"
    fi

    log_success "Broadcom WiFi configuration complete"
}

# Configure BCM43602
configure_bcm43602() {
    log_info "Configuring BCM43602..."

    local fw_txt="$FIRMWARE_DIR/brcmfmac43602-pcie.txt"

    # Check if firmware text file exists
    if [[ ! -f "$fw_txt" ]]; then
        log_info "Creating firmware configuration..."

        # Try to copy from backup
        if [[ -f "$BACKUP_FIRMWARE_DIR/brcmfmac43602-pcie.txt" ]]; then
            safe_exec cp "$BACKUP_FIRMWARE_DIR/brcmfmac43602-pcie.txt" "$fw_txt"
        fi
    fi

    # Create symlink if needed
    local product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if [[ -n "$product_name" ]]; then
        local fw_link="$FIRMWARE_DIR/brcmfmac43602-pcie.Apple Inc.-${product_name}.txt"
        if [[ ! -f "$fw_link" ]] && [[ -f "$fw_txt" ]]; then
            safe_exec ln -sf "$(basename "$fw_txt")" "$fw_link"
        fi
    fi
}

# Configure BCM4350
configure_bcm4350() {
    log_info "Configuring BCM4350..."

    # Similar configuration for BCM4350
    local fw_txt="$FIRMWARE_DIR/brcmfmac4350-pcie.txt"

    if [[ ! -f "$fw_txt" ]] && [[ -f "$BACKUP_FIRMWARE_DIR/brcmfmac4350-pcie.txt" ]]; then
        safe_exec cp "$BACKUP_FIRMWARE_DIR/brcmfmac4350-pcie.txt" "$fw_txt"
    fi
}

# Check WiFi status
macbook_wifi_status() {
    echo "WiFi Status:"
    echo ""

    # Check driver
    if lsmod | grep -q "brcmfmac\|wl"; then
        echo "Driver: loaded"
        lsmod | grep -E "brcmfmac|wl" | head -3
    else
        echo "Driver: not loaded"
    fi

    echo ""

    # Check interface
    echo "Interfaces:"
    ip link show | grep -E "wlan|wlp" || echo "  No WiFi interfaces found"

    echo ""

    # Check firmware
    echo "Firmware files:"
    ls -la "$FIRMWARE_DIR"/brcmfmac* 2>/dev/null | head -10 || echo "  No firmware files found"
}

# Scan for networks
macbook_wifi_scan() {
    # Use iw dev for more robust interface detection
    local iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')

    # Fallback to ip link if iw not available
    if [[ -z "$iface" ]]; then
        iface=$(ip link show | grep -oE "wlan[0-9]+|wlp[0-9a-z]+s[0-9a-z]+" | head -1)
    fi

    if [[ -z "$iface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi

    log_info "Scanning for networks on $iface..."
    sudo iw dev "$iface" scan 2>/dev/null | grep -E "SSID:|signal:" | head -20
}
