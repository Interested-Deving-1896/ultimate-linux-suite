#!/usr/bin/env bash
# Unified Suite - Optimization Profiles
# License: GPL-3.0-or-later
#
# Pre-configured optimization profiles for common use cases
# All profiles maintain swappiness >= 85 per specification

[[ -n "${_MOD_PROFILES_LOADED:-}" ]] && return 0
readonly _MOD_PROFILES_LOADED=1

# Source libraries
[[ -z "${_UNIFIED_OPTIMIZATION_LOADED:-}" ]] && source "${SUITE_ROOT}/lib/optimization.sh"

# ============================================================
# PRESET PROFILES
# ============================================================

# Gaming Profile
# Optimized for gaming performance with low latency
apply_profile_gaming() {
    log_header "Applying Gaming Profile"

    safety_checkpoint "profile-gaming"

    # Apply VERY_HIGH or HIGH profile (depends on RAM)
    local ram_profile=$(detect_ram_profile)
    apply_sysctl_config "$ram_profile"

    # Gaming-specific tweaks
    if [[ $DRY_RUN -eq 0 ]]; then
        # Ensure high map count for games
        echo 2147483642 > /proc/sys/vm/max_map_count 2>/dev/null || true

        # CPU governor to performance
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "performance" > "$cpu" 2>/dev/null || true
        done

        # I/O scheduler for responsiveness
        for device in /sys/block/*/queue/scheduler; do
            echo "mq-deadline" > "$device" 2>/dev/null || true
        done
    fi

    log_success "Gaming profile applied"
    log_info "Swappiness: $(cat /proc/sys/vm/swappiness) (compliant: 85+)"
}

# Server Profile
# Optimized for server workloads
apply_profile_server() {
    log_header "Applying Server Profile"

    safety_checkpoint "profile-server"

    local ram_profile=$(detect_ram_profile)
    apply_sysctl_config "$ram_profile"

    # Server-specific tweaks
    if [[ $DRY_RUN -eq 0 ]]; then
        # Higher connection limits
        echo 262144 > /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || true

        # CPU governor for balanced performance
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "performance" > "$cpu" 2>/dev/null || true
        done
    fi

    log_success "Server profile applied"
}

# Laptop Profile
# Optimized for battery life on laptops
apply_profile_laptop() {
    log_header "Applying Laptop Profile"

    safety_checkpoint "profile-laptop"

    local ram_profile=$(detect_ram_profile)
    apply_sysctl_config "$ram_profile"

    # Laptop-specific tweaks
    if [[ $DRY_RUN -eq 0 ]]; then
        # Power-saving governor
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "powersave" > "$cpu" 2>/dev/null || true
        done

        # Enable laptop mode
        echo 5 > /proc/sys/vm/laptop_mode 2>/dev/null || true
    fi

    log_success "Laptop profile applied"
}

# Workstation Profile
# Balanced profile for desktop workstations
apply_profile_workstation() {
    log_header "Applying Workstation Profile"

    safety_checkpoint "profile-workstation"

    local ram_profile=$(detect_ram_profile)
    apply_sysctl_config "$ram_profile"

    # Workstation tweaks
    if [[ $DRY_RUN -eq 0 ]]; then
        # Balanced governor
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if grep -q schedutil /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
                echo "schedutil" > "$cpu" 2>/dev/null || true
            else
                echo "ondemand" > "$cpu" 2>/dev/null || true
            fi
        done
    fi

    log_success "Workstation profile applied"
}

# Low-end Profile
# For systems with very limited resources
apply_profile_lowend() {
    log_header "Applying Low-End System Profile"

    safety_checkpoint "profile-lowend"

    # Force MINIMAL or LOW profile
    local ram_mb=$(get_total_ram_mb)
    local profile="LOW"
    [[ $ram_mb -le 2048 ]] && profile="MINIMAL"

    apply_sysctl_config "$profile"
    configure_zram "$profile"

    log_success "Low-end profile applied"
    log_info "ZRAM enabled for maximum RAM efficiency"
}

# ============================================================
# PROFILE SELECTION
# ============================================================

# Interactive profile selection
select_profile_interactive() {
    log_header "Optimization Profiles"

    echo "Available profiles:"
    echo "  gaming      - Maximum gaming performance"
    echo "  server      - Server workload optimization"
    echo "  laptop      - Battery life optimization"
    echo "  workstation - Balanced desktop performance"
    echo "  lowend      - Low-resource system optimization"
    echo "  auto        - Auto-detect best profile"
    echo ""

    local profile=""
    if tui_available; then
        profile=$(tui_menu "Select Profile" \
            "auto" "Auto-detect best profile" \
            "gaming" "Gaming performance" \
            "server" "Server optimization" \
            "laptop" "Battery life" \
            "workstation" "Balanced desktop" \
            "lowend" "Low-resource system")
    else
        read -rp "Select profile [auto]: " profile
        [[ -z "$profile" ]] && profile="auto"
    fi

    apply_profile "$profile"
}

# Apply named profile
apply_profile() {
    local profile="$1"

    case "$profile" in
        gaming)      apply_profile_gaming ;;
        server)      apply_profile_server ;;
        laptop)      apply_profile_laptop ;;
        workstation) apply_profile_workstation ;;
        lowend)      apply_profile_lowend ;;
        auto)
            if is_laptop; then
                apply_profile_laptop
            else
                apply_profile_workstation
            fi
            ;;
        *)
            log_error "Unknown profile: $profile"
            return 1
            ;;
    esac
}
