#!/usr/bin/env bash
# Unified Suite - Core Optimization Library
# Source: Ported from Ultimate Linux Suite v5.0
# License: GPL-3.0-or-later
#
# CRITICAL: All swappiness values are 85+ per specification

[[ -n "${_UNIFIED_OPTIMIZATION_LOADED:-}" ]] && return 0
readonly _UNIFIED_OPTIMIZATION_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"
[[ -z "${_UNIFIED_OS_DETECT_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/os_detect.sh"
[[ -z "${_UNIFIED_PKG_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/pkg.sh"
[[ -z "${_UNIFIED_SAFETY_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/safety.sh"

# ============================================================
# OPTIMIZATION CONSTANTS
# ============================================================

readonly SYSCTL_CONF_DIR="/etc/sysctl.d"
readonly SYSCTL_CONF_FILE="${SYSCTL_CONF_DIR}/99-unified-suite.conf"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly MODPROBE_DIR="/etc/modprobe.d"
readonly UDEV_RULES_DIR="/etc/udev/rules.d"
readonly OPT_BACKUP_DIR="/var/backups/unified-suite/optimization"

# ============================================================
# RAM PROFILES WITH SWAPPINESS 85+
# ============================================================
# CRITICAL: All swappiness values MUST be 85 or higher

declare -A RAM_PROFILES

# Profile: MINIMAL (<=2GB RAM)
RAM_PROFILES[MINIMAL_RAM_MAX]=2048
RAM_PROFILES[MINIMAL_SWAPPINESS]=95
RAM_PROFILES[MINIMAL_CACHE_PRESSURE]=100
RAM_PROFILES[MINIMAL_DIRTY_RATIO]=5
RAM_PROFILES[MINIMAL_DIRTY_BG_RATIO]=3
RAM_PROFILES[MINIMAL_ZRAM_ENABLED]=1
RAM_PROFILES[MINIMAL_ZRAM_PERCENT]=100
RAM_PROFILES[MINIMAL_SWAP_SIZE]="1G"

# Profile: LOW (2-4GB RAM)
RAM_PROFILES[LOW_RAM_MIN]=2048
RAM_PROFILES[LOW_RAM_MAX]=4096
RAM_PROFILES[LOW_SWAPPINESS]=90
RAM_PROFILES[LOW_CACHE_PRESSURE]=80
RAM_PROFILES[LOW_DIRTY_RATIO]=8
RAM_PROFILES[LOW_DIRTY_BG_RATIO]=4
RAM_PROFILES[LOW_ZRAM_ENABLED]=1
RAM_PROFILES[LOW_ZRAM_PERCENT]=75
RAM_PROFILES[LOW_SWAP_SIZE]="2G"

# Profile: MEDIUM (4-8GB RAM)
RAM_PROFILES[MEDIUM_RAM_MIN]=4096
RAM_PROFILES[MEDIUM_RAM_MAX]=8192
RAM_PROFILES[MEDIUM_SWAPPINESS]=88
RAM_PROFILES[MEDIUM_CACHE_PRESSURE]=60
RAM_PROFILES[MEDIUM_DIRTY_RATIO]=10
RAM_PROFILES[MEDIUM_DIRTY_BG_RATIO]=5
RAM_PROFILES[MEDIUM_ZRAM_ENABLED]=1
RAM_PROFILES[MEDIUM_ZRAM_PERCENT]=50
RAM_PROFILES[MEDIUM_SWAP_SIZE]="4G"

# Profile: HIGH (8-16GB RAM)
RAM_PROFILES[HIGH_RAM_MIN]=8192
RAM_PROFILES[HIGH_RAM_MAX]=16384
RAM_PROFILES[HIGH_SWAPPINESS]=86
RAM_PROFILES[HIGH_CACHE_PRESSURE]=50
RAM_PROFILES[HIGH_DIRTY_RATIO]=15
RAM_PROFILES[HIGH_DIRTY_BG_RATIO]=5
RAM_PROFILES[HIGH_ZRAM_ENABLED]=0
RAM_PROFILES[HIGH_ZRAM_PERCENT]=0
RAM_PROFILES[HIGH_SWAP_SIZE]="8G"

# Profile: VERY_HIGH (>16GB RAM)
RAM_PROFILES[VERY_HIGH_RAM_MIN]=16384
RAM_PROFILES[VERY_HIGH_SWAPPINESS]=85
RAM_PROFILES[VERY_HIGH_CACHE_PRESSURE]=40
RAM_PROFILES[VERY_HIGH_DIRTY_RATIO]=20
RAM_PROFILES[VERY_HIGH_DIRTY_BG_RATIO]=10
RAM_PROFILES[VERY_HIGH_ZRAM_ENABLED]=0
RAM_PROFILES[VERY_HIGH_ZRAM_PERCENT]=0
RAM_PROFILES[VERY_HIGH_SWAP_SIZE]="16G"

# ============================================================
# PROFILE DETECTION
# ============================================================

detect_ram_profile() {
    local ram_mb=$(get_total_ram_mb)
    local profile=""

    if [[ $ram_mb -le ${RAM_PROFILES[MINIMAL_RAM_MAX]} ]]; then
        profile="MINIMAL"
    elif [[ $ram_mb -le ${RAM_PROFILES[LOW_RAM_MAX]} ]]; then
        profile="LOW"
    elif [[ $ram_mb -le ${RAM_PROFILES[MEDIUM_RAM_MAX]} ]]; then
        profile="MEDIUM"
    elif [[ $ram_mb -le ${RAM_PROFILES[HIGH_RAM_MAX]} ]]; then
        profile="HIGH"
    else
        profile="VERY_HIGH"
    fi

    log_debug "Detected RAM: ${ram_mb}MB -> Profile: $profile"
    echo "$profile"
}

get_profile_value() {
    local profile="$1"
    local key="$2"
    local full_key="${profile}_${key}"
    echo "${RAM_PROFILES[$full_key]:-}"
}

# ============================================================
# SYSCTL OPTIMIZATION
# ============================================================

generate_sysctl_config() {
    local profile="$1"

    local swappiness=$(get_profile_value "$profile" "SWAPPINESS")
    local cache_pressure=$(get_profile_value "$profile" "CACHE_PRESSURE")
    local dirty_ratio=$(get_profile_value "$profile" "DIRTY_RATIO")
    local dirty_bg_ratio=$(get_profile_value "$profile" "DIRTY_BG_RATIO")

    cat << EOF
# Unified Suite - Kernel Optimization
# Profile: $profile
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# SWAPPINESS NOTE: All values are 85+ per project specification

# ============================================================
# MEMORY MANAGEMENT
# ============================================================

vm.swappiness = ${swappiness}
vm.vfs_cache_pressure = ${cache_pressure}
vm.dirty_ratio = ${dirty_ratio}
vm.dirty_background_ratio = ${dirty_bg_ratio}
vm.dirty_expire_centisecs = 1500
vm.dirty_writeback_centisecs = 500
vm.overcommit_memory = 0
vm.overcommit_ratio = 50
vm.page-cluster = 0
vm.min_free_kbytes = 65536

# ============================================================
# NETWORK OPTIMIZATION
# ============================================================

net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1

# ============================================================
# FILE SYSTEM
# ============================================================

fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
fs.inotify.max_queued_events = 32768
fs.file-max = 2097152
fs.nr_open = 1048576

# ============================================================
# GAMING / LOW LATENCY
# ============================================================

vm.max_map_count = 2147483642

# ============================================================
# SECURITY
# ============================================================

kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.icmp_echo_ignore_broadcasts = 1

# ============================================================
# SHARED MEMORY
# ============================================================

kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF
}

apply_sysctl_config() {
    local profile="$1"

    log_info "Applying sysctl configuration for profile: $profile"

    # Create backup
    mkdir -p "$OPT_BACKUP_DIR"
    if [[ -f "$SYSCTL_CONF_FILE" ]]; then
        cp "$SYSCTL_CONF_FILE" "${OPT_BACKUP_DIR}/sysctl.conf.$(date +%Y%m%d_%H%M%S).bak"
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would write sysctl configuration to $SYSCTL_CONF_FILE"
        generate_sysctl_config "$profile"
        return 0
    fi

    mkdir -p "$SYSCTL_CONF_DIR"
    generate_sysctl_config "$profile" > "$SYSCTL_CONF_FILE"

    # Apply immediately
    sysctl -p "$SYSCTL_CONF_FILE" 2>/dev/null || {
        log_warn "Some sysctl parameters may not have applied"
    }

    log_success "Sysctl configuration applied"
}

# ============================================================
# ZRAM CONFIGURATION
# ============================================================

configure_zram() {
    local profile="$1"

    local zram_enabled=$(get_profile_value "$profile" "ZRAM_ENABLED")
    local zram_percent=$(get_profile_value "$profile" "ZRAM_PERCENT")

    if [[ $zram_enabled -ne 1 ]]; then
        log_info "ZRAM not recommended for profile $profile"
        return 0
    fi

    log_info "Configuring ZRAM with ${zram_percent}% of RAM"

    local ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    local zram_size_kb=$((ram_kb * zram_percent / 100))

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would configure ZRAM: ${zram_size_kb}KB"
        return 0
    fi

    # Try systemd-zram-generator first
    if [[ -d /usr/lib/systemd/system-generators ]]; then
        mkdir -p /etc/systemd/zram-generator.conf.d
        cat > /etc/systemd/zram-generator.conf.d/unified-suite.conf << EOF
# Unified Suite ZRAM Configuration
[zram0]
zram-size = ram * ${zram_percent} / 100
compression-algorithm = zstd
EOF
        systemctl daemon-reload
        systemctl enable --now systemd-zram-setup@zram0.service 2>/dev/null || true
        log_success "ZRAM configured via systemd-zram-generator"
    else
        # Manual ZRAM setup
        modprobe zram num_devices=1 2>/dev/null || true
        echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || \
            echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
        echo "${zram_size_kb}K" > /sys/block/zram0/disksize 2>/dev/null || true
        mkswap /dev/zram0 2>/dev/null || true
        swapon -p 100 /dev/zram0 2>/dev/null || true
        log_success "ZRAM configured manually"
    fi
}

# ============================================================
# I/O SCHEDULER OPTIMIZATION
# ============================================================

configure_io_scheduler() {
    local storage_type=$(get_storage_type "$(get_primary_storage)")
    local scheduler=""

    case "$storage_type" in
        nvme)    scheduler="none" ;;
        ssd)     scheduler="mq-deadline" ;;
        hdd)     scheduler="bfq" ;;
        *)       scheduler="mq-deadline" ;;
    esac

    log_info "Configuring I/O scheduler: $scheduler (storage: $storage_type)"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would configure I/O scheduler: $scheduler"
        return 0
    fi

    # Create udev rule
    cat > "${UDEV_RULES_DIR}/60-unified-ioschedulers.rules" << EOF
# Unified Suite - I/O Scheduler Configuration
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="$scheduler"
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="256"
EOF

    # Apply immediately
    for device in /sys/block/*/queue/scheduler; do
        echo "$scheduler" > "$device" 2>/dev/null || true
    done

    log_success "I/O scheduler configured: $scheduler"
}

# ============================================================
# CPU GOVERNOR
# ============================================================

configure_cpu_governor() {
    local governor="performance"

    if is_laptop; then
        local bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
        [[ "$bat_status" == "Discharging" ]] && governor="powersave"
    fi

    log_info "Configuring CPU governor: $governor"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would set CPU governor: $governor"
        return 0
    fi

    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$governor" > "$cpu" 2>/dev/null || true
    done

    log_success "CPU governor configured: $governor"
}

# ============================================================
# MAIN OPTIMIZATION FUNCTION
# ============================================================

run_optimization() {
    local profile="${1:-$(detect_ram_profile)}"

    log_header "System Optimization - Profile: $profile"

    safety_checkpoint "optimization-$profile"

    local swappiness=$(get_profile_value "$profile" "SWAPPINESS")
    if [[ -z "$swappiness" ]]; then
        log_error "Invalid profile: $profile"
        return $EXIT_FAILURE
    fi

    # Verify swappiness compliance
    if [[ $swappiness -lt 85 ]]; then
        log_error "CRITICAL: Swappiness ($swappiness) below minimum 85!"
        return $EXIT_FAILURE
    fi

    log_info "RAM Profile: $profile"
    log_info "Swappiness: $swappiness (minimum 85 per specification)"

    log_section "Kernel Parameters (sysctl)"
    apply_sysctl_config "$profile"

    log_section "ZRAM Configuration"
    configure_zram "$profile"

    log_section "I/O Scheduler"
    configure_io_scheduler

    log_section "CPU Governor"
    configure_cpu_governor

    log_success "System optimization complete"
    log_warn "A reboot is recommended for all changes to take effect"

    return $EXIT_SUCCESS
}

# ============================================================
# VERIFICATION
# ============================================================

verify_optimization() {
    log_section "Current Optimization Status"

    echo "RAM:"
    echo "  Total: $(get_total_ram_mb) MB"
    echo "  Available: $(get_available_ram_mb) MB"
    echo "  Profile: $(detect_ram_profile)"
    echo ""

    echo "Swappiness:"
    echo "  Current: $(cat /proc/sys/vm/swappiness)"
    echo "  Target: 85+ (per specification)"
    echo ""

    echo "Swap:"
    swapon --show 2>/dev/null || echo "  (none)"
    echo ""

    echo "ZRAM:"
    if [[ -b /dev/zram0 ]]; then
        echo "  Status: Active"
        zramctl 2>/dev/null || true
    else
        echo "  Status: Not active"
    fi
    echo ""

    echo "I/O Scheduler:"
    for device in /sys/block/*/queue/scheduler; do
        local dev=$(dirname "$device" | xargs basename)
        [[ "$dev" == loop* ]] && continue
        local sched=$(cat "$device" 2>/dev/null | grep -oE '\[[a-z-]+\]' | tr -d '[]')
        echo "  $dev: $sched"
    done
    echo ""

    echo "CPU Governor:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "  (not available)"
}
