#!/usr/bin/env bash
#
# zram.sh - ZRAM Compressed Swap Configuration Module
#
# This module provides comprehensive ZRAM (compressed RAM) swap configuration
# for the Ultimate Linux Suite. ZRAM creates a compressed block device in RAM
# that can be used as swap, providing better performance than disk-based swap
# while reducing memory pressure.
#

# Prevent multiple sourcing
[[ -n "${_ZRAM_LOADED:-}" ]] && return 0
readonly _ZRAM_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

# Get script directory for relative sourcing
_ZRAM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${_ZRAM_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# Source hardware_detect with fallback
if ! declare -f detect_total_ram_mb &>/dev/null; then
    source "${_ZRAM_SCRIPT_DIR}/hardware_detect.sh" 2>/dev/null || {
        # Provide fallback function for RAM detection
        detect_total_ram_mb() {
            awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "4096"
        }
    }
fi

# ============================================================================
# ZRAM Configuration Constants
# ============================================================================

readonly ZRAM_SYSTEMD_CONFIG="/etc/systemd/zram-generator.conf"
readonly ZRAM_SYSTEMD_DIR="/etc/systemd/zram-generator.conf.d"
readonly ZRAM_MODULE="zram"
readonly ZRAM_DEFAULT_PRIORITY=100
readonly ZRAM_MIN_SIZE_MB=512
readonly ZRAM_MAX_SIZE_GB=8

# Compression algorithm preferences (ordered by quality)
declare -ra ZRAM_ALGORITHMS=(
    "zstd"      # Best compression ratio, good speed (needs kernel 4.18+)
    "lz4"       # Best speed, good compression (widely available)
    "lzo-rle"   # Good balance (kernel 5.1+)
    "lzo"       # Fallback, widely available
    "zsmalloc"  # Legacy fallback
)

# ============================================================================
# ZRAM Support Detection
# ============================================================================

# Check if kernel supports ZRAM
# Returns: 0 if supported, 1 otherwise
check_zram_support() {
    log_debug "Checking ZRAM kernel support..."

    # Check if zram module exists
    if [[ -e "/sys/module/zram" ]]; then
        log_debug "ZRAM module already loaded"
        return 0
    fi

    # Try to find zram module
    if modinfo "$ZRAM_MODULE" &>/dev/null; then
        log_debug "ZRAM module available but not loaded"
        return 0
    fi

    # Check if zram is compiled into kernel
    if [[ -e "/dev/zram0" ]]; then
        log_debug "ZRAM support compiled into kernel"
        return 0
    fi

    # Check kernel config if available
    local kernel_version
    kernel_version=$(uname -r)
    local config_file="/boot/config-${kernel_version}"

    if [[ -r "$config_file" ]]; then
        if grep -q "^CONFIG_ZRAM=y" "$config_file" 2>/dev/null; then
            log_debug "ZRAM compiled into kernel (CONFIG_ZRAM=y)"
            return 0
        elif grep -q "^CONFIG_ZRAM=m" "$config_file" 2>/dev/null; then
            log_debug "ZRAM available as module (CONFIG_ZRAM=m)"
            return 0
        fi
    fi

    log_warn "ZRAM support not detected in kernel"
    return 1
}

# Check if a compression algorithm is available
# Arguments:
#   $1 - algorithm name (e.g., "zstd", "lz4")
# Returns: 0 if available, 1 otherwise
check_algorithm_available() {
    local algorithm="$1"

    if [[ -z "$algorithm" ]]; then
        log_error "check_algorithm_available: algorithm name required"
        return 1
    fi

    log_debug "Checking availability of compression algorithm: $algorithm"

    # Ensure zram module is loaded
    if ! lsmod | grep -q "^zram "; then
        if ! modprobe "$ZRAM_MODULE" 2>/dev/null; then
            log_debug "Failed to load ZRAM module"
            return 1
        fi
    fi

    # Check if algorithm is supported by any zram device
    local zram_dev
    for zram_dev in /sys/block/zram*/comp_algorithm; do
        if [[ -r "$zram_dev" ]]; then
            if grep -qw "$algorithm" "$zram_dev" 2>/dev/null; then
                log_debug "Algorithm $algorithm is available"
                return 0
            fi
        fi
    done

    # If no device exists, create a temporary one to check
    if [[ ! -e "/dev/zram0" ]]; then
        if echo 1 > /sys/class/zram-control/hot_add 2>/dev/null; then
            if [[ -r "/sys/block/zram0/comp_algorithm" ]]; then
                local result
                if grep -qw "$algorithm" /sys/block/zram0/comp_algorithm 2>/dev/null; then
                    result=0
                else
                    result=1
                fi
                # Remove temporary device
                echo 0 > /sys/class/zram-control/hot_remove 2>/dev/null || true
                return $result
            fi
        fi
    fi

    log_debug "Algorithm $algorithm not available"
    return 1
}

# Select best available compression algorithm
# Returns: algorithm name on stdout
select_zram_algorithm() {
    log_debug "Selecting optimal ZRAM compression algorithm..."

    # Ensure hardware detection has run
    if [[ -z "$CPU_CORES" ]]; then
        detect_cpu >/dev/null 2>&1
    fi

    local cores=${CPU_CORES:-1}

    # For systems with many cores, prefer zstd for better compression
    # For systems with few cores, prefer lz4 for lower CPU overhead
    local preferred_order
    if [[ $cores -ge 4 ]]; then
        preferred_order=("zstd" "lz4" "lzo-rle" "lzo" "zsmalloc")
        log_debug "Multi-core system detected ($cores cores), preferring zstd"
    else
        preferred_order=("lz4" "lzo-rle" "zstd" "lzo" "zsmalloc")
        log_debug "Low-core system detected ($cores cores), preferring lz4"
    fi

    # Find first available algorithm
    local algo
    for algo in "${preferred_order[@]}"; do
        if check_algorithm_available "$algo"; then
            log_info "Selected compression algorithm: $algo"
            echo "$algo"
            return 0
        fi
    done

    # Fallback to lzo (most widely available)
    log_warn "No preferred algorithm available, using lzo fallback"
    echo "lzo"
    return 0
}

# ============================================================================
# ZRAM Size Calculation
# ============================================================================

# Calculate optimal ZRAM size based on system RAM
# Returns: size in MB on stdout
calculate_zram_size() {
    log_debug "Calculating optimal ZRAM size..."

    # Ensure RAM detection has run
    if [[ -z "$RAM_TOTAL_GB" ]]; then
        detect_ram >/dev/null 2>&1
    fi

    local ram_gb=${RAM_TOTAL_GB:-0}
    local ram_mb=$((ram_gb * 1024))

    if [[ $ram_gb -eq 0 ]] || [[ ! $ram_gb =~ ^[0-9]+$ ]]; then
        log_warn "Could not detect RAM size, using default 2GB ZRAM"
        echo "2048"
        return 0
    fi

    local zram_mb

    # Size recommendations based on total RAM:
    # - Very low RAM (<=2GB): Use 50% of RAM
    # - Low RAM (2-4GB): Use 50% of RAM
    # - Medium RAM (4-8GB): Use 50% of RAM
    # - High RAM (8-16GB): Use 25-33% of RAM
    # - Very high RAM (>16GB): Cap at 8GB

    if [[ $ram_gb -le 2 ]]; then
        # Very low RAM: use 50% to help with memory pressure
        zram_mb=$((ram_mb / 2))
        log_debug "Very low RAM system ($ram_gb GB), using 50% for ZRAM"
    elif [[ $ram_gb -le 4 ]]; then
        # Low RAM: use 50%
        zram_mb=$((ram_mb / 2))
        log_debug "Low RAM system ($ram_gb GB), using 50% for ZRAM"
    elif [[ $ram_gb -le 8 ]]; then
        # Medium RAM: use 50%
        zram_mb=$((ram_mb / 2))
        log_debug "Medium RAM system ($ram_gb GB), using 50% for ZRAM"
    elif [[ $ram_gb -le 16 ]]; then
        # High RAM: use 33%
        zram_mb=$((ram_mb / 3))
        log_debug "High RAM system ($ram_gb GB), using 33% for ZRAM"
    else
        # Very high RAM: cap at 8GB
        zram_mb=$((ZRAM_MAX_SIZE_GB * 1024))
        log_debug "Very high RAM system ($ram_gb GB), capping ZRAM at ${ZRAM_MAX_SIZE_GB}GB"
    fi

    # Ensure minimum size
    if [[ $zram_mb -lt $ZRAM_MIN_SIZE_MB ]]; then
        log_warn "Calculated ZRAM size too small, using minimum ${ZRAM_MIN_SIZE_MB}MB"
        zram_mb=$ZRAM_MIN_SIZE_MB
    fi

    log_info "Calculated ZRAM size: ${zram_mb}MB (from ${ram_gb}GB total RAM)"
    echo "$zram_mb"
}

# ============================================================================
# ZRAM Status and Information
# ============================================================================

# Get current ZRAM configuration and status
# Returns: 0 if ZRAM is active, 1 otherwise
get_zram_status() {
    log_debug "Checking ZRAM status..."

    local zram_found=0
    local status_output=""

    # Check if zram module is loaded
    if ! lsmod | grep -q "^zram "; then
        log_info "ZRAM module not loaded"
        echo "ZRAM Status: Not loaded"
        return 1
    fi

    # Check for active zram swap devices
    local zram_dev
    for zram_dev in /dev/zram*; do
        [[ -b "$zram_dev" ]] || continue

        local dev_name
        dev_name=$(basename "$zram_dev")

        # Check if it's being used as swap
        if swapon --show=NAME,SIZE,USED,PRIO 2>/dev/null | grep -q "$zram_dev"; then
            zram_found=1
            local swap_info
            swap_info=$(swapon --show=NAME,SIZE,USED,PRIO --noheadings 2>/dev/null | grep "$zram_dev")

            # Get compression stats
            local disksize orig_data compr_data algorithm
            if [[ -r "/sys/block/$dev_name/disksize" ]]; then
                disksize=$(cat "/sys/block/$dev_name/disksize")
                disksize=$((disksize / 1024 / 1024))  # Convert to MB
            else
                disksize="?"
            fi

            if [[ -r "/sys/block/$dev_name/orig_data_size" ]]; then
                orig_data=$(cat "/sys/block/$dev_name/orig_data_size")
                orig_data=$((orig_data / 1024 / 1024))  # Convert to MB
            else
                orig_data="?"
            fi

            if [[ -r "/sys/block/$dev_name/compr_data_size" ]]; then
                compr_data=$(cat "/sys/block/$dev_name/compr_data_size")
                compr_data=$((compr_data / 1024 / 1024))  # Convert to MB
            else
                compr_data="?"
            fi

            if [[ -r "/sys/block/$dev_name/comp_algorithm" ]]; then
                algorithm=$(cat "/sys/block/$dev_name/comp_algorithm" | grep -oP '\[\K[^\]]+')
            else
                algorithm="?"
            fi

            status_output="${status_output}Device: $zram_dev\n"
            status_output="${status_output}  Swap: $swap_info\n"
            status_output="${status_output}  Size: ${disksize}MB\n"
            status_output="${status_output}  Algorithm: $algorithm\n"

            if [[ "$orig_data" != "?" ]] && [[ "$compr_data" != "?" ]] && [[ $compr_data -gt 0 ]]; then
                local ratio
                ratio=$(awk "BEGIN {printf \"%.2f\", $orig_data / $compr_data}")
                status_output="${status_output}  Compression: ${orig_data}MB -> ${compr_data}MB (ratio: ${ratio}:1)\n"
            fi
            status_output="${status_output}\n"
        fi
    done

    if [[ $zram_found -eq 1 ]]; then
        echo -e "$status_output"
        return 0
    else
        log_info "ZRAM module loaded but no swap devices active"
        echo "ZRAM Status: Module loaded, no active swap"
        return 1
    fi
}

# Get ZRAM statistics (compression ratio, memory saved, etc.)
# Returns: formatted statistics on stdout
get_zram_stats() {
    log_debug "Gathering ZRAM statistics..."

    local total_orig=0
    local total_compr=0
    local total_disksize=0
    local device_count=0

    local zram_dev
    for zram_dev in /sys/block/zram*; do
        [[ -d "$zram_dev" ]] || continue

        local dev_name
        dev_name=$(basename "$zram_dev")

        # Check if device is initialized (has disksize > 0)
        if [[ -r "$zram_dev/disksize" ]]; then
            local disksize
            disksize=$(cat "$zram_dev/disksize")
            if [[ $disksize -eq 0 ]]; then
                continue
            fi

            ((device_count++))
            total_disksize=$((total_disksize + disksize))

            if [[ -r "$zram_dev/orig_data_size" ]]; then
                local orig_data
                orig_data=$(cat "$zram_dev/orig_data_size")
                total_orig=$((total_orig + orig_data))
            fi

            if [[ -r "$zram_dev/compr_data_size" ]]; then
                local compr_data
                compr_data=$(cat "$zram_dev/compr_data_size")
                total_compr=$((total_compr + compr_data))
            fi
        fi
    done

    if [[ $device_count -eq 0 ]]; then
        echo "No active ZRAM devices"
        return 1
    fi

    # Convert to MB
    total_disksize=$((total_disksize / 1024 / 1024))
    total_orig=$((total_orig / 1024 / 1024))
    total_compr=$((total_compr / 1024 / 1024))

    echo "ZRAM Statistics:"
    echo "  Active devices: $device_count"
    echo "  Total capacity: ${total_disksize}MB"
    echo "  Original data: ${total_orig}MB"
    echo "  Compressed size: ${total_compr}MB"

    if [[ $total_compr -gt 0 ]] && [[ $total_orig -gt 0 ]]; then
        local ratio saved_pct
        ratio=$(awk "BEGIN {printf \"%.2f\", $total_orig / $total_compr}")
        saved_pct=$(awk "BEGIN {printf \"%.1f\", (1 - $total_compr / $total_orig) * 100}")
        echo "  Compression ratio: ${ratio}:1"
        echo "  Space saved: ${saved_pct}%"

        local saved_mb
        saved_mb=$((total_orig - total_compr))
        echo "  Memory saved: ${saved_mb}MB"
    fi
}

# ============================================================================
# ZRAM Configuration - systemd-zram-generator
# ============================================================================

# Setup ZRAM using systemd-zram-generator (modern method)
# Arguments:
#   $1 - size in MB (optional, auto-calculated if not provided)
#   $2 - compression algorithm (optional, auto-selected if not provided)
#   $3 - swap priority (optional, default: 100)
# Returns: 0 on success, 1 on failure
setup_zram_systemd() {
    local size_mb="${1:-}"
    local algorithm="${2:-}"
    local priority="${3:-$ZRAM_DEFAULT_PRIORITY}"

    log_info "Setting up ZRAM using systemd-zram-generator..."

    # Check if systemd-zram-generator is available
    if ! command -v systemd-zram-generator &>/dev/null && \
       ! command -v /usr/lib/systemd/system-generators/systemd-zram-generator &>/dev/null; then
        log_warn "systemd-zram-generator not found, falling back to manual setup"
        return 1
    fi

    # Check for root permissions
    if [[ $EUID -ne 0 ]]; then
        log_error "Root permissions required to setup ZRAM"
        return 1
    fi

    # Auto-calculate size if not provided
    if [[ -z "$size_mb" ]]; then
        size_mb=$(calculate_zram_size)
    fi

    # Auto-select algorithm if not provided
    if [[ -z "$algorithm" ]]; then
        algorithm=$(select_zram_algorithm)
    fi

    # Validate algorithm
    if ! check_algorithm_available "$algorithm"; then
        log_warn "Algorithm $algorithm not available, auto-selecting..."
        algorithm=$(select_zram_algorithm)
    fi

    # Create config directory if needed
    mkdir -p "$(dirname "$ZRAM_SYSTEMD_CONFIG")"

    # Create systemd-zram-generator configuration
    log_debug "Creating $ZRAM_SYSTEMD_CONFIG"
    cat > "$ZRAM_SYSTEMD_CONFIG" <<EOF
# ZRAM Configuration
# Generated by Ultimate Linux Suite
# Date: $(date '+%Y-%m-%d %H:%M:%S')

[zram0]
# ZRAM device size
zram-size = ${size_mb}

# Compression algorithm
compression-algorithm = ${algorithm}

# Swap priority (higher than disk swap)
swap-priority = ${priority}

# Mount point (for swap)
mount-point = swap
EOF

    if [[ $? -ne 0 ]]; then
        log_error "Failed to create ZRAM configuration file"
        return 1
    fi

    log_success "ZRAM configuration created: ${size_mb}MB with $algorithm compression"

    # Reload systemd and enable zram
    log_debug "Reloading systemd daemon..."
    systemctl daemon-reload

    # The systemd-zram-generator runs automatically, but we can trigger it
    if systemctl list-units --all | grep -q "swap-create@zram0"; then
        log_debug "Enabling and starting swap-create@zram0.service"
        systemctl enable swap-create@zram0.service 2>/dev/null || true
        systemctl start swap-create@zram0.service 2>/dev/null || true
    fi

    # Verify ZRAM was created
    sleep 1
    if [[ -b "/dev/zram0" ]]; then
        log_success "ZRAM device created successfully"

        # Check if it's active as swap
        if swapon --show | grep -q "/dev/zram0"; then
            log_success "ZRAM swap is active"
            get_zram_stats
            return 0
        else
            log_warn "ZRAM device created but not active as swap yet"
            return 0
        fi
    else
        log_error "ZRAM device was not created"
        return 1
    fi
}

# ============================================================================
# ZRAM Configuration - Manual Setup
# ============================================================================

# Create ZRAM device manually
# Arguments:
#   $1 - device number (e.g., 0 for /dev/zram0)
#   $2 - size in MB
#   $3 - compression algorithm
# Returns: 0 on success, 1 on failure
create_zram_device() {
    local device_num="$1"
    local size_mb="$2"
    local algorithm="$3"

    if [[ -z "$device_num" ]] || [[ -z "$size_mb" ]] || [[ -z "$algorithm" ]]; then
        log_error "create_zram_device: device number, size, and algorithm required"
        return 1
    fi

    log_debug "Creating ZRAM device: /dev/zram${device_num} (${size_mb}MB, $algorithm)"

    # Check for root permissions
    if [[ $EUID -ne 0 ]]; then
        log_error "Root permissions required to create ZRAM device"
        return 1
    fi

    # Load zram module
    if ! lsmod | grep -q "^zram "; then
        log_debug "Loading ZRAM kernel module..."
        if ! modprobe "$ZRAM_MODULE"; then
            log_error "Failed to load ZRAM module"
            return 1
        fi
    fi

    local zram_dev="/dev/zram${device_num}"

    # Check if device already exists
    if [[ -b "$zram_dev" ]]; then
        # Check if it's already in use
        if swapon --show | grep -q "$zram_dev"; then
            log_warn "ZRAM device $zram_dev already in use as swap"
            return 1
        fi

        # Reset the device
        log_debug "Resetting existing ZRAM device"
        echo 1 > "/sys/block/zram${device_num}/reset" 2>/dev/null || true
    else
        # Create new device if supported
        if [[ -e /sys/class/zram-control/hot_add ]]; then
            log_debug "Creating ZRAM device using hot_add"
            echo "$device_num" > /sys/class/zram-control/hot_add 2>/dev/null || true
        fi
    fi

    # Wait for device to appear
    local timeout=5
    local count=0
    while [[ ! -b "$zram_dev" ]] && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done

    if [[ ! -b "$zram_dev" ]]; then
        log_error "ZRAM device $zram_dev not found after creation"
        return 1
    fi

    # Set compression algorithm
    if [[ -w "/sys/block/zram${device_num}/comp_algorithm" ]]; then
        log_debug "Setting compression algorithm to $algorithm"
        if ! echo "$algorithm" > "/sys/block/zram${device_num}/comp_algorithm"; then
            log_warn "Failed to set compression algorithm to $algorithm"
            # Try to continue anyway with default algorithm
        fi
    fi

    # Set compression streams based on CPU cores
    optimize_zram_streams "$device_num"

    # Set disksize (this initializes the device)
    local size_bytes=$((size_mb * 1024 * 1024))
    log_debug "Setting ZRAM size to ${size_mb}MB"
    if ! echo "$size_bytes" > "/sys/block/zram${device_num}/disksize"; then
        log_error "Failed to set ZRAM disk size"
        return 1
    fi

    log_success "ZRAM device $zram_dev created (${size_mb}MB, $algorithm)"
    return 0
}

# Enable ZRAM device as swap
# Arguments:
#   $1 - device number (e.g., 0 for /dev/zram0)
#   $2 - swap priority (optional, default: 100)
# Returns: 0 on success, 1 on failure
enable_zram_swap() {
    local device_num="$1"
    local priority="${2:-$ZRAM_DEFAULT_PRIORITY}"

    if [[ -z "$device_num" ]]; then
        log_error "enable_zram_swap: device number required"
        return 1
    fi

    local zram_dev="/dev/zram${device_num}"

    log_debug "Enabling ZRAM swap on $zram_dev with priority $priority"

    # Check for root permissions
    if [[ $EUID -ne 0 ]]; then
        log_error "Root permissions required to enable ZRAM swap"
        return 1
    fi

    # Verify device exists
    if [[ ! -b "$zram_dev" ]]; then
        log_error "ZRAM device $zram_dev not found"
        return 1
    fi

    # Check if already enabled
    if swapon --show | grep -q "$zram_dev"; then
        log_warn "ZRAM swap already enabled on $zram_dev"
        return 0
    fi

    # Make swap filesystem
    log_debug "Creating swap filesystem on $zram_dev"
    if ! mkswap "$zram_dev" >/dev/null 2>&1; then
        log_error "Failed to create swap filesystem on $zram_dev"
        return 1
    fi

    # Enable swap with priority
    log_debug "Activating swap with priority $priority"
    if ! swapon -p "$priority" "$zram_dev"; then
        log_error "Failed to enable swap on $zram_dev"
        return 1
    fi

    log_success "ZRAM swap enabled on $zram_dev (priority: $priority)"

    # Show current swap status
    swapon --show

    return 0
}

# Setup ZRAM manually (without systemd-zram-generator)
# Arguments:
#   $1 - size in MB (optional, auto-calculated if not provided)
#   $2 - compression algorithm (optional, auto-selected if not provided)
#   $3 - swap priority (optional, default: 100)
# Returns: 0 on success, 1 on failure
setup_zram_manual() {
    local size_mb="${1:-}"
    local algorithm="${2:-}"
    local priority="${3:-$ZRAM_DEFAULT_PRIORITY}"

    log_info "Setting up ZRAM manually..."

    # Check for root permissions
    if [[ $EUID -ne 0 ]]; then
        log_error "Root permissions required to setup ZRAM"
        return 1
    fi

    # Check ZRAM support
    if ! check_zram_support; then
        log_error "ZRAM not supported on this system"
        return 1
    fi

    # Auto-calculate size if not provided
    if [[ -z "$size_mb" ]]; then
        size_mb=$(calculate_zram_size)
    fi

    # Auto-select algorithm if not provided
    if [[ -z "$algorithm" ]]; then
        algorithm=$(select_zram_algorithm)
    fi

    # Create ZRAM device
    if ! create_zram_device 0 "$size_mb" "$algorithm"; then
        log_error "Failed to create ZRAM device"
        return 1
    fi

    # Enable as swap
    if ! enable_zram_swap 0 "$priority"; then
        log_error "Failed to enable ZRAM swap"
        return 1
    fi

    log_success "ZRAM setup complete: ${size_mb}MB with $algorithm compression"

    # Create systemd service for persistence (optional)
    create_zram_systemd_service "$size_mb" "$algorithm" "$priority"

    return 0
}

# Create systemd service for manual ZRAM setup (for persistence across reboots)
# Arguments:
#   $1 - size in MB
#   $2 - compression algorithm
#   $3 - swap priority
create_zram_systemd_service() {
    local size_mb="$1"
    local algorithm="$2"
    local priority="$3"

    log_debug "Creating systemd service for ZRAM persistence..."

    local service_file="/etc/systemd/system/zram-swap.service"

    cat > "$service_file" <<EOF
# ZRAM Swap Service
# Generated by Ultimate Linux Suite
# Date: $(date '+%Y-%m-%d %H:%M:%S')

[Unit]
Description=ZRAM Compressed Swap
After=multi-user.target
Before=swap.target

[Service]
Type=oneshot
RemainAfterExit=yes

# Load zram module
ExecStartPre=/usr/sbin/modprobe zram

# Reset device if it exists
ExecStartPre=-/bin/sh -c 'echo 1 > /sys/block/zram0/reset 2>/dev/null || true'

# Set compression algorithm
ExecStartPre=/bin/sh -c 'echo ${algorithm} > /sys/block/zram0/comp_algorithm 2>/dev/null || true'

# Set disk size
ExecStart=/bin/sh -c 'echo $((${size_mb} * 1024 * 1024)) > /sys/block/zram0/disksize'

# Create and enable swap
ExecStart=/usr/sbin/mkswap /dev/zram0
ExecStart=/usr/sbin/swapon -p ${priority} /dev/zram0

# Disable swap and reset on stop
ExecStop=/usr/sbin/swapoff /dev/zram0
ExecStop=/bin/sh -c 'echo 1 > /sys/block/zram0/reset 2>/dev/null || true'

[Install]
WantedBy=multi-user.target
EOF

    if [[ $? -eq 0 ]]; then
        log_debug "Enabling zram-swap.service"
        systemctl daemon-reload
        systemctl enable zram-swap.service
        log_success "ZRAM systemd service created and enabled"
        return 0
    else
        log_warn "Failed to create ZRAM systemd service"
        return 1
    fi
}

# ============================================================================
# ZRAM Optimization
# ============================================================================

# Optimize compression streams based on CPU cores
# Arguments:
#   $1 - device number (e.g., 0 for /dev/zram0)
optimize_zram_streams() {
    local device_num="$1"

    if [[ -z "$device_num" ]]; then
        log_error "optimize_zram_streams: device number required"
        return 1
    fi

    # Ensure CPU detection has run
    if [[ -z "$CPU_CORES" ]]; then
        detect_cpu >/dev/null 2>&1
    fi

    local cores=${CPU_CORES:-1}
    local streams

    # Set compression streams to match CPU cores (max 4 for most cases)
    if [[ $cores -gt 4 ]]; then
        streams=4
    else
        streams=$cores
    fi

    log_debug "Setting ZRAM compression streams to $streams (CPU cores: $cores)"

    # Some older kernels use max_comp_streams, newer ones auto-manage
    if [[ -w "/sys/block/zram${device_num}/max_comp_streams" ]]; then
        if echo "$streams" > "/sys/block/zram${device_num}/max_comp_streams" 2>/dev/null; then
            log_debug "Compression streams set to $streams"
        else
            log_debug "Could not set compression streams (may not be supported)"
        fi
    else
        log_debug "Compression streams auto-managed by kernel"
    fi

    return 0
}

# ============================================================================
# ZRAM Removal and Cleanup
# ============================================================================

# Disable and remove ZRAM
# Arguments:
#   $1 - device number (optional, default: all devices)
# Returns: 0 on success, 1 on failure
disable_zram() {
    local device_num="${1:-all}"

    log_info "Disabling ZRAM..."

    # Check for root permissions
    if [[ $EUID -ne 0 ]]; then
        log_error "Root permissions required to disable ZRAM"
        return 1
    fi

    local success=0

    if [[ "$device_num" == "all" ]]; then
        # Disable all ZRAM swap devices
        local zram_dev
        for zram_dev in /dev/zram*; do
            [[ -b "$zram_dev" ]] || continue

            local dev_name
            dev_name=$(basename "$zram_dev")
            local dev_num="${dev_name#zram}"

            if swapon --show | grep -q "$zram_dev"; then
                log_debug "Disabling swap on $zram_dev"
                if swapoff "$zram_dev"; then
                    log_success "Swap disabled on $zram_dev"
                    success=1
                else
                    log_error "Failed to disable swap on $zram_dev"
                fi
            fi

            # Reset device
            if [[ -w "/sys/block/$dev_name/reset" ]]; then
                log_debug "Resetting $zram_dev"
                echo 1 > "/sys/block/$dev_name/reset" 2>/dev/null || true
            fi
        done
    else
        # Disable specific device
        local zram_dev="/dev/zram${device_num}"

        if [[ ! -b "$zram_dev" ]]; then
            log_warn "ZRAM device $zram_dev not found"
            return 1
        fi

        if swapon --show | grep -q "$zram_dev"; then
            log_debug "Disabling swap on $zram_dev"
            if swapoff "$zram_dev"; then
                log_success "Swap disabled on $zram_dev"
                success=1
            else
                log_error "Failed to disable swap on $zram_dev"
                return 1
            fi
        fi

        # Reset device
        if [[ -w "/sys/block/zram${device_num}/reset" ]]; then
            log_debug "Resetting $zram_dev"
            echo 1 > "/sys/block/zram${device_num}/reset" 2>/dev/null || true
        fi
    fi

    # Optionally unload module
    if [[ $success -eq 1 ]]; then
        log_debug "Unloading ZRAM module..."
        rmmod "$ZRAM_MODULE" 2>/dev/null || log_debug "Could not unload ZRAM module (may be in use)"
    fi

    # Disable systemd services
    if systemctl is-enabled zram-swap.service &>/dev/null; then
        log_debug "Disabling zram-swap.service"
        systemctl disable zram-swap.service
        systemctl stop zram-swap.service
    fi

    if systemctl is-enabled swap-create@zram0.service &>/dev/null; then
        log_debug "Disabling swap-create@zram0.service"
        systemctl disable swap-create@zram0.service
        systemctl stop swap-create@zram0.service
    fi

    # Remove configuration files
    if [[ -f "$ZRAM_SYSTEMD_CONFIG" ]]; then
        log_debug "Removing $ZRAM_SYSTEMD_CONFIG"
        rm -f "$ZRAM_SYSTEMD_CONFIG"
    fi

    if [[ -f "/etc/systemd/system/zram-swap.service" ]]; then
        log_debug "Removing /etc/systemd/system/zram-swap.service"
        rm -f "/etc/systemd/system/zram-swap.service"
    fi

    systemctl daemon-reload

    log_success "ZRAM disabled and cleaned up"
    return 0
}

# ============================================================================
# Main ZRAM Setup Function (Auto-detect method)
# ============================================================================

# Main ZRAM setup function - automatically chooses best method
# Arguments:
#   $1 - size in MB (optional, auto-calculated if not provided)
#   $2 - compression algorithm (optional, auto-selected if not provided)
#   $3 - swap priority (optional, default: 100)
# Returns: 0 on success, 1 on failure
setup_zram() {
    local size_mb="${1:-}"
    local algorithm="${2:-}"
    local priority="${3:-$ZRAM_DEFAULT_PRIORITY}"

    log_section "ZRAM Compressed Swap Setup"

    # Check ZRAM support
    if ! check_zram_support; then
        log_error "ZRAM not supported on this kernel"
        log_info "Please upgrade your kernel or enable CONFIG_ZRAM"
        return 1
    fi

    log_success "ZRAM support detected"

    # Try systemd-zram-generator first (preferred method)
    if command -v systemd-zram-generator &>/dev/null || \
       command -v /usr/lib/systemd/system-generators/systemd-zram-generator &>/dev/null; then
        log_info "Using systemd-zram-generator (preferred method)"
        if setup_zram_systemd "$size_mb" "$algorithm" "$priority"; then
            return 0
        else
            log_warn "systemd-zram-generator setup failed, trying manual method..."
        fi
    else
        log_info "systemd-zram-generator not available, using manual method"
    fi

    # Fallback to manual setup
    setup_zram_manual "$size_mb" "$algorithm" "$priority"
}

# ============================================================================
# Export Functions
# ============================================================================

# Functions available for use by other modules:
# - check_zram_support
# - get_zram_status
# - calculate_zram_size
# - select_zram_algorithm
# - check_algorithm_available
# - setup_zram_systemd
# - setup_zram_manual
# - create_zram_device
# - enable_zram_swap
# - disable_zram
# - get_zram_stats
# - optimize_zram_streams
# - setup_zram (main function)
