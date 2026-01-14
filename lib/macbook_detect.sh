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

# Initialize detection on source (don't fail if not MacBook)
macbook_detect || true
