#!/usr/bin/env bash
#
# cpu_governor.sh - CPU Frequency Scaling Configuration for Ultimate Linux Suite
#
# This module provides comprehensive CPU governor and frequency scaling management
# for Intel, AMD, and ACPI-based systems. Supports persistence via systemd, TLP,
# and cpufrequtils.
#

# Prevent multiple sourcing
[[ -n "${_CPU_GOVERNOR_LOADED:-}" ]] && return 0
readonly _CPU_GOVERNOR_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

_CPU_GOV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${_CPU_GOV_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# Source hardware_detect with fallback
source "${_CPU_GOV_SCRIPT_DIR}/hardware_detect.sh" 2>/dev/null || {
    log_debug "hardware_detect.sh not available, using fallbacks"
}

# ============================================================================
# Global Variables
# ============================================================================

# CPU frequency paths
readonly CPUFREQ_PATH="/sys/devices/system/cpu"
readonly SCALING_DRIVER_PATH="/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"
readonly INTEL_PSTATE_PATH="/sys/devices/system/cpu/intel_pstate"
readonly AMD_PSTATE_PATH="/sys/devices/system/cpu/amd_pstate"

# Cache variables
declare -g _CPUFREQ_DRIVER=""
declare -g _CPUFREQ_AVAILABLE_GOVERNORS=""
declare -g _CPU_COUNT=""

# ============================================================================
# Core Detection Functions
# ============================================================================

# Check if CPU frequency scaling is supported
check_cpufreq_support() {
    if [[ ! -d "$CPUFREQ_PATH" ]]; then
        log_error "CPU frequency scaling not available: $CPUFREQ_PATH not found"
        return 1
    fi

    if [[ ! -r "$SCALING_DRIVER_PATH" ]]; then
        log_error "CPU frequency scaling driver not available"
        return 1
    fi

    log_debug "CPU frequency scaling is supported"
    return 0
}

# Get the CPU frequency scaling driver
get_cpu_driver() {
    if [[ -n "$_CPUFREQ_DRIVER" ]]; then
        echo "$_CPUFREQ_DRIVER"
        return 0
    fi

    if [[ ! -r "$SCALING_DRIVER_PATH" ]]; then
        log_error "Cannot read scaling driver path"
        echo "unknown"
        return 1
    fi

    _CPUFREQ_DRIVER=$(cat "$SCALING_DRIVER_PATH" 2>/dev/null || echo "unknown")
    echo "$_CPUFREQ_DRIVER"
    log_debug "CPU frequency driver: $_CPUFREQ_DRIVER"
    return 0
}

# Get available governors
get_available_governors() {
    if [[ -n "$_CPUFREQ_AVAILABLE_GOVERNORS" ]]; then
        echo "$_CPUFREQ_AVAILABLE_GOVERNORS"
        return 0
    fi

    local gov_path="${CPUFREQ_PATH}/cpu0/cpufreq/scaling_available_governors"
    if [[ ! -r "$gov_path" ]]; then
        log_error "Cannot read available governors"
        return 1
    fi

    _CPUFREQ_AVAILABLE_GOVERNORS=$(cat "$gov_path" 2>/dev/null)
    echo "$_CPUFREQ_AVAILABLE_GOVERNORS"
    log_debug "Available governors: $_CPUFREQ_AVAILABLE_GOVERNORS"
    return 0
}

# Get current governor for each CPU
get_current_governor() {
    local cpu="${1:-all}"

    if [[ "$cpu" == "all" ]]; then
        local governors=()
        local unique_gov=""

        for cpu_dir in "${CPUFREQ_PATH}"/cpu[0-9]*; do
            [[ -d "$cpu_dir" ]] || continue
            local gov_file="${cpu_dir}/cpufreq/scaling_governor"
            [[ -r "$gov_file" ]] || continue

            local gov
            gov=$(cat "$gov_file" 2>/dev/null)
            governors+=("$gov")

            if [[ -z "$unique_gov" ]]; then
                unique_gov="$gov"
            elif [[ "$unique_gov" != "$gov" ]]; then
                unique_gov="mixed"
            fi
        done

        echo "$unique_gov"
    else
        local gov_file="${CPUFREQ_PATH}/cpu${cpu}/cpufreq/scaling_governor"
        if [[ ! -r "$gov_file" ]]; then
            log_error "Cannot read governor for CPU $cpu"
            return 1
        fi
        cat "$gov_file" 2>/dev/null
    fi
}

# Get number of CPUs with frequency scaling
get_cpu_count() {
    if [[ -n "$_CPU_COUNT" ]]; then
        echo "$_CPU_COUNT"
        return 0
    fi

    local count=0
    for cpu_dir in "${CPUFREQ_PATH}"/cpu[0-9]*/cpufreq; do
        [[ -d "$cpu_dir" ]] && ((count++))
    done

    _CPU_COUNT=$count
    echo "$_CPU_COUNT"
    return 0
}

# ============================================================================
# Governor Recommendation
# ============================================================================

# Recommend governor based on use case and hardware
# Usage: recommend_governor [use_case]
# use_case: desktop, gaming, laptop, server, balanced (default: auto-detect)
recommend_governor() {
    local use_case="${1:-auto}"
    local driver
    driver=$(get_cpu_driver)
    local available
    available=$(get_available_governors)

    # Auto-detect use case from hardware
    if [[ "$use_case" == "auto" ]]; then
        # Ensure hardware is detected
        [[ -z "$CHASSIS_TYPE" ]] && detect_chassis_type >/dev/null 2>&1
        [[ -z "$HAS_BATTERY" ]] && detect_battery >/dev/null 2>&1

        if [[ "$HAS_BATTERY" -eq 1 ]] || [[ "$CHASSIS_TYPE" == "laptop" ]]; then
            use_case="laptop"
        elif [[ "$CHASSIS_TYPE" == "server" ]]; then
            use_case="server"
        elif [[ "$GPU_VENDOR" == "nvidia" ]] || [[ "$GPU_VENDOR" == "amd" ]]; then
            # Check for discrete GPU
            if [[ -n "$GPU_MODEL" ]] && ! echo "$GPU_MODEL" | grep -qiE "integrated|vega [0-9]+ graphics|uhd|iris"; then
                use_case="gaming"
            else
                use_case="desktop"
            fi
        else
            use_case="balanced"
        fi
        log_debug "Auto-detected use case: $use_case"
    fi

    local recommended=""
    local epp_recommendation=""

    # Governor recommendations by use case
    case "$use_case" in
        gaming|desktop)
            # Prefer schedutil on modern kernels, performance for max FPS
            if echo "$available" | grep -qw "schedutil"; then
                recommended="schedutil"
                epp_recommendation="balance_performance"
            elif echo "$available" | grep -qw "performance"; then
                recommended="performance"
                epp_recommendation="performance"
            else
                recommended="ondemand"
            fi
            ;;

        laptop)
            # Battery life priority
            if echo "$available" | grep -qw "schedutil"; then
                recommended="schedutil"
                epp_recommendation="balance_power"
            elif echo "$available" | grep -qw "powersave"; then
                recommended="powersave"
                epp_recommendation="balance_power"
            elif echo "$available" | grep -qw "conservative"; then
                recommended="conservative"
            else
                recommended="ondemand"
            fi
            ;;

        server)
            # Consistent performance for server workloads
            if echo "$available" | grep -qw "performance"; then
                recommended="performance"
                epp_recommendation="balance_performance"
            elif echo "$available" | grep -qw "schedutil"; then
                recommended="schedutil"
                epp_recommendation="performance"
            else
                recommended="ondemand"
            fi
            ;;

        balanced|*)
            # Best all-around choice
            if echo "$available" | grep -qw "schedutil"; then
                recommended="schedutil"
                epp_recommendation="balance_performance"
            elif echo "$available" | grep -qw "ondemand"; then
                recommended="ondemand"
            else
                recommended="powersave"
                epp_recommendation="balance_power"
            fi
            ;;
    esac

    # Validate recommendation is available
    if ! echo "$available" | grep -qw "$recommended"; then
        log_warn "Recommended governor '$recommended' not available, using first available"
        recommended=$(echo "$available" | awk '{print $1}')
    fi

    echo "$recommended"

    # Export EPP recommendation for use by caller
    if [[ -n "$epp_recommendation" ]]; then
        export _RECOMMENDED_EPP="$epp_recommendation"
    fi

    log_debug "Recommended governor for $use_case: $recommended (EPP: ${epp_recommendation:-none})"
    return 0
}

# ============================================================================
# Governor Setting
# ============================================================================

# Set governor for all CPUs
set_governor() {
    local governor="$1"

    if [[ -z "$governor" ]]; then
        log_error "No governor specified"
        return 1
    fi

    # Validate governor is available
    local available
    available=$(get_available_governors)
    if ! echo "$available" | grep -qw "$governor"; then
        log_error "Governor '$governor' not available. Available: $available"
        return 1
    fi

    log_info "Setting governor to '$governor' for all CPUs..."

    local success=0
    local failed=0

    for cpu_dir in "${CPUFREQ_PATH}"/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue

        local gov_file="${cpu_dir}/cpufreq/scaling_governor"
        [[ -w "$gov_file" ]] || continue

        if echo "$governor" > "$gov_file" 2>/dev/null; then
            ((success++))
        else
            ((failed++))
            local cpu_num
            cpu_num=$(basename "$cpu_dir")
            log_warn "Failed to set governor for $cpu_num"
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "Set governor for $success CPUs, failed for $failed CPUs"
        return 1
    else
        log_success "Governor '$governor' set for $success CPUs"
        return 0
    fi
}

# ============================================================================
# Frequency Limits
# ============================================================================

# Get min/max frequency limits
get_frequency_limits() {
    local cpu="${1:-0}"
    local cpu_path="${CPUFREQ_PATH}/cpu${cpu}/cpufreq"

    if [[ ! -d "$cpu_path" ]]; then
        log_error "CPU $cpu does not support frequency scaling"
        return 1
    fi

    local scaling_min scaling_max cpuinfo_min cpuinfo_max
    scaling_min=$(cat "${cpu_path}/scaling_min_freq" 2>/dev/null || echo "0")
    scaling_max=$(cat "${cpu_path}/scaling_max_freq" 2>/dev/null || echo "0")
    cpuinfo_min=$(cat "${cpu_path}/cpuinfo_min_freq" 2>/dev/null || echo "0")
    cpuinfo_max=$(cat "${cpu_path}/cpuinfo_max_freq" 2>/dev/null || echo "0")

    # Convert kHz to MHz
    local scaling_min_mhz=$((scaling_min / 1000))
    local scaling_max_mhz=$((scaling_max / 1000))
    local cpuinfo_min_mhz=$((cpuinfo_min / 1000))
    local cpuinfo_max_mhz=$((cpuinfo_max / 1000))

    cat <<EOF
CPU $cpu Frequency Limits:
  Hardware Limits: ${cpuinfo_min_mhz} MHz - ${cpuinfo_max_mhz} MHz
  Current Limits:  ${scaling_min_mhz} MHz - ${scaling_max_mhz} MHz
EOF
    return 0
}

# Set frequency limits for all CPUs
set_frequency_limits() {
    local min_freq="$1"  # in MHz
    local max_freq="$2"  # in MHz

    if [[ -z "$min_freq" ]] || [[ -z "$max_freq" ]]; then
        log_error "Usage: set_frequency_limits MIN_MHZ MAX_MHZ"
        return 1
    fi

    # Convert MHz to kHz
    local min_khz=$((min_freq * 1000))
    local max_khz=$((max_freq * 1000))

    log_info "Setting frequency limits: ${min_freq} MHz - ${max_freq} MHz"

    local success=0
    local failed=0

    for cpu_dir in "${CPUFREQ_PATH}"/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue

        local min_file="${cpu_dir}/cpufreq/scaling_min_freq"
        local max_file="${cpu_dir}/cpufreq/scaling_max_freq"

        # Verify hardware limits
        local cpuinfo_min cpuinfo_max
        cpuinfo_min=$(cat "${cpu_dir}/cpufreq/cpuinfo_min_freq" 2>/dev/null || echo "0")
        cpuinfo_max=$(cat "${cpu_dir}/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo "0")

        if [[ $min_khz -lt $cpuinfo_min ]] || [[ $max_khz -gt $cpuinfo_max ]]; then
            log_warn "Requested frequency limits outside hardware capabilities for $(basename "$cpu_dir")"
            ((failed++))
            continue
        fi

        # Set max first to avoid min > max errors
        if [[ -w "$max_file" ]] && echo "$max_khz" > "$max_file" 2>/dev/null; then
            if [[ -w "$min_file" ]] && echo "$min_khz" > "$min_file" 2>/dev/null; then
                ((success++))
            else
                ((failed++))
            fi
        else
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "Set frequency limits for $success CPUs, failed for $failed CPUs"
        return 1
    else
        log_success "Frequency limits set for $success CPUs"
        return 0
    fi
}

# ============================================================================
# Energy Performance Preference (EPP)
# ============================================================================

# Get Energy Performance Preference (Intel/AMD pstate)
get_energy_preference() {
    local driver
    driver=$(get_cpu_driver)

    case "$driver" in
        intel_pstate|intel_cpufreq)
            local epp_file="${CPUFREQ_PATH}/cpu0/cpufreq/energy_performance_preference"
            if [[ -r "$epp_file" ]]; then
                cat "$epp_file" 2>/dev/null
                return 0
            else
                log_warn "EPP not supported or HWP not enabled"
                return 1
            fi
            ;;
        amd-pstate*|amd_pstate*)
            local epp_file="${CPUFREQ_PATH}/cpu0/cpufreq/energy_performance_preference"
            if [[ -r "$epp_file" ]]; then
                cat "$epp_file" 2>/dev/null
                return 0
            else
                log_warn "EPP not supported on this AMD system"
                return 1
            fi
            ;;
        *)
            log_warn "EPP not supported by driver: $driver"
            return 1
            ;;
    esac
}

# Set Energy Performance Preference
# Valid values: performance, balance_performance, default, balance_power, power
set_energy_preference() {
    local epp="$1"

    if [[ -z "$epp" ]]; then
        log_error "Usage: set_energy_preference <performance|balance_performance|default|balance_power|power>"
        return 1
    fi

    local driver
    driver=$(get_cpu_driver)

    # Validate EPP is supported
    case "$driver" in
        intel_pstate|intel_cpufreq|amd-pstate*|amd_pstate*)
            ;;
        *)
            log_error "EPP not supported by driver: $driver"
            return 1
            ;;
    esac

    log_info "Setting energy performance preference to '$epp'..."

    local success=0
    local failed=0

    for cpu_dir in "${CPUFREQ_PATH}"/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue

        local epp_file="${cpu_dir}/cpufreq/energy_performance_preference"
        [[ -w "$epp_file" ]] || continue

        if echo "$epp" > "$epp_file" 2>/dev/null; then
            ((success++))
        else
            ((failed++))
        fi
    done

    if [[ $success -eq 0 ]]; then
        log_error "Failed to set EPP (not supported or permission denied)"
        return 1
    elif [[ $failed -gt 0 ]]; then
        log_warn "Set EPP for $success CPUs, failed for $failed CPUs"
        return 1
    else
        log_success "EPP '$epp' set for $success CPUs"
        return 0
    fi
}

# ============================================================================
# Turbo Boost Control
# ============================================================================

# Get turbo/boost status
get_turbo_status() {
    local driver
    driver=$(get_cpu_driver)

    case "$driver" in
        intel_pstate)
            if [[ -r "${INTEL_PSTATE_PATH}/no_turbo" ]]; then
                local no_turbo
                no_turbo=$(cat "${INTEL_PSTATE_PATH}/no_turbo" 2>/dev/null)
                if [[ "$no_turbo" == "0" ]]; then
                    echo "enabled"
                else
                    echo "disabled"
                fi
                return 0
            fi
            ;;
        amd-pstate*|amd_pstate*)
            if [[ -r "${CPUFREQ_PATH}/cpufreq/boost" ]]; then
                local boost
                boost=$(cat "${CPUFREQ_PATH}/cpufreq/boost" 2>/dev/null)
                if [[ "$boost" == "1" ]]; then
                    echo "enabled"
                else
                    echo "disabled"
                fi
                return 0
            fi
            ;;
        acpi-cpufreq)
            if [[ -r "${CPUFREQ_PATH}/cpufreq/boost" ]]; then
                local boost
                boost=$(cat "${CPUFREQ_PATH}/cpufreq/boost" 2>/dev/null)
                if [[ "$boost" == "1" ]]; then
                    echo "enabled"
                else
                    echo "disabled"
                fi
                return 0
            fi
            ;;
    esac

    echo "unknown"
    return 1
}

# Set turbo/boost status
# Usage: set_turbo <enable|disable>
set_turbo() {
    local action="$1"

    if [[ "$action" != "enable" ]] && [[ "$action" != "disable" ]]; then
        log_error "Usage: set_turbo <enable|disable>"
        return 1
    fi

    local driver
    driver=$(get_cpu_driver)

    case "$driver" in
        intel_pstate)
            if [[ -w "${INTEL_PSTATE_PATH}/no_turbo" ]]; then
                if [[ "$action" == "enable" ]]; then
                    echo "0" > "${INTEL_PSTATE_PATH}/no_turbo" 2>/dev/null
                else
                    echo "1" > "${INTEL_PSTATE_PATH}/no_turbo" 2>/dev/null
                fi

                if [[ $? -eq 0 ]]; then
                    log_success "Turbo boost ${action}d"
                    return 0
                else
                    log_error "Failed to ${action} turbo boost"
                    return 1
                fi
            else
                log_error "Intel turbo control not writable"
                return 1
            fi
            ;;

        amd-pstate*|amd_pstate*|acpi-cpufreq)
            local boost_file="${CPUFREQ_PATH}/cpufreq/boost"
            if [[ -w "$boost_file" ]]; then
                if [[ "$action" == "enable" ]]; then
                    echo "1" > "$boost_file" 2>/dev/null
                else
                    echo "0" > "$boost_file" 2>/dev/null
                fi

                if [[ $? -eq 0 ]]; then
                    log_success "CPU boost ${action}d"
                    return 0
                else
                    log_error "Failed to ${action} CPU boost"
                    return 1
                fi
            else
                log_error "CPU boost control not writable"
                return 1
            fi
            ;;

        *)
            log_error "Turbo/boost control not supported by driver: $driver"
            return 1
            ;;
    esac
}

# ============================================================================
# Persistence
# ============================================================================

# Create systemd service for cpupower persistence
create_cpupower_service() {
    local governor="$1"
    local min_freq="${2:-}"
    local max_freq="${3:-}"
    local epp="${4:-}"

    if [[ -z "$governor" ]]; then
        log_error "Usage: create_cpupower_service GOVERNOR [MIN_FREQ] [MAX_FREQ] [EPP]"
        return 1
    fi

    # Check for cpupower
    if ! command -v cpupower >/dev/null 2>&1; then
        log_error "cpupower not found. Install with: dnf install kernel-tools (Fedora) or apt install linux-cpupower (Debian/Ubuntu)"
        return 1
    fi

    local service_file="/etc/systemd/system/cpupower-governor.service"
    local config_file="/etc/default/cpupower-governor"

    log_info "Creating cpupower systemd service..."

    # Create configuration file
    cat > "$config_file" <<EOF
# CPU Governor Configuration
# Generated by Ultimate Linux Suite

# Governor: ${governor}
GOVERNOR="${governor}"

# Frequency limits (in MHz, optional)
MIN_FREQ="${min_freq}"
MAX_FREQ="${max_freq}"

# Energy Performance Preference (Intel/AMD pstate only)
EPP="${epp}"
EOF

    if [[ $? -ne 0 ]]; then
        log_error "Failed to create configuration file"
        return 1
    fi

    # Create systemd service
    cat > "$service_file" <<'EOF'
[Unit]
Description=Set CPU Frequency Governor
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
EnvironmentFile=/etc/default/cpupower-governor
ExecStart=/bin/bash -c '\
    if [ -n "$GOVERNOR" ]; then \
        cpupower frequency-set -g "$GOVERNOR"; \
    fi; \
    if [ -n "$MIN_FREQ" ] && [ -n "$MAX_FREQ" ]; then \
        cpupower frequency-set -d "${MIN_FREQ}MHz" -u "${MAX_FREQ}MHz"; \
    fi; \
    if [ -n "$EPP" ]; then \
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do \
            [ -w "$cpu" ] && echo "$EPP" > "$cpu" 2>/dev/null || true; \
        done; \
    fi'

[Install]
WantedBy=multi-user.target
EOF

    if [[ $? -ne 0 ]]; then
        log_error "Failed to create systemd service"
        return 1
    fi

    # Reload systemd and enable service
    systemctl daemon-reload
    if systemctl enable cpupower-governor.service; then
        log_success "Systemd service created and enabled: cpupower-governor.service"
        log_info "Service will apply settings on boot"
        log_info "To apply now: systemctl start cpupower-governor.service"
        return 0
    else
        log_error "Failed to enable systemd service"
        return 1
    fi
}

# Set governor with persistence
set_governor_persistent() {
    local governor="$1"
    local method="${2:-auto}"  # auto, systemd, tlp, cpufrequtils

    if [[ -z "$governor" ]]; then
        log_error "Usage: set_governor_persistent GOVERNOR [METHOD]"
        return 1
    fi

    # Set immediately
    if ! set_governor "$governor"; then
        log_error "Failed to set governor"
        return 1
    fi

    # Determine persistence method
    if [[ "$method" == "auto" ]]; then
        if command -v tlp >/dev/null 2>&1; then
            method="tlp"
        elif [[ -f /etc/default/cpufrequtils ]]; then
            method="cpufrequtils"
        else
            method="systemd"
        fi
        log_debug "Auto-selected persistence method: $method"
    fi

    # Apply persistence
    case "$method" in
        systemd)
            create_cpupower_service "$governor" "" "" ""
            ;;

        tlp)
            log_info "Configuring TLP for persistent governor..."
            local tlp_conf="/etc/tlp.conf"
            if [[ ! -f "$tlp_conf" ]]; then
                log_error "TLP configuration not found: $tlp_conf"
                return 1
            fi

            # Backup original
            cp "$tlp_conf" "${tlp_conf}.backup.$(date +%Y%m%d-%H%M%S)"

            # Update TLP configuration
            if grep -q "^CPU_SCALING_GOVERNOR_ON_AC=" "$tlp_conf"; then
                sed -i "s/^CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=$governor/" "$tlp_conf"
            else
                echo "CPU_SCALING_GOVERNOR_ON_AC=$governor" >> "$tlp_conf"
            fi

            if grep -q "^CPU_SCALING_GOVERNOR_ON_BAT=" "$tlp_conf"; then
                sed -i "s/^CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=$governor/" "$tlp_conf"
            else
                echo "CPU_SCALING_GOVERNOR_ON_BAT=$governor" >> "$tlp_conf"
            fi

            log_success "TLP configured with governor: $governor"
            log_info "Restart TLP: systemctl restart tlp"
            ;;

        cpufrequtils)
            log_info "Configuring cpufrequtils for persistent governor..."
            local cpufreq_conf="/etc/default/cpufrequtils"

            cat > "$cpufreq_conf" <<EOF
# CPU Frequency Scaling Configuration
# Generated by Ultimate Linux Suite
GOVERNOR="$governor"
EOF

            log_success "cpufrequtils configured with governor: $governor"
            log_info "Changes will apply on next boot"
            ;;

        *)
            log_error "Unknown persistence method: $method"
            return 1
            ;;
    esac

    return 0
}

# ============================================================================
# Status and Monitoring
# ============================================================================

# Get comprehensive CPU frequency statistics
get_cpu_stats() {
    local driver
    driver=$(get_cpu_driver)

    echo "========================================="
    echo "CPU Frequency Scaling Status"
    echo "========================================="
    echo ""
    echo "Driver: $driver"
    echo ""

    # Current governor
    local current_gov
    current_gov=$(get_current_governor all)
    echo "Current Governor: $current_gov"
    echo ""

    # Available governors
    local available
    available=$(get_available_governors)
    echo "Available Governors: $available"
    echo ""

    # Turbo status
    local turbo
    turbo=$(get_turbo_status)
    echo "Turbo/Boost: $turbo"
    echo ""

    # EPP (if supported)
    local epp
    epp=$(get_energy_preference 2>/dev/null)
    if [[ -n "$epp" ]]; then
        echo "Energy Performance Preference: $epp"
        echo ""
    fi

    # Per-CPU stats (show first 4 CPUs to avoid clutter)
    echo "Per-CPU Status (first 4 CPUs):"
    echo "-------------------------------------------"
    printf "%-6s %-12s %-10s %-10s %s\n" "CPU" "Governor" "Current" "Min" "Max"
    echo "-------------------------------------------"

    local count=0
    for cpu_dir in "${CPUFREQ_PATH}"/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue
        [[ $count -ge 4 ]] && break

        local cpu_num
        cpu_num=$(basename "$cpu_dir" | sed 's/cpu//')
        local freq_path="${cpu_dir}/cpufreq"

        if [[ -d "$freq_path" ]]; then
            local gov cur_freq min_freq max_freq
            gov=$(cat "${freq_path}/scaling_governor" 2>/dev/null || echo "?")
            cur_freq=$(cat "${freq_path}/scaling_cur_freq" 2>/dev/null || echo "0")
            min_freq=$(cat "${freq_path}/scaling_min_freq" 2>/dev/null || echo "0")
            max_freq=$(cat "${freq_path}/scaling_max_freq" 2>/dev/null || echo "0")

            # Convert kHz to MHz
            cur_freq=$((cur_freq / 1000))
            min_freq=$((min_freq / 1000))
            max_freq=$((max_freq / 1000))

            printf "%-6s %-12s %-10s %-10s %s\n" \
                "cpu$cpu_num" "$gov" "${cur_freq}MHz" "${min_freq}MHz" "${max_freq}MHz"
        fi

        ((count++))
    done

    local total_cpus
    total_cpus=$(get_cpu_count)
    if [[ $total_cpus -gt 4 ]]; then
        echo "... and $((total_cpus - 4)) more CPUs"
    fi

    echo ""

    # Temperature (if available)
    if command -v sensors >/dev/null 2>&1; then
        echo "CPU Temperature:"
        sensors 2>/dev/null | grep -E "Core|Package|Tctl|Tdie" | head -5 || echo "  Not available"
        echo ""
    fi

    echo "========================================="
}

# Show brief CPU frequency status (one-liner)
get_cpu_status_brief() {
    local driver
    driver=$(get_cpu_driver)
    local governor
    governor=$(get_current_governor all)
    local turbo
    turbo=$(get_turbo_status)

    # Get current frequency of first CPU
    local cur_freq
    cur_freq=$(cat "${CPUFREQ_PATH}/cpu0/cpufreq/scaling_cur_freq" 2>/dev/null || echo "0")
    cur_freq=$((cur_freq / 1000))

    echo "Driver: $driver | Governor: $governor | Frequency: ${cur_freq}MHz | Turbo: $turbo"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Validate governor name
is_valid_governor() {
    local governor="$1"
    local available
    available=$(get_available_governors)

    echo "$available" | grep -qw "$governor"
}

# Get recommended settings for use case
get_recommended_settings() {
    local use_case="${1:-auto}"

    local governor
    governor=$(recommend_governor "$use_case")
    local epp="${_RECOMMENDED_EPP:-}"

    cat <<EOF
Recommended Settings for '$use_case':
  Governor: $governor
  EPP: ${epp:-not applicable}
  Turbo: $(if [[ "$use_case" == "laptop" ]]; then echo "optional (disable for better battery)"; else echo "enable"; fi)
EOF
}

# Apply recommended settings
apply_recommended_settings() {
    local use_case="${1:-auto}"
    local make_persistent="${2:-no}"

    log_info "Applying recommended settings for use case: $use_case"

    # Get recommendations
    local governor
    governor=$(recommend_governor "$use_case")
    local epp="${_RECOMMENDED_EPP:-}"

    # Apply governor
    if [[ "$make_persistent" == "yes" ]] || [[ "$make_persistent" == "true" ]]; then
        set_governor_persistent "$governor" "auto"
    else
        set_governor "$governor"
    fi

    # Apply EPP if recommended
    if [[ -n "$epp" ]]; then
        set_energy_preference "$epp" 2>/dev/null || log_debug "EPP not supported, skipping"
    fi

    # Turbo recommendations
    case "$use_case" in
        laptop)
            log_info "For better battery life, consider: set_turbo disable"
            ;;
        gaming|desktop|server)
            set_turbo enable 2>/dev/null || log_debug "Turbo control not supported"
            ;;
    esac

    log_success "Recommended settings applied"
    get_cpu_stats
}

# ============================================================================
# Module Information
# ============================================================================

# Display module help
cpu_governor_help() {
    cat <<'EOF'
CPU Governor Module - Help
==========================

DETECTION FUNCTIONS:
  check_cpufreq_support          - Check if CPU frequency scaling is available
  get_cpu_driver                 - Get the scaling driver (intel_pstate, amd-pstate, acpi-cpufreq)
  get_available_governors        - List available governors
  get_current_governor [CPU]     - Get current governor (CPU number or 'all')
  get_cpu_count                  - Get number of CPUs with frequency scaling

GOVERNOR MANAGEMENT:
  recommend_governor [USE_CASE]  - Recommend governor for use case
                                   Use cases: desktop, gaming, laptop, server, balanced, auto
  set_governor GOVERNOR          - Set governor for all CPUs (temporary)
  set_governor_persistent GOV    - Set governor and make persistent
                                   Methods: auto, systemd, tlp, cpufrequtils

FREQUENCY CONTROL:
  get_frequency_limits [CPU]     - Get min/max frequency limits
  set_frequency_limits MIN MAX   - Set frequency limits (in MHz)

ENERGY PREFERENCE (Intel/AMD pstate):
  get_energy_preference          - Get current EPP setting
  set_energy_preference EPP      - Set EPP (performance, balance_performance,
                                   default, balance_power, power)

TURBO BOOST:
  get_turbo_status               - Check if turbo/boost is enabled
  set_turbo <enable|disable>     - Enable/disable turbo boost

PERSISTENCE:
  create_cpupower_service GOV [MIN] [MAX] [EPP]
                                 - Create systemd service for persistence

STATUS:
  get_cpu_stats                  - Show comprehensive CPU frequency statistics
  get_cpu_status_brief           - Show one-line status summary
  get_recommended_settings USE   - Show recommended settings for use case
  apply_recommended_settings USE [PERSIST]
                                 - Apply recommended settings (PERSIST: yes/no)

EXAMPLES:
  # Auto-detect and apply recommended settings
  apply_recommended_settings auto yes

  # Gaming setup
  set_governor_persistent performance systemd
  set_energy_preference performance
  set_turbo enable

  # Laptop battery saving
  set_governor_persistent powersave systemd
  set_energy_preference balance_power
  set_turbo disable

  # View current status
  get_cpu_stats

NOTES:
  - Most operations require root privileges
  - Settings without persistence are lost on reboot
  - Drivers: intel_pstate (Intel), amd-pstate (AMD), acpi-cpufreq (legacy)
  - EPP requires HWP support (Intel 6th gen+, AMD Zen2+)

EOF
}

# ============================================================================
# Initialization
# ============================================================================

# Initialize module (run basic checks)
_cpu_governor_init() {
    log_debug "CPU Governor module loaded"

    # Pre-populate cache if CPU freq is available
    if check_cpufreq_support >/dev/null 2>&1; then
        get_cpu_driver >/dev/null 2>&1
        get_available_governors >/dev/null 2>&1
        get_cpu_count >/dev/null 2>&1
    fi
}

# Run initialization
_cpu_governor_init

# Export functions for external use
export -f check_cpufreq_support
export -f get_cpu_driver
export -f get_available_governors
export -f get_current_governor
export -f recommend_governor
export -f set_governor
export -f set_governor_persistent
export -f get_frequency_limits
export -f set_frequency_limits
export -f get_energy_preference
export -f set_energy_preference
export -f get_turbo_status
export -f set_turbo
export -f create_cpupower_service
export -f get_cpu_stats
export -f apply_recommended_settings
export -f cpu_governor_help
