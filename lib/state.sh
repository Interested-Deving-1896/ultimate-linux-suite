#!/usr/bin/env bash
#
# state.sh - Production-Grade State Management for Ultimate Linux Suite
#

# Prevent multiple sourcing
[[ -n "${_STATE_LOADED:-}" ]] && return 0
readonly _STATE_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

# Get script directory for relative sourcing
_STATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    source "${_STATE_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# Check for jq dependency
if ! command -v jq &>/dev/null; then
    log_warn "jq is not installed - state management will have limited functionality"
fi

# ============================================================================
# State Configuration
# ============================================================================

readonly STATE_VERSION="1.0"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ultimate-suite"
readonly LOCK_FILE="$STATE_DIR/.lock"
readonly STATE_FILE="$STATE_DIR/state.json"
readonly HISTORY_FILE="$STATE_DIR/history.json"

# ============================================================================
# Atomic File Operations
# ============================================================================

# Atomic write operation with fsync for data integrity
# Usage: atomic_write <file> <content>
atomic_write() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp.$$"

    echo "$content" > "$temp_file"
    sync "$temp_file"
    mv "$temp_file" "$file"
    sync "$file"
}

# ============================================================================
# Lock Management
# ============================================================================

# Acquire exclusive lock with timeout and stale lock detection
# Usage: acquire_lock [timeout_seconds]
# Returns: 0 on success, 1 on failure
acquire_lock() {
    local timeout="${1:-30}"
    local start_time=$(date +%s)

    while true; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            echo $$ > "$LOCK_FILE/pid"
            trap 'release_lock' EXIT
            return 0
        fi

        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Failed to acquire state lock after ${timeout}s"
            return 1
        fi

        # Check if holding process is still alive
        if [[ -f "$LOCK_FILE/pid" ]]; then
            local holding_pid=$(cat "$LOCK_FILE/pid")
            if ! kill -0 "$holding_pid" 2>/dev/null; then
                log_warn "Removing stale lock from PID $holding_pid"
                rm -rf "$LOCK_FILE"
                continue
            fi
        fi

        sleep 0.5
    done
}

# Release the lock
# Usage: release_lock
release_lock() {
    rm -rf "$LOCK_FILE"
}

# ============================================================================
# State Initialization
# ============================================================================

# Initialize state system directories and files
# Usage: init_state_system
init_state_system() {
    log_debug "Initializing state system at $STATE_DIR"

    mkdir -p "$STATE_DIR"/{checkpoints,logs,cache}

    if [[ ! -f "$STATE_FILE" ]]; then
        log_info "Creating initial state file"
        local initial_state=$(cat <<EOF
{
    "version": "$STATE_VERSION",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "boot_id": "$(cat /proc/sys/kernel/random/boot_id)",
    "machine_id": "$(cat /etc/machine-id 2>/dev/null || echo 'unknown')",
    "phase": {
        "current": 0,
        "name": "INIT",
        "started_at": null,
        "attempts": 0
    },
    "hardware": null,
    "distribution": null,
    "optimizations": {
        "applied": [],
        "pending": [],
        "failed": []
    },
    "packages": {
        "managers_installed": [],
        "utilities_installed": [],
        "applications_installed": []
    },
    "errors": [],
    "warnings": []
}
EOF
)
        atomic_write "$STATE_FILE" "$initial_state"
        log_debug "State file created at $STATE_FILE"
    else
        log_debug "State file already exists at $STATE_FILE"
    fi

    # Initialize history
    if [[ ! -f "$HISTORY_FILE" ]]; then
        log_debug "Creating history file"
        echo '{"events": []}' > "$HISTORY_FILE"
    fi
}

# ============================================================================
# State Mutations
# ============================================================================

# Update state using jq filter with automatic timestamp update
# Usage: update_state <jq_filter>
# Example: update_state '.phase.current = 1 | .phase.name = "DETECT"'
update_state() {
    local jq_filter="$1"

    if ! acquire_lock; then
        log_error "Failed to acquire lock for state update"
        return 1
    fi

    local current=$(cat "$STATE_FILE")
    local updated=$(echo "$current" | jq "$jq_filter | .updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

    if [[ -z "$updated" ]]; then
        log_error "Failed to update state: jq filter failed"
        release_lock
        return 1
    fi

    atomic_write "$STATE_FILE" "$updated"
    log_debug "State updated successfully"

    release_lock
    return 0
}

# Query state using jq filter
# Usage: get_state [jq_filter]
# Example: get_state '.phase.current'
get_state() {
    local jq_filter="${1:-.}"

    if [[ ! -f "$STATE_FILE" ]]; then
        log_error "State file does not exist at $STATE_FILE"
        return 1
    fi

    jq -r "$jq_filter" "$STATE_FILE"
}

# Record an event to history
# Usage: record_event <event_type> <event_data_json>
# Example: record_event "phase_change" '{"from": 0, "to": 1}'
record_event() {
    local event_type="$1"
    local event_data="$2"

    if ! acquire_lock; then
        log_error "Failed to acquire lock for event recording"
        return 1
    fi

    local event=$(cat <<EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "type": "$event_type",
    "data": $event_data,
    "boot_id": "$(cat /proc/sys/kernel/random/boot_id)"
}
EOF
)

    local current=$(cat "$HISTORY_FILE")
    local updated=$(echo "$current" | jq ".events += [$event]")

    if [[ -z "$updated" ]]; then
        log_error "Failed to record event: jq filter failed"
        release_lock
        return 1
    fi

    atomic_write "$HISTORY_FILE" "$updated"
    log_debug "Event recorded: $event_type"

    release_lock
    return 0
}
