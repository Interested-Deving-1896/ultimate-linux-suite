#!/usr/bin/env bash
# Unified Suite - CPU Optimizer Module
# Source: Ported from Ultimate Linux Suite v5.0
# License: GPL-3.0-or-later

[[ -n "${_MOD_CPU_OPTIMIZER_LOADED:-}" ]] && return 0
readonly _MOD_CPU_OPTIMIZER_LOADED=1

# Source libraries
[[ -z "${_UNIFIED_OPTIMIZATION_LOADED:-}" ]] && source "${SUITE_ROOT}/lib/optimization.sh"
[[ -z "${_UNIFIED_HARDWARE_LOADED:-}" ]] && source "${SUITE_ROOT}/lib/hardware.sh"

# ============================================================
# CPU OPTIMIZER FUNCTIONS
# ============================================================

# Get current CPU governor
cpu_get_governor() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown"
}

# Get available governors
cpu_get_available_governors() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo ""
}

# Set CPU governor
cpu_set_governor() {
    local governor="$1"

    log_info "Setting CPU governor to: $governor"

    local available=$(cpu_get_available_governors)
    if ! echo "$available" | grep -qw "$governor"; then
        log_error "Governor '$governor' not available"
        log_info "Available: $available"
        return $EXIT_FAILURE
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would set governor to $governor"
        return 0
    fi

    local success=0
    local total=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        ((total++))
        if echo "$governor" > "$cpu" 2>/dev/null; then
            ((success++))
        fi
    done

    if [[ $success -eq $total ]]; then
        log_success "Governor set to $governor on all $total CPUs"
    else
        log_warn "Governor set on $success/$total CPUs"
    fi
}

# Interactive CPU optimization
cpu_optimize_interactive() {
    log_header "CPU Optimization"

    local current=$(cpu_get_governor)
    local available=$(cpu_get_available_governors)
    local recommended=$(get_recommended_power_profile)

    log_info "Current governor: $current"
    log_info "Recommended: $recommended"
    echo ""

    echo "Available governors:"
    for gov in $available; do
        local desc=""
        case "$gov" in
            performance)  desc="Maximum performance" ;;
            powersave)    desc="Maximum power saving" ;;
            ondemand)     desc="Dynamic scaling (older)" ;;
            conservative) desc="Gradual changes" ;;
            schedutil)    desc="Scheduler-driven (modern)" ;;
            *)            desc="No description" ;;
        esac
        printf "  %-14s %s\n" "$gov:" "$desc"
    done
    echo ""

    local governor=""
    if tui_available; then
        local menu_items=()
        for gov in $available; do
            menu_items+=("$gov" "$gov governor")
        done
        governor=$(tui_menu "Select CPU Governor" "${menu_items[@]}")
    else
        read -rp "Enter governor [$recommended]: " governor
        [[ -z "$governor" ]] && governor="$recommended"
    fi

    if confirm "Set CPU governor to '$governor'?"; then
        safety_checkpoint "cpu-governor"
        cpu_set_governor "$governor"
    fi
}

# CPU info display
cpu_show_info() {
    log_section "CPU Information"

    echo "Model: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "Cores: $(nproc)"
    echo "Architecture: $(uname -m)"
    echo ""
    echo "Governor: $(cpu_get_governor)"
    echo "Available: $(cpu_get_available_governors)"
    echo ""

    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]]; then
        local min=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq)
        local max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
        local cur=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        echo "Frequency:"
        echo "  Min: $((min/1000)) MHz"
        echo "  Max: $((max/1000)) MHz"
        echo "  Current: $((cur/1000)) MHz"
    fi
}
