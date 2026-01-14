#!/usr/bin/env bash
# Unified Suite - RAM Optimizer Module
# Source: Ported from Ultimate Linux Suite v5.0
# License: GPL-3.0-or-later
#
# CRITICAL: All swappiness values are 85+ per specification

[[ -n "${_MOD_RAM_OPTIMIZER_LOADED:-}" ]] && return 0
readonly _MOD_RAM_OPTIMIZER_LOADED=1

# Source libraries
[[ -z "${_UNIFIED_OPTIMIZATION_LOADED:-}" ]] && source "${SUITE_ROOT}/lib/optimization.sh"

# ============================================================
# RAM OPTIMIZER FUNCTIONS
# ============================================================

# Interactive RAM optimization
ram_optimize_interactive() {
    log_header "RAM Optimization"

    local auto_profile=$(detect_ram_profile)
    local ram_mb=$(get_total_ram_mb)

    log_info "Detected RAM: ${ram_mb}MB"
    log_info "Recommended profile: $auto_profile"
    echo ""

    echo "Available profiles (all swappiness 85+):"
    echo ""
    printf "  %-12s %-15s %-12s %-8s\n" "Profile" "RAM Range" "Swappiness" "ZRAM"
    echo "  $(printf '=%.0s' {1..50})"
    printf "  %-12s %-15s %-12s %-8s\n" "MINIMAL" "<=2GB" "95" "100%"
    printf "  %-12s %-15s %-12s %-8s\n" "LOW" "2-4GB" "90" "75%"
    printf "  %-12s %-15s %-12s %-8s\n" "MEDIUM" "4-8GB" "88" "50%"
    printf "  %-12s %-15s %-12s %-8s\n" "HIGH" "8-16GB" "86" "Off"
    printf "  %-12s %-15s %-12s %-8s\n" "VERY_HIGH" ">16GB" "85" "Off"
    echo ""

    local profile=""
    if tui_available; then
        profile=$(tui_menu "Select RAM Profile" \
            "AUTO" "Auto-detect ($auto_profile)" \
            "MINIMAL" "Minimal RAM (<=2GB)" \
            "LOW" "Low RAM (2-4GB)" \
            "MEDIUM" "Medium RAM (4-8GB)" \
            "HIGH" "High RAM (8-16GB)" \
            "VERY_HIGH" "Very High RAM (>16GB)")
        [[ "$profile" == "AUTO" ]] && profile="$auto_profile"
    else
        echo "Select profile (Enter for auto):"
        echo "  1) MINIMAL   2) LOW   3) MEDIUM   4) HIGH   5) VERY_HIGH"
        read -rp "Choice [$auto_profile]: " choice
        case "$choice" in
            1) profile="MINIMAL" ;;
            2) profile="LOW" ;;
            3) profile="MEDIUM" ;;
            4) profile="HIGH" ;;
            5) profile="VERY_HIGH" ;;
            *) profile="$auto_profile" ;;
        esac
    fi

    log_info "Selected profile: $profile"

    if confirm "Apply RAM optimization for $profile profile?"; then
        ram_optimize_apply "$profile"
    else
        log_info "Optimization cancelled"
    fi
}

# Apply RAM optimization
ram_optimize_apply() {
    local profile="$1"

    log_section "Applying RAM Optimization - Profile: $profile"

    local swappiness=$(get_profile_value "$profile" "SWAPPINESS")
    if [[ -z "$swappiness" ]]; then
        log_error "Invalid profile: $profile"
        return $EXIT_FAILURE
    fi

    # Verify swappiness compliance (85+)
    if [[ $swappiness -lt 85 ]]; then
        log_error "CRITICAL: Profile swappiness ($swappiness) below minimum 85!"
        return $EXIT_FAILURE
    fi

    safety_checkpoint "ram-optimization-$profile"

    log_info "Configuring kernel memory parameters..."
    apply_sysctl_config "$profile"

    local zram_enabled=$(get_profile_value "$profile" "ZRAM_ENABLED")
    if [[ "$zram_enabled" -eq 1 ]]; then
        log_info "Configuring ZRAM..."
        configure_zram "$profile"
    fi

    echo ""
    log_success "RAM optimization complete!"
    echo ""
    echo "Applied settings:"
    echo "  Swappiness: $swappiness (compliant: 85+)"
    echo "  Cache Pressure: $(get_profile_value "$profile" "CACHE_PRESSURE")"
    echo "  ZRAM: $(get_profile_value "$profile" "ZRAM_ENABLED" | sed 's/1/Enabled/;s/0/Disabled/')"
    echo ""
    log_warn "A reboot is recommended"

    return $EXIT_SUCCESS
}

# Quick RAM optimization
ram_optimize_quick() {
    local profile="${1:-$(detect_ram_profile)}"
    log_info "Quick RAM optimization with profile: $profile"
    ram_optimize_apply "$profile"
}

# Show RAM status
ram_show_status() {
    verify_optimization
}
