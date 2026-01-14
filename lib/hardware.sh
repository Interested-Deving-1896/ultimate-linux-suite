#!/usr/bin/env bash
# Unified Suite - Hardware Abstraction
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_HARDWARE_LOADED:-}" ]] && return 0
readonly _UNIFIED_HARDWARE_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"

# ============================================================
# HARDWARE DETECTION
# ============================================================

# Get system vendor
get_system_vendor() {
    cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "Unknown"
}

# Get system product name
get_system_product() {
    cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown"
}

# Get chassis type
get_chassis_type() {
    local type_id=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "0")
    case "$type_id" in
        1)  echo "Other" ;;
        2)  echo "Unknown" ;;
        3)  echo "Desktop" ;;
        4)  echo "Low Profile Desktop" ;;
        5)  echo "Pizza Box" ;;
        6)  echo "Mini Tower" ;;
        7)  echo "Tower" ;;
        8)  echo "Portable" ;;
        9)  echo "Laptop" ;;
        10) echo "Notebook" ;;
        11) echo "Hand Held" ;;
        12) echo "Docking Station" ;;
        13) echo "All in One" ;;
        14) echo "Sub Notebook" ;;
        *)  echo "Unknown ($type_id)" ;;
    esac
}

# Detect GPU vendor
detect_gpu_vendor() {
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        echo "nvidia"
    elif lspci 2>/dev/null | grep -qi "amd\|radeon"; then
        echo "amd"
    elif lspci 2>/dev/null | grep -qi "intel"; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# Get GPU info
get_gpu_info() {
    lspci 2>/dev/null | grep -iE "vga|3d|display" | head -1 | cut -d: -f3 | xargs
}

# Check if VM
is_virtual_machine() {
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product=$(cat /sys/class/dmi/id/product_name)
        case "$product" in
            *Virtual*|*VMware*|*VirtualBox*|*KVM*|*QEMU*|*Hyper-V*)
                return 0
                ;;
        esac
    fi
    systemd-detect-virt -q 2>/dev/null && return 0
    return 1
}

# Get virtualization type
get_virtualization() {
    systemd-detect-virt 2>/dev/null || echo "none"
}

# ============================================================
# POWER PROFILES
# ============================================================

# Get recommended power profile
get_recommended_power_profile() {
    if is_laptop; then
        local bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
        if [[ "$bat_status" == "Discharging" ]]; then
            echo "powersave"
        else
            echo "balanced"
        fi
    else
        echo "performance"
    fi
}

# Get battery percentage
get_battery_percent() {
    if [[ -f /sys/class/power_supply/BAT0/capacity ]]; then
        cat /sys/class/power_supply/BAT0/capacity
    else
        echo "100"
    fi
}

# Get battery status
get_battery_status() {
    cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Not Present"
}

# ============================================================
# HARDWARE INFO DISPLAY
# ============================================================

print_hardware_info() {
    log_section "Hardware Information"

    echo "System:"
    echo "  Vendor: $(get_system_vendor)"
    echo "  Product: $(get_system_product)"
    echo "  Chassis: $(get_chassis_type)"
    echo "  Laptop: $(is_laptop && echo "Yes" || echo "No")"
    echo "  Virtual: $(is_virtual_machine && echo "Yes ($(get_virtualization))" || echo "No")"
    echo ""

    echo "CPU:"
    echo "  Model: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "  Cores: $(get_cpu_count)"
    echo "  Architecture: $(uname -m)"
    echo ""

    echo "Memory:"
    echo "  Total: $(get_total_ram_mb) MB"
    echo "  Available: $(get_available_ram_mb) MB"
    echo ""

    echo "GPU:"
    echo "  Vendor: $(detect_gpu_vendor)"
    echo "  Info: $(get_gpu_info)"
    echo ""

    echo "Storage:"
    local primary=$(get_primary_storage)
    echo "  Primary: $primary ($(get_storage_type "$primary"))"
    echo ""

    if is_laptop; then
        echo "Battery:"
        echo "  Status: $(get_battery_status)"
        echo "  Level: $(get_battery_percent)%"
    fi
}
