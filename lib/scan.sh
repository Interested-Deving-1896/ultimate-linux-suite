#!/usr/bin/env bash
#
# scan.sh - Comprehensive Hardware Scanning Module for Ultimate Linux Suite
#
# This module provides deep hardware detection with JSON output for system profiling,
# optimization recommendations, and driver detection.
#
# Output: $STATE_DIR/hardware_scan.json

# Prevent multiple sourcing
[[ -n "${_SCAN_LOADED:-}" ]] && return 0
readonly _SCAN_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

# Get script directory for relative sourcing
_SCAN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    source "${_SCAN_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_section() { echo "=== $* ==="; }
    }
fi

# Set default STATE_DIR if not defined
: "${STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/ultimate-suite}"

# ============================================================================
# CPU Detection
# ============================================================================

# Detect CPU with full feature detection
detect_cpu() {
    local cpu_model cpu_cores cpu_threads cpu_freq cpu_vendor

    # Basic CPU information
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    cpu_cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "0")
    cpu_threads=$(nproc --all 2>/dev/null || echo "$cpu_cores")
    cpu_freq=$(grep -m1 'cpu MHz' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)

    # Normalize vendor
    case "$cpu_vendor" in
        GenuineIntel) cpu_vendor="intel" ;;
        AuthenticAMD) cpu_vendor="amd" ;;
        *) cpu_vendor="${cpu_vendor,,}" ;;
    esac

    # Detect CPU features for optimization decisions
    local has_aes has_avx has_avx2 has_sse42
    grep -qw 'aes' /proc/cpuinfo 2>/dev/null && has_aes=true || has_aes=false
    grep -qw 'avx' /proc/cpuinfo 2>/dev/null && has_avx=true || has_avx=false
    grep -qw 'avx2' /proc/cpuinfo 2>/dev/null && has_avx2=true || has_avx2=false
    grep -qw 'sse4_2' /proc/cpuinfo 2>/dev/null && has_sse42=true || has_sse42=false

    # Get max and min frequencies if available
    local cpu_freq_max cpu_freq_min
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
        cpu_freq_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
        cpu_freq_max=$((cpu_freq_max / 1000))  # Convert to MHz
    else
        cpu_freq_max="${cpu_freq%.*}"
    fi

    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]]; then
        cpu_freq_min=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null)
        cpu_freq_min=$((cpu_freq_min / 1000))  # Convert to MHz
    else
        cpu_freq_min="${cpu_freq%.*}"
    fi

    # Get current governor if available
    local cpu_governor="unknown"
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        cpu_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    fi

    # Set defaults
    [[ -z "$cpu_model" ]] && cpu_model="Unknown CPU"
    [[ -z "$cpu_vendor" ]] && cpu_vendor="unknown"
    [[ -z "$cpu_freq" ]] && cpu_freq="0"
    [[ -z "$cpu_freq_max" ]] && cpu_freq_max="0"
    [[ -z "$cpu_freq_min" ]] && cpu_freq_min="0"

    # Export as JSON
    cat <<EOF
{
    "model": "$cpu_model",
    "vendor": "$cpu_vendor",
    "cores": $cpu_cores,
    "threads": $cpu_threads,
    "current_frequency_mhz": ${cpu_freq%.*},
    "max_frequency_mhz": ${cpu_freq_max},
    "min_frequency_mhz": ${cpu_freq_min},
    "governor": "$cpu_governor",
    "features": {
        "aes": $has_aes,
        "avx": $has_avx,
        "avx2": $has_avx2,
        "sse42": $has_sse42
    }
}
EOF
}

# ============================================================================
# Memory Detection
# ============================================================================

# Calculate memory-based recommendations
calculate_memory_recommendation() {
    local mem_gb="$1"
    local recommendations=()

    if [[ "$mem_gb" -lt 4 ]]; then
        recommendations+=("Consider upgrading RAM for better performance")
        recommendations+=("Enable zswap for better memory management")
        recommendations+=("Avoid heavy desktop environments")
    elif [[ "$mem_gb" -lt 8 ]]; then
        recommendations+=("System suitable for light to medium workloads")
        recommendations+=("Consider swap on SSD if available")
    elif [[ "$mem_gb" -lt 16 ]]; then
        recommendations+=("Good for most workloads including development")
        recommendations+=("Can run multiple applications smoothly")
    else
        recommendations+=("Excellent memory capacity for heavy workloads")
        recommendations+=("Suitable for VMs, containers, and development")
    fi

    # Output as JSON array
    printf '['
    local first=true
    for rec in "${recommendations[@]}"; do
        [[ "$first" == "false" ]] && printf ','
        printf '"%s"' "$rec"
        first=false
    done
    printf ']'
}

# Detect memory configuration
detect_memory() {
    local mem_total mem_available mem_swap_total mem_swap_free

    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    mem_available=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
    mem_swap_total=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    mem_swap_free=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{print $2}')

    # Convert to human-readable
    local mem_total_gb=$((mem_total / 1024 / 1024))
    local mem_total_mb=$((mem_total / 1024))
    local mem_available_mb=$((mem_available / 1024))
    local mem_swap_total_gb=$((mem_swap_total / 1024 / 1024))

    # Set defaults
    [[ -z "$mem_total" ]] && mem_total=0
    [[ -z "$mem_available" ]] && mem_available=0
    [[ -z "$mem_swap_total" ]] && mem_swap_total=0
    [[ -z "$mem_swap_free" ]] && mem_swap_free=0

    cat <<EOF
{
    "total_kb": $mem_total,
    "total_gb": $mem_total_gb,
    "total_mb": $mem_total_mb,
    "available_kb": $mem_available,
    "available_mb": $mem_available_mb,
    "swap_total_kb": $mem_swap_total,
    "swap_total_gb": $mem_swap_total_gb,
    "swap_free_kb": $mem_swap_free,
    "has_swap": $([ "$mem_swap_total" -gt 0 ] && echo "true" || echo "false"),
    "recommendations": $(calculate_memory_recommendation "$mem_total_gb")
}
EOF
}

# ============================================================================
# Storage Detection
# ============================================================================

# Recommend I/O scheduler based on device type
recommend_scheduler() {
    local dev_type="$1"

    case "$dev_type" in
        NVMe|nvme)
            echo "none"  # NVMe devices work best with none/noop
            ;;
        SSD|ssd)
            echo "mq-deadline"  # Good for SSDs
            ;;
        HDD|hdd)
            echo "bfq"  # Better for rotational media
            ;;
        *)
            echo "mq-deadline"  # Safe default
            ;;
    esac
}

# Detect storage devices
detect_storage() {
    local storage_json="["
    local first=true

    for device in /sys/block/*/; do
        [[ ! -d "$device" ]] && continue

        local dev_name
        dev_name=$(basename "$device")

        # Skip loop, ram, and other virtual devices
        [[ "$dev_name" =~ ^(loop|ram|dm-|sr|fd|zram) ]] && continue

        local rotational scheduler size_sectors size_gb dev_type model
        rotational=$(cat "$device/queue/rotational" 2>/dev/null || echo "1")
        scheduler=$(cat "$device/queue/scheduler" 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
        size_sectors=$(cat "$device/size" 2>/dev/null || echo "0")
        size_gb=$((size_sectors * 512 / 1024 / 1024 / 1024))

        # Get device model if available
        if [[ -r "$device/device/model" ]]; then
            model=$(cat "$device/device/model" 2>/dev/null | xargs)
        else
            model="Unknown"
        fi

        # Determine device type
        dev_type="HDD"
        if [[ "$rotational" == "0" ]]; then
            dev_type="SSD"
        fi

        # Detect NVMe (more reliable detection)
        if [[ "$dev_name" =~ ^nvme ]]; then
            dev_type="NVMe"
        fi

        # Skip if device is too small (likely not a real disk)
        [[ "$size_gb" -lt 1 ]] && continue

        [[ "$first" == "false" ]] && storage_json+=","
        first=false

        storage_json+=$(cat <<EOF
{
    "device": "/dev/$dev_name",
    "model": "$model",
    "type": "$dev_type",
    "size_gb": $size_gb,
    "rotational": $([ "$rotational" == "1" ] && echo "true" || echo "false"),
    "current_scheduler": "$scheduler",
    "recommended_scheduler": "$(recommend_scheduler "$dev_type")"
}
EOF
)
    done

    storage_json+="]"
    echo "$storage_json"
}

# ============================================================================
# GPU Detection
# ============================================================================

# Recommend GPU driver based on vendor
recommend_gpu_driver() {
    local gpu_vendor="$1"

    case "$gpu_vendor" in
        nvidia)
            echo "nvidia-proprietary (for best performance) or nouveau (open-source)"
            ;;
        amd)
            echo "amdgpu (built-in kernel driver, recommended)"
            ;;
        intel)
            echo "i915 or xe (built-in kernel drivers, usually auto-configured)"
            ;;
        *)
            echo "Default kernel driver should work"
            ;;
    esac
}

# Detect GPU information
detect_gpu() {
    local gpu_vendor="unknown"
    local gpu_model="Unknown GPU"
    local gpu_driver="unknown"
    local gpu_pci_id=""

    if ! command -v lspci &>/dev/null; then
        log_debug "lspci not available for GPU detection"
        cat <<EOF
{
    "vendor": "$gpu_vendor",
    "model": "$gpu_model",
    "driver": "$gpu_driver",
    "pci_id": "$gpu_pci_id",
    "driver_recommendation": "$(recommend_gpu_driver "$gpu_vendor")"
}
EOF
        return 0
    fi

    # Check for NVIDIA
    if lspci 2>/dev/null | grep -qi nvidia; then
        gpu_vendor="nvidia"
        local gpu_line
        gpu_line=$(lspci 2>/dev/null | grep -i nvidia | grep -iE 'vga|3d|display' | head -1)
        gpu_model=$(echo "$gpu_line" | cut -d: -f3 | xargs)
        gpu_pci_id=$(echo "$gpu_line" | awk '{print $1}')

        # Check for nvidia driver
        if [[ -f /proc/driver/nvidia/version ]]; then
            gpu_driver="nvidia-proprietary"
        elif lsmod 2>/dev/null | grep -q nouveau; then
            gpu_driver="nouveau"
        fi
    # Check for AMD
    elif lspci 2>/dev/null | grep -qiE 'amd|radeon|ati'; then
        gpu_vendor="amd"
        local gpu_line
        gpu_line=$(lspci 2>/dev/null | grep -iE 'amd|radeon|ati' | grep -iE 'vga|3d|display' | head -1)
        gpu_model=$(echo "$gpu_line" | cut -d: -f3 | xargs)
        gpu_pci_id=$(echo "$gpu_line" | awk '{print $1}')

        # Check for amdgpu driver
        if lsmod 2>/dev/null | grep -q amdgpu; then
            gpu_driver="amdgpu"
        elif lsmod 2>/dev/null | grep -q radeon; then
            gpu_driver="radeon"
        fi
    # Check for Intel
    elif lspci 2>/dev/null | grep -qiE 'intel.*(graphics|vga|display)'; then
        gpu_vendor="intel"
        local gpu_line
        gpu_line=$(lspci 2>/dev/null | grep -i intel | grep -iE 'vga|graphics|display' | head -1)
        gpu_model=$(echo "$gpu_line" | cut -d: -f3 | xargs)
        gpu_pci_id=$(echo "$gpu_line" | awk '{print $1}')

        # Check for Intel drivers
        if lsmod 2>/dev/null | grep -q '^i915\s'; then
            gpu_driver="i915"
        elif lsmod 2>/dev/null | grep -q '^xe\s'; then
            gpu_driver="xe"
        fi
    fi

    cat <<EOF
{
    "vendor": "$gpu_vendor",
    "model": "$gpu_model",
    "driver": "$gpu_driver",
    "pci_id": "$gpu_pci_id",
    "driver_recommendation": "$(recommend_gpu_driver "$gpu_vendor")"
}
EOF
}

# ============================================================================
# Network Detection
# ============================================================================

# Detect network interfaces
detect_network() {
    local network_json="["
    local first=true

    for iface in /sys/class/net/*/; do
        [[ ! -d "$iface" ]] && continue

        local if_name
        if_name=$(basename "$iface")

        # Skip loopback
        [[ "$if_name" == "lo" ]] && continue

        local if_type="ethernet"
        local driver mac state speed

        # Detect wireless
        [[ -d "$iface/wireless" ]] && if_type="wireless"

        # Get driver
        if [[ -L "$iface/device/driver" ]]; then
            driver=$(readlink "$iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
        else
            driver="unknown"
        fi

        # Get MAC address
        mac=$(cat "$iface/address" 2>/dev/null || echo "unknown")

        # Get operational state
        state=$(cat "$iface/operstate" 2>/dev/null || echo "unknown")

        # Get link speed (for ethernet)
        if [[ "$if_type" == "ethernet" ]] && [[ -r "$iface/speed" ]]; then
            speed=$(cat "$iface/speed" 2>/dev/null || echo "0")
            [[ "$speed" == "-1" ]] && speed="0"
        else
            speed="0"
        fi

        [[ "$first" == "false" ]] && network_json+=","
        first=false

        network_json+=$(cat <<EOF
{
    "interface": "$if_name",
    "type": "$if_type",
    "driver": "$driver",
    "mac": "$mac",
    "state": "$state",
    "speed_mbps": $speed
}
EOF
)
    done

    network_json+="]"
    echo "$network_json"
}

# ============================================================================
# Virtualization Detection
# ============================================================================

# Recommend guest tools based on hypervisor type
recommend_guest_tools() {
    local virt_type="$1"

    case "$virt_type" in
        virtualbox|VirtualBox)
            echo "virtualbox-guest-utils, virtualbox-guest-dkms"
            ;;
        vmware|VMware)
            echo "open-vm-tools, open-vm-tools-desktop"
            ;;
        kvm|qemu|QEMU)
            echo "qemu-guest-agent, spice-vdagent"
            ;;
        hyperv|Hyper-V)
            echo "hyperv-daemons (usually built into kernel)"
            ;;
        xen|Xen)
            echo "xe-guest-utilities"
            ;;
        none)
            echo "Not running in a VM - no guest tools needed"
            ;;
        *)
            echo "Unknown virtualization - check documentation"
            ;;
    esac
}

# Detect virtualization environment
detect_virtualization() {
    local virt_type="none"
    local virt_role="host"

    # Method 1: Check DMI product name
    if [[ -r /sys/class/dmi/id/product_name ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case "$product" in
            *VirtualBox*) virt_type="virtualbox"; virt_role="guest" ;;
            *VMware*) virt_type="vmware"; virt_role="guest" ;;
            *QEMU*|*KVM*) virt_type="kvm"; virt_role="guest" ;;
            *Hyper-V*) virt_type="hyperv"; virt_role="guest" ;;
        esac
    fi

    # Method 2: Check system vendor
    if [[ "$virt_type" == "none" ]] && [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        local vendor
        vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
        case "$vendor" in
            *QEMU*) virt_type="kvm"; virt_role="guest" ;;
            *VMware*) virt_type="vmware"; virt_role="guest" ;;
            *innotek*) virt_type="virtualbox"; virt_role="guest" ;;
            *Microsoft*)
                [[ "$vendor" == *"Hyper-V"* ]] && virt_type="hyperv" && virt_role="guest"
                ;;
        esac
    fi

    # Method 3: Use systemd-detect-virt if available (most reliable)
    if command -v systemd-detect-virt &>/dev/null; then
        local detected
        detected=$(systemd-detect-virt 2>/dev/null | tr -d '\n' || echo "none")
        if [[ "$detected" != "none" ]] && [[ -n "$detected" ]]; then
            virt_type="$detected"
            virt_role="guest"
        fi
    fi

    # Method 4: Check for hypervisor CPU flag
    if [[ "$virt_type" == "none" ]] && grep -qw hypervisor /proc/cpuinfo 2>/dev/null; then
        virt_type="unknown-hypervisor"
        virt_role="guest"
    fi

    cat <<EOF
{
    "type": "$virt_type",
    "role": "$virt_role",
    "is_vm": $([ "$virt_role" == "guest" ] && echo "true" || echo "false"),
    "guest_tools_recommendation": "$(recommend_guest_tools "$virt_type")"
}
EOF
}

# ============================================================================
# Distribution Detection (for scan completeness)
# ============================================================================

# Detect Linux distribution
detect_distribution() {
    local distro_id="unknown"
    local distro_name="Unknown Linux"
    local distro_version=""
    local distro_codename=""

    # Try os-release first (most modern systems)
    if [[ -r /etc/os-release ]]; then
        # Source the file in a subshell to avoid polluting environment
        eval "$(grep '^ID=' /etc/os-release 2>/dev/null)"
        eval "$(grep '^NAME=' /etc/os-release 2>/dev/null)"
        eval "$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null)"
        eval "$(grep '^VERSION_CODENAME=' /etc/os-release 2>/dev/null)"

        distro_id="${ID:-unknown}"
        distro_name="${NAME:-Unknown Linux}"
        distro_version="${VERSION_ID:-}"
        distro_codename="${VERSION_CODENAME:-}"
    # Fallback to lsb_release
    elif command -v lsb_release &>/dev/null; then
        distro_id=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
        distro_name=$(lsb_release -sd 2>/dev/null | tr -d '"')
        distro_version=$(lsb_release -sr 2>/dev/null)
        distro_codename=$(lsb_release -sc 2>/dev/null)
    fi

    cat <<EOF
{
    "id": "$distro_id",
    "name": "$distro_name",
    "version": "$distro_version",
    "codename": "$distro_codename"
}
EOF
}

# ============================================================================
# Master Scan Function
# ============================================================================

# Perform full hardware scan and output JSON
perform_full_scan() {
    # Ensure STATE_DIR exists
    if [[ -z "${STATE_DIR:-}" ]]; then
        log_error "STATE_DIR not set - cannot perform scan"
        return 1
    fi

    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR" 2>/dev/null || {
            log_error "Cannot create STATE_DIR: $STATE_DIR"
            return 1
        }
    fi

    local scan_output="$STATE_DIR/hardware_scan.json"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "Performing comprehensive hardware scan..."
    log_debug "Scan output: $scan_output"

    # Create JSON output
    cat > "$scan_output" <<EOF
{
    "scan_timestamp": "$timestamp",
    "hostname": "$(hostname 2>/dev/null || echo 'unknown')",
    "kernel": "$(uname -r 2>/dev/null || echo 'unknown')",
    "architecture": "$(uname -m 2>/dev/null || echo 'unknown')",
    "distribution": $(detect_distribution),
    "cpu": $(detect_cpu),
    "memory": $(detect_memory),
    "storage": $(detect_storage),
    "gpu": $(detect_gpu),
    "network": $(detect_network),
    "virtualization": $(detect_virtualization)
}
EOF

    if [[ $? -eq 0 ]] && [[ -f "$scan_output" ]]; then
        log_success "Hardware scan complete: $scan_output"
        # Return just the path (without echoing) for programmatic use
        return 0
    else
        log_error "Failed to create hardware scan output"
        return 1
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get scan file path
get_scan_file() {
    echo "${STATE_DIR:-$HOME/.local/state/ultimate-suite}/hardware_scan.json"
}

# Print scan summary to console
print_scan_summary() {
    local scan_file="${1:-$STATE_DIR/hardware_scan.json}"

    if [[ ! -f "$scan_file" ]]; then
        log_error "Scan file not found: $scan_file"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_warn "jq not installed - displaying raw JSON"
        cat "$scan_file"
        return 0
    fi

    log_section "Hardware Scan Summary"

    echo "Distribution: $(jq -r '.distribution.name' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo "Kernel: $(jq -r '.kernel' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo ""

    echo "CPU:"
    echo "  Model: $(jq -r '.cpu.model' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo "  Vendor: $(jq -r '.cpu.vendor' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo "  Cores: $(jq -r '.cpu.cores' "$scan_file" 2>/dev/null || echo '?')"
    echo "  Threads: $(jq -r '.cpu.threads' "$scan_file" 2>/dev/null || echo '?')"
    echo "  Features: AES=$(jq -r '.cpu.features.aes' "$scan_file" 2>/dev/null), AVX2=$(jq -r '.cpu.features.avx2' "$scan_file" 2>/dev/null)"
    echo ""

    echo "Memory:"
    echo "  Total: $(jq -r '.memory.total_gb' "$scan_file" 2>/dev/null || echo '?') GB"
    echo "  Available: $(jq -r '.memory.available_mb' "$scan_file" 2>/dev/null || echo '?') MB"
    echo "  Swap: $(jq -r '.memory.swap_total_gb' "$scan_file" 2>/dev/null || echo '?') GB"
    echo ""

    echo "GPU:"
    echo "  Vendor: $(jq -r '.gpu.vendor' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo "  Model: $(jq -r '.gpu.model' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo "  Driver: $(jq -r '.gpu.driver' "$scan_file" 2>/dev/null || echo 'unknown')"
    echo ""

    echo "Virtualization:"
    echo "  Type: $(jq -r '.virtualization.type' "$scan_file" 2>/dev/null || echo 'none')"
    echo "  Is VM: $(jq -r '.virtualization.is_vm' "$scan_file" 2>/dev/null || echo 'false')"
    echo ""

    log_divider
}

# Get specific hardware info from scan
get_scan_value() {
    local key="$1"
    local scan_file="${2:-$STATE_DIR/hardware_scan.json}"

    if [[ ! -f "$scan_file" ]]; then
        log_debug "Scan file not found: $scan_file"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_debug "jq not installed - cannot query scan data"
        return 1
    fi

    jq -r "$key" "$scan_file" 2>/dev/null
}

# Check if scan exists and is recent (less than 24 hours old)
is_scan_fresh() {
    local scan_file="${1:-$STATE_DIR/hardware_scan.json}"
    local max_age_hours="${2:-24}"

    if [[ ! -f "$scan_file" ]]; then
        return 1
    fi

    local scan_age
    scan_age=$(( $(date +%s) - $(stat -c %Y "$scan_file" 2>/dev/null || echo 0) ))
    local max_age_seconds=$((max_age_hours * 3600))

    [[ "$scan_age" -lt "$max_age_seconds" ]]
}

# ============================================================================
# Optimization Recommendations (Blueprint Algorithms)
# ============================================================================

# Generate optimization recommendations based on hardware scan
# Returns JSON with recommended settings for ZRAM, swappiness, scheduler, governor
generate_optimization_recommendations() {
    local scan_file="${1:-$STATE_DIR/hardware_scan.json}"

    if [[ ! -f "$scan_file" ]]; then
        log_error "Scan file not found: $scan_file"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq required for recommendations"
        return 1
    fi

    # Read hardware values
    local ram_gb=$(jq -r '.memory.total_gb // 8' "$scan_file" 2>/dev/null)
    local has_ssd=$(jq -r '[.storage[].type] | any(. == "ssd" or . == "nvme")' "$scan_file" 2>/dev/null)
    local has_nvme=$(jq -r '[.storage[].type] | any(. == "nvme")' "$scan_file" 2>/dev/null)
    local has_battery=$(jq -r '.virtualization.is_vm == false' "$scan_file" 2>/dev/null)
    local is_vm=$(jq -r '.virtualization.is_vm // false' "$scan_file" 2>/dev/null)

    # Detect form factor from chassis or battery
    local form_factor="desktop"
    if [[ -d /sys/class/power_supply ]]; then
        for supply in /sys/class/power_supply/*; do
            if [[ -r "$supply/type" ]] && [[ "$(cat "$supply/type" 2>/dev/null)" == "Battery" ]]; then
                form_factor="laptop"
                break
            fi
        done
    fi

    # ---- ZRAM Size: min(RAM/2, 8GB) ----
    local zram_size_mb
    local half_ram=$((ram_gb * 1024 / 2))
    local max_zram=$((8 * 1024))  # 8GB in MB
    if [[ $half_ram -lt $max_zram ]]; then
        zram_size_mb=$half_ram
    else
        zram_size_mb=$max_zram
    fi

    # ---- Swappiness based on RAM ----
    # RAM < 8GB: 60; 8-16GB: 40; 32GB+: 10-20; With ZRAM: 100-180
    local swappiness
    local swappiness_with_zram
    if [[ $ram_gb -lt 8 ]]; then
        swappiness=60
        swappiness_with_zram=180
    elif [[ $ram_gb -lt 16 ]]; then
        swappiness=40
        swappiness_with_zram=150
    elif [[ $ram_gb -lt 32 ]]; then
        swappiness=20
        swappiness_with_zram=120
    else
        swappiness=10
        swappiness_with_zram=100
    fi

    # ---- I/O Scheduler: NVMe → none, SSD → mq-deadline, HDD → bfq ----
    local io_scheduler_nvme="none"
    local io_scheduler_ssd="mq-deadline"
    local io_scheduler_hdd="bfq"

    # ---- CPU Governor: Desktop → performance, Laptop → schedutil ----
    local cpu_governor
    if [[ "$form_factor" == "laptop" ]]; then
        cpu_governor="schedutil"
    elif [[ "$is_vm" == "true" ]]; then
        cpu_governor="ondemand"
    else
        cpu_governor="performance"
    fi

    # Output recommendations as JSON
    cat <<EOF
{
    "zram": {
        "size_mb": $zram_size_mb,
        "compression": "zstd",
        "priority": 100
    },
    "swappiness": {
        "without_zram": $swappiness,
        "with_zram": $swappiness_with_zram
    },
    "io_scheduler": {
        "nvme": "$io_scheduler_nvme",
        "ssd": "$io_scheduler_ssd",
        "hdd": "$io_scheduler_hdd"
    },
    "cpu_governor": "$cpu_governor",
    "form_factor": "$form_factor",
    "profile": "$(
        if [[ $ram_gb -lt 4 ]]; then
            echo "low_memory"
        elif [[ "$form_factor" == "laptop" ]]; then
            echo "laptop"
        elif [[ $ram_gb -ge 32 ]]; then
            echo "workstation"
        else
            echo "desktop"
        fi
    )"
}
EOF
}

# Save hardware profile with recommendations to blueprint-specified path
save_hardware_profile() {
    local output_file="${1:-}"

    # Determine output path
    if [[ -z "$output_file" ]]; then
        if [[ $EUID -eq 0 ]]; then
            output_file="/var/lib/linux-suite/hardware-profile.json"
        else
            output_file="${STATE_DIR}/hardware-profile.json"
        fi
    fi

    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" 2>/dev/null || {
        log_error "Cannot create directory: $output_dir"
        return 1
    }

    log_info "Generating hardware profile with optimization recommendations..."

    # Perform scan if not done recently
    if ! is_scan_fresh "$STATE_DIR/hardware_scan.json" 1; then
        perform_full_scan || return 1
    fi

    local scan_file="$STATE_DIR/hardware_scan.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Combine scan data with recommendations
    if command -v jq &>/dev/null; then
        local recommendations=$(generate_optimization_recommendations "$scan_file")

        jq --argjson recs "$recommendations" --arg ts "$timestamp" \
            '. + {"optimization_recommendations": $recs, "profile_generated": $ts}' \
            "$scan_file" > "$output_file"
    else
        # Fallback without jq - just copy scan
        cp "$scan_file" "$output_file"
    fi

    if [[ -f "$output_file" ]]; then
        log_success "Hardware profile saved: $output_file"
        return 0
    else
        log_error "Failed to save hardware profile"
        return 1
    fi
}

# Get hardware profile path
get_hardware_profile_path() {
    if [[ $EUID -eq 0 ]]; then
        echo "/var/lib/linux-suite/hardware-profile.json"
    else
        echo "${STATE_DIR}/hardware-profile.json"
    fi
}

# Print optimization recommendations
print_optimization_recommendations() {
    local scan_file="${1:-$STATE_DIR/hardware_scan.json}"

    if [[ ! -f "$scan_file" ]]; then
        log_error "Scan file not found. Run perform_full_scan first."
        return 1
    fi

    local recs=$(generate_optimization_recommendations "$scan_file")

    echo "=== Optimization Recommendations ==="
    echo ""
    echo "Based on your hardware, the following settings are recommended:"
    echo ""

    if command -v jq &>/dev/null; then
        echo "ZRAM Configuration:"
        echo "  Size: $(echo "$recs" | jq -r '.zram.size_mb') MB"
        echo "  Compression: $(echo "$recs" | jq -r '.zram.compression')"
        echo ""

        echo "Swappiness:"
        echo "  Without ZRAM: $(echo "$recs" | jq -r '.swappiness.without_zram')"
        echo "  With ZRAM: $(echo "$recs" | jq -r '.swappiness.with_zram')"
        echo ""

        echo "I/O Schedulers:"
        echo "  NVMe: $(echo "$recs" | jq -r '.io_scheduler.nvme')"
        echo "  SSD: $(echo "$recs" | jq -r '.io_scheduler.ssd')"
        echo "  HDD: $(echo "$recs" | jq -r '.io_scheduler.hdd')"
        echo ""

        echo "CPU Governor: $(echo "$recs" | jq -r '.cpu_governor')"
        echo "Form Factor: $(echo "$recs" | jq -r '.form_factor')"
        echo "Profile: $(echo "$recs" | jq -r '.profile')"
    else
        echo "$recs"
    fi
}

# ============================================================================
# Module Documentation
# ============================================================================
#
# SCAN MODULE OVERVIEW
# ====================
#
# This module provides comprehensive hardware detection with JSON output for:
# - System profiling and optimization
# - Driver detection and recommendations
# - Hardware compatibility checking
# - Resource planning
#
# MAIN FUNCTIONS:
# ---------------
# perform_full_scan()           - Master scan function, outputs to STATE_DIR/hardware_scan.json
# detect_cpu()                  - CPU detection with features (AES, AVX, AVX2, SSE4.2)
# detect_memory()               - Memory detection with recommendations
# detect_storage()              - Storage enumeration with scheduler recommendations
# detect_gpu()                  - GPU detection with driver recommendations
# detect_network()              - Network interface detection
# detect_virtualization()       - VM detection with guest tools recommendations
# detect_distribution()         - Linux distribution detection
#
# HELPER FUNCTIONS:
# -----------------
# recommend_scheduler()         - I/O scheduler recommendation based on device type
# calculate_memory_recommendation() - Memory-based system recommendations
# recommend_gpu_driver()        - GPU driver recommendations
# recommend_guest_tools()       - VM guest tools recommendations
# print_scan_summary()          - Display scan results in human-readable format
# get_scan_value()              - Query specific value from scan JSON
# is_scan_fresh()               - Check if scan is recent
#
# USAGE EXAMPLE:
# --------------
#   source lib/scan.sh
#   perform_full_scan
#   print_scan_summary
#
#   # Query specific values
#   cpu_vendor=$(get_scan_value '.cpu.vendor')
#   is_vm=$(get_scan_value '.virtualization.is_vm')
#
# OUTPUT LOCATION:
# ----------------
#   $STATE_DIR/hardware_scan.json (typically ~/.local/state/ultimate-suite/)
#
# JSON STRUCTURE:
# ---------------
#   {
#     "scan_timestamp": "ISO8601 timestamp",
#     "hostname": "string",
#     "kernel": "string",
#     "architecture": "string",
#     "distribution": { "id", "name", "version", "codename" },
#     "cpu": { "model", "vendor", "cores", "threads", "features": {...} },
#     "memory": { "total_gb", "available_mb", "swap_total_gb", "recommendations": [...] },
#     "storage": [ { "device", "type", "size_gb", "scheduler", ... } ],
#     "gpu": { "vendor", "model", "driver", "recommendation" },
#     "network": [ { "interface", "type", "driver", "state", ... } ],
#     "virtualization": { "type", "role", "is_vm", "recommendation" }
#   }
#
# ============================================================================
