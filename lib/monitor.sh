#!/usr/bin/env bash
# Unified Suite - System Monitoring
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_MONITOR_LOADED:-}" ]] && return 0
readonly _UNIFIED_MONITOR_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"

# ============================================================
# SYSTEM MONITORING FUNCTIONS
# ============================================================

# Get memory usage percentage
get_memory_usage_percent() {
    free | awk '/Mem:/ {printf "%.1f", ($3/$2) * 100}'
}

# Get swap usage percentage
get_swap_usage_percent() {
    local swap_total=$(free | awk '/Swap:/ {print $2}')
    if [[ "$swap_total" -gt 0 ]]; then
        free | awk '/Swap:/ {printf "%.1f", ($3/$2) * 100}'
    else
        echo "0.0"
    fi
}

# Get CPU usage percentage
get_cpu_usage_percent() {
    top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}'
}

# Get load average
get_load_average() {
    cat /proc/loadavg | cut -d' ' -f1-3
}

# Get disk usage for root
get_disk_usage_percent() {
    df -h / | awk 'NR==2 {print $5}' | tr -d '%'
}

# Get uptime
get_system_uptime() {
    uptime -p 2>/dev/null || cat /proc/uptime | awk '{print int($1/86400)"d "int(($1%86400)/3600)"h "int(($1%3600)/60)"m"}'
}

# ============================================================
# RAM CHECK
# ============================================================

ram_check() {
    log_section "RAM Status Check"

    local total=$(get_total_ram_mb)
    local available=$(get_available_ram_mb)
    local used=$((total - available))
    local percent=$(awk "BEGIN {printf \"%.1f\", ($used / $total) * 100}")

    echo "Total:     ${total} MB"
    echo "Used:      ${used} MB"
    echo "Available: ${available} MB"
    echo "Usage:     ${percent}%"
    echo ""

    # Swap info
    echo "Swap:"
    swapon --show 2>/dev/null || echo "  (none configured)"
    echo ""

    # ZRAM info
    if [[ -b /dev/zram0 ]]; then
        echo "ZRAM: Active"
        zramctl 2>/dev/null || true
    else
        echo "ZRAM: Not active"
    fi
    echo ""

    # Current swappiness
    local swappiness=$(cat /proc/sys/vm/swappiness)
    echo "Swappiness: $swappiness"
    if [[ $swappiness -lt 85 ]]; then
        log_warn "Swappiness below recommended 85+"
    else
        log_success "Swappiness compliant (85+)"
    fi
}

# ============================================================
# SYSTEM HEALTH CHECK
# ============================================================

system_health() {
    log_header "System Health Report"

    local issues=0

    # CPU
    echo "CPU:"
    echo "  Model: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "  Cores: $(get_cpu_count)"
    echo "  Load: $(get_load_average)"
    echo ""

    # Memory
    echo "Memory:"
    local mem_percent=$(get_memory_usage_percent)
    echo "  Usage: ${mem_percent}%"
    if (( $(echo "$mem_percent > 90" | bc -l) )); then
        echo -e "  ${C_RED}[WARNING] High memory usage!${C_RESET}"
        ((issues++))
    fi
    echo ""

    # Swap
    echo "Swap:"
    local swap_percent=$(get_swap_usage_percent)
    echo "  Usage: ${swap_percent}%"
    if (( $(echo "$swap_percent > 80" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  ${C_YELLOW}[INFO] High swap usage${C_RESET}"
    fi
    echo ""

    # Disk
    echo "Disk (/):"
    local disk_percent=$(get_disk_usage_percent)
    echo "  Usage: ${disk_percent}%"
    if [[ $disk_percent -gt 90 ]]; then
        echo -e "  ${C_RED}[WARNING] Disk almost full!${C_RESET}"
        ((issues++))
    fi
    echo ""

    # Uptime
    echo "System:"
    echo "  Uptime: $(get_system_uptime)"
    echo "  Kernel: $(uname -r)"
    echo ""

    # Summary
    if [[ $issues -eq 0 ]]; then
        log_success "System health: OK"
    else
        log_warn "System health: $issues issue(s) detected"
    fi

    return $issues
}

# ============================================================
# QUICK STATUS
# ============================================================

quick_status() {
    echo "CPU:  $(get_load_average) | MEM: $(get_memory_usage_percent)% | SWAP: $(get_swap_usage_percent)% | DISK: $(get_disk_usage_percent)%"
}
