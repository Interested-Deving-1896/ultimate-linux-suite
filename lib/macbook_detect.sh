#!/usr/bin/env bash
# Unified Suite - MacBook Detection
# Source: OffTrack Suite (updated)
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_MACBOOK_DETECT_LOADED:-}" ]] && return 0
readonly _UNIFIED_MACBOOK_DETECT_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"

# ============================================================
# MACBOOK DETECTION
# ============================================================

declare -g MACBOOK_MODEL=""
declare -g MACBOOK_YEAR=""
declare -g MACBOOK_GENERATION=""
declare -g IS_MACBOOK=0

# Known MacBook models requiring Linux support
declare -A MACBOOK_MODELS=(
    ["MacBookPro16,1"]="MacBook Pro 16-inch 2019"
    ["MacBookPro16,2"]="MacBook Pro 13-inch 2020 (4 TB3)"
    ["MacBookPro16,3"]="MacBook Pro 13-inch 2020 (2 TB3)"
    ["MacBookPro16,4"]="MacBook Pro 16-inch 2019"
    ["MacBookPro15,1"]="MacBook Pro 15-inch 2018/2019"
    ["MacBookPro15,2"]="MacBook Pro 13-inch 2018/2019"
    ["MacBookPro15,3"]="MacBook Pro 15-inch 2019 (Vega)"
    ["MacBookPro15,4"]="MacBook Pro 13-inch 2019 (2 TB3)"
    ["MacBookPro14,1"]="MacBook Pro 13-inch 2017"
    ["MacBookPro14,2"]="MacBook Pro 13-inch 2017 (4 TB3)"
    ["MacBookPro14,3"]="MacBook Pro 15-inch 2017"
    ["MacBookPro13,1"]="MacBook Pro 13-inch 2016"
    ["MacBookPro13,2"]="MacBook Pro 13-inch 2016 (4 TB3)"
    ["MacBookPro13,3"]="MacBook Pro 15-inch 2016"
    ["MacBookAir9,1"]="MacBook Air 2020"
    ["MacBookAir8,2"]="MacBook Air 2019"
    ["MacBookAir8,1"]="MacBook Air 2018"
)

# Detect if running on MacBook
is_macbook() {
    [[ $IS_MACBOOK -eq 1 ]]
}

# Detect MacBook model
macbook_detect() {
    # Check system vendor
    local vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")

    if [[ "$vendor" != "Apple Inc." ]]; then
        IS_MACBOOK=0
        log_debug "Not a MacBook (vendor: $vendor)"
        return 1
    fi

    # Get product name
    local product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")

    if [[ -z "$product" ]]; then
        IS_MACBOOK=0
        log_debug "Could not determine Apple product"
        return 1
    fi

    IS_MACBOOK=1
    MACBOOK_MODEL="$product"

    # Get human-readable name
    if [[ -n "${MACBOOK_MODELS[$product]:-}" ]]; then
        MACBOOK_GENERATION="${MACBOOK_MODELS[$product]}"
    else
        MACBOOK_GENERATION="Unknown MacBook ($product)"
    fi

    # Extract year from model
    case "$product" in
        *16,*) MACBOOK_YEAR="2019-2020" ;;
        *15,*) MACBOOK_YEAR="2018-2019" ;;
        *14,*) MACBOOK_YEAR="2017" ;;
        *13,*) MACBOOK_YEAR="2016" ;;
        *9,*|*8,*) MACBOOK_YEAR="2018-2020" ;;
        *) MACBOOK_YEAR="Unknown" ;;
    esac

    log_debug "MacBook detected: $MACBOOK_GENERATION (Year: $MACBOOK_YEAR)"
    return 0
}

# Print MacBook info
print_macbook_info() {
    if ! is_macbook; then
        echo "Not running on a MacBook"
        return 1
    fi

    log_section "MacBook Information"
    echo "Model ID: $MACBOOK_MODEL"
    echo "Model: $MACBOOK_GENERATION"
    echo "Year: $MACBOOK_YEAR"
    echo ""

    # Check driver status
    echo "Driver Status:"

    # SPI keyboard/trackpad
    if lsmod | grep -q "apple_spi"; then
        echo "  SPI (Keyboard/Trackpad): Loaded"
    else
        echo "  SPI (Keyboard/Trackpad): Not loaded"
    fi

    # Audio
    if lsmod | grep -q "snd_hda_codec_cirrus"; then
        echo "  Audio (Cirrus): Loaded"
    else
        echo "  Audio (Cirrus): Not loaded"
    fi

    # WiFi
    if lsmod | grep -q "brcmfmac"; then
        echo "  WiFi (Broadcom): Loaded"
    else
        echo "  WiFi (Broadcom): Not loaded"
    fi

    # Bluetooth
    if lsmod | grep -q "bluetooth"; then
        echo "  Bluetooth: Loaded"
    else
        echo "  Bluetooth: Not loaded"
    fi

    echo ""

    # Check for common issues
    echo "Known Issues Check:"

    # Keyboard working?
    if [[ -e /dev/input/by-path/*-event-kbd ]]; then
        echo "  Keyboard: Working"
    else
        echo "  Keyboard: May need driver installation"
    fi

    # Audio working?
    if command -v pactl &>/dev/null && pactl list sinks 2>/dev/null | grep -q "Running"; then
        echo "  Audio: Working"
    else
        echo "  Audio: May need configuration"
    fi

    # WiFi working?
    if ip link show 2>/dev/null | grep -q "wlan\|wlp"; then
        echo "  WiFi: Interface detected"
    else
        echo "  WiFi: May need firmware/driver"
    fi
}

# ============================================================
# DRIVER REQUIREMENT CHECKS
# ============================================================

# Check if SPI driver is needed (keyboard/trackpad)
macbook_needs_spi_driver() {
    if ! is_macbook; then
        return 1
    fi

    # Check if apple_spi module is already loaded
    if lsmod | grep -q "apple_spi\|applespi"; then
        return 1  # Already working
    fi

    # Check if internal keyboard is detected
    if [[ -e /dev/input/by-path/*-event-kbd ]]; then
        # Keyboard exists, check if it's USB (external) or internal
        local kbd_path=$(ls /dev/input/by-path/*-event-kbd 2>/dev/null | head -1)
        if [[ "$kbd_path" == *"usb"* ]]; then
            return 0  # Only USB keyboard, needs SPI driver
        fi
        return 1  # Internal keyboard working
    fi

    return 0  # No keyboard detected, needs driver
}

# Check if audio driver is needed
macbook_needs_audio_driver() {
    if ! is_macbook; then
        return 1
    fi

    # Check if Cirrus codec driver is loaded
    if lsmod | grep -q "snd_hda_codec_cs8409\|snd_hda_macbookpro"; then
        return 1  # Already loaded
    fi

    # Check if any audio device is working
    if command -v pactl &>/dev/null; then
        if pactl list sinks 2>/dev/null | grep -qi "running\|idle"; then
            return 1  # Audio is working
        fi
    fi

    # Check for Cirrus hardware
    if lspci 2>/dev/null | grep -qi "cirrus\|cs8409"; then
        return 0  # Has Cirrus chip, needs driver
    fi

    # MacBook Pros 2016-2020 typically need audio driver
    case "$MACBOOK_MODEL" in
        MacBookPro1[3-6],*)
            return 0  # These models need Cirrus driver
            ;;
    esac

    return 1
}

# Check if WiFi configuration is needed
macbook_needs_wifi_config() {
    if ! is_macbook; then
        return 1
    fi

    # Check if WiFi interface exists
    if ip link show 2>/dev/null | grep -qE "wlan[0-9]|wlp"; then
        return 1  # WiFi interface exists
    fi

    # Check if brcmfmac module is loaded
    if lsmod | grep -q "brcmfmac"; then
        # Module loaded but no interface - might need firmware
        return 0
    fi

    # Check for Broadcom hardware
    if lspci 2>/dev/null | grep -qi "broadcom.*wireless\|bcm43"; then
        return 0  # Has Broadcom chip, needs config
    fi

    return 1
}

# Detect WiFi chip model
macbook_detect_wifi() {
    local chip=""

    # Try to detect from lspci
    local pci_info=$(lspci 2>/dev/null | grep -i "network\|wireless" | head -1)

    if echo "$pci_info" | grep -qi "bcm43602"; then
        chip="bcm43602"
    elif echo "$pci_info" | grep -qi "bcm4350"; then
        chip="bcm4350"
    elif echo "$pci_info" | grep -qi "bcm4360"; then
        chip="bcm4360"
    elif echo "$pci_info" | grep -qi "bcm4352"; then
        chip="bcm4352"
    elif echo "$pci_info" | grep -qi "broadcom"; then
        # Generic Broadcom detection based on MacBook model
        case "$MACBOOK_MODEL" in
            MacBookPro1[5-6],*)
                chip="bcm4364"
                ;;
            MacBookPro1[3-4],*)
                chip="bcm43602"
                ;;
            MacBookAir*)
                chip="bcm4350"
                ;;
            *)
                chip="bcm43xx"
                ;;
        esac
    fi

    echo "$chip"
}

# Initialize detection on source (don't fail if not MacBook)
macbook_detect || true
