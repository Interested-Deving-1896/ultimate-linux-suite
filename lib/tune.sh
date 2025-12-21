#!/usr/bin/env bash
#
# tune.sh - Comprehensive Sysctl Configuration Generator for Ultimate Linux Suite
#
# This module provides intelligent system tuning based on hardware detection,
# generating optimized sysctl configurations for performance and security.
#
# Output: /etc/sysctl.d/99-ultimate-suite.conf
# Backup: $STATE_DIR/sysctl_backup/

# Prevent multiple sourcing
[[ -n "${_TUNE_LOADED:-}" ]] && return 0
readonly _TUNE_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

# Source required modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh" || { echo "ERROR: Cannot load logging.sh" >&2; exit 1; }
source "$SCRIPT_DIR/scan.sh" || { log_error "Cannot load scan.sh"; exit 1; }

# ============================================================================
# Configuration
# ============================================================================

readonly SYSCTL_CONFIG_DIR="/etc/sysctl.d"
readonly SYSCTL_CONFIG_FILE="$SYSCTL_CONFIG_DIR/99-ultimate-suite.conf"
readonly SYSCTL_BACKUP_DIR="${STATE_DIR:-$HOME/.local/state/ultimate-suite}/sysctl_backup"
readonly SYSCTL_VALIDATION_TIMEOUT=5

# ============================================================================
# Backup Management
# ============================================================================

# Backup current sysctl settings before making changes
# Usage: backup_sysctl
# Returns: 0 on success, 1 on failure
backup_sysctl() {
    log_info "Backing up current sysctl settings"

    # Create backup directory
    if ! mkdir -p "$SYSCTL_BACKUP_DIR" 2>/dev/null; then
        log_error "Failed to create backup directory: $SYSCTL_BACKUP_DIR"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$SYSCTL_BACKUP_DIR/sysctl_backup_${timestamp}.conf"
    local backup_json="$SYSCTL_BACKUP_DIR/sysctl_backup_${timestamp}.json"

    # Backup current sysctl -a output
    if ! sysctl -a > "$backup_file" 2>/dev/null; then
        log_warn "Failed to backup all sysctl values (may need sudo)"
        # Try to backup at least what we can read
        sysctl -a 2>/dev/null | grep -v 'permission denied' > "$backup_file" || true
    fi

    # Also backup our config file if it exists
    if [[ -f "$SYSCTL_CONFIG_FILE" ]]; then
        cp "$SYSCTL_CONFIG_FILE" "${SYSCTL_BACKUP_DIR}/99-ultimate-suite.conf_${timestamp}.bak" 2>/dev/null || true
    fi

    # Create metadata JSON
    cat > "$backup_json" <<EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "hostname": "$(hostname 2>/dev/null || echo 'unknown')",
    "kernel": "$(uname -r 2>/dev/null || echo 'unknown')",
    "backup_file": "$backup_file",
    "config_file_existed": $([ -f "$SYSCTL_CONFIG_FILE" ] && echo "true" || echo "false")
}
EOF

    log_success "Sysctl settings backed up to: $backup_file"
    log_debug "Backup metadata: $backup_json"

    # Clean old backups (keep last 10)
    local backup_count
    backup_count=$(find "$SYSCTL_BACKUP_DIR" -name "sysctl_backup_*.conf" | wc -l)
    if [[ "$backup_count" -gt 10 ]]; then
        log_debug "Cleaning old backups (keeping last 10)"
        find "$SYSCTL_BACKUP_DIR" -name "sysctl_backup_*.conf" -type f | sort | head -n -10 | xargs rm -f 2>/dev/null || true
        find "$SYSCTL_BACKUP_DIR" -name "sysctl_backup_*.json" -type f | sort | head -n -10 | xargs rm -f 2>/dev/null || true
    fi

    return 0
}

# Restore sysctl settings from backup
# Usage: restore_sysctl [backup_file]
# Returns: 0 on success, 1 on failure
restore_sysctl() {
    local backup_file="${1:-}"

    # If no backup file specified, find the most recent
    if [[ -z "$backup_file" ]]; then
        backup_file=$(find "$SYSCTL_BACKUP_DIR" -name "sysctl_backup_*.conf" -type f 2>/dev/null | sort -r | head -1)
        if [[ -z "$backup_file" ]]; then
            log_error "No backup files found in $SYSCTL_BACKUP_DIR"
            return 1
        fi
        log_info "Using most recent backup: $backup_file"
    fi

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    log_warn "Restoring sysctl settings from backup"
    log_info "This will reload settings from: $backup_file"

    # Apply each line from the backup
    local restored=0
    local failed=0

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Parse key = value format
        if [[ "$line" =~ ^([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Try to restore the value
            if sysctl -w "${key}=${value}" >/dev/null 2>&1; then
                ((restored++))
            else
                ((failed++))
                log_debug "Failed to restore: ${key}=${value}"
            fi
        fi
    done < "$backup_file"

    log_info "Restored $restored settings, $failed failed"

    if [[ "$failed" -gt 0 ]]; then
        log_warn "Some settings could not be restored (may require reboot or kernel modules)"
    fi

    return 0
}

# ============================================================================
# Validation Functions
# ============================================================================

# Validate a sysctl value before applying
# Usage: validate_sysctl_value <key> <value>
# Returns: 0 if valid, 1 if invalid
validate_sysctl_value() {
    local key="$1"
    local value="$2"

    # Check if key exists
    if ! sysctl -n "$key" >/dev/null 2>&1; then
        log_debug "Sysctl key does not exist: $key"
        return 1
    fi

    # Basic value validation
    case "$value" in
        # Numeric values
        [0-9]*|*[0-9])
            # Check if it's within reasonable bounds for common parameters
            case "$key" in
                vm.swappiness)
                    [[ "$value" -ge 0 && "$value" -le 100 ]] || {
                        log_error "Invalid swappiness value: $value (must be 0-100)"
                        return 1
                    }
                    ;;
                vm.vfs_cache_pressure)
                    [[ "$value" -ge 0 && "$value" -le 1000 ]] || {
                        log_error "Invalid vfs_cache_pressure value: $value (must be 0-1000)"
                        return 1
                    }
                    ;;
                vm.dirty_ratio|vm.dirty_background_ratio)
                    [[ "$value" -ge 0 && "$value" -le 100 ]] || {
                        log_error "Invalid dirty ratio value: $value (must be 0-100)"
                        return 1
                    }
                    ;;
            esac
            ;;
        # String values (like fq, bbr)
        [a-zA-Z]*)
            # Additional validation for specific parameters
            case "$key" in
                net.ipv4.tcp_congestion_control)
                    # Check if the congestion control algorithm is available
                    if [[ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
                        local available
                        available=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control)
                        if [[ ! "$available" =~ $value ]]; then
                            log_warn "Congestion control '$value' may not be available"
                            log_debug "Available: $available"
                        fi
                    fi
                    ;;
                net.core.default_qdisc)
                    # Common valid values: fq, pfifo_fast, mq, fq_codel, etc.
                    ;;
            esac
            ;;
        *)
            log_debug "Unknown value type for $key: $value"
            ;;
    esac

    return 0
}

# ============================================================================
# Hardware-Based Tuning Functions
# ============================================================================

# Calculate memory tuning parameters based on RAM size
# Usage: get_memory_tuning
# Output: JSON object with memory tuning parameters
get_memory_tuning() {
    local mem_gb
    local swappiness
    local vfs_cache_pressure
    local dirty_ratio
    local dirty_background_ratio
    local dirty_expire_centisecs
    local dirty_writeback_centisecs

    # Get memory size from scan or fallback to direct detection
    if [[ -f "$STATE_DIR/hardware_scan.json" ]] && command -v jq &>/dev/null; then
        mem_gb=$(jq -r '.memory.total_gb' "$STATE_DIR/hardware_scan.json" 2>/dev/null || echo "0")
    else
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
        mem_gb=$((mem_kb / 1024 / 1024))
    fi

    log_debug "Detected memory: ${mem_gb}GB"

    # Calculate swappiness based on RAM size
    if [[ "$mem_gb" -ge 16 ]]; then
        swappiness=10
        vfs_cache_pressure=50
        dirty_ratio=10
        dirty_background_ratio=5
    elif [[ "$mem_gb" -ge 8 ]]; then
        swappiness=30
        vfs_cache_pressure=75
        dirty_ratio=15
        dirty_background_ratio=5
    elif [[ "$mem_gb" -ge 4 ]]; then
        swappiness=60
        vfs_cache_pressure=100
        dirty_ratio=20
        dirty_background_ratio=10
    else
        # Low memory system - be more aggressive with swapping
        swappiness=80
        vfs_cache_pressure=100
        dirty_ratio=20
        dirty_background_ratio=10
    fi

    # Dirty page writeback timing (in centiseconds)
    dirty_expire_centisecs=3000      # 30 seconds
    dirty_writeback_centisecs=500    # 5 seconds

    cat <<EOF
{
    "vm.swappiness": $swappiness,
    "vm.vfs_cache_pressure": $vfs_cache_pressure,
    "vm.dirty_ratio": $dirty_ratio,
    "vm.dirty_background_ratio": $dirty_background_ratio,
    "vm.dirty_expire_centisecs": $dirty_expire_centisecs,
    "vm.dirty_writeback_centisecs": $dirty_writeback_centisecs
}
EOF
}

# Get I/O tuning parameters based on storage type
# Usage: get_io_tuning
# Output: JSON object with I/O tuning parameters
get_io_tuning() {
    local has_ssd=false
    local has_nvme=false

    # Detect storage types from scan or direct check
    if [[ -f "$STATE_DIR/hardware_scan.json" ]] && command -v jq &>/dev/null; then
        local storage_types
        storage_types=$(jq -r '.storage[].type' "$STATE_DIR/hardware_scan.json" 2>/dev/null)
        echo "$storage_types" | grep -qi "ssd" && has_ssd=true
        echo "$storage_types" | grep -qi "nvme" && has_nvme=true
    else
        # Fallback to direct detection
        for device in /sys/block/*/; do
            [[ ! -d "$device" ]] && continue
            local dev_name
            dev_name=$(basename "$device")
            [[ "$dev_name" =~ ^(loop|ram|dm-|sr|fd|zram) ]] && continue

            local rotational
            rotational=$(cat "$device/queue/rotational" 2>/dev/null || echo "1")
            [[ "$rotational" == "0" ]] && has_ssd=true
            [[ "$dev_name" =~ ^nvme ]] && has_nvme=true
        done
    fi

    log_debug "Storage detection: SSD=$has_ssd, NVMe=$has_nvme"

    # Adjust dirty ratios for SSD/NVMe
    local dirty_ratio=20
    local dirty_background_ratio=10

    if [[ "$has_nvme" == "true" ]] || [[ "$has_ssd" == "true" ]]; then
        dirty_ratio=10
        dirty_background_ratio=5
    fi

    cat <<EOF
{
    "vm.dirty_ratio": $dirty_ratio,
    "vm.dirty_background_ratio": $dirty_background_ratio,
    "comment": "Optimized for $([ "$has_nvme" = "true" ] && echo "NVMe" || ([ "$has_ssd" = "true" ] && echo "SSD" || echo "HDD"))"
}
EOF
}

# Get network tuning parameters
# Usage: get_network_tuning
# Output: JSON object with network tuning parameters
get_network_tuning() {
    # Check if BBR is available
    local has_bbr=false
    if [[ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
        grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null && has_bbr=true
    fi

    # Check if fq qdisc is available (usually is on modern kernels)
    local qdisc="fq_codel"
    if modinfo sch_fq &>/dev/null || [[ -f /proc/sys/net/core/default_qdisc ]]; then
        qdisc="fq"
    fi

    local congestion_control="cubic"
    [[ "$has_bbr" == "true" ]] && congestion_control="bbr"

    log_debug "Network tuning: qdisc=$qdisc, congestion_control=$congestion_control"

    # Calculate buffer sizes based on memory
    local mem_gb
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    mem_gb=$((mem_kb / 1024 / 1024))

    # Scale network buffers with available memory
    local rmem_max=$((16 * 1024 * 1024))  # 16 MB default
    local wmem_max=$((16 * 1024 * 1024))  # 16 MB default

    if [[ "$mem_gb" -ge 16 ]]; then
        rmem_max=$((32 * 1024 * 1024))  # 32 MB
        wmem_max=$((32 * 1024 * 1024))  # 32 MB
    elif [[ "$mem_gb" -ge 8 ]]; then
        rmem_max=$((16 * 1024 * 1024))  # 16 MB
        wmem_max=$((16 * 1024 * 1024))  # 16 MB
    else
        rmem_max=$((8 * 1024 * 1024))   # 8 MB
        wmem_max=$((8 * 1024 * 1024))   # 8 MB
    fi

    cat <<EOF
{
    "net.core.default_qdisc": "$qdisc",
    "net.ipv4.tcp_congestion_control": "$congestion_control",
    "net.core.rmem_max": $rmem_max,
    "net.core.wmem_max": $wmem_max,
    "net.core.rmem_default": $((rmem_max / 4)),
    "net.core.wmem_default": $((wmem_max / 4)),
    "net.core.netdev_max_backlog": 5000,
    "net.ipv4.tcp_rmem": "4096 87380 $rmem_max",
    "net.ipv4.tcp_wmem": "4096 65536 $wmem_max",
    "net.ipv4.tcp_fastopen": 3,
    "net.ipv4.tcp_slow_start_after_idle": 0,
    "net.ipv4.tcp_mtu_probing": 1,
    "net.ipv4.tcp_window_scaling": 1,
    "net.ipv4.tcp_timestamps": 1
}
EOF
}

# Get security hardening parameters (optional)
# Usage: get_security_tuning
# Output: JSON object with security tuning parameters
get_security_tuning() {
    cat <<EOF
{
    "kernel.kptr_restrict": 1,
    "kernel.dmesg_restrict": 1,
    "kernel.yama.ptrace_scope": 1,
    "net.ipv4.conf.all.rp_filter": 1,
    "net.ipv4.conf.default.rp_filter": 1,
    "net.ipv4.conf.all.accept_source_route": 0,
    "net.ipv4.conf.default.accept_source_route": 0,
    "net.ipv4.conf.all.accept_redirects": 0,
    "net.ipv4.conf.default.accept_redirects": 0,
    "net.ipv4.conf.all.secure_redirects": 0,
    "net.ipv4.conf.default.secure_redirects": 0,
    "net.ipv4.conf.all.send_redirects": 0,
    "net.ipv4.conf.default.send_redirects": 0,
    "net.ipv4.icmp_echo_ignore_broadcasts": 1,
    "net.ipv4.icmp_ignore_bogus_error_responses": 1,
    "net.ipv4.tcp_syncookies": 1,
    "net.ipv6.conf.all.accept_redirects": 0,
    "net.ipv6.conf.default.accept_redirects": 0,
    "net.ipv6.conf.all.accept_source_route": 0,
    "net.ipv6.conf.default.accept_source_route": 0,
    "fs.suid_dumpable": 0
}
EOF
}

# ============================================================================
# Configuration Generation
# ============================================================================

# Generate optimized sysctl configuration based on hardware
# Usage: generate_sysctl_config [--security] [--output FILE]
# Returns: 0 on success, 1 on failure
generate_sysctl_config() {
    local include_security=false
    local output_file="${SYSCTL_CONFIG_FILE}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --security)
                include_security=true
                shift
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    log_info "Generating sysctl configuration"
    log_debug "Output file: $output_file"
    log_debug "Include security hardening: $include_security"

    # Ensure hardware scan exists
    if [[ ! -f "$STATE_DIR/hardware_scan.json" ]]; then
        log_warn "Hardware scan not found, performing scan now"
        if ! perform_full_scan; then
            log_error "Failed to perform hardware scan"
            return 1
        fi
    fi

    # Get tuning parameters
    local memory_tuning
    local io_tuning
    local network_tuning
    local security_tuning

    memory_tuning=$(get_memory_tuning)
    io_tuning=$(get_io_tuning)
    network_tuning=$(get_network_tuning)
    [[ "$include_security" == "true" ]] && security_tuning=$(get_security_tuning)

    # Generate configuration file
    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    # Create temporary file
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }

    # Write header
    cat > "$temp_file" <<EOF
# ============================================================================
# Ultimate Linux Suite - Optimized Sysctl Configuration
# ============================================================================
#
# Generated: $timestamp
# Hostname: $(hostname 2>/dev/null || echo 'unknown')
# Kernel: $(uname -r 2>/dev/null || echo 'unknown')
#
# This configuration is automatically generated based on your hardware
# specifications for optimal performance.
#
# To apply: sudo sysctl --system
# To reload: sudo sysctl -p $output_file
#
# BACKUP: Settings are backed up to $SYSCTL_BACKUP_DIR
#
# ============================================================================

EOF

    # Add memory tuning section
    cat >> "$temp_file" <<EOF
# ============================================================================
# Memory Management Tuning
# ============================================================================
# Based on detected RAM: $(get_memory_size)
#
# - swappiness: How aggressively to use swap (0-100)
# - vfs_cache_pressure: Tendency to reclaim VFS caches (lower = keep more)
# - dirty_ratio: Max % of system memory that can be dirty before forced write
# - dirty_background_ratio: % at which background writeback starts
#

EOF

    echo "$memory_tuning" | jq -r 'to_entries[] | "\(.key) = \(.value)"' >> "$temp_file" 2>/dev/null || {
        log_error "Failed to parse memory tuning JSON"
        rm -f "$temp_file"
        return 1
    }

    # Add I/O tuning section (only if different from memory tuning)
    local io_comment
    io_comment=$(echo "$io_tuning" | jq -r '.comment' 2>/dev/null)
    if [[ -n "$io_comment" ]]; then
        cat >> "$temp_file" <<EOF

# ============================================================================
# I/O Tuning
# ============================================================================
# $io_comment
#

EOF
        echo "$io_tuning" | jq -r 'to_entries[] | select(.key != "comment") | "\(.key) = \(.value)"' >> "$temp_file" 2>/dev/null
    fi

    # Add network tuning section
    cat >> "$temp_file" <<EOF

# ============================================================================
# Network Performance Tuning
# ============================================================================
# Optimized for high-throughput, low-latency networking
#
# - default_qdisc: Packet scheduling algorithm (fq = Fair Queue)
# - tcp_congestion_control: TCP congestion algorithm (bbr recommended)
# - Buffer sizes optimized for your RAM capacity
# - TCP Fast Open (TFO) enabled for faster connection establishment
#

EOF

    echo "$network_tuning" | jq -r 'to_entries[] |
        if .value | type == "string" then
            "\(.key) = \(.value)"
        else
            "\(.key) = \(.value)"
        end' >> "$temp_file" 2>/dev/null || {
        log_error "Failed to parse network tuning JSON"
        rm -f "$temp_file"
        return 1
    }

    # Add security tuning section if requested
    if [[ "$include_security" == "true" ]]; then
        cat >> "$temp_file" <<EOF

# ============================================================================
# Security Hardening (Optional)
# ============================================================================
# Additional security settings - may break some legacy applications
#
# - Kernel pointer and dmesg restrictions
# - Ptrace scope restrictions
# - Network source routing and redirect protections
# - SYN flood protection
#

EOF
        echo "$security_tuning" | jq -r 'to_entries[] | "\(.key) = \(.value)"' >> "$temp_file" 2>/dev/null || {
            log_error "Failed to parse security tuning JSON"
            rm -f "$temp_file"
            return 1
        }
    fi

    # Add footer
    cat >> "$temp_file" <<EOF

# ============================================================================
# End of Ultimate Linux Suite Configuration
# ============================================================================
EOF

    # Validate the generated configuration
    log_debug "Validating generated configuration"
    if ! validate_sysctl_config "$temp_file"; then
        log_error "Generated configuration failed validation"
        rm -f "$temp_file"
        return 1
    fi

    # Move temp file to final location
    echo "$temp_file"

    log_success "Sysctl configuration generated successfully"
    return 0
}

# Validate a sysctl configuration file
# Usage: validate_sysctl_config <config_file>
# Returns: 0 if valid, 1 if invalid
validate_sysctl_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    log_debug "Validating configuration file: $config_file"

    local errors=0
    local warnings=0

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Parse key = value
        if [[ "$line" =~ ^([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            # Validate the key-value pair
            if ! validate_sysctl_value "$key" "$value"; then
                ((warnings++))
                log_warn "Validation warning for: $key = $value"
            fi
        else
            ((errors++))
            log_error "Invalid syntax in config: $line"
        fi
    done < "$config_file"

    log_debug "Validation complete: $errors errors, $warnings warnings"

    # Return 0 if no errors (warnings are okay)
    return "$errors"
}

# ============================================================================
# Application Functions
# ============================================================================

# Apply sysctl configuration safely
# Usage: apply_sysctl_config [config_file]
# Returns: 0 on success, 1 on failure
apply_sysctl_config() {
    local config_file="${1:-$SYSCTL_CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Check if running as root
    if [[ "$EUID" -ne 0 ]]; then
        log_error "Root privileges required to apply sysctl configuration"
        log_info "Try: sudo bash -c 'source lib/tune.sh && apply_sysctl_config'"
        return 1
    fi

    log_info "Applying sysctl configuration from: $config_file"

    # Backup current settings first
    if ! backup_sysctl; then
        log_warn "Backup failed, but continuing with application"
    fi

    # Copy config to system location if it's not already there
    if [[ "$config_file" != "$SYSCTL_CONFIG_FILE" ]]; then
        log_info "Installing configuration to: $SYSCTL_CONFIG_FILE"

        # Ensure directory exists
        mkdir -p "$SYSCTL_CONFIG_DIR" 2>/dev/null || {
            log_error "Failed to create directory: $SYSCTL_CONFIG_DIR"
            return 1
        }

        # Copy the file
        if ! cp "$config_file" "$SYSCTL_CONFIG_FILE"; then
            log_error "Failed to copy configuration to $SYSCTL_CONFIG_FILE"
            return 1
        fi
    fi

    # Apply the configuration
    log_info "Loading sysctl settings"

    local applied=0
    local failed=0
    local output

    # Apply using sysctl -p
    output=$(sysctl -p "$SYSCTL_CONFIG_FILE" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Count applied settings
        applied=$(echo "$output" | grep -c "=" || echo 0)
        log_success "Successfully applied $applied sysctl settings"
    else
        log_error "Failed to apply sysctl configuration"
        log_debug "Output: $output"

        # Try to apply settings one by one to identify failures
        log_info "Attempting to apply settings individually"

        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            if [[ "$line" =~ ^([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                key=$(echo "$key" | xargs)
                value=$(echo "$value" | xargs)

                if sysctl -w "${key}=${value}" >/dev/null 2>&1; then
                    ((applied++))
                else
                    ((failed++))
                    log_warn "Failed to apply: ${key}=${value}"
                fi
            fi
        done < "$SYSCTL_CONFIG_FILE"

        log_info "Applied $applied settings, $failed failed"
    fi

    # Reload all sysctl configs
    log_info "Reloading all sysctl configurations"
    sysctl --system >/dev/null 2>&1

    log_success "Sysctl configuration applied"

    if [[ "$failed" -gt 0 ]]; then
        log_warn "Some settings failed to apply - may require kernel modules or reboot"
        return 1
    fi

    return 0
}

# ============================================================================
# Comparison and Analysis Functions
# ============================================================================

# Compare current sysctl values with recommended values
# Usage: compare_sysctl_current [config_file]
# Returns: 0 on success
compare_sysctl_current() {
    local config_file="${1:-$SYSCTL_CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    log_section "Sysctl Configuration Comparison"

    printf "%-50s %-20s %-20s %s\n" "Parameter" "Current" "Recommended" "Status"
    log_divider

    local differences=0
    local matches=0

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local recommended="${BASH_REMATCH[2]}"
            key=$(echo "$key" | xargs)
            recommended=$(echo "$recommended" | xargs)

            # Get current value
            local current
            current=$(sysctl -n "$key" 2>/dev/null || echo "N/A")

            # Compare
            local status
            if [[ "$current" == "$recommended" ]]; then
                status="${GREEN}MATCH${RESET}"
                ((matches++))
            elif [[ "$current" == "N/A" ]]; then
                status="${YELLOW}NOT FOUND${RESET}"
                ((differences++))
            else
                status="${RED}DIFFERENT${RESET}"
                ((differences++))
            fi

            printf "%-50s %-20s %-20s %b\n" "$key" "$current" "$recommended" "$status"
        fi
    done < "$config_file"

    log_divider
    echo ""
    echo "Summary: $matches matching, $differences different"
    echo ""

    if [[ "$differences" -gt 0 ]]; then
        log_warn "$differences parameter(s) differ from recommendations"
        log_info "Run 'apply_sysctl_config' to apply recommended settings"
    else
        log_success "All parameters match recommendations"
    fi

    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get memory size in human-readable format
# Usage: get_memory_size
# Output: Memory size string (e.g., "16GB")
get_memory_size() {
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local mem_gb=$((mem_kb / 1024 / 1024))
    echo "${mem_gb}GB"
}

# Show current sysctl statistics
# Usage: show_sysctl_stats
show_sysctl_stats() {
    log_section "Current System Tuning Status"

    echo "Memory Management:"
    echo "  Swappiness: $(sysctl -n vm.swappiness 2>/dev/null || echo 'N/A')"
    echo "  VFS Cache Pressure: $(sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo 'N/A')"
    echo "  Dirty Ratio: $(sysctl -n vm.dirty_ratio 2>/dev/null || echo 'N/A')%"
    echo "  Dirty Background Ratio: $(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo 'N/A')%"
    echo ""

    echo "Network:"
    echo "  Default Qdisc: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'N/A')"
    echo "  TCP Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
    echo "  TCP Window Scaling: $(sysctl -n net.ipv4.tcp_window_scaling 2>/dev/null || echo 'N/A')"
    echo "  TCP Fast Open: $(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo 'N/A')"
    echo ""

    echo "Security:"
    echo "  Kernel Pointer Restrict: $(sysctl -n kernel.kptr_restrict 2>/dev/null || echo 'N/A')"
    echo "  Ptrace Scope: $(sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo 'N/A')"
    echo "  TCP SYN Cookies: $(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo 'N/A')"
    echo ""

    log_divider
}

# ============================================================================
# Module Documentation
# ============================================================================
#
# TUNE MODULE OVERVIEW
# ====================
#
# This module provides intelligent sysctl tuning based on hardware detection,
# optimizing system performance for memory, I/O, network, and security.
#
# MAIN FUNCTIONS:
# ---------------
# generate_sysctl_config()      - Generate optimized sysctl configuration
# apply_sysctl_config()         - Apply configuration safely (requires sudo)
# backup_sysctl()               - Backup current sysctl settings
# restore_sysctl()              - Restore from backup
# compare_sysctl_current()      - Show diff between current and recommended
# validate_sysctl_value()       - Validate parameter before applying
#
# TUNING FUNCTIONS:
# -----------------
# get_memory_tuning()           - Memory management parameters
# get_network_tuning()          - Network performance parameters
# get_io_tuning()               - I/O scheduler parameters
# get_security_tuning()         - Security hardening parameters
#
# UTILITY FUNCTIONS:
# ------------------
# show_sysctl_stats()           - Display current tuning status
# get_memory_size()             - Get system memory in human format
# validate_sysctl_config()      - Validate config file syntax
#
# TUNING RECOMMENDATIONS:
# -----------------------
# Memory (based on RAM):
#   - 16GB+:    swappiness=10, vfs_cache_pressure=50
#   - 8-16GB:   swappiness=30, vfs_cache_pressure=75
#   - 4-8GB:    swappiness=60, vfs_cache_pressure=100
#   - <4GB:     swappiness=80, vfs_cache_pressure=100
#
# I/O (based on storage):
#   - NVMe/SSD: dirty_ratio=10, dirty_background_ratio=5
#   - HDD:      dirty_ratio=20, dirty_background_ratio=10
#
# Network:
#   - TCP BBR congestion control (if available)
#   - Fair Queue (fq) packet scheduler
#   - Optimized TCP buffers based on RAM
#   - TCP Fast Open enabled
#
# Security (optional):
#   - Kernel pointer restrictions
#   - Ptrace scope restrictions
#   - Network hardening (no redirects, source routing)
#
# USAGE EXAMPLE:
# --------------
#   # Generate and preview configuration
#   source lib/tune.sh
#   config_file=$(generate_sysctl_config --security)
#   cat "$config_file"
#
#   # Compare with current settings
#   compare_sysctl_current "$config_file"
#
#   # Apply configuration (requires sudo)
#   sudo bash -c "source lib/tune.sh && apply_sysctl_config '$config_file'"
#
#   # Restore from backup if needed
#   sudo bash -c "source lib/tune.sh && restore_sysctl"
#
# OUTPUT LOCATIONS:
# -----------------
#   Config:  /etc/sysctl.d/99-ultimate-suite.conf
#   Backup:  $STATE_DIR/sysctl_backup/sysctl_backup_TIMESTAMP.conf
#
# ============================================================================
