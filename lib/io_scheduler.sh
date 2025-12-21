#!/usr/bin/env bash
#
# io_scheduler.sh - I/O Scheduler Configuration for Ultimate Linux Suite
#
# This module provides comprehensive I/O scheduler detection, configuration,
# and optimization for block devices based on their type (NVMe, SSD, HDD, VM).
#

# Prevent multiple sourcing
[[ -n "${_IO_SCHEDULER_LOADED:-}" ]] && return 0
readonly _IO_SCHEDULER_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

_IO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${_IO_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# Source hardware_detect with fallback
source "${_IO_SCRIPT_DIR}/hardware_detect.sh" 2>/dev/null || {
    log_debug "hardware_detect.sh not available, using fallbacks"
}

# ============================================================================
# Constants
# ============================================================================

readonly UDEV_RULES_FILE="/etc/udev/rules.d/60-io-scheduler.rules"
readonly SYS_BLOCK_PATH="/sys/block"

# Scheduler recommendations by device type
declare -gA SCHEDULER_RECOMMENDATIONS=(
    [nvme]="none"
    [ssd]="mq-deadline"
    [hdd]="bfq"
    [vm]="none"
)

# Fallback schedulers if primary is not available
declare -gA SCHEDULER_FALLBACKS=(
    [nvme]="mq-deadline"
    [ssd]="kyber"
    [hdd]="mq-deadline"
    [vm]="mq-deadline"
)

# ============================================================================
# Device Detection Functions
# ============================================================================

# Get all block devices, excluding loop and ram devices
# Returns: List of block device names (e.g., sda nvme0n1)
get_block_devices() {
    local devices=()

    if [[ ! -d "$SYS_BLOCK_PATH" ]]; then
        log_error "System block device path not found: $SYS_BLOCK_PATH"
        return 1
    fi

    for device in "$SYS_BLOCK_PATH"/*; do
        [[ -d "$device" ]] || continue

        local dev_name
        dev_name=$(basename "$device")

        # Skip loop, ram, and zram devices
        if [[ "$dev_name" =~ ^(loop|ram|zram) ]]; then
            log_debug "Skipping device: $dev_name"
            continue
        fi

        devices+=("$dev_name")
    done

    if [[ ${#devices[@]} -eq 0 ]]; then
        log_warn "No block devices found"
        return 1
    fi

    printf "%s\n" "${devices[@]}"
    return 0
}

# Detect device type: nvme, ssd, hdd, or vm
# Args: $1 - device name (e.g., sda, nvme0n1)
# Returns: Device type string
get_device_type() {
    local device="$1"

    if [[ -z "$device" ]]; then
        log_error "get_device_type: No device specified"
        return 1
    fi

    # Check if device exists
    if [[ ! -d "$SYS_BLOCK_PATH/$device" ]]; then
        log_error "Device not found: $device"
        return 1
    fi

    # NVMe detection - simple and reliable
    if [[ "$device" == nvme* ]]; then
        echo "nvme"
        return 0
    fi

    # Check for virtual devices (common in VMs)
    # Virtual devices often don't have a proper rotational attribute
    if [[ -r "$SYS_BLOCK_PATH/$device/device/vendor" ]]; then
        local vendor
        vendor=$(cat "$SYS_BLOCK_PATH/$device/device/vendor" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

        # Check for common VM vendors
        if [[ "$vendor" =~ (qemu|vbox|vmware|xen|virtio|virtual) ]]; then
            echo "vm"
            return 0
        fi
    fi

    # Check rotational attribute for SSD vs HDD
    if [[ -r "$SYS_BLOCK_PATH/$device/queue/rotational" ]]; then
        local rotational
        rotational=$(cat "$SYS_BLOCK_PATH/$device/queue/rotational" 2>/dev/null)

        if [[ "$rotational" == "0" ]]; then
            echo "ssd"
            return 0
        elif [[ "$rotational" == "1" ]]; then
            echo "hdd"
            return 0
        fi
    fi

    # Additional VM detection via product/model name
    if [[ -r "$SYS_BLOCK_PATH/$device/device/model" ]]; then
        local model
        model=$(cat "$SYS_BLOCK_PATH/$device/device/model" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

        if [[ "$model" =~ (virtual|vdisk|qemu|vmware) ]]; then
            echo "vm"
            return 0
        fi
    fi

    # Default to SSD if we can't determine (safer for modern systems)
    log_warn "Could not determine device type for $device, defaulting to ssd"
    echo "ssd"
    return 0
}

# Get available schedulers for a device
# Args: $1 - device name (e.g., sda, nvme0n1)
# Returns: Space-separated list of available schedulers
get_available_schedulers() {
    local device="$1"

    if [[ -z "$device" ]]; then
        log_error "get_available_schedulers: No device specified"
        return 1
    fi

    local scheduler_file="$SYS_BLOCK_PATH/$device/queue/scheduler"

    if [[ ! -r "$scheduler_file" ]]; then
        log_error "Cannot read scheduler file for device: $device"
        return 1
    fi

    # Read and clean up the scheduler list
    # Format is: [current] other1 other2
    local schedulers
    schedulers=$(cat "$scheduler_file" 2>/dev/null | tr -d '[]')

    if [[ -z "$schedulers" ]]; then
        log_error "No schedulers available for device: $device"
        return 1
    fi

    echo "$schedulers"
    return 0
}

# Get current scheduler for a device
# Args: $1 - device name (e.g., sda, nvme0n1)
# Returns: Current scheduler name
get_current_scheduler() {
    local device="$1"

    if [[ -z "$device" ]]; then
        log_error "get_current_scheduler: No device specified"
        return 1
    fi

    local scheduler_file="$SYS_BLOCK_PATH/$device/queue/scheduler"

    if [[ ! -r "$scheduler_file" ]]; then
        log_error "Cannot read scheduler file for device: $device"
        return 1
    fi

    # Extract the current scheduler (within brackets)
    local current
    current=$(grep -o '\[.*\]' "$scheduler_file" 2>/dev/null | tr -d '[]')

    if [[ -z "$current" ]]; then
        log_error "Could not determine current scheduler for device: $device"
        return 1
    fi

    echo "$current"
    return 0
}

# Recommend best scheduler based on device type
# Args: $1 - device name (e.g., sda, nvme0n1)
# Returns: Recommended scheduler name
recommend_scheduler() {
    local device="$1"

    if [[ -z "$device" ]]; then
        log_error "recommend_scheduler: No device specified"
        return 1
    fi

    # Get device type
    local dev_type
    dev_type=$(get_device_type "$device")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to detect device type for $device"
        return 1
    fi

    # Get available schedulers
    local available
    available=$(get_available_schedulers "$device")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get available schedulers for $device"
        return 1
    fi

    # Get primary recommendation
    local recommended="${SCHEDULER_RECOMMENDATIONS[$dev_type]}"

    # Check if recommended scheduler is available
    if echo "$available" | grep -qw "$recommended"; then
        echo "$recommended"
        return 0
    fi

    # Try fallback
    local fallback="${SCHEDULER_FALLBACKS[$dev_type]}"
    if echo "$available" | grep -qw "$fallback"; then
        log_warn "Recommended scheduler '$recommended' not available for $device ($dev_type), using fallback: $fallback"
        echo "$fallback"
        return 0
    fi

    # Last resort: use first available scheduler
    local first_available
    first_available=$(echo "$available" | awk '{print $1}')
    log_warn "Neither recommended nor fallback scheduler available for $device ($dev_type), using: $first_available"
    echo "$first_available"
    return 0
}

# ============================================================================
# Scheduler Configuration Functions
# ============================================================================

# Set scheduler for a specific device (runtime only, not persistent)
# Args: $1 - device name, $2 - scheduler name
# Returns: 0 on success, 1 on failure
set_scheduler() {
    local device="$1"
    local scheduler="$2"

    if [[ -z "$device" ]] || [[ -z "$scheduler" ]]; then
        log_error "set_scheduler: Device and scheduler required"
        return 1
    fi

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required to set I/O scheduler"
        return 1
    fi

    local scheduler_file="$SYS_BLOCK_PATH/$device/queue/scheduler"

    if [[ ! -w "$scheduler_file" ]]; then
        log_error "Cannot write to scheduler file for device: $device"
        return 1
    fi

    # Verify scheduler is available
    local available
    available=$(get_available_schedulers "$device")
    if ! echo "$available" | grep -qw "$scheduler"; then
        log_error "Scheduler '$scheduler' not available for device $device"
        log_error "Available schedulers: $available"
        return 1
    fi

    # Get current scheduler before changing
    local current
    current=$(get_current_scheduler "$device")

    # Set the scheduler
    if echo "$scheduler" > "$scheduler_file" 2>/dev/null; then
        log_info "Set I/O scheduler for $device: $current -> $scheduler"
        return 0
    else
        log_error "Failed to set scheduler '$scheduler' for device $device"
        return 1
    fi
}

# Apply optimal schedulers to all block devices
# Returns: 0 on success, 1 if any failures occurred
apply_all_schedulers() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required to apply I/O schedulers"
        return 1
    fi

    log_info "Applying optimal I/O schedulers to all block devices..."

    local devices
    devices=$(get_block_devices)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get block devices"
        return 1
    fi

    local success=0
    local failed=0

    while IFS= read -r device; do
        local dev_type
        dev_type=$(get_device_type "$device")

        local recommended
        recommended=$(recommend_scheduler "$device")

        local current
        current=$(get_current_scheduler "$device")

        # Skip if already set to recommended
        if [[ "$current" == "$recommended" ]]; then
            log_debug "Device $device ($dev_type) already using optimal scheduler: $recommended"
            ((success++))
            continue
        fi

        # Apply the scheduler
        if set_scheduler "$device" "$recommended"; then
            ((success++))
        else
            ((failed++))
        fi
    done <<< "$devices"

    log_info "Applied schedulers: $success successful, $failed failed"

    [[ $failed -eq 0 ]] && return 0 || return 1
}

# ============================================================================
# Udev Rules Management
# ============================================================================

# Generate udev rules for persistent scheduler configuration
# Returns: 0 on success, 1 on failure
generate_udev_rules() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required to generate udev rules"
        return 1
    fi

    log_info "Generating udev rules for I/O schedulers..."

    # Create backup if file exists
    if [[ -f "$UDEV_RULES_FILE" ]]; then
        local backup="${UDEV_RULES_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$UDEV_RULES_FILE" "$backup" 2>/dev/null
        log_info "Backed up existing rules to: $backup"
    fi

    # Create the rules file
    cat > "$UDEV_RULES_FILE" <<'EOF'
# I/O Scheduler Rules - Generated by Ultimate Linux Suite
# This file configures optimal I/O schedulers for different device types
#
# Scheduler Selection Logic:
# - NVMe: "none" - No scheduling overhead needed, hardware handles it
# - SSD:  "mq-deadline" - Low latency, good for SSDs
# - HDD:  "bfq" - Budget Fair Queueing for rotational media
# - VM:   "none" or "mq-deadline" - Host handles scheduling
#
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# NVMe devices - use 'none' scheduler (no overhead needed)
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"

# SATA/SCSI SSDs (non-rotational) - use mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]|sd[a-z][a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# HDDs (rotational) - use bfq for fair queuing
ACTION=="add|change", KERNEL=="sd[a-z]|sd[a-z][a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

# VirtIO block devices (VMs) - use none for minimal overhead
ACTION=="add|change", KERNEL=="vd[a-z]|vd[a-z][a-z]", ATTR{queue/scheduler}="none"

# MMC/eMMC devices - use mq-deadline
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline"
EOF

    if [[ $? -eq 0 ]]; then
        chmod 644 "$UDEV_RULES_FILE" 2>/dev/null
        log_success "Generated udev rules: $UDEV_RULES_FILE"
        return 0
    else
        log_error "Failed to generate udev rules"
        return 1
    fi
}

# Apply (reload) udev rules
# Returns: 0 on success, 1 on failure
apply_udev_rules() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required to reload udev rules"
        return 1
    fi

    if [[ ! -f "$UDEV_RULES_FILE" ]]; then
        log_error "Udev rules file not found: $UDEV_RULES_FILE"
        log_info "Run generate_udev_rules first"
        return 1
    fi

    log_info "Reloading udev rules..."

    # Reload udev rules
    if command -v udevadm &>/dev/null; then
        if udevadm control --reload-rules 2>/dev/null; then
            log_success "Reloaded udev rules"

            # Trigger rules for block devices
            log_info "Triggering udev rules for block devices..."
            if udevadm trigger --subsystem-match=block 2>/dev/null; then
                log_success "Triggered udev rules for block devices"
                return 0
            else
                log_warn "Failed to trigger udev rules, changes will apply on next boot"
                return 0
            fi
        else
            log_error "Failed to reload udev rules"
            return 1
        fi
    else
        log_error "udevadm not found, cannot reload rules"
        return 1
    fi
}

# ============================================================================
# Statistics and Monitoring
# ============================================================================

# Get I/O statistics for a device
# Args: $1 - device name (e.g., sda, nvme0n1)
# Returns: Formatted I/O statistics
get_scheduler_stats() {
    local device="$1"

    if [[ -z "$device" ]]; then
        log_error "get_scheduler_stats: No device specified"
        return 1
    fi

    if [[ ! -d "$SYS_BLOCK_PATH/$device" ]]; then
        log_error "Device not found: $device"
        return 1
    fi

    local stats_file="$SYS_BLOCK_PATH/$device/stat"
    local scheduler_file="$SYS_BLOCK_PATH/$device/queue/scheduler"

    if [[ ! -r "$stats_file" ]]; then
        log_error "Cannot read stats for device: $device"
        return 1
    fi

    # Get device info
    local dev_type
    dev_type=$(get_device_type "$device")

    local current_scheduler
    current_scheduler=$(get_current_scheduler "$device")

    local recommended
    recommended=$(recommend_scheduler "$device")

    # Read stats (format: read_ios read_merges read_sectors read_ticks write_ios ...)
    local stats
    stats=$(cat "$stats_file" 2>/dev/null)

    # Parse stats
    local read_ios write_ios read_sectors write_sectors
    read -r read_ios _ read_sectors _ write_ios _ write_sectors _ <<< "$stats"

    # Convert sectors to MB (512 bytes per sector)
    local read_mb=$((read_sectors / 2048))
    local write_mb=$((write_sectors / 2048))

    # Get queue depth
    local queue_depth="N/A"
    if [[ -r "$SYS_BLOCK_PATH/$device/queue/nr_requests" ]]; then
        queue_depth=$(cat "$SYS_BLOCK_PATH/$device/queue/nr_requests")
    fi

    # Print formatted output
    cat <<EOF

Device: $device ($dev_type)
Current Scheduler: $current_scheduler
Recommended Scheduler: $recommended
Queue Depth: $queue_depth
─────────────────────────────────────────
Read Operations: $read_ios
Write Operations: $write_ios
Data Read: ${read_mb} MB
Data Written: ${write_mb} MB
EOF

    return 0
}

# Show I/O stats for all devices
# Returns: 0 on success
get_all_scheduler_stats() {
    log_info "I/O Scheduler Statistics for All Devices"
    echo ""

    local devices
    devices=$(get_block_devices)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get block devices"
        return 1
    fi

    while IFS= read -r device; do
        get_scheduler_stats "$device"
        echo ""
    done <<< "$devices"

    return 0
}

# ============================================================================
# Benchmarking
# ============================================================================

# Quick benchmark to compare schedulers
# Args: $1 - device name, $2 - test file path (optional)
# Returns: 0 on success
benchmark_schedulers() {
    local device="$1"
    local test_file="${2:-/tmp/io_scheduler_bench_$$}"

    if [[ -z "$device" ]]; then
        log_error "benchmark_schedulers: Device name required"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required for scheduler benchmarking"
        return 1
    fi

    if ! command -v dd &>/dev/null; then
        log_error "dd command not found, cannot benchmark"
        return 1
    fi

    # Get available schedulers
    local available
    available=$(get_available_schedulers "$device")

    # Get current scheduler to restore later
    local original_scheduler
    original_scheduler=$(get_current_scheduler "$device")

    log_info "Benchmarking schedulers for $device"
    log_info "Available schedulers: $available"
    log_warn "This will perform brief I/O tests and may impact system performance"
    echo ""

    declare -A results

    # Test each scheduler
    for scheduler in $available; do
        log_info "Testing scheduler: $scheduler"

        # Set scheduler
        if ! set_scheduler "$device" "$scheduler"; then
            log_warn "Skipping $scheduler (cannot set)"
            continue
        fi

        # Wait a moment for scheduler to take effect
        sleep 1

        # Perform write test (100MB)
        local start_time end_time duration throughput
        start_time=$(date +%s.%N)

        dd if=/dev/zero of="$test_file" bs=1M count=100 conv=fdatasync 2>/dev/null

        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc)
        throughput=$(echo "100 / $duration" | bc -l)

        results[$scheduler]=$(printf "%.2f" "$throughput")

        log_info "  Throughput: ${results[$scheduler]} MB/s"

        # Cleanup
        rm -f "$test_file" 2>/dev/null

        # Brief pause between tests
        sleep 2
    done

    # Restore original scheduler
    set_scheduler "$device" "$original_scheduler" >/dev/null
    log_info "Restored original scheduler: $original_scheduler"

    # Display results
    echo ""
    log_info "Benchmark Results Summary"
    echo "───────────────────────────────────────"

    # Sort results by throughput (descending)
    for scheduler in "${!results[@]}"; do
        printf "%-15s %8s MB/s\n" "$scheduler" "${results[$scheduler]}"
    done | sort -k2 -rn

    echo ""

    return 0
}

# ============================================================================
# User-Friendly Display Functions
# ============================================================================

# Show current scheduler configuration for all devices
# Returns: 0 on success
show_scheduler_config() {
    log_info "Current I/O Scheduler Configuration"
    echo ""
    printf "%-15s %-10s %-15s %-15s %s\n" "DEVICE" "TYPE" "CURRENT" "RECOMMENDED" "STATUS"
    echo "─────────────────────────────────────────────────────────────────────────────"

    local devices
    devices=$(get_block_devices)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get block devices"
        return 1
    fi

    while IFS= read -r device; do
        local dev_type current recommended status

        dev_type=$(get_device_type "$device")
        current=$(get_current_scheduler "$device")
        recommended=$(recommend_scheduler "$device")

        if [[ "$current" == "$recommended" ]]; then
            status="✓ Optimal"
        else
            status="⚠ Suboptimal"
        fi

        printf "%-15s %-10s %-15s %-15s %s\n" "$device" "$dev_type" "$current" "$recommended" "$status"
    done <<< "$devices"

    echo ""
    return 0
}

# ============================================================================
# Main Optimization Function
# ============================================================================

# Complete I/O scheduler optimization (runtime + persistent)
# Returns: 0 on success
optimize_io_schedulers() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required for I/O scheduler optimization"
        return 1
    fi

    log_section "I/O Scheduler Optimization"

    # Show current configuration
    show_scheduler_config

    # Apply runtime changes
    log_info "Applying runtime scheduler changes..."
    if apply_all_schedulers; then
        log_success "Runtime schedulers applied successfully"
    else
        log_warn "Some runtime scheduler changes failed"
    fi

    echo ""

    # Generate and apply udev rules for persistence
    log_info "Creating persistent udev rules..."
    if generate_udev_rules; then
        log_success "Udev rules generated"

        if apply_udev_rules; then
            log_success "Udev rules applied and activated"
        else
            log_warn "Udev rules generated but not immediately activated"
        fi
    else
        log_error "Failed to generate udev rules"
        return 1
    fi

    echo ""

    # Show final configuration
    log_info "Final I/O Scheduler Configuration"
    show_scheduler_config

    log_success "I/O scheduler optimization complete"
    log_info "Changes are both active now and will persist across reboots"

    return 0
}

# ============================================================================
# Module Information
# ============================================================================

# Print module usage information
io_scheduler_help() {
    cat <<'EOF'
I/O Scheduler Configuration Module
===================================

This module provides comprehensive I/O scheduler management for optimal
storage performance based on device type.

FUNCTIONS:

Device Detection:
  get_block_devices()           - List all block devices
  get_device_type DEVICE        - Detect device type (nvme/ssd/hdd/vm)
  get_available_schedulers DEV  - List available schedulers
  get_current_scheduler DEVICE  - Get current scheduler
  recommend_scheduler DEVICE    - Recommend optimal scheduler

Configuration:
  set_scheduler DEVICE SCHED    - Set scheduler (runtime only)
  apply_all_schedulers()        - Apply optimal schedulers to all devices
  optimize_io_schedulers()      - Complete optimization (runtime + persistent)

Persistence:
  generate_udev_rules()         - Create udev rules for persistence
  apply_udev_rules()            - Reload and trigger udev rules

Monitoring:
  show_scheduler_config()       - Display current configuration
  get_scheduler_stats DEVICE    - Show I/O statistics for device
  get_all_scheduler_stats()     - Show stats for all devices
  benchmark_schedulers DEVICE   - Benchmark available schedulers

SCHEDULER RECOMMENDATIONS:

  NVMe:  none (mq-deadline fallback)
         No scheduling needed, hardware is smart enough

  SSD:   mq-deadline (kyber fallback)
         Low latency, optimized for flash storage

  HDD:   bfq (mq-deadline fallback)
         Budget Fair Queueing for rotational media

  VM:    none (mq-deadline fallback)
         Host hypervisor handles scheduling

EXAMPLES:

  # Show current configuration
  show_scheduler_config

  # Apply optimal schedulers (runtime)
  apply_all_schedulers

  # Complete optimization (runtime + persistent)
  optimize_io_schedulers

  # Check stats for a device
  get_scheduler_stats sda

  # Benchmark schedulers
  benchmark_schedulers nvme0n1

EOF
}

# Export functions for use by other modules
export -f get_block_devices
export -f get_device_type
export -f get_available_schedulers
export -f get_current_scheduler
export -f recommend_scheduler
export -f set_scheduler
export -f apply_all_schedulers
export -f generate_udev_rules
export -f apply_udev_rules
export -f get_scheduler_stats
export -f get_all_scheduler_stats
export -f benchmark_schedulers
export -f show_scheduler_config
export -f optimize_io_schedulers
export -f io_scheduler_help

log_debug "I/O scheduler module loaded successfully"
