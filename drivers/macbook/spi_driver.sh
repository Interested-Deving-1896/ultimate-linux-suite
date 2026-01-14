#!/usr/bin/env bash
# OffTrack Suite - MacBook SPI Driver Installation
# Installs macbook12-spi-driver for Touch Bar, keyboard, and trackpad
# License: GPL-3.0-or-later

[[ -n "${_MACBOOK_SPI_DRIVER_LOADED:-}" ]] && return 0
readonly _MACBOOK_SPI_DRIVER_LOADED=1

# Configuration
MACBOOK_SPI_REPO="https://github.com/roadrunner2/macbook12-spi-driver.git"
MACBOOK_SPI_BRANCH="touchbar-driver-hid-driver"
MACBOOK_SPI_DIR="/usr/src/macbook12-spi-driver"
MACBOOK_SPI_VERSION="0.1"
MACBOOK_SPI_CACHYOS=${MACBOOK_SPI_CACHYOS:-0}

# Install SPI driver
macbook_spi_install() {
    log_section "Installing macbook12-spi-driver"

    require_root

    # Create safety snapshot
    safety_checkpoint "macbook-spi"

    # Install build dependencies
    log_info "Installing build dependencies..."
    pkg_install_build_deps

    # Clone or update repository
    log_info "Fetching driver source..."
    if [[ -d "$MACBOOK_SPI_DIR" ]]; then
        log_info "Updating existing installation..."
        cd "$MACBOOK_SPI_DIR"
        safe_exec git fetch origin
        safe_exec git checkout "$MACBOOK_SPI_BRANCH"
        safe_exec git pull origin "$MACBOOK_SPI_BRANCH"
    else
        safe_exec git clone -b "$MACBOOK_SPI_BRANCH" "$MACBOOK_SPI_REPO" "$MACBOOK_SPI_DIR"
    fi

    cd "$MACBOOK_SPI_DIR"

    # Remove old DKMS installation if exists
    log_info "Removing old DKMS installation (if any)..."
    safe_exec dkms remove -m macbook12-spi-driver -v "$MACBOOK_SPI_VERSION" --all 2>/dev/null || true
    safe_exec dkms remove -m applespi -v "$MACBOOK_SPI_VERSION" --all 2>/dev/null || true

    # Add to DKMS
    log_info "Adding driver to DKMS..."
    safe_exec dkms add "$MACBOOK_SPI_DIR"

    # Build driver
    log_info "Building driver for kernel $(uname -r)..."
    safe_exec dkms build -m macbook12-spi-driver -v "$MACBOOK_SPI_VERSION"

    # Install driver
    log_info "Installing driver..."
    safe_exec dkms install -m macbook12-spi-driver -v "$MACBOOK_SPI_VERSION"

    # Configure dracut for early loading (Fedora/RHEL)
    if [[ "$OS_FAMILY" == "fedora" ]]; then
        log_info "Configuring dracut for early module loading..."
        local dracut_conf="/etc/dracut.conf.d/macbook-spi.conf"
        safe_exec bash -c "cat > '$dracut_conf' << 'EOF'
# MacBook SPI driver early loading
add_drivers+=\" intel_lpss_pci spi_pxa2xx_platform apple_ibridge apple_ib_tb apple_ib_als applespi \"
EOF"
    fi

    # Configure modules-load.d
    log_info "Configuring module autoload..."
    local modules_conf="/etc/modules-load.d/macbook-spi.conf"
    safe_exec bash -c "cat > '$modules_conf' << 'EOF'
# MacBook SPI drivers
intel_lpss_pci
spi_pxa2xx_platform
apple_ibridge
apple_ib_tb
apple_ib_als
applespi
EOF"

    # Disable usbmuxd (conflicts with Touch Bar)
    log_info "Disabling usbmuxd (conflicts with Touch Bar)..."
    safe_exec systemctl disable usbmuxd.service 2>/dev/null || true
    safe_exec systemctl stop usbmuxd.service 2>/dev/null || true

    # Load modules
    log_info "Loading driver modules..."
    for mod in intel_lpss_pci spi_pxa2xx_platform apple_ibridge apple_ib_tb applespi; do
        safe_exec modprobe "$mod" 2>/dev/null || true
    done

    # Rebuild initramfs
    log_info "Rebuilding initramfs..."
    case "$OS_FAMILY" in
        fedora)
            safe_exec dracut --force
            ;;
        debian)
            safe_exec update-initramfs -u
            ;;
        arch)
            safe_exec mkinitcpio -P
            ;;
    esac

    log_success "macbook12-spi-driver installed successfully"
    log_warn "A reboot is required for full functionality"
}

# Remove SPI driver
macbook_spi_remove() {
    log_section "Removing macbook12-spi-driver"

    require_root

    # Remove from DKMS
    safe_exec dkms remove -m macbook12-spi-driver -v "$MACBOOK_SPI_VERSION" --all 2>/dev/null || true

    # Remove source
    [[ -d "$MACBOOK_SPI_DIR" ]] && safe_exec rm -rf "$MACBOOK_SPI_DIR"

    # Remove module config
    safe_exec rm -f /etc/modules-load.d/macbook-spi.conf
    safe_exec rm -f /etc/dracut.conf.d/macbook-spi.conf

    # Re-enable usbmuxd
    safe_exec systemctl enable usbmuxd.service 2>/dev/null || true

    # Rebuild initramfs
    case "$OS_FAMILY" in
        fedora)
            safe_exec dracut --force
            ;;
        debian)
            safe_exec update-initramfs -u
            ;;
        arch)
            safe_exec mkinitcpio -P
            ;;
    esac

    log_success "macbook12-spi-driver removed"
}

# Check SPI driver status
macbook_spi_status() {
    echo "SPI Driver Status:"
    echo ""

    # Check if modules are loaded
    for mod in apple_ibridge apple_ib_tb applespi; do
        if lsmod | grep -q "$mod"; then
            echo "  $mod: LOADED"
        else
            echo "  $mod: not loaded"
        fi
    done

    echo ""

    # Check DKMS status
    if dkms status 2>/dev/null | grep -q "macbook12-spi-driver"; then
        echo "DKMS: installed"
        dkms status | grep "macbook12-spi-driver"
    else
        echo "DKMS: not installed"
    fi
}
