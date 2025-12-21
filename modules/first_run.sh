#!/usr/bin/env bash
#
# first_run.sh - First Run Experience and Multi-Phase Execution
#
# Implements the automated first-run experience with multi-phase execution,
# reboot handling, and progress persistence across system restarts.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_FIRST_RUN_LOADED:-}" ]] && return 0
readonly _FIRST_RUN_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${LIB_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_section() { echo ""; echo "========================================"; echo "  $*"; echo "========================================"; }
    }
fi

# Source optional modules (with silent fallback)
source "${LIB_DIR}/tui.sh" 2>/dev/null || log_debug "tui.sh not available"
source "${LIB_DIR}/state.sh" 2>/dev/null || log_debug "state.sh not available"
source "${LIB_DIR}/autostart.sh" 2>/dev/null || log_debug "autostart.sh not available"
source "${LIB_DIR}/scan.sh" 2>/dev/null || log_debug "scan.sh not available"
source "${LIB_DIR}/tune.sh" 2>/dev/null || log_debug "tune.sh not available"
source "${LIB_DIR}/pkg_universal.sh" 2>/dev/null || log_debug "pkg_universal.sh not available"
source "${LIB_DIR}/utilities.sh" 2>/dev/null || log_debug "utilities.sh not available"
source "${LIB_DIR}/os_detect.sh" 2>/dev/null || log_debug "os_detect.sh not available"

# Run OS detection if function exists
if declare -f detect_os &>/dev/null; then
    detect_os 2>/dev/null || true
fi

# ============================================================================
# Global Variables
# ============================================================================

# State directories
declare -g FIRST_RUN_STATE_DIR="${HOME}/.local/state/ultimate-linux-suite"
declare -g FIRST_RUN_PHASE_FILE="${FIRST_RUN_STATE_DIR}/first_run_phase"
declare -g FIRST_RUN_LOG="${FIRST_RUN_STATE_DIR}/first_run.log"
declare -g FIRST_RUN_COMPLETE_FLAG="${FIRST_RUN_STATE_DIR}/.first_run_complete"

# Current script path (for resume)
declare -g FIRST_RUN_SCRIPT="${BASH_SOURCE[0]}"

# Phase definitions
declare -ga PHASES=(
    "INIT"
    "SCAN"
    "OPTIMIZE"
    "REBOOT_REQUIRED"
    "VERIFY"
    "PKG_MANAGERS"
    "UTILITIES"
    "REBOOT_OPTIONAL"
    "VERIFY_FINAL"
    "APPS_READY"
    "COMPLETE"
)

# Phase descriptions
declare -gA PHASE_DESCRIPTIONS=(
    [INIT]="Initializing first-run experience"
    [SCAN]="Scanning hardware and system"
    [OPTIMIZE]="Applying system optimizations"
    [REBOOT_REQUIRED]="Reboot required for changes"
    [VERIFY]="Verifying post-reboot state"
    [PKG_MANAGERS]="Installing package managers"
    [UTILITIES]="Installing essential utilities"
    [REBOOT_OPTIONAL]="Optional reboot available"
    [VERIFY_FINAL]="Final verification"
    [APPS_READY]="Ready for application installation"
    [COMPLETE]="First-run complete"
)

# Current phase index
declare -g CURRENT_PHASE_INDEX=0

# ============================================================================
# Initialization
# ============================================================================

_first_run_init() {
    mkdir -p "$FIRST_RUN_STATE_DIR" 2>/dev/null || log_warn "Cannot create state directory"
}

_first_run_init

# ============================================================================
# Phase Management
# ============================================================================

# Get current phase name
get_current_phase() {
    if [[ -f "$FIRST_RUN_PHASE_FILE" ]]; then
        cat "$FIRST_RUN_PHASE_FILE"
    else
        echo "INIT"
    fi
}

# Get phase index by name
get_phase_index() {
    local phase_name="$1"
    local index=0

    for phase in "${PHASES[@]}"; do
        if [[ "$phase" == "$phase_name" ]]; then
            echo "$index"
            return 0
        fi
        ((index++))
    done

    echo "-1"
    return 1
}

# Save current phase
save_phase() {
    local phase="$1"
    echo "$phase" > "$FIRST_RUN_PHASE_FILE"
    CURRENT_PHASE_INDEX=$(get_phase_index "$phase")
    log_debug "Phase saved: $phase (index: $CURRENT_PHASE_INDEX)"

    # Log to first run log
    echo "$(date '+%Y-%m-%d %H:%M:%S') Phase: $phase" >> "$FIRST_RUN_LOG"
}

# Advance to next phase
advance_phase() {
    local current
    current=$(get_current_phase)
    local current_index
    current_index=$(get_phase_index "$current")
    local next_index=$((current_index + 1))

    if [[ $next_index -lt ${#PHASES[@]} ]]; then
        local next_phase="${PHASES[$next_index]}"
        save_phase "$next_phase"
        log_info "Advanced to phase: $next_phase"
        return 0
    else
        log_info "Already at final phase"
        return 1
    fi
}

# Check if first run is complete
is_first_run_complete() {
    [[ -f "$FIRST_RUN_COMPLETE_FLAG" ]]
}

# Mark first run as complete
mark_first_run_complete() {
    touch "$FIRST_RUN_COMPLETE_FLAG"
    save_phase "COMPLETE"
    log_success "First run marked as complete"
}

# Reset first run state
reset_first_run() {
    rm -f "$FIRST_RUN_PHASE_FILE"
    rm -f "$FIRST_RUN_COMPLETE_FLAG"
    rm -f "$FIRST_RUN_LOG"
    log_info "First run state reset"
}

# ============================================================================
# Phase Execution Functions
# ============================================================================

# Phase 0: INIT
phase_init() {
    log_section "Phase: INIT"
    log_info "${PHASE_DESCRIPTIONS[INIT]}"

    # Display welcome message
    echo ""
    echo "========================================"
    echo "  Ultimate Linux Suite - First Run"
    echo "========================================"
    echo ""
    echo "This wizard will:"
    echo "  1. Scan your hardware"
    echo "  2. Apply system optimizations"
    echo "  3. Install package managers"
    echo "  4. Install essential utilities"
    echo ""
    echo "Some phases may require a reboot."
    echo "The wizard will resume automatically."
    echo ""

    # Check prerequisites
    log_info "Checking prerequisites..."

    # Verify we can write to config directories
    if ! mkdir -p "${HOME}/.config" 2>/dev/null; then
        log_error "Cannot write to ~/.config"
        return 1
    fi

    # Check for root/sudo access
    if ! sudo -n true 2>/dev/null; then
        log_warn "Sudo access may be required for some operations"
        echo ""
        echo "Please enter your password if prompted:"
        if ! sudo true; then
            log_error "Cannot obtain sudo access"
            return 1
        fi
    fi

    log_success "Prerequisites check passed"
    advance_phase
    return 0
}

# Phase 1: SCAN
phase_scan() {
    log_section "Phase: SCAN"
    log_info "${PHASE_DESCRIPTIONS[SCAN]}"

    # Run hardware scan
    if type perform_full_scan &>/dev/null; then
        log_info "Performing full hardware scan..."
        perform_full_scan || log_warn "Some scan operations failed"
    else
        log_warn "Full scan not available, running basic detection..."

        # Basic hardware info
        log_info "CPU: $(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)"
        log_info "RAM: $(free -h 2>/dev/null | awk '/^Mem:/{print $2}')"
        log_info "Kernel: $(uname -r)"
    fi

    # Detect OS
    if type detect_os &>/dev/null; then
        detect_os
        log_info "Detected OS: ${OS_NAME:-Unknown} (${OS_FAMILY:-unknown})"
    fi

    advance_phase
    return 0
}

# Phase 2: OPTIMIZE
phase_optimize() {
    log_section "Phase: OPTIMIZE"
    log_info "${PHASE_DESCRIPTIONS[OPTIMIZE]}"

    local changes_made=0

    # Apply sysctl optimizations
    if type tune_generate_sysctl &>/dev/null; then
        log_info "Generating sysctl configuration..."
        if tune_generate_sysctl "balanced"; then
            ((changes_made++))
        fi
    fi

    # Configure ZRAM
    if type zram_configure &>/dev/null; then
        log_info "Configuring ZRAM..."
        if zram_configure; then
            ((changes_made++))
        fi
    fi

    # Configure I/O scheduler
    if type io_scheduler_configure &>/dev/null; then
        log_info "Configuring I/O scheduler..."
        if io_scheduler_configure; then
            ((changes_made++))
        fi
    fi

    # Configure CPU governor
    if type cpu_governor_set &>/dev/null; then
        log_info "Configuring CPU governor..."
        if cpu_governor_set "schedutil"; then
            ((changes_made++))
        fi
    fi

    if [[ $changes_made -gt 0 ]]; then
        log_success "Applied $changes_made optimizations"
        advance_phase  # Goes to REBOOT_REQUIRED
    else
        log_info "No optimizations applied"
        save_phase "VERIFY"  # Skip reboot
    fi

    return 0
}

# Phase 3: REBOOT_REQUIRED
phase_reboot_required() {
    log_section "Phase: REBOOT_REQUIRED"
    log_info "${PHASE_DESCRIPTIONS[REBOOT_REQUIRED]}"

    echo ""
    echo "A system reboot is required to apply optimizations."
    echo ""
    echo "Options:"
    echo "  1) Reboot now (recommended)"
    echo "  2) Continue without reboot"
    echo "  3) Reboot later (exit wizard)"
    echo ""

    # Setup resume for after reboot
    if type setup_resume_system &>/dev/null; then
        local script_path
        script_path=$(readlink -f "${BASH_SOURCE[0]}")
        # Will resume at VERIFY phase
        save_phase "VERIFY"
        setup_resume_system "$script_path" "VERIFY"
    fi

    # Ask user
    local choice
    read -r -p "Enter choice [1-3]: " choice

    case "$choice" in
        1)
            log_info "Initiating reboot..."
            autostart_save_boot_id 2>/dev/null || true
            echo ""
            echo "The system will reboot in 5 seconds..."
            echo "The wizard will resume automatically after login."
            sleep 5
            sudo reboot
            ;;
        2)
            log_warn "Continuing without reboot - some changes may not take effect"
            advance_phase
            ;;
        3)
            log_info "Exiting wizard. Run again to continue."
            exit 0
            ;;
        *)
            log_warn "Invalid choice, continuing without reboot"
            advance_phase
            ;;
    esac

    return 0
}

# Phase 4: VERIFY
phase_verify() {
    log_section "Phase: VERIFY"
    log_info "${PHASE_DESCRIPTIONS[VERIFY]}"

    # Check if we're resuming after reboot
    if type check_reboot_occurred &>/dev/null; then
        if check_reboot_occurred; then
            log_success "Reboot detected - resuming wizard"

            # Update boot ID
            autostart_save_boot_id 2>/dev/null || true
        fi
    fi

    # Verify optimizations are active
    log_info "Verifying system state..."

    # Check sysctl settings
    local swappiness
    swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    log_info "Current swappiness: $swappiness"

    # Check ZRAM
    if [[ -e /dev/zram0 ]]; then
        log_success "ZRAM is active"
    else
        log_debug "ZRAM not active"
    fi

    # Check I/O scheduler
    if [[ -f /sys/block/sda/queue/scheduler ]]; then
        log_info "I/O scheduler: $(cat /sys/block/sda/queue/scheduler 2>/dev/null)"
    fi

    log_success "Verification complete"
    advance_phase
    return 0
}

# Phase 5: PKG_MANAGERS
phase_pkg_managers() {
    log_section "Phase: PKG_MANAGERS"
    log_info "${PHASE_DESCRIPTIONS[PKG_MANAGERS]}"

    echo ""
    echo "Installing universal package managers..."
    echo ""

    local installed=0

    # Install Flatpak
    if type universal_install_flatpak &>/dev/null; then
        log_info "Installing Flatpak..."
        if universal_install_flatpak; then
            ((installed++))
        fi
    fi

    # Ask about Snap (optional on some systems)
    echo ""
    read -r -p "Install Snap package manager? [y/N]: " snap_choice
    if [[ "$snap_choice" =~ ^[Yy] ]]; then
        if type universal_install_snap &>/dev/null; then
            log_info "Installing Snap..."
            if universal_install_snap; then
                ((installed++))
            fi
        fi
    fi

    # Ask about Nix (optional, advanced)
    echo ""
    read -r -p "Install Nix package manager? [y/N]: " nix_choice
    if [[ "$nix_choice" =~ ^[Yy] ]]; then
        if type universal_install_nix &>/dev/null; then
            log_info "Installing Nix..."
            if universal_install_nix; then
                ((installed++))
            fi
        fi
    fi

    # AppImage support
    if type universal_install_appimage_support &>/dev/null; then
        log_info "Setting up AppImage support..."
        universal_install_appimage_support || true
    fi

    log_success "Installed $installed package manager(s)"
    advance_phase
    return 0
}

# Phase 6: UTILITIES
phase_utilities() {
    log_section "Phase: UTILITIES"
    log_info "${PHASE_DESCRIPTIONS[UTILITIES]}"

    echo ""
    echo "Installing essential utilities..."
    echo ""

    # Install essential utilities
    if type util_install_essentials &>/dev/null; then
        util_install_essentials
    else
        log_warn "Utilities module not available"
    fi

    # Offer additional utility categories
    echo ""
    read -r -p "Install modern CLI tools (fd, ripgrep, bat, etc.)? [Y/n]: " modern_choice
    if [[ ! "$modern_choice" =~ ^[Nn] ]]; then
        if type util_install_modern_cli &>/dev/null; then
            util_install_modern_cli
        fi
    fi

    advance_phase
    return 0
}

# Phase 7: REBOOT_OPTIONAL
phase_reboot_optional() {
    log_section "Phase: REBOOT_OPTIONAL"
    log_info "${PHASE_DESCRIPTIONS[REBOOT_OPTIONAL]}"

    echo ""
    echo "All essential setup is complete."
    echo ""
    echo "A reboot is recommended but not required."
    echo ""

    read -r -p "Reboot now? [y/N]: " reboot_choice

    if [[ "$reboot_choice" =~ ^[Yy] ]]; then
        # Setup resume
        save_phase "VERIFY_FINAL"
        if type setup_resume_system &>/dev/null; then
            local script_path
            script_path=$(readlink -f "${BASH_SOURCE[0]}")
            setup_resume_system "$script_path" "VERIFY_FINAL"
        fi

        log_info "Rebooting..."
        sudo reboot
    else
        advance_phase
    fi

    return 0
}

# Phase 8: VERIFY_FINAL
phase_verify_final() {
    log_section "Phase: VERIFY_FINAL"
    log_info "${PHASE_DESCRIPTIONS[VERIFY_FINAL]}"

    # Final system verification
    log_info "Running final verification..."

    # Package manager status
    if type universal_status &>/dev/null; then
        universal_status
    fi

    # Utility check
    if type util_check &>/dev/null; then
        util_check git curl wget vim 2>/dev/null || true
    fi

    log_success "Final verification complete"
    advance_phase
    return 0
}

# Phase 9: APPS_READY
phase_apps_ready() {
    log_section "Phase: APPS_READY"
    log_info "${PHASE_DESCRIPTIONS[APPS_READY]}"

    echo ""
    echo "========================================"
    echo "  System is ready for applications!"
    echo "========================================"
    echo ""
    echo "Your system has been optimized and"
    echo "package managers are installed."
    echo ""
    echo "You can now use the main menu to:"
    echo "  - Install applications"
    echo "  - Configure additional settings"
    echo "  - Manage system services"
    echo ""

    # Cleanup resume system
    if type cleanup_resume_system &>/dev/null; then
        cleanup_resume_system
    fi

    advance_phase
    return 0
}

# Phase 10: COMPLETE
phase_complete() {
    log_section "Phase: COMPLETE"
    log_info "${PHASE_DESCRIPTIONS[COMPLETE]}"

    mark_first_run_complete

    echo ""
    log_success "First-run experience complete!"
    echo ""
    echo "You can now use Ultimate Linux Suite normally."
    echo ""

    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

# Execute current phase
execute_current_phase() {
    local phase
    phase=$(get_current_phase)

    log_debug "Executing phase: $phase"

    case "$phase" in
        INIT)           phase_init ;;
        SCAN)           phase_scan ;;
        OPTIMIZE)       phase_optimize ;;
        REBOOT_REQUIRED) phase_reboot_required ;;
        VERIFY)         phase_verify ;;
        PKG_MANAGERS)   phase_pkg_managers ;;
        UTILITIES)      phase_utilities ;;
        REBOOT_OPTIONAL) phase_reboot_optional ;;
        VERIFY_FINAL)   phase_verify_final ;;
        APPS_READY)     phase_apps_ready ;;
        COMPLETE)       phase_complete ;;
        *)
            log_error "Unknown phase: $phase"
            return 1
            ;;
    esac
}

# Run all phases from current to completion
run_first_run() {
    local start_phase="${1:-}"

    # Start from specified phase if provided
    if [[ -n "$start_phase" ]]; then
        save_phase "$start_phase"
    fi

    log_section "Starting First-Run Experience"

    # Run phases until complete
    while true; do
        local current_phase
        current_phase=$(get_current_phase)

        if [[ "$current_phase" == "COMPLETE" ]]; then
            log_success "First-run experience finished"
            break
        fi

        if ! execute_current_phase; then
            log_error "Phase failed: $current_phase"
            return 1
        fi
    done

    return 0
}

# Resume from a specific phase
resume_first_run() {
    local resume_phase="${1:-}"

    if [[ -z "$resume_phase" ]]; then
        resume_phase=$(get_current_phase)
    fi

    log_info "Resuming first-run from phase: $resume_phase"
    save_phase "$resume_phase"
    run_first_run
}

# Show first-run status
first_run_status() {
    log_section "First-Run Status"

    if is_first_run_complete; then
        echo "Status: Complete"
        echo "Completed on: $(stat -c %y "$FIRST_RUN_COMPLETE_FLAG" 2>/dev/null | cut -d. -f1)"
    else
        local current_phase
        current_phase=$(get_current_phase)
        local index
        index=$(get_phase_index "$current_phase")

        echo "Status: In Progress"
        echo "Current phase: $current_phase (${index}/${#PHASES[@]})"
        echo "Description: ${PHASE_DESCRIPTIONS[$current_phase]}"
    fi

    echo ""
    echo "Phase progression:"
    local i=0
    for phase in "${PHASES[@]}"; do
        local status="[ ]"
        local current_index
        current_index=$(get_phase_index "$(get_current_phase)")

        if [[ $i -lt $current_index ]]; then
            status="[x]"
        elif [[ $i -eq $current_index ]]; then
            status="[>]"
        fi

        printf "  %s %s - %s\n" "$status" "$phase" "${PHASE_DESCRIPTIONS[$phase]}"
        ((i++))
    done
}

# ============================================================================
# Entry Point
# ============================================================================

# Handle command line arguments
first_run_main() {
    case "${1:-}" in
        --status)
            first_run_status
            ;;
        --reset)
            reset_first_run
            ;;
        --resume)
            resume_first_run "${2:-}"
            ;;
        --phase)
            if [[ -n "${2:-}" ]]; then
                save_phase "$2"
                execute_current_phase
            else
                echo "Usage: $0 --phase PHASE_NAME"
            fi
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --status    Show current first-run status"
            echo "  --reset     Reset first-run state"
            echo "  --resume    Resume from current or specified phase"
            echo "  --phase X   Execute specific phase"
            echo "  --help      Show this help"
            echo ""
            echo "Without options, starts/continues the first-run experience."
            ;;
        *)
            # Check if already complete
            if is_first_run_complete; then
                echo "First-run experience is already complete."
                echo ""
                read -r -p "Run again? [y/N]: " choice
                if [[ "$choice" =~ ^[Yy] ]]; then
                    reset_first_run
                    run_first_run
                fi
            else
                run_first_run
            fi
            ;;
    esac
}

# ============================================================================
# USAGE DOCUMENTATION
# ============================================================================
#
# FIRST_RUN.SH - First Run Experience
# ====================================
#
# STARTING FIRST RUN:
#
#   # Run first-run experience
#   ./modules/first_run.sh
#
#   # Or source and call
#   source modules/first_run.sh
#   run_first_run
#
# STATUS AND CONTROL:
#
#   # Check status
#   ./modules/first_run.sh --status
#
#   # Reset to start over
#   ./modules/first_run.sh --reset
#
#   # Resume from current phase
#   ./modules/first_run.sh --resume
#
#   # Resume from specific phase
#   ./modules/first_run.sh --resume SCAN
#
#   # Execute single phase
#   ./modules/first_run.sh --phase PKG_MANAGERS
#
# PHASES:
#
#   0. INIT            - Initialize and check prerequisites
#   1. SCAN            - Hardware and system detection
#   2. OPTIMIZE        - Apply system optimizations
#   3. REBOOT_REQUIRED - Prompt for reboot
#   4. VERIFY          - Post-reboot verification
#   5. PKG_MANAGERS    - Install package managers
#   6. UTILITIES       - Install essential utilities
#   7. REBOOT_OPTIONAL - Offer optional reboot
#   8. VERIFY_FINAL    - Final system verification
#   9. APPS_READY      - System ready notification
#  10. COMPLETE        - Mark as complete
#
# AUTO-RESUME:
#
#   The wizard automatically sets up resume after reboot.
#   It will restart where it left off after login.
#
# ============================================================================

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    first_run_main "$@"
fi
