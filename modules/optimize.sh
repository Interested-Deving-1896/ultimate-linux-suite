#!/usr/bin/env bash
#
# optimize.sh - System Optimization Module for Ultimate Linux Suite
#
# Comprehensive system tuning with queue-based application
#

# Prevent multiple sourcing
[[ -n "${_OPTIMIZE_MODULE_LOADED:-}" ]] && return 0
readonly _OPTIMIZE_MODULE_LOADED=1

# ============================================================================
# Current Settings Detection
# ============================================================================

get_current_swappiness() {
    cat /proc/sys/vm/swappiness 2>/dev/null || echo "?"
}

get_current_vfs_cache_pressure() {
    cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "?"
}

get_current_dirty_ratio() {
    cat /proc/sys/vm/dirty_ratio 2>/dev/null || echo "?"
}

get_zram_status() {
    if [[ -d /sys/block/zram0 ]]; then
        local size
        size=$(cat /sys/block/zram0/disksize 2>/dev/null)
        if [[ -n "$size" ]] && [[ "$size" -gt 0 ]]; then
            echo "enabled ($(( size / 1024 / 1024 ))MB)"
            return 0
        fi
    fi
    echo "disabled"
    return 1
}

get_thp_status() {
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        cat /sys/kernel/mm/transparent_hugepage/enabled | grep -oP '\[\K[^\]]+'
    else
        echo "not available"
    fi
}

get_bbr_status() {
    local cc
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cc" == "bbr" ]]; then
        echo "enabled"
    else
        echo "disabled ($cc)"
    fi
}

get_ipv6_status() {
    local disabled
    disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
    if [[ "$disabled" == "1" ]]; then
        echo "disabled"
    else
        echo "enabled"
    fi
}

# ============================================================================
# Show Current Settings
# ============================================================================

show_current_settings() {
    log_section "Current System Settings"

    printf "${BOLD}Memory:${RESET}\n"
    printf "  Swappiness: %s\n" "$(get_current_swappiness)"
    printf "  VFS Cache Pressure: %s\n" "$(get_current_vfs_cache_pressure)"
    printf "  Dirty Ratio: %s\n" "$(get_current_dirty_ratio)"
    printf "  ZRAM: %s\n" "$(get_zram_status)"
    printf "  THP: %s\n" "$(get_thp_status)"

    printf "\n${BOLD}I/O Scheduler:${RESET}\n"
    local scheduler_found=0
    for disk in /sys/block/sd*/queue/scheduler /sys/block/nvme*/queue/scheduler; do
        [[ -f "$disk" ]] || continue
        scheduler_found=1
        local name
        name=$(dirname "$disk" | xargs basename)
        printf "  %s: %s\n" "$name" "$(cat "$disk")"
    done
    [[ $scheduler_found -eq 0 ]] && printf "  (no disks found)\n"

    printf "\n${BOLD}CPU Governor:${RESET}\n"
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        printf "  %s\n" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    else
        printf "  (not available)\n"
    fi

    printf "\n${BOLD}Network:${RESET}\n"
    printf "  TCP Congestion: %s\n" "$(get_bbr_status)"
    printf "  IPv6: %s\n" "$(get_ipv6_status)"

    pause
}

# ============================================================================
# Sysctl Application
# ============================================================================

apply_sysctl() {
    local key="$1"
    local value="$2"

    log_info "Setting $key = $value"
    sysctl -w "$key=$value" >/dev/null

    # Make persistent
    local conf="/etc/sysctl.d/99-ultimate-linux-suite.conf"
    if [[ ! -f "$conf" ]]; then
        echo "# Ultimate Linux Suite optimizations" > "$conf"
    fi

    if grep -q "^$key" "$conf" 2>/dev/null; then
        sed -i "s|^$key.*|$key = $value|" "$conf"
    else
        echo "$key = $value" >> "$conf"
    fi
}

# Queue sysctl change
queue_sysctl_change() {
    local key="$1"
    local value="$2"
    local desc="${3:-Set $key = $value}"
    queue_sysctl "$key" "$value" "$desc"
}

# ============================================================================
# Memory Optimizations
# ============================================================================

optimize_swappiness() {
    log_section "Swappiness Optimization"

    local current
    current=$(get_current_swappiness)
    printf "Current swappiness: %s\n\n" "$current"

    printf "Recommended values:\n"
    printf "  10-30: Desktop (more responsive)\n"
    printf "  60: Default\n"
    printf "  80-100: Server with lots of RAM\n"

    local ram_gb="$RAM_TOTAL_GB"
    local recommended=60
    if [[ "$ram_gb" -ge 16 ]]; then
        recommended=10
        printf "\nWith %sGB RAM, recommend: 10\n" "$ram_gb"
    elif [[ "$ram_gb" -ge 8 ]]; then
        recommended=20
        printf "\nWith %sGB RAM, recommend: 20\n" "$ram_gb"
    else
        recommended=40
        printf "\nWith %sGB RAM, recommend: 40\n" "$ram_gb"
    fi

    printf "\nEnter new swappiness (0-100) or press Enter for recommended (%d): " "$recommended"
    read -r value
    value="${value:-$recommended}"

    if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -le 100 ]]; then
        queue_sysctl_change "vm.swappiness" "$value"
        log_success "Queued: swappiness = $value"
    fi
}

optimize_vfs_cache() {
    log_section "VFS Cache Pressure"

    local current
    current=$(get_current_vfs_cache_pressure)
    printf "Current value: %s\n\n" "$current"

    printf "Lower values keep directory/inode caches longer.\n"
    printf "Recommended:\n"
    printf "  50-75: Desktop/workstation\n"
    printf "  100: Default\n"
    printf "  150+: Many small files\n"

    printf "\nEnter new value (10-200) or press Enter to skip: "
    read -r value

    if [[ -n "$value" ]] && [[ "$value" =~ ^[0-9]+$ ]]; then
        queue_sysctl_change "vm.vfs_cache_pressure" "$value"
        log_success "Queued: vfs_cache_pressure = $value"
    fi
}

# ============================================================================
# ZRAM Management
# ============================================================================

configure_zram() {
    log_section "ZRAM Configuration"

    printf "ZRAM provides compressed RAM swap, reducing disk I/O.\n"
    printf "Current status: %s\n\n" "$(get_zram_status)"

    simple_menu "ZRAM Options" \
        "Enable ZRAM (50% of RAM)" \
        "Enable ZRAM (custom size)" \
        "Disable ZRAM"

    case "$MENU_CHOICE" in
        1)
            local size_mb=$((RAM_TOTAL_GB * 1024 / 2))
            queue_command "modprobe zram && echo ${size_mb}M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0" "Enable ZRAM (${size_mb}MB)"
            log_success "Queued: Enable ZRAM with ${size_mb}MB"
            ;;
        2)
            printf "Enter ZRAM size in MB: "
            read -r size_mb
            if [[ "$size_mb" =~ ^[0-9]+$ ]]; then
                queue_command "modprobe zram && echo ${size_mb}M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0" "Enable ZRAM (${size_mb}MB)"
                log_success "Queued: Enable ZRAM with ${size_mb}MB"
            fi
            ;;
        3)
            queue_command "swapoff /dev/zram0 2>/dev/null; rmmod zram 2>/dev/null" "Disable ZRAM"
            log_success "Queued: Disable ZRAM"
            ;;
    esac
    pause
}

# ============================================================================
# THP (Transparent Huge Pages)
# ============================================================================

configure_thp() {
    log_section "Transparent Huge Pages"

    printf "THP can improve memory performance but may cause latency.\n"
    printf "Current status: %s\n\n" "$(get_thp_status)"

    printf "Options:\n"
    printf "  always:  THP enabled for all allocations\n"
    printf "  madvise: THP only when apps request it (recommended)\n"
    printf "  never:   THP disabled\n"

    simple_menu "THP Mode" \
        "Always" \
        "Madvise (recommended)" \
        "Never (disable)"

    local mode=""
    case "$MENU_CHOICE" in
        1) mode="always" ;;
        2) mode="madvise" ;;
        3) mode="never" ;;
        0) return ;;
    esac

    if [[ -n "$mode" ]]; then
        queue_command "echo $mode > /sys/kernel/mm/transparent_hugepage/enabled" "Set THP to $mode"
        log_success "Queued: THP = $mode"
    fi
    pause
}

# ============================================================================
# Network Optimizations
# ============================================================================

configure_bbr() {
    log_section "TCP BBR Congestion Control"

    printf "BBR is Google's congestion control algorithm.\n"
    printf "It generally improves network throughput.\n\n"
    printf "Current status: %s\n\n" "$(get_bbr_status)"

    if confirm "Enable BBR?"; then
        queue_sysctl_change "net.core.default_qdisc" "fq" "Set queue discipline to fq"
        queue_sysctl_change "net.ipv4.tcp_congestion_control" "bbr" "Enable TCP BBR"
        log_success "Queued: Enable BBR"
    fi
    pause
}

configure_ipv6() {
    log_section "IPv6 Configuration"

    printf "Current IPv6 status: %s\n\n" "$(get_ipv6_status)"

    simple_menu "IPv6 Options" \
        "Enable IPv6" \
        "Disable IPv6"

    case "$MENU_CHOICE" in
        1)
            queue_sysctl_change "net.ipv6.conf.all.disable_ipv6" "0" "Enable IPv6"
            queue_sysctl_change "net.ipv6.conf.default.disable_ipv6" "0" "Enable IPv6 default"
            log_success "Queued: Enable IPv6"
            ;;
        2)
            queue_sysctl_change "net.ipv6.conf.all.disable_ipv6" "1" "Disable IPv6"
            queue_sysctl_change "net.ipv6.conf.default.disable_ipv6" "1" "Disable IPv6 default"
            log_success "Queued: Disable IPv6"
            ;;
    esac
    pause
}

configure_dns_cache() {
    log_section "DNS Cache"

    printf "Local DNS caching can speed up DNS lookups.\n\n"

    if cmd_exists systemd-resolve; then
        printf "systemd-resolved is available.\n"
        local status
        status=$(systemctl is-active systemd-resolved 2>/dev/null || echo "inactive")
        printf "Status: %s\n\n" "$status"

        if [[ "$status" != "active" ]]; then
            if confirm "Enable systemd-resolved DNS caching?"; then
                queue_service "enable" "systemd-resolved" "Enable DNS cache"
                queue_service "start" "systemd-resolved" "Start DNS cache"
            fi
        else
            log_info "DNS caching already active"
        fi
    else
        printf "Consider installing dnsmasq or unbound for DNS caching.\n"
    fi
    pause
}

configure_tcp_buffers() {
    log_section "TCP Buffer Sizes"

    printf "Larger buffers can improve throughput on fast networks.\n\n"

    printf "Current values:\n"
    printf "  rmem_max: %s\n" "$(sysctl -n net.core.rmem_max 2>/dev/null)"
    printf "  wmem_max: %s\n" "$(sysctl -n net.core.wmem_max 2>/dev/null)"

    if confirm "Apply optimized TCP buffer settings?"; then
        queue_sysctl_change "net.core.rmem_max" "16777216" "TCP receive buffer max"
        queue_sysctl_change "net.core.wmem_max" "16777216" "TCP send buffer max"
        queue_sysctl_change "net.ipv4.tcp_rmem" "4096 87380 16777216" "TCP receive buffer"
        queue_sysctl_change "net.ipv4.tcp_wmem" "4096 65536 16777216" "TCP send buffer"
        log_success "Queued: TCP buffer optimization"
    fi
    pause
}

# ============================================================================
# I/O Scheduler
# ============================================================================

set_io_scheduler() {
    log_section "I/O Scheduler"

    printf "Available schedulers:\n"
    printf "  none/noop: Best for NVMe/SSD\n"
    printf "  mq-deadline: Good for SSD\n"
    printf "  bfq: Best for HDD, fair scheduling\n"
    printf "  kyber: Low latency for fast storage\n\n"

    printf "Current schedulers:\n"
    for disk in /sys/block/sd* /sys/block/nvme*; do
        [[ -d "$disk" ]] || continue
        local name
        name=$(basename "$disk")
        local sched_file="$disk/queue/scheduler"
        [[ -f "$sched_file" ]] || continue
        printf "  %s: %s\n" "$name" "$(cat "$sched_file")"
    done

    printf "\nNote: This setting is temporary. Use udev rules for persistence.\n"
    pause
}

# ============================================================================
# CPU Governor
# ============================================================================

set_cpu_governor() {
    log_section "CPU Governor"

    if [[ ! -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        log_warn "CPU frequency scaling not available"
        pause
        return 0
    fi

    local current
    current=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    printf "Current governor: %s\n\n" "$current"

    local available
    available=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
    printf "Available: %s\n\n" "$available"

    printf "Common governors:\n"
    printf "  performance: Max speed (high power)\n"
    printf "  powersave: Min speed (low power)\n"
    printf "  ondemand/schedutil: Dynamic scaling\n"

    printf "\nEnter governor name or press Enter to skip: "
    read -r gov

    if [[ -n "$gov" ]]; then
        queue_command "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo $gov > \$cpu 2>/dev/null; done" "Set CPU governor to $gov"
        log_success "Queued: CPU governor = $gov"
    fi

    pause
}

# ============================================================================
# Desktop Tweaks
# ============================================================================

desktop_tweaks_menu() {
    while true; do
        simple_menu "Desktop Tweaks" \
            "GNOME tweaks" \
            "KDE tweaks" \
            "XFCE tweaks" \
            "Cinnamon tweaks"

        case "$MENU_CHOICE" in
            1) gnome_tweaks ;;
            2) kde_tweaks ;;
            3) xfce_tweaks ;;
            4) cinnamon_tweaks ;;
            0) return ;;
        esac
    done
}

gnome_tweaks() {
    if ! cmd_exists gsettings; then
        log_warn "gsettings not found. Is GNOME installed?"
        pause
        return
    fi

    log_section "GNOME Tweaks"

    simple_menu "GNOME Options" \
        "Disable animations" \
        "Enable animations" \
        "Reduce animation speed"

    case "$MENU_CHOICE" in
        1)
            queue_command "gsettings set org.gnome.desktop.interface enable-animations false" "Disable GNOME animations"
            log_success "Queued: Disable GNOME animations"
            ;;
        2)
            queue_command "gsettings set org.gnome.desktop.interface enable-animations true" "Enable GNOME animations"
            log_success "Queued: Enable GNOME animations"
            ;;
        3)
            queue_command "gsettings set org.gnome.desktop.interface enable-animations true && gsettings set org.gnome.desktop.interface cursor-blink-time 1200" "Reduce GNOME animation speed"
            ;;
    esac
    pause
}

kde_tweaks() {
    log_section "KDE Tweaks"

    printf "KDE settings can be adjusted via System Settings.\n"
    printf "For performance, consider:\n"
    printf "  - Disabling desktop effects\n"
    printf "  - Using a lighter window decoration\n"
    printf "  - Reducing animation speed\n"
    pause
}

xfce_tweaks() {
    log_section "XFCE Tweaks"

    printf "XFCE is already lightweight.\n"
    printf "Consider:\n"
    printf "  - Disabling compositor\n"
    printf "  - Using lighter themes\n"
    pause
}

cinnamon_tweaks() {
    if ! cmd_exists gsettings; then
        log_warn "gsettings not found"
        pause
        return
    fi

    log_section "Cinnamon Tweaks"

    simple_menu "Cinnamon Options" \
        "Disable effects" \
        "Enable effects"

    case "$MENU_CHOICE" in
        1)
            queue_command "gsettings set org.cinnamon desktop-effects false" "Disable Cinnamon effects"
            log_success "Queued: Disable Cinnamon effects"
            ;;
        2)
            queue_command "gsettings set org.cinnamon desktop-effects true" "Enable Cinnamon effects"
            log_success "Queued: Enable Cinnamon effects"
            ;;
    esac
    pause
}

# ============================================================================
# Quick Profiles
# ============================================================================

apply_desktop_profile() {
    log_section "Applying Desktop Profile"

    log_info "This will optimize for desktop responsiveness:"
    printf "  - Swappiness: 10\n"
    printf "  - VFS Cache Pressure: 50\n"
    printf "  - Dirty Ratio: 10\n"
    printf "  - Dirty Background Ratio: 5\n"

    if ! confirm "Apply desktop optimizations?"; then
        return 0
    fi

    queue_sysctl_change "vm.swappiness" "10"
    queue_sysctl_change "vm.vfs_cache_pressure" "50"
    queue_sysctl_change "vm.dirty_ratio" "10"
    queue_sysctl_change "vm.dirty_background_ratio" "5"

    log_success "Desktop profile queued"
    pause
}

apply_gaming_profile() {
    log_section "Applying Gaming Profile"

    log_info "This will optimize for gaming:"
    printf "  - Swappiness: 10\n"
    printf "  - VFS Cache Pressure: 50\n"
    printf "  - Disable watchdogs\n"
    printf "  - TCP BBR enabled\n"

    if ! confirm "Apply gaming optimizations?"; then
        return 0
    fi

    queue_sysctl_change "vm.swappiness" "10"
    queue_sysctl_change "vm.vfs_cache_pressure" "50"
    queue_sysctl_change "kernel.nmi_watchdog" "0"
    queue_sysctl_change "net.ipv4.tcp_congestion_control" "bbr"
    queue_sysctl_change "net.core.default_qdisc" "fq"

    log_warn "For maximum performance, some users disable CPU mitigations."
    log_warn "This has security implications. Not applying automatically."

    log_success "Gaming profile queued"
    pause
}

apply_laptop_profile() {
    log_section "Applying Laptop/Battery Profile"

    log_info "This will optimize for battery life:"
    printf "  - Higher swappiness (reduce disk writes)\n"
    printf "  - Longer dirty writeback\n"
    printf "  - Laptop mode enabled\n"

    if ! confirm "Apply laptop optimizations?"; then
        return 0
    fi

    queue_sysctl_change "vm.swappiness" "60"
    queue_sysctl_change "vm.dirty_writeback_centisecs" "6000"
    queue_sysctl_change "vm.laptop_mode" "5"

    log_success "Laptop profile queued"
    pause
}

apply_server_profile() {
    log_section "Applying Server Profile"

    log_info "This will optimize for server workloads:"
    printf "  - Higher file limits\n"
    printf "  - Network optimizations\n"
    printf "  - Balanced memory settings\n"

    if ! confirm "Apply server optimizations?"; then
        return 0
    fi

    queue_sysctl_change "vm.swappiness" "30"
    queue_sysctl_change "fs.file-max" "2097152"
    queue_sysctl_change "net.core.somaxconn" "65535"
    queue_sysctl_change "net.ipv4.tcp_max_syn_backlog" "65535"
    queue_sysctl_change "net.core.netdev_max_backlog" "65535"
    queue_sysctl_change "net.ipv4.tcp_congestion_control" "bbr"
    queue_sysctl_change "net.core.default_qdisc" "fq"

    log_success "Server profile queued"
    pause
}

# ============================================================================
# Module Initialization
# ============================================================================

optimize_init() {
    log_debug "Optimize module initialized"
}

# ============================================================================
# Main Entry Point
# ============================================================================

optimize_main() {
    while true; do
        local queue_count
        queue_count=$(queue_count)

        simple_menu "System Optimization" \
            "Show Current Settings" \
            "Quick Profile: Desktop" \
            "Quick Profile: Gaming" \
            "Quick Profile: Laptop" \
            "Quick Profile: Server" \
            "Memory: Swappiness" \
            "Memory: VFS Cache" \
            "Memory: ZRAM" \
            "Memory: THP" \
            "Network: BBR" \
            "Network: IPv6" \
            "Network: DNS Cache" \
            "Network: TCP Buffers" \
            "Disk: I/O Scheduler" \
            "CPU: Governor" \
            "Desktop Tweaks" \
            "View Queue ($queue_count pending)"

        case "$MENU_CHOICE" in
            1) show_current_settings ;;
            2) apply_desktop_profile ;;
            3) apply_gaming_profile ;;
            4) apply_laptop_profile ;;
            5) apply_server_profile ;;
            6) optimize_swappiness; pause ;;
            7) optimize_vfs_cache; pause ;;
            8) configure_zram ;;
            9) configure_thp ;;
            10) configure_bbr ;;
            11) configure_ipv6 ;;
            12) configure_dns_cache ;;
            13) configure_tcp_buffers ;;
            14) set_io_scheduler ;;
            15) set_cpu_governor ;;
            16) desktop_tweaks_menu ;;
            17) queue_menu ;;
            0) return 0 ;;
        esac
    done
}
