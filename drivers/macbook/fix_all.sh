#!/usr/bin/env bash
# OffTrack Suite - MacBook Fix All
# Installs all MacBook hardware drivers
# License: GPL-3.0-or-later

[[ -n "${_MACBOOK_FIX_ALL_LOADED:-}" ]] && return 0
readonly _MACBOOK_FIX_ALL_LOADED=1

# Source driver modules
source "$SUITE_ROOT/drivers/macbook/spi_driver.sh"
source "$SUITE_ROOT/drivers/macbook/audio_cirrus.sh"
source "$SUITE_ROOT/drivers/macbook/wifi_broadcom.sh"

# Fix all MacBook hardware
macbook_fix_all() {
    log_section "MacBook Hardware Fix - All-in-One"

    # Detect MacBook
    macbook_detect
    if [[ $MACBOOK_DETECTED -eq 0 ]]; then
        log_error "This does not appear to be a MacBook system"
        log_info "Product name: $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
        return 1
    fi

    log_info "Detected: $MACBOOK_MODEL"
    macbook_print_info

    require_root

    # Create master snapshot
    safety_checkpoint "macbook-fix-all"

    local needs_reboot=0

    # Step 1: Install build dependencies
    log_section "Step 1: Installing Build Dependencies"
    pkg_install_build_deps

    # Step 2: SPI Driver (if needed)
    if macbook_needs_spi_driver; then
        log_section "Step 2: Installing SPI Driver"
        log_info "Installing Touch Bar, keyboard, and trackpad support..."
        macbook_spi_install
        needs_reboot=1
    else
        log_section "Step 2: SPI Driver"
        log_info "SPI driver not needed or already installed"
    fi

    # Step 3: Audio Driver (if needed)
    if macbook_needs_audio_driver; then
        log_section "Step 3: Installing Audio Driver"
        log_info "Installing Cirrus CS8409 audio support..."
        macbook_audio_install
        needs_reboot=1
    else
        log_section "Step 3: Audio Driver"
        log_info "Audio driver not needed or already working"
    fi

    # Step 4: WiFi Configuration (if needed)
    if macbook_needs_wifi_config; then
        log_section "Step 4: Configuring WiFi"
        log_info "Configuring Broadcom WiFi..."
        macbook_wifi_configure
    else
        log_section "Step 4: WiFi Configuration"
        log_info "WiFi configuration not needed or already working"
    fi

    # Summary
    log_section "Installation Complete"
    echo ""
    echo "Summary:"
    echo "  Model: $MACBOOK_MODEL"
    echo "  SPI Driver: $(lsmod | grep -q applespi && echo 'loaded' || echo 'installed (reboot needed)')"
    echo "  Audio: $(aplay -l 2>/dev/null | grep -qi cirrus && echo 'working' || echo 'installed (reboot needed)')"
    echo "  WiFi: $(ip link show | grep -qE 'wlan|wlp' && echo 'detected' || echo 'configured')"
    echo ""

    if [[ $needs_reboot -eq 1 ]]; then
        log_warn "A REBOOT IS REQUIRED for all changes to take effect"
        echo ""
        if confirm "Reboot now?"; then
            log_info "Rebooting in 5 seconds..."
            sleep 5
            safe_exec reboot
        fi
    fi

    log_success "MacBook hardware fix complete"
}

# Quick status check
macbook_status_all() {
    log_section "MacBook Hardware Status"

    macbook_detect
    if [[ $MACBOOK_DETECTED -eq 0 ]]; then
        echo "Not a MacBook system"
        return 1
    fi

    macbook_print_info
    echo ""

    log_section "SPI Driver Status"
    macbook_spi_status
    echo ""

    log_section "Audio Status"
    macbook_audio_status
    echo ""

    log_section "WiFi Status"
    macbook_wifi_status
}
