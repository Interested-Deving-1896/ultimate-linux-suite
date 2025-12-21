#!/usr/bin/env bash
#
# state_advanced.sh - Advanced State Management for Ultimate Linux Suite
# Provides checkpoint system, phase transitions, and event recording
#

# Prevent multiple sourcing
[[ -n "${_STATE_ADVANCED_LOADED:-}" ]] && return 0
readonly _STATE_ADVANCED_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

_STATE_ADV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${_STATE_ADV_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# ============================================================================
# State System Configuration
# ============================================================================

STATE_VERSION="1.0"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ultimate-suite"
LOCK_FILE="$STATE_DIR/.lock"
STATE_FILE="$STATE_DIR/state.json"
HISTORY_FILE="$STATE_DIR/history.json"

# ============================================================================
# Atomic File Operations
# ============================================================================

atomic_write() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp.$$"

    echo "$content" > "$temp_file"
    sync "$temp_file"
    mv "$temp_file" "$file"
    sync "$file"
}

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

release_lock() {
    rm -rf "$LOCK_FILE"
}

# ============================================================================
# State Initialization
# ============================================================================

init_state_system() {
    mkdir -p "$STATE_DIR"/{checkpoints,logs,cache}

    if [[ ! -f "$STATE_FILE" ]]; then
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
    fi

    # Initialize history
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo '{"events": []}' > "$HISTORY_FILE"
    fi
}

# ============================================================================
# State Mutations
# ============================================================================

update_state() {
    local jq_filter="$1"

    acquire_lock

    local current=$(cat "$STATE_FILE")
    local updated=$(echo "$current" | jq "$jq_filter | .updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

    atomic_write "$STATE_FILE" "$updated"

    release_lock
}

get_state() {
    local jq_filter="${1:-.}"
    jq -r "$jq_filter" "$STATE_FILE"
}

record_event() {
    local event_type="$1"
    local event_data="$2"

    acquire_lock

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

    atomic_write "$HISTORY_FILE" "$updated"

    release_lock
}

# ============================================================================
# Phase Transitions
# ============================================================================

declare -A PHASE_GRAPH=(
    # [current_phase]="next_phase:condition|next_phase:condition|..."
    [0]="1:always"
    [1]="2:scan_complete"
    [2]="3:optimizations_applied"
    [3]="4:reboot_detected"
    [4]="5:verification_passed"
    [5]="6:packages_installed"
    [6]="7:utilities_installed"
    [7]="8:reboot_detected"
    [8]="9:verification_passed"
    [9]="10:complete"
)

can_transition() {
    local from="$1"
    local to="$2"

    local valid_transitions="${PHASE_GRAPH[$from]}"
    if [[ "$valid_transitions" == *"$to:"* ]]; then
        return 0
    fi
    return 1
}

transition_phase() {
    local to_phase="$1"
    local to_name="$2"

    local from_phase=$(get_state '.phase.current')

    if ! can_transition "$from_phase" "$to_phase"; then
        log_error "Invalid phase transition: $from_phase -> $to_phase"
        return 1
    fi

    update_state "
        .phase.current = $to_phase |
        .phase.name = \"$to_name\" |
        .phase.started_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\" |
        .phase.attempts = 0
    "

    record_event "phase_transition" "{\"from\": $from_phase, \"to\": $to_phase, \"name\": \"$to_name\"}"

    log_info "Phase transition: $from_phase -> $to_phase ($to_name)"
}

increment_attempt() {
    update_state '.phase.attempts += 1'
}

# ============================================================================
# Checkpoint System
# ============================================================================

create_checkpoint() {
    local name="$1"
    local description="${2:-}"

    local checkpoint_dir="$STATE_DIR/checkpoints/$name"
    mkdir -p "$checkpoint_dir"

    # Snapshot current state
    cp "$STATE_FILE" "$checkpoint_dir/state.json"

    # Backup system configurations
    tar -czf "$checkpoint_dir/sysctl.tar.gz" /etc/sysctl.d/ 2>/dev/null || true
    tar -czf "$checkpoint_dir/udev.tar.gz" /etc/udev/rules.d/ 2>/dev/null || true

    # Record installed packages
    case "$OS_FAMILY" in
        debian) dpkg --get-selections > "$checkpoint_dir/packages.list" ;;
        fedora) rpm -qa > "$checkpoint_dir/packages.list" ;;
        arch)   pacman -Qq > "$checkpoint_dir/packages.list" ;;
    esac

    # Flatpak list
    flatpak list --columns=application > "$checkpoint_dir/flatpak.list" 2>/dev/null || true

    # Snap list
    snap list 2>/dev/null | tail -n +2 | awk '{print $1}' > "$checkpoint_dir/snap.list" || true

    # Metadata
    cat > "$checkpoint_dir/metadata.json" <<EOF
{
    "name": "$name",
    "description": "$description",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "boot_id": "$(cat /proc/sys/kernel/random/boot_id)",
    "phase": $(get_state '.phase')
}
EOF

    log_info "Checkpoint created: $name"
    record_event "checkpoint_created" "{\"name\": \"$name\"}"
}

restore_checkpoint() {
    local name="$1"
    local checkpoint_dir="$STATE_DIR/checkpoints/$name"

    if [[ ! -d "$checkpoint_dir" ]]; then
        log_error "Checkpoint not found: $name"
        return 1
    fi

    log_warn "Restoring checkpoint: $name"

    # Restore sysctl configurations
    if [[ -f "$checkpoint_dir/sysctl.tar.gz" ]]; then
        tar -xzf "$checkpoint_dir/sysctl.tar.gz" -C /
        sysctl --system
    fi

    # Restore udev rules
    if [[ -f "$checkpoint_dir/udev.tar.gz" ]]; then
        tar -xzf "$checkpoint_dir/udev.tar.gz" -C /
        udevadm control --reload-rules
    fi

    # Restore state
    cp "$checkpoint_dir/state.json" "$STATE_FILE"

    record_event "checkpoint_restored" "{\"name\": \"$name\"}"
}

list_checkpoints() {
    local checkpoints_dir="$STATE_DIR/checkpoints"

    if [[ ! -d "$checkpoints_dir" ]]; then
        echo "[]"
        return
    fi

    local result="["
    local first=true

    for dir in "$checkpoints_dir"/*/; do
        [[ ! -d "$dir" ]] && continue

        local metadata="$dir/metadata.json"
        [[ ! -f "$metadata" ]] && continue

        [[ "$first" == "false" ]] && result+=","
        first=false

        result+=$(cat "$metadata")
    done

    result+="]"
    echo "$result"
}
