#!/usr/bin/env bash
#
# autostart.sh - Autostart and Multi-Phase Resume System
#
# Manages automatic startup entries for resuming multi-phase operations
# across reboots. Supports systemd user services and XDG autostart.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_AUTOSTART_LOADED:-}" ]] && return 0
readonly _AUTOSTART_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_section() { echo ""; echo "=== $* ==="; }
    }
fi

# ============================================================================
# Global Variables
# ============================================================================

# Autostart directories
declare -g AUTOSTART_XDG_DIR="${HOME}/.config/autostart"
declare -g AUTOSTART_SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
declare -g AUTOSTART_STATE_DIR="${HOME}/.local/state/ultimate-linux-suite"

# Boot ID tracking
declare -g AUTOSTART_BOOT_ID_FILE="${AUTOSTART_STATE_DIR}/boot_id"
declare -g AUTOSTART_LAST_BOOT_ID=""
declare -g AUTOSTART_CURRENT_BOOT_ID=""

# Service/entry names
declare -g AUTOSTART_SERVICE_NAME="ultimate-linux-suite-resume"
declare -g AUTOSTART_DESKTOP_NAME="ultimate-linux-suite-resume"

# ============================================================================
# Initialization
# ============================================================================

_autostart_init() {
    mkdir -p "$AUTOSTART_XDG_DIR" 2>/dev/null || log_warn "Cannot create XDG autostart directory"
    mkdir -p "$AUTOSTART_SYSTEMD_USER_DIR" 2>/dev/null || log_warn "Cannot create systemd user directory"
    mkdir -p "$AUTOSTART_STATE_DIR" 2>/dev/null || log_warn "Cannot create state directory"

    # Read current boot ID
    if [[ -f /proc/sys/kernel/random/boot_id ]]; then
        AUTOSTART_CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
    elif command -v journalctl &>/dev/null; then
        AUTOSTART_CURRENT_BOOT_ID=$(journalctl --list-boots -1 2>/dev/null | awk '{print $2}')
    fi

    # Read last boot ID
    if [[ -f "$AUTOSTART_BOOT_ID_FILE" ]]; then
        AUTOSTART_LAST_BOOT_ID=$(cat "$AUTOSTART_BOOT_ID_FILE" 2>/dev/null)
    fi
}

_autostart_init

# ============================================================================
# Boot ID Management
# ============================================================================

# Save current boot ID
autostart_save_boot_id() {
    if [[ -n "$AUTOSTART_CURRENT_BOOT_ID" ]]; then
        echo "$AUTOSTART_CURRENT_BOOT_ID" > "$AUTOSTART_BOOT_ID_FILE"
        log_debug "Saved boot ID: $AUTOSTART_CURRENT_BOOT_ID"
    fi
}

# Check if reboot occurred since last save
check_reboot_occurred() {
    # No previous boot ID means first run
    if [[ -z "$AUTOSTART_LAST_BOOT_ID" ]]; then
        log_debug "No previous boot ID found (first run or never saved)"
        return 1  # No reboot detected (or first run)
    fi

    # No current boot ID means we can't determine
    if [[ -z "$AUTOSTART_CURRENT_BOOT_ID" ]]; then
        log_debug "Cannot determine current boot ID"
        return 1
    fi

    # Compare boot IDs
    if [[ "$AUTOSTART_CURRENT_BOOT_ID" != "$AUTOSTART_LAST_BOOT_ID" ]]; then
        log_info "Reboot detected (Boot ID changed)"
        log_debug "Previous: $AUTOSTART_LAST_BOOT_ID"
        log_debug "Current: $AUTOSTART_CURRENT_BOOT_ID"
        return 0  # Reboot occurred
    fi

    log_debug "No reboot detected (same boot session)"
    return 1  # No reboot
}

# Get time since last boot
get_uptime() {
    if [[ -f /proc/uptime ]]; then
        local uptime_seconds
        uptime_seconds=$(cut -d. -f1 /proc/uptime)
        local days=$((uptime_seconds / 86400))
        local hours=$(((uptime_seconds % 86400) / 3600))
        local minutes=$(((uptime_seconds % 3600) / 60))
        echo "${days}d ${hours}h ${minutes}m"
    else
        echo "unknown"
    fi
}

# ============================================================================
# Systemd Detection
# ============================================================================

# Check if running under systemd
is_systemd() {
    [[ -d /run/systemd/system ]] || \
    [[ "$(cat /proc/1/comm 2>/dev/null)" == "systemd" ]]
}

# Check if systemd user service support is available
has_systemd_user() {
    is_systemd && [[ -n "$XDG_RUNTIME_DIR" ]] && [[ -d "$XDG_RUNTIME_DIR" ]]
}

# ============================================================================
# Systemd User Service Management
# ============================================================================

# Create systemd user service for resume
create_systemd_service() {
    local exec_command="$1"
    local description="${2:-Ultimate Linux Suite Resume Service}"

    if [[ -z "$exec_command" ]]; then
        log_error "Usage: create_systemd_service EXEC_COMMAND [DESCRIPTION]"
        return 1
    fi

    local service_file="${AUTOSTART_SYSTEMD_USER_DIR}/${AUTOSTART_SERVICE_NAME}.service"

    log_info "Creating systemd user service: $AUTOSTART_SERVICE_NAME"

    cat > "$service_file" <<EOF
[Unit]
Description=${description}
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=${exec_command}
RemainAfterExit=no

# Environment
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=%t

# Timeout
TimeoutStartSec=300

[Install]
WantedBy=default.target
EOF

    if [[ -f "$service_file" ]]; then
        log_success "Created service: $service_file"

        # Reload systemd user daemon
        systemctl --user daemon-reload 2>/dev/null || true

        return 0
    else
        log_error "Failed to create service file"
        return 1
    fi
}

# Enable systemd user service
enable_systemd_service() {
    if ! has_systemd_user; then
        log_warn "Systemd user services not available"
        return 1
    fi

    log_info "Enabling systemd user service: $AUTOSTART_SERVICE_NAME"

    if systemctl --user enable "$AUTOSTART_SERVICE_NAME" 2>/dev/null; then
        log_success "Service enabled"
        return 0
    else
        log_error "Failed to enable service"
        return 1
    fi
}

# Disable systemd user service
disable_systemd_service() {
    if ! has_systemd_user; then
        return 0  # Nothing to disable
    fi

    log_info "Disabling systemd user service: $AUTOSTART_SERVICE_NAME"

    systemctl --user disable "$AUTOSTART_SERVICE_NAME" 2>/dev/null || true
    systemctl --user stop "$AUTOSTART_SERVICE_NAME" 2>/dev/null || true

    log_success "Service disabled"
}

# Remove systemd user service
remove_systemd_service() {
    local service_file="${AUTOSTART_SYSTEMD_USER_DIR}/${AUTOSTART_SERVICE_NAME}.service"

    if [[ -f "$service_file" ]]; then
        disable_systemd_service
        rm -f "$service_file"
        systemctl --user daemon-reload 2>/dev/null || true
        log_success "Removed systemd service"
    fi
}

# Check if systemd service exists and is enabled
is_systemd_service_enabled() {
    has_systemd_user && \
    systemctl --user is-enabled "$AUTOSTART_SERVICE_NAME" &>/dev/null
}

# ============================================================================
# XDG Autostart Management
# ============================================================================

# Create XDG desktop autostart entry
create_xdg_autostart() {
    local exec_command="$1"
    local name="${2:-Ultimate Linux Suite}"
    local comment="${3:-Resume interrupted operations}"

    if [[ -z "$exec_command" ]]; then
        log_error "Usage: create_xdg_autostart EXEC_COMMAND [NAME] [COMMENT]"
        return 1
    fi

    local desktop_file="${AUTOSTART_XDG_DIR}/${AUTOSTART_DESKTOP_NAME}.desktop"

    log_info "Creating XDG autostart entry: $AUTOSTART_DESKTOP_NAME"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Comment=${comment}
Exec=${exec_command}
Icon=system-software-update
Terminal=false
Categories=System;
StartupNotify=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
NoDisplay=true
EOF

    chmod +x "$desktop_file" 2>/dev/null

    if [[ -f "$desktop_file" ]]; then
        log_success "Created autostart entry: $desktop_file"
        return 0
    else
        log_error "Failed to create autostart entry"
        return 1
    fi
}

# Remove XDG autostart entry
remove_xdg_autostart() {
    local desktop_file="${AUTOSTART_XDG_DIR}/${AUTOSTART_DESKTOP_NAME}.desktop"

    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
        log_success "Removed autostart entry"
    fi
}

# Check if XDG autostart entry exists
has_xdg_autostart() {
    [[ -f "${AUTOSTART_XDG_DIR}/${AUTOSTART_DESKTOP_NAME}.desktop" ]]
}

# ============================================================================
# Unified Autostart API
# ============================================================================

# Create autostart entry (tries systemd first, falls back to XDG)
create_autostart() {
    local exec_command="$1"
    local description="${2:-Ultimate Linux Suite Resume}"

    if [[ -z "$exec_command" ]]; then
        log_error "Usage: create_autostart EXEC_COMMAND [DESCRIPTION]"
        return 1
    fi

    log_info "Setting up autostart for resume..."

    # Try systemd user service first
    if has_systemd_user; then
        if create_systemd_service "$exec_command" "$description"; then
            if enable_systemd_service; then
                log_success "Autostart configured via systemd"
                return 0
            fi
        fi
        log_warn "Systemd service setup failed, falling back to XDG"
    fi

    # Fall back to XDG autostart
    if create_xdg_autostart "$exec_command" "$description"; then
        log_success "Autostart configured via XDG"
        return 0
    fi

    log_error "Failed to configure autostart"
    return 1
}

# Remove all autostart entries
remove_autostart() {
    log_info "Removing autostart entries..."

    remove_systemd_service
    remove_xdg_autostart

    log_success "Autostart entries removed"
}

# Check if any autostart is configured
has_autostart() {
    is_systemd_service_enabled || has_xdg_autostart
}

# ============================================================================
# Linger Support (for systemd user services without login)
# ============================================================================

# Enable lingering for current user
enable_linger() {
    if ! is_systemd; then
        log_warn "Lingering only available with systemd"
        return 1
    fi

    log_info "Enabling systemd linger for user: $USER"

    if loginctl enable-linger "$USER" 2>/dev/null; then
        log_success "Linger enabled"
        return 0
    else
        log_warn "Failed to enable linger (may require root)"
        return 1
    fi
}

# Disable lingering
disable_linger() {
    if ! is_systemd; then
        return 0
    fi

    loginctl disable-linger "$USER" 2>/dev/null || true
    log_info "Linger disabled"
}

# Check if lingering is enabled
is_linger_enabled() {
    is_systemd && [[ -f "/var/lib/systemd/linger/$USER" ]]
}

# ============================================================================
# One-shot Resume Script Generation
# ============================================================================

# Generate a resume script
generate_resume_script() {
    local target_script="$1"
    local phase="${2:-}"
    local resume_script="${AUTOSTART_STATE_DIR}/resume.sh"

    if [[ -z "$target_script" ]]; then
        log_error "Usage: generate_resume_script TARGET_SCRIPT [PHASE]"
        return 1
    fi

    log_info "Generating resume script..."

    cat > "$resume_script" <<EOF
#!/usr/bin/env bash
#
# Auto-generated resume script for Ultimate Linux Suite
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
#

# Wait for desktop to be ready
sleep 5

# Check if we should resume
PHASE_FILE="${AUTOSTART_STATE_DIR}/current_phase"
if [[ ! -f "\$PHASE_FILE" ]]; then
    echo "No phase file found, nothing to resume"
    exit 0
fi

CURRENT_PHASE=\$(cat "\$PHASE_FILE")
echo "Resuming from phase: \$CURRENT_PHASE"

# Launch in terminal if available
if command -v gnome-terminal &>/dev/null; then
    gnome-terminal -- bash -c "${target_script} --resume \$CURRENT_PHASE; exec bash"
elif command -v konsole &>/dev/null; then
    konsole -e bash -c "${target_script} --resume \$CURRENT_PHASE; exec bash"
elif command -v xfce4-terminal &>/dev/null; then
    xfce4-terminal -e "bash -c '${target_script} --resume \$CURRENT_PHASE; exec bash'"
elif command -v xterm &>/dev/null; then
    xterm -e "bash -c '${target_script} --resume \$CURRENT_PHASE; exec bash'"
else
    # No terminal, run directly
    ${target_script} --resume \$CURRENT_PHASE
fi
EOF

    chmod +x "$resume_script"

    if [[ -f "$resume_script" ]]; then
        log_success "Resume script created: $resume_script"
        echo "$resume_script"
        return 0
    else
        log_error "Failed to create resume script"
        return 1
    fi
}

# ============================================================================
# Phase Tracking
# ============================================================================

# Save current phase
save_phase() {
    local phase="$1"

    if [[ -z "$phase" ]]; then
        log_error "Usage: save_phase PHASE"
        return 1
    fi

    local phase_file="${AUTOSTART_STATE_DIR}/current_phase"
    echo "$phase" > "$phase_file"
    log_debug "Saved phase: $phase"
}

# Get current phase
get_phase() {
    local phase_file="${AUTOSTART_STATE_DIR}/current_phase"

    if [[ -f "$phase_file" ]]; then
        cat "$phase_file"
    else
        echo ""
    fi
}

# Clear phase (mark as complete)
clear_phase() {
    local phase_file="${AUTOSTART_STATE_DIR}/current_phase"
    rm -f "$phase_file"
    log_debug "Phase cleared"
}

# Check if a phase is pending
has_pending_phase() {
    local phase_file="${AUTOSTART_STATE_DIR}/current_phase"
    [[ -f "$phase_file" ]] && [[ -s "$phase_file" ]]
}

# ============================================================================
# Complete Resume Setup
# ============================================================================

# Setup complete resume system
setup_resume_system() {
    local target_script="$1"
    local initial_phase="${2:-1}"

    if [[ -z "$target_script" ]]; then
        log_error "Usage: setup_resume_system TARGET_SCRIPT [INITIAL_PHASE]"
        return 1
    fi

    log_section "Setting Up Resume System"

    # Generate resume script
    local resume_script
    resume_script=$(generate_resume_script "$target_script")

    if [[ -z "$resume_script" ]]; then
        log_error "Failed to generate resume script"
        return 1
    fi

    # Create autostart entry
    if ! create_autostart "$resume_script" "Ultimate Linux Suite Resume"; then
        log_error "Failed to create autostart"
        return 1
    fi

    # Save initial phase
    save_phase "$initial_phase"

    # Save boot ID
    autostart_save_boot_id

    log_success "Resume system configured"
    log_info "Script will resume from phase $initial_phase after reboot"

    return 0
}

# Clean up resume system
cleanup_resume_system() {
    log_section "Cleaning Up Resume System"

    remove_autostart
    clear_phase

    local resume_script="${AUTOSTART_STATE_DIR}/resume.sh"
    rm -f "$resume_script"

    log_success "Resume system cleaned up"
}

# ============================================================================
# Status and Diagnostics
# ============================================================================

# Show autostart status
autostart_status() {
    log_section "Autostart Status"

    echo "System type: $(is_systemd && echo "systemd" || echo "non-systemd")"
    echo "User services available: $(has_systemd_user && echo "yes" || echo "no")"
    echo "Linger enabled: $(is_linger_enabled && echo "yes" || echo "no")"
    echo ""

    echo "Autostart entries:"
    echo "  Systemd service: $(is_systemd_service_enabled && echo "enabled" || echo "not configured")"
    echo "  XDG autostart: $(has_xdg_autostart && echo "configured" || echo "not configured")"
    echo ""

    echo "Current boot ID: ${AUTOSTART_CURRENT_BOOT_ID:-unknown}"
    echo "Last saved boot ID: ${AUTOSTART_LAST_BOOT_ID:-none}"
    echo "Uptime: $(get_uptime)"
    echo ""

    if has_pending_phase; then
        echo "Pending phase: $(get_phase)"
    else
        echo "No pending phase"
    fi
}

# ============================================================================
# USAGE DOCUMENTATION
# ============================================================================
#
# AUTOSTART.SH - Autostart and Resume Management
# ===============================================
#
# BOOT ID TRACKING:
#
#   # Check if reboot occurred
#   if check_reboot_occurred; then
#       echo "System was rebooted"
#   fi
#
#   # Save current boot ID
#   autostart_save_boot_id
#
#   # Get uptime
#   get_uptime
#
# AUTOSTART MANAGEMENT:
#
#   # Create autostart (auto-selects best method)
#   create_autostart "/path/to/script.sh" "Description"
#
#   # Check if autostart is configured
#   has_autostart && echo "Configured"
#
#   # Remove autostart
#   remove_autostart
#
# SYSTEMD USER SERVICES:
#
#   # Check if available
#   has_systemd_user && echo "Available"
#
#   # Create service
#   create_systemd_service "/path/to/script.sh" "Description"
#
#   # Enable/disable
#   enable_systemd_service
#   disable_systemd_service
#
#   # Remove
#   remove_systemd_service
#
# XDG AUTOSTART:
#
#   # Create entry
#   create_xdg_autostart "/path/to/script.sh" "Name" "Comment"
#
#   # Check/remove
#   has_xdg_autostart && echo "Exists"
#   remove_xdg_autostart
#
# LINGER (for background services):
#
#   enable_linger
#   disable_linger
#   is_linger_enabled && echo "Enabled"
#
# PHASE TRACKING:
#
#   # Save current phase
#   save_phase "3"
#
#   # Get phase
#   phase=$(get_phase)
#
#   # Clear phase
#   clear_phase
#
#   # Check for pending
#   has_pending_phase && echo "Phase pending"
#
# COMPLETE RESUME SETUP:
#
#   # Setup resume system
#   setup_resume_system "/path/to/ultimate.sh" "1"
#
#   # Cleanup when done
#   cleanup_resume_system
#
# STATUS:
#
#   autostart_status
#
# ============================================================================
