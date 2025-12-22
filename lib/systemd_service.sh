#!/usr/bin/env bash
#
# systemd_service.sh - System-Level Systemd Service Management
#
# Manages the system-level oneshot service for multi-stage installation
# that persists across reboots. This is the ROOT service, not user-level.
#
# Based on patterns from Anaconda and Calamares installers.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_SYSTEMD_SERVICE_LOADED:-}" ]] && return 0
readonly _SYSTEMD_SERVICE_LOADED=1

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
    }
fi

# ============================================================================
# Configuration
# ============================================================================

# System paths (root level)
declare -gr SYSTEMD_SERVICE_DIR="/etc/systemd/system"
declare -gr SUITE_SERVICE_NAME="linux-suite.service"
declare -gr SUITE_SERVICE_FILE="${SYSTEMD_SERVICE_DIR}/${SUITE_SERVICE_NAME}"

# State directory (root level for system service)
declare -gr SUITE_STATE_DIR="/var/lib/linux-suite"
declare -gr SUITE_STATE_FILE="${SUITE_STATE_DIR}/state.json"
declare -gr SUITE_COMPLETE_FLAG="${SUITE_STATE_DIR}/installation_complete"
declare -gr SUITE_LOG_DIR="${SUITE_STATE_DIR}/logs"

# Installation directory
declare -gr SUITE_INSTALL_DIR="/opt/linux-suite"
declare -gr SUITE_STAGE_RUNNER="${SUITE_INSTALL_DIR}/run-stage.sh"

# Retry limits
declare -gr MAX_STAGE_RETRIES=3

# ============================================================================
# Root Check
# ============================================================================

_require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges"
        return 1
    fi
    return 0
}

# ============================================================================
# State Directory Management
# ============================================================================

# Initialize system state directory
init_system_state() {
    _require_root || return 1

    log_info "Initializing system state directory: $SUITE_STATE_DIR"

    mkdir -p "$SUITE_STATE_DIR"/{checkpoints,logs,cache}
    chmod 755 "$SUITE_STATE_DIR"

    # Create initial state file if not exists
    if [[ ! -f "$SUITE_STATE_FILE" ]]; then
        cat > "$SUITE_STATE_FILE" << 'EOF'
{
    "version": "1.0",
    "created_at": null,
    "updated_at": null,
    "boot_id": null,
    "machine_id": null,
    "current_stage": 0,
    "stage_name": "INIT",
    "completed_stages": [],
    "retry_count": 0,
    "errors": [],
    "hardware_profile": null
}
EOF
        # Update timestamps
        local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo "unknown")
        local machine_id=$(cat /etc/machine-id 2>/dev/null || echo "unknown")

        if command -v jq &>/dev/null; then
            local tmp=$(mktemp)
            jq --arg now "$now" --arg boot "$boot_id" --arg machine "$machine_id" \
                '.created_at = $now | .updated_at = $now | .boot_id = $boot | .machine_id = $machine' \
                "$SUITE_STATE_FILE" > "$tmp" && mv "$tmp" "$SUITE_STATE_FILE"
        fi

        log_success "Created initial state file"
    fi

    return 0
}

# ============================================================================
# Systemd Service Management
# ============================================================================

# Generate the systemd service unit file
_generate_service_unit() {
    cat << EOF
[Unit]
Description=Ultimate Linux Suite - Stage Runner
Documentation=https://github.com/Nerds489/ultimate-linux-suite
After=network-online.target multi-user.target
Wants=network-online.target
ConditionPathExists=!${SUITE_COMPLETE_FLAG}

[Service]
Type=oneshot
ExecStart=${SUITE_STAGE_RUNNER}
RemainAfterExit=no
TimeoutStartSec=3600
StandardOutput=journal+console
StandardError=journal+console
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="HOME=/root"

[Install]
WantedBy=multi-user.target
EOF
}

# Generate the stage runner script
_generate_stage_runner() {
    local suite_dir="$1"

    cat << 'RUNNER_EOF'
#!/usr/bin/env bash
#
# run-stage.sh - Stage Runner for Ultimate Linux Suite
#
# Executed by systemd service after boot to continue multi-stage installation
# This runs as root at system boot (before user login)
#

set -euo pipefail

# Configuration
SUITE_DIR="SUITE_DIR_PLACEHOLDER"
STATE_FILE="/var/lib/linux-suite/state.json"
LOG_FILE="/var/lib/linux-suite/logs/stage-$(date +%Y%m%d-%H%M%S).log"
COMPLETE_FLAG="/var/lib/linux-suite/installation_complete"
USER_STATE_DIR=""
MAX_RETRIES=3

# Logging
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
log_error() { log "ERROR: $*" >&2; }
log_info() { log "INFO: $*"; }
log_success() { log "SUCCESS: $*"; }

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_info "=== Ultimate Linux Suite Stage Runner ==="
log_info "Boot ID: $(cat /proc/sys/kernel/random/boot_id)"
log_info "Suite directory: $SUITE_DIR"

# Find the user who started the installation
find_install_user() {
    # Look for the user state directory
    for user_home in /home/*; do
        local user_state="${user_home}/.local/state/ultimate-linux-suite"
        if [[ -d "$user_state" ]] && [[ -f "${user_state}/first_run_phase" ]]; then
            USER_STATE_DIR="$user_state"
            local username=$(basename "$user_home")
            log_info "Found installation state for user: $username"
            export HOME="$user_home"
            export USER="$username"
            return 0
        fi
    done

    # Check root's state
    if [[ -d "/root/.local/state/ultimate-linux-suite" ]]; then
        USER_STATE_DIR="/root/.local/state/ultimate-linux-suite"
        export HOME="/root"
        export USER="root"
        log_info "Using root's installation state"
        return 0
    fi

    log_error "No installation state found"
    return 1
}

# Get current phase from user state
get_user_phase() {
    if [[ -f "${USER_STATE_DIR}/first_run_phase" ]]; then
        cat "${USER_STATE_DIR}/first_run_phase"
    else
        echo "VERIFY"
    fi
}

# Mark as complete
mark_complete() {
    touch "$COMPLETE_FLAG"
    log_success "Installation complete!"

    # Disable service
    systemctl disable linux-suite.service 2>/dev/null || true
}

# Main execution
main() {
    log_info "Starting stage runner..."

    # Find the user who started the installation
    if ! find_install_user; then
        log_error "Cannot find installation state - marking complete to prevent loops"
        mark_complete
        exit 1
    fi

    local current_phase=$(get_user_phase)
    log_info "Resuming from phase: $current_phase"

    # Run the main suite script which will detect and resume first_run
    if [[ -x "${SUITE_DIR}/ultimate.sh" ]]; then
        log_info "Launching ultimate.sh to resume installation..."

        # Run the suite - it will auto-detect the resume state
        cd "$SUITE_DIR"
        bash "${SUITE_DIR}/ultimate.sh" 2>&1 | tee -a "$LOG_FILE" || {
            log_error "ultimate.sh failed"
            exit 1
        }

        log_success "Installation resumed successfully"
    else
        log_error "ultimate.sh not found at ${SUITE_DIR}/ultimate.sh"
        exit 1
    fi
}

main "$@"
RUNNER_EOF
}

# Install the systemd service
install_systemd_service() {
    _require_root || return 1

    local suite_dir="${1:-$(dirname "$SCRIPT_DIR")}"

    log_info "Installing systemd service..."

    # Initialize state directory
    init_system_state || return 1

    # Create installation directory
    mkdir -p "$SUITE_INSTALL_DIR"

    # Generate and install stage runner
    log_info "Creating stage runner at $SUITE_STAGE_RUNNER"
    _generate_stage_runner "$suite_dir" | sed "s|SUITE_DIR_PLACEHOLDER|$suite_dir|g" > "$SUITE_STAGE_RUNNER"
    chmod 755 "$SUITE_STAGE_RUNNER"

    # Generate and install service unit
    log_info "Creating service unit at $SUITE_SERVICE_FILE"
    _generate_service_unit > "$SUITE_SERVICE_FILE"
    chmod 644 "$SUITE_SERVICE_FILE"

    # Reload systemd
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload

    log_success "Systemd service installed"
    return 0
}

# Enable the systemd service
enable_systemd_service() {
    _require_root || return 1

    if [[ ! -f "$SUITE_SERVICE_FILE" ]]; then
        log_error "Service not installed. Run install_systemd_service first."
        return 1
    fi

    log_info "Enabling systemd service..."
    systemctl enable "$SUITE_SERVICE_NAME"

    log_success "Service enabled - will run on next boot"
    return 0
}

# Disable the systemd service
disable_systemd_service() {
    _require_root || return 1

    log_info "Disabling systemd service..."
    systemctl disable "$SUITE_SERVICE_NAME" 2>/dev/null || true

    log_success "Service disabled"
    return 0
}

# Remove the systemd service completely
remove_systemd_service() {
    _require_root || return 1

    log_info "Removing systemd service..."

    # Disable first
    disable_systemd_service

    # Remove files
    rm -f "$SUITE_SERVICE_FILE"
    rm -f "$SUITE_STAGE_RUNNER"

    # Reload systemd
    systemctl daemon-reload

    log_success "Service removed"
    return 0
}

# Check if service is installed
is_service_installed() {
    [[ -f "$SUITE_SERVICE_FILE" ]]
}

# Check if service is enabled
is_service_enabled() {
    systemctl is-enabled "$SUITE_SERVICE_NAME" &>/dev/null
}

# Get service status
get_service_status() {
    if ! is_service_installed; then
        echo "not_installed"
    elif is_service_enabled; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

# ============================================================================
# State Management (System Level)
# ============================================================================

# Get current stage from system state
get_system_stage() {
    if [[ ! -f "$SUITE_STATE_FILE" ]]; then
        echo "0"
        return 1
    fi

    if command -v jq &>/dev/null; then
        jq -r '.current_stage // 0' "$SUITE_STATE_FILE"
    else
        echo "0"
    fi
}

# Get stage name from system state
get_system_stage_name() {
    if [[ ! -f "$SUITE_STATE_FILE" ]]; then
        echo "INIT"
        return 1
    fi

    if command -v jq &>/dev/null; then
        jq -r '.stage_name // "INIT"' "$SUITE_STATE_FILE"
    else
        echo "INIT"
    fi
}

# Update system state
update_system_state() {
    _require_root || return 1

    local jq_filter="$1"

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for state management"
        return 1
    fi

    local tmp=$(mktemp)
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq "$jq_filter | .updated_at = \"$now\"" "$SUITE_STATE_FILE" > "$tmp" && \
        mv "$tmp" "$SUITE_STATE_FILE"
}

# Mark installation as complete
mark_installation_complete() {
    _require_root || return 1

    log_info "Marking installation as complete..."

    # Create completion flag
    touch "$SUITE_COMPLETE_FLAG"

    # Update state
    update_system_state '.stage_name = "COMPLETE"'

    # Disable and remove service
    remove_systemd_service

    log_success "Installation marked complete"
    return 0
}

# Check if installation is complete
is_installation_complete() {
    [[ -f "$SUITE_COMPLETE_FLAG" ]]
}

# Reset installation state (for testing/re-running)
reset_installation_state() {
    _require_root || return 1

    log_warn "Resetting installation state..."

    # Remove completion flag
    rm -f "$SUITE_COMPLETE_FLAG"

    # Reset state file
    rm -f "$SUITE_STATE_FILE"
    init_system_state

    log_success "Installation state reset"
    return 0
}

# ============================================================================
# Setup Functions
# ============================================================================

# Full setup: install and enable service, initialize state
setup_multi_stage_installation() {
    _require_root || return 1

    local suite_dir="${1:-$(dirname "$SCRIPT_DIR")}"

    log_info "Setting up multi-stage installation system..."

    # Check if already complete
    if is_installation_complete; then
        log_warn "Installation already marked complete"
        log_info "Use reset_installation_state to restart"
        return 1
    fi

    # Install and enable service
    install_systemd_service "$suite_dir" || return 1
    enable_systemd_service || return 1

    log_success "Multi-stage installation system ready"
    log_info "The system will continue setup after next reboot"

    return 0
}

# ============================================================================
# Status Display
# ============================================================================

# Show full status
show_system_service_status() {
    echo "=== Ultimate Linux Suite - System Service Status ==="
    echo ""
    echo "Service Status: $(get_service_status)"
    echo "Service File: $SUITE_SERVICE_FILE"
    echo "Stage Runner: $SUITE_STAGE_RUNNER"
    echo ""
    echo "State Directory: $SUITE_STATE_DIR"
    echo "State File: $SUITE_STATE_FILE"
    echo "Complete Flag: $SUITE_COMPLETE_FLAG"
    echo ""

    if is_installation_complete; then
        echo "Installation Status: COMPLETE"
    else
        echo "Installation Status: IN PROGRESS"
        echo "Current Stage: $(get_system_stage) ($(get_system_stage_name))"
    fi

    echo ""

    if is_service_installed && is_service_enabled; then
        echo "Service will run on next boot"
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

# Main functions available externally
export -f init_system_state
export -f install_systemd_service
export -f enable_systemd_service
export -f disable_systemd_service
export -f remove_systemd_service
export -f is_service_installed
export -f is_service_enabled
export -f get_service_status
export -f get_system_stage
export -f get_system_stage_name
export -f update_system_state
export -f mark_installation_complete
export -f is_installation_complete
export -f reset_installation_state
export -f setup_multi_stage_installation
export -f show_system_service_status
