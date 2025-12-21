#!/usr/bin/env bash
#
# hardware_detect.sh - Hardware Detection for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# shellcheck disable=SC2034  # Variables exported for use by other modules

# Prevent multiple sourcing
[[ -n "${_HARDWARE_DETECT_LOADED:-}" ]] && return 0
readonly _HARDWARE_DETECT_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

_HW_DETECT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback (only log_debug is used here)
if ! declare -f log_debug &>/dev/null; then
    source "${_HW_DETECT_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback for log_debug
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# ============================================================================
# Hardware detection variables
# ============================================================================
declare -g CPU_MODEL=""
declare -g CPU_VENDOR=""
declare -g CPU_CORES=""
declare -g CPU_THREADS=""
declare -g CPU_FLAGS=""
declare -g CPU_HAS_AES=0
declare -g CPU_HAS_AVX=0
declare -g CPU_HAS_AVX2=0
declare -g CPU_HAS_SSE42=0
declare -g GPU_VENDOR=""
declare -g GPU_MODEL=""
declare -g RAM_TOTAL=""
declare -g RAM_TOTAL_GB=""
declare -g RAM_AVAILABLE=""
declare -g DISK_ROOT=""
declare -g DISK_SIZE=""
declare -g DISK_TYPE=""
declare -g DISK_FS=""

# WiFi detection variables
declare -g WIFI_VENDOR=""
declare -g WIFI_CHIPSET=""
declare -g WIFI_DRIVER=""

# Battery/Laptop detection
declare -g HAS_BATTERY=0
declare -g BATTERY_STATUS=""
declare -g BATTERY_PERCENT=""
declare -g BATTERY_CAPACITY=""
declare -g FORM_FACTOR=""
declare -g CHASSIS_TYPE=""

# Detect CPU information
detect_cpu() {
    if [[ -r /proc/cpuinfo ]]; then
        CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
        CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "?")

        # Detect vendor
        local vendor_id
        vendor_id=$(grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
        case "$vendor_id" in
            GenuineIntel) CPU_VENDOR="intel" ;;
            AuthenticAMD) CPU_VENDOR="amd" ;;
            *) CPU_VENDOR="${vendor_id,,}" ;;
        esac

        # Get CPU flags (useful for capability detection)
        CPU_FLAGS=$(grep -m1 "^flags" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)

        # Physical cores vs threads
        local physical
        physical=$(grep "cpu cores" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
        if [[ -n "$physical" ]]; then
            local sockets
            sockets=$(grep "physical id" /proc/cpuinfo 2>/dev/null | sort -u | wc -l)
            [[ "$sockets" -gt 0 ]] || sockets=1
            CPU_CORES=$((physical * sockets))
            CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo)
        else
            CPU_THREADS="$CPU_CORES"
        fi

        # Detect CPU features
        if echo "$CPU_FLAGS" | grep -qw "aes"; then
            CPU_HAS_AES=1
        fi
        if echo "$CPU_FLAGS" | grep -qw "avx"; then
            CPU_HAS_AVX=1
        fi
        if echo "$CPU_FLAGS" | grep -qw "avx2"; then
            CPU_HAS_AVX2=1
        fi
        if echo "$CPU_FLAGS" | grep -qw "sse4_2"; then
            CPU_HAS_SSE42=1
        fi
    fi

    [[ -z "$CPU_MODEL" ]] && CPU_MODEL="Unknown CPU"
    [[ -z "$CPU_VENDOR" ]] && CPU_VENDOR="unknown"

    local features=""
    [[ $CPU_HAS_AES -eq 1 ]] && features="${features}AES "
    [[ $CPU_HAS_AVX -eq 1 ]] && features="${features}AVX "
    [[ $CPU_HAS_AVX2 -eq 1 ]] && features="${features}AVX2 "
    [[ $CPU_HAS_SSE42 -eq 1 ]] && features="${features}SSE4.2 "
    features="${features% }"  # Remove trailing space

    log_debug "CPU: $CPU_MODEL ($CPU_VENDOR, $CPU_CORES cores, $CPU_THREADS threads)"
    [[ -n "$features" ]] && log_debug "CPU Features: $features"
}

# Detect GPU information
detect_gpu() {
    GPU_VENDOR="unknown"
    GPU_MODEL="Unknown GPU"

    if cmd_exists lspci; then
        local gpu_info
        gpu_info=$(lspci 2>/dev/null | grep -iE "vga|3d|display" | head -1)

        if [[ -n "$gpu_info" ]]; then
            GPU_MODEL=$(echo "$gpu_info" | sed 's/.*: //')

            if echo "$gpu_info" | grep -qi "nvidia"; then
                GPU_VENDOR="nvidia"
            elif echo "$gpu_info" | grep -qi "amd\|radeon\|ati"; then
                GPU_VENDOR="amd"
            elif echo "$gpu_info" | grep -qi "intel"; then
                GPU_VENDOR="intel"
            fi
        fi
    else
        log_debug "lspci not found, GPU detection limited"
    fi

    log_debug "GPU: $GPU_MODEL (vendor: $GPU_VENDOR)"
}

# Detect RAM
detect_ram() {
    if [[ -r /proc/meminfo ]]; then
        local mem_kb avail_kb
        mem_kb=$(grep "MemTotal" /proc/meminfo 2>/dev/null | awk '{print $2}')
        avail_kb=$(grep "MemAvailable" /proc/meminfo 2>/dev/null | awk '{print $2}')
        if [[ -n "$mem_kb" ]]; then
            RAM_TOTAL="$mem_kb"
            RAM_TOTAL_GB=$(( mem_kb / 1024 / 1024 ))
        fi
        if [[ -n "$avail_kb" ]]; then
            RAM_AVAILABLE=$(( avail_kb / 1024 ))  # In MB
        fi
    fi

    [[ -z "$RAM_TOTAL_GB" ]] && RAM_TOTAL_GB="?"
    log_debug "RAM: ${RAM_TOTAL_GB}GB (${RAM_AVAILABLE:-?}MB available)"
}

# Detect root disk
detect_disk() {
    DISK_ROOT="unknown"
    DISK_SIZE="?"
    DISK_TYPE="unknown"
    DISK_FS="unknown"

    # Find root device and filesystem
    local root_dev
    root_dev=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/\[.*\]//')
    DISK_FS=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")

    if [[ -n "$root_dev" ]]; then
        # Get base device (remove partition number)
        local base_dev
        base_dev=$(echo "$root_dev" | sed 's/[0-9]*$//' | sed 's/p$//')
        DISK_ROOT="$base_dev"

        # Get size
        if cmd_exists lsblk; then
            DISK_SIZE=$(lsblk -dno SIZE "$base_dev" 2>/dev/null || echo "?")
        fi

        # Detect type (nvme, ssd, hdd)
        local disk_name
        disk_name=$(basename "$base_dev")
        if [[ "$disk_name" == nvme* ]]; then
            DISK_TYPE="nvme"
        elif [[ -r "/sys/block/$disk_name/queue/rotational" ]]; then
            if [[ $(cat "/sys/block/$disk_name/queue/rotational") == "0" ]]; then
                DISK_TYPE="ssd"
            else
                DISK_TYPE="hdd"
            fi
        fi
    fi

    log_debug "Disk: $DISK_ROOT ($DISK_SIZE, $DISK_TYPE, $DISK_FS)"
}

# Detect network interfaces
detect_network() {
    local eth_count=0
    local wifi_count=0

    if [[ -d /sys/class/net ]]; then
        for iface in /sys/class/net/*; do
            local name
            name=$(basename "$iface")
            [[ "$name" == "lo" ]] && continue

            if [[ -d "$iface/wireless" ]]; then
                ((wifi_count++))
            elif [[ -r "$iface/type" ]] && [[ $(cat "$iface/type") == "1" ]]; then
                ((eth_count++))
            fi
        done
    fi

    log_debug "Network: $eth_count ethernet, $wifi_count wifi"
}

# Detect WiFi chipset details
detect_wifi() {
    WIFI_VENDOR="none"
    WIFI_CHIPSET=""
    WIFI_DRIVER=""

    if ! cmd_exists lspci; then
        log_debug "lspci not available for WiFi detection"
        return 0
    fi

    # Check PCI WiFi devices
    local wifi_pci
    wifi_pci=$(lspci 2>/dev/null | grep -iE "network|wireless|wifi" | head -1)

    if [[ -n "$wifi_pci" ]]; then
        WIFI_CHIPSET=$(echo "$wifi_pci" | sed 's/.*: //')

        # Determine vendor
        if echo "$wifi_pci" | grep -qi "intel"; then
            WIFI_VENDOR="intel"
        elif echo "$wifi_pci" | grep -qi "broadcom"; then
            WIFI_VENDOR="broadcom"
        elif echo "$wifi_pci" | grep -qi "realtek"; then
            WIFI_VENDOR="realtek"
        elif echo "$wifi_pci" | grep -qi "atheros\|qualcomm"; then
            WIFI_VENDOR="atheros"
        elif echo "$wifi_pci" | grep -qi "mediatek\|ralink"; then
            WIFI_VENDOR="mediatek"
        fi

        # Try to find the driver in use
        local pci_slot
        pci_slot=$(echo "$wifi_pci" | awk '{print $1}')
        if [[ -n "$pci_slot" ]] && [[ -d "/sys/bus/pci/devices/0000:$pci_slot/driver" ]]; then
            WIFI_DRIVER=$(basename "$(readlink -f "/sys/bus/pci/devices/0000:$pci_slot/driver")")
        fi
    fi

    # Check USB WiFi devices (common for Realtek)
    if [[ "$WIFI_VENDOR" == "none" ]] && cmd_exists lsusb; then
        local wifi_usb
        wifi_usb=$(lsusb 2>/dev/null | grep -iE "wireless|wifi|wlan|802.11|rtl8|r8" | head -1)

        if [[ -n "$wifi_usb" ]]; then
            WIFI_CHIPSET=$(echo "$wifi_usb" | sed 's/.*ID [0-9a-f:]* //')

            if echo "$wifi_usb" | grep -qi "realtek\|rtl8\|r8"; then
                WIFI_VENDOR="realtek"
                # Detect specific Realtek USB chipsets
                if echo "$wifi_usb" | grep -qi "8821\|8812"; then
                    WIFI_CHIPSET="Realtek RTL8821/8812AU"
                elif echo "$wifi_usb" | grep -qi "8152\|8153"; then
                    WIFI_CHIPSET="Realtek RTL8152/8153"
                fi
            elif echo "$wifi_usb" | grep -qi "ralink\|mediatek"; then
                WIFI_VENDOR="mediatek"
            fi
        fi
    fi

    log_debug "WiFi: $WIFI_VENDOR - $WIFI_CHIPSET (driver: ${WIFI_DRIVER:-unknown})"
}

# Detect battery and form factor
detect_battery() {
    HAS_BATTERY=0
    BATTERY_STATUS=""
    BATTERY_PERCENT=""
    FORM_FACTOR="desktop"

    # Check for battery
    if [[ -d /sys/class/power_supply ]]; then
        for supply in /sys/class/power_supply/*; do
            [[ -d "$supply" ]] || continue
            if [[ -r "$supply/type" ]]; then
                local type
                type=$(cat "$supply/type" 2>/dev/null)
                if [[ "$type" == "Battery" ]]; then
                    HAS_BATTERY=1
                    FORM_FACTOR="laptop"

                    # Get battery status
                    [[ -r "$supply/status" ]] && BATTERY_STATUS=$(cat "$supply/status")

                    # Get battery percentage
                    if [[ -r "$supply/capacity" ]]; then
                        BATTERY_PERCENT=$(cat "$supply/capacity")
                    elif [[ -r "$supply/energy_now" ]] && [[ -r "$supply/energy_full" ]]; then
                        local now full
                        now=$(cat "$supply/energy_now")
                        full=$(cat "$supply/energy_full")
                        [[ "$full" -gt 0 ]] && BATTERY_PERCENT=$((now * 100 / full))
                    fi

                    # Get battery capacity (design capacity)
                    if [[ -r "$supply/energy_full_design" ]]; then
                        local design_wh
                        design_wh=$(cat "$supply/energy_full_design")
                        BATTERY_CAPACITY=$((design_wh / 1000000))  # Convert to Wh
                    elif [[ -r "$supply/charge_full_design" ]]; then
                        local design_ah
                        design_ah=$(cat "$supply/charge_full_design")
                        BATTERY_CAPACITY=$((design_ah / 1000000))  # Convert to Ah
                    fi

                    break
                fi
            fi
        done
    fi

    # Additional form factor detection via DMI
    if [[ -r /sys/class/dmi/id/chassis_type ]]; then
        local chassis
        chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
        case "$chassis" in
            3|4|5|6|7|15|16) FORM_FACTOR="desktop" ;;
            8|9|10|11|12|14|18|21|31|32) FORM_FACTOR="laptop" ;;
            17|23) FORM_FACTOR="server" ;;
            1) FORM_FACTOR="other" ;;
        esac
    fi

    log_debug "Battery: ${HAS_BATTERY} (${BATTERY_PERCENT:-?}% ${BATTERY_STATUS:-}), Form: $FORM_FACTOR"
}

# Detect chassis type - returns "desktop", "laptop", "server", or "vm"
detect_chassis_type() {
    CHASSIS_TYPE="desktop"

    # Check if running in a VM first
    if [[ -r /sys/class/dmi/id/product_name ]]; then
        local product_name
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if echo "$product_name" | grep -qE "virtualbox|vmware|qemu|kvm|xen|hyperv|virtual machine"; then
            CHASSIS_TYPE="vm"
            log_debug "Chassis: $CHASSIS_TYPE (detected from product name)"
            return 0
        fi
    fi

    if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        local sys_vendor
        sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if echo "$sys_vendor" | grep -qE "qemu|bochs|virtualbox|vmware|xen|microsoft corporation"; then
            CHASSIS_TYPE="vm"
            log_debug "Chassis: $CHASSIS_TYPE (detected from sys vendor)"
            return 0
        fi
    fi

    # Check dmidecode if available for VM detection
    if cmd_exists dmidecode && [[ $EUID -eq 0 ]]; then
        local dmi_info
        dmi_info=$(dmidecode -s system-product-name 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if echo "$dmi_info" | grep -qE "virtualbox|vmware|qemu|kvm|xen|hyperv|virtual"; then
            CHASSIS_TYPE="vm"
            log_debug "Chassis: $CHASSIS_TYPE (detected via dmidecode)"
            return 0
        fi
    fi

    # Check for chassis type from DMI
    if [[ -r /sys/class/dmi/id/chassis_type ]]; then
        local chassis
        chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
        case "$chassis" in
            3|4|5|6|7|15|16)  # Desktop variants
                CHASSIS_TYPE="desktop"
                ;;
            8|9|10|11|12|14|18|21|31|32)  # Laptop/portable variants
                CHASSIS_TYPE="laptop"
                ;;
            17|23)  # Server/rack mount
                CHASSIS_TYPE="server"
                ;;
            1)  # Other
                CHASSIS_TYPE="desktop"
                ;;
        esac
    fi

    # Check for battery as fallback indicator for laptop
    if [[ "$CHASSIS_TYPE" == "desktop" ]] && [[ -d /sys/class/power_supply ]]; then
        for supply in /sys/class/power_supply/*; do
            if [[ -r "$supply/type" ]]; then
                local type
                type=$(cat "$supply/type" 2>/dev/null)
                if [[ "$type" == "Battery" ]]; then
                    CHASSIS_TYPE="laptop"
                    break
                fi
            fi
        done
    fi

    log_debug "Chassis: $CHASSIS_TYPE"
}

# Get battery information - returns formatted string or empty if no battery
get_battery_info() {
    if [[ $HAS_BATTERY -eq 0 ]]; then
        echo ""
        return 1
    fi

    local info="Battery: ${BATTERY_PERCENT:-?}% (${BATTERY_STATUS:-unknown})"
    if [[ -n "$BATTERY_CAPACITY" ]] && [[ "$BATTERY_CAPACITY" -gt 0 ]]; then
        info="$info, ${BATTERY_CAPACITY}Wh"
    fi
    echo "$info"
    return 0
}

# Get system profile recommendation based on hardware
# Returns: gaming, desktop, laptop, server, low_ram, high_ram
get_system_profile_recommendation() {
    local profile="desktop"

    # Ensure hardware is detected
    if [[ -z "$RAM_TOTAL_GB" ]] || [[ -z "$CHASSIS_TYPE" ]]; then
        detect_hardware >/dev/null 2>&1
    fi

    # Check chassis type first
    case "$CHASSIS_TYPE" in
        vm)
            profile="desktop"
            ;;
        server)
            profile="server"
            ;;
        laptop)
            profile="laptop"
            ;;
    esac

    # RAM-based adjustments
    local ram_gb=${RAM_TOTAL_GB:-0}
    if [[ "$ram_gb" =~ ^[0-9]+$ ]]; then
        if [[ $ram_gb -le 4 ]]; then
            profile="low_ram"
        elif [[ $ram_gb -ge 32 ]]; then
            # High RAM could be server or high-end workstation
            if [[ "$CHASSIS_TYPE" == "server" ]] || [[ $CPU_CORES -ge 16 ]]; then
                profile="server"
            else
                profile="high_ram"
            fi
        fi
    fi

    # Gaming detection - discrete NVIDIA/AMD GPU + desktop/high_ram
    if [[ "$GPU_VENDOR" == "nvidia" ]] || [[ "$GPU_VENDOR" == "amd" ]]; then
        # Exclude integrated GPUs by checking if it's a desktop with good specs
        if [[ "$CHASSIS_TYPE" == "desktop" ]] || [[ "$CHASSIS_TYPE" == "vm" ]]; then
            if [[ $ram_gb -ge 16 ]] && [[ $CPU_CORES -ge 4 ]]; then
                # Check if it's likely a discrete GPU (not integrated)
                if ! echo "$GPU_MODEL" | grep -qiE "integrated|vega [0-9]+ graphics|uhd|iris"; then
                    profile="gaming"
                fi
            fi
        fi
    fi

    # Low RAM overrides everything except explicit laptop
    if [[ $ram_gb -le 4 ]] && [[ "$profile" != "laptop" ]]; then
        profile="low_ram"
    fi

    echo "$profile"
}

# Main detection function
detect_hardware() {
    log_debug "Starting hardware detection..."

    detect_cpu
    detect_gpu
    detect_ram
    detect_disk
    detect_network
    detect_wifi
    detect_battery
    detect_chassis_type

    log_debug "Hardware detection complete"
}

# Print hardware summary
print_hardware_summary() {
    printf "CPU: %s (%s)\n" "$CPU_MODEL" "$CPU_VENDOR"
    printf "     Cores: %s, Threads: %s\n" "$CPU_CORES" "$CPU_THREADS"
    printf "GPU: %s\n" "$GPU_MODEL"
    printf "     Vendor: %s\n" "$GPU_VENDOR"
    printf "RAM: %sGB total (%sMB available)\n" "$RAM_TOTAL_GB" "${RAM_AVAILABLE:-?}"
    printf "Disk: %s (%s, %s, %s)\n" "$DISK_ROOT" "$DISK_SIZE" "$DISK_TYPE" "$DISK_FS"
    if [[ "$WIFI_VENDOR" != "none" ]]; then
        printf "WiFi: %s (%s)\n" "$WIFI_CHIPSET" "$WIFI_VENDOR"
        [[ -n "$WIFI_DRIVER" ]] && printf "      Driver: %s\n" "$WIFI_DRIVER"
    fi
    printf "Form Factor: %s\n" "$FORM_FACTOR"
    if [[ "$HAS_BATTERY" -eq 1 ]]; then
        printf "Battery: %s%% (%s)\n" "${BATTERY_PERCENT:-?}" "${BATTERY_STATUS:-unknown}"
    fi
}

# JSON output for CPU information
detect_cpu_json() {
    # Ensure CPU is detected
    if [[ -z "$CPU_MODEL" ]]; then
        detect_cpu >/dev/null 2>&1
    fi

    cat <<EOF
{
  "model": "${CPU_MODEL}",
  "vendor": "${CPU_VENDOR}",
  "cores": ${CPU_CORES:-0},
  "threads": ${CPU_THREADS:-0},
  "features": {
    "aes": ${CPU_HAS_AES},
    "avx": ${CPU_HAS_AVX},
    "avx2": ${CPU_HAS_AVX2},
    "sse4_2": ${CPU_HAS_SSE42}
  }
}
EOF
}

# JSON output for GPU information
detect_gpu_json() {
    # Ensure GPU is detected
    if [[ -z "$GPU_MODEL" ]]; then
        detect_gpu >/dev/null 2>&1
    fi

    # Escape double quotes in GPU_MODEL for JSON
    local gpu_model_escaped="${GPU_MODEL//\"/\\\"}"

    cat <<EOF
{
  "model": "${gpu_model_escaped}",
  "vendor": "${GPU_VENDOR}"
}
EOF
}

# JSON output for RAM information
detect_ram_json() {
    # Ensure RAM is detected
    if [[ -z "$RAM_TOTAL_GB" ]]; then
        detect_ram >/dev/null 2>&1
    fi

    cat <<EOF
{
  "total_kb": ${RAM_TOTAL:-0},
  "total_gb": ${RAM_TOTAL_GB:-0},
  "available_mb": ${RAM_AVAILABLE:-0}
}
EOF
}

# Get complete hardware summary as JSON
get_hardware_summary_json() {
    # Ensure all hardware is detected
    if [[ -z "$CPU_MODEL" ]] || [[ -z "$GPU_MODEL" ]] || [[ -z "$RAM_TOTAL_GB" ]]; then
        detect_hardware >/dev/null 2>&1
    fi

    # Escape strings for JSON
    local cpu_model_escaped="${CPU_MODEL//\"/\\\"}"
    local gpu_model_escaped="${GPU_MODEL//\"/\\\"}"
    local wifi_chipset_escaped="${WIFI_CHIPSET//\"/\\\"}"
    local disk_root_escaped="${DISK_ROOT//\"/\\\"}"
    local disk_size_escaped="${DISK_SIZE//\"/\\\"}"

    # Get recommended profile
    local profile
    profile=$(get_system_profile_recommendation)

    cat <<EOF
{
  "cpu": {
    "model": "${cpu_model_escaped}",
    "vendor": "${CPU_VENDOR}",
    "cores": ${CPU_CORES:-0},
    "threads": ${CPU_THREADS:-0},
    "features": {
      "aes": ${CPU_HAS_AES},
      "avx": ${CPU_HAS_AVX},
      "avx2": ${CPU_HAS_AVX2},
      "sse4_2": ${CPU_HAS_SSE42}
    }
  },
  "gpu": {
    "model": "${gpu_model_escaped}",
    "vendor": "${GPU_VENDOR}"
  },
  "ram": {
    "total_kb": ${RAM_TOTAL:-0},
    "total_gb": ${RAM_TOTAL_GB:-0},
    "available_mb": ${RAM_AVAILABLE:-0}
  },
  "disk": {
    "root_device": "${disk_root_escaped}",
    "size": "${disk_size_escaped}",
    "type": "${DISK_TYPE}",
    "filesystem": "${DISK_FS}"
  },
  "wifi": {
    "vendor": "${WIFI_VENDOR}",
    "chipset": "${wifi_chipset_escaped}",
    "driver": "${WIFI_DRIVER}"
  },
  "system": {
    "chassis_type": "${CHASSIS_TYPE}",
    "form_factor": "${FORM_FACTOR}",
    "has_battery": ${HAS_BATTERY},
    "battery": {
      "status": "${BATTERY_STATUS}",
      "percent": ${BATTERY_PERCENT:-0},
      "capacity": ${BATTERY_CAPACITY:-0}
    },
    "recommended_profile": "${profile}"
  }
}
EOF
}

# Get form factor (uses cached value if available)
get_form_factor() {
    # Return cached value if already detected
    if [[ -n "$FORM_FACTOR" ]]; then
        echo "$FORM_FACTOR"
        return 0
    fi

    # Fallback detection
    if [[ -d /sys/class/power_supply ]]; then
        for supply in /sys/class/power_supply/*; do
            if [[ -r "$supply/type" ]]; then
                local type
                type=$(cat "$supply/type")
                if [[ "$type" == "Battery" ]]; then
                    echo "laptop"
                    return 0
                fi
            fi
        done
    fi

    if [[ -r /sys/class/dmi/id/chassis_type ]]; then
        local chassis
        chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
        case "$chassis" in
            3|4|5|6|7|15|16) echo "desktop"; return 0 ;;
            8|9|10|11|12|14|18|21|31|32) echo "laptop"; return 0 ;;
            17|23) echo "server"; return 0 ;;
        esac
    fi

    echo "desktop"
}

# ============================================================================
# Hardware helper functions
# ============================================================================

# Check if laptop
uls_is_laptop() { [[ "$(get_form_factor)" == "laptop" ]]; }

# Check if desktop
uls_is_desktop() { [[ "$(get_form_factor)" == "desktop" ]]; }

# Check if has battery
uls_has_battery() { [[ "$HAS_BATTERY" -eq 1 ]]; }

# Get WiFi vendor
uls_get_wifi_vendor() { echo "$WIFI_VENDOR"; }

# Check WiFi vendors
uls_has_intel_wifi() { [[ "$WIFI_VENDOR" == "intel" ]]; }
uls_has_broadcom_wifi() { [[ "$WIFI_VENDOR" == "broadcom" ]]; }
uls_has_realtek_wifi() { [[ "$WIFI_VENDOR" == "realtek" ]]; }

# Check GPU vendors
uls_has_nvidia() { [[ "$GPU_VENDOR" == "nvidia" ]]; }
uls_has_amd_gpu() { [[ "$GPU_VENDOR" == "amd" ]]; }
uls_has_intel_gpu() { [[ "$GPU_VENDOR" == "intel" ]]; }

# Check storage type
uls_has_ssd() { [[ "$DISK_TYPE" == "ssd" ]] || [[ "$DISK_TYPE" == "nvme" ]]; }
uls_has_nvme() { [[ "$DISK_TYPE" == "nvme" ]]; }
uls_has_hdd() { [[ "$DISK_TYPE" == "hdd" ]]; }

# Check CPU feature flags
uls_cpu_has_flag() {
    local flag="$1"
    echo "$CPU_FLAGS" | grep -qw "$flag"
}
