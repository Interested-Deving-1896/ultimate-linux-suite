#!/usr/bin/env bash
#
# error_handling.sh - Robust Error Handling and Recovery
#

# Prevent multiple sourcing
[[ -n "${_ERROR_HANDLING_LOADED:-}" ]] && return 0
readonly _ERROR_HANDLING_LOADED=1

# Enable pipefail to catch errors in pipes
set -o pipefail

# ============================================================================
# Dependencies
# ============================================================================

# Get script directory for relative sourcing
_ERR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging if not already loaded (with fallback)
if ! declare -f log_info &>/dev/null; then
    source "${_ERR_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_json() { :; }  # No-op for JSON logging
    }
fi

# ============================================================================
# Global error state variables
# ============================================================================

declare -g LAST_ERROR=""
declare -g ERROR_STACK=()
declare -g CRITICAL_SECTION="false"

# ============================================================================
# TRAP HANDLERS
# ============================================================================

# Error trap handler for ERR signal
# This is called when a command fails (returns non-zero exit code)
# Note: Traps are set up in ultimate.sh after all libraries are loaded
error_handler() {
    local exit_code=$1
    local line_number=$2
    local command="${BASH_COMMAND}"

    LAST_ERROR="Error $exit_code at line $line_number: $command"
    ERROR_STACK+=("$LAST_ERROR")

    # Log the error with appropriate severity
    if type -t log_error &>/dev/null; then
        log_error "$LAST_ERROR"
    else
        echo "ERROR: $LAST_ERROR" >&2
    fi

    # Log structured error data if JSON logging is available
    if type -t log_json &>/dev/null; then
        log_json ERROR "command_failed" "{\"exit_code\": $exit_code, \"line\": $line_number, \"command\": \"$command\"}"
    fi

    # Don't exit on non-critical errors
    if [[ "$CRITICAL_SECTION" != "true" ]]; then
        return 0
    fi

    # Critical error - attempt recovery
    attempt_recovery "$exit_code" "$line_number"
}

# Exit trap handler for EXIT signal
# This is called when the script exits (normally or abnormally)
exit_handler() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        if type -t log_error &>/dev/null; then
            log_error "Script exiting with code $exit_code"
        else
            echo "ERROR: Script exiting with code $exit_code" >&2
        fi

        # Save error state to state file if update_state is available
        if type -t update_state &>/dev/null && [[ -n "$LAST_ERROR" ]]; then
            update_state ".errors += [\"$(echo "$LAST_ERROR" | jq -Rs .)\"]" 2>/dev/null || true
        fi
    fi

    # Cleanup operations
    if type -t release_lock &>/dev/null; then
        release_lock 2>/dev/null || true
    fi
    rm -f /tmp/ultimate-suite-*.tmp 2>/dev/null || true
}

# Interrupt trap handler for INT and TERM signals
# This is called when the user presses Ctrl+C or the process is terminated
interrupt_handler() {
    echo ""
    if type -t log_warn &>/dev/null; then
        log_warn "Interrupted by user"
    else
        echo "WARNING: Interrupted by user" >&2
    fi

    # Offer to save progress if confirm_action is available
    if type -t confirm_action &>/dev/null && type -t create_checkpoint &>/dev/null; then
        if confirm_action "Save current progress before exiting?"; then
            create_checkpoint "interrupted_$(date +%Y%m%d_%H%M%S)"
        fi
    fi

    exit 130
}

# ============================================================================
# RECOVERY MECHANISMS
# ============================================================================

# Attempt to recover from common errors
# Args:
#   $1 - exit_code: The exit code of the failed command
#   $2 - line_number: The line number where the error occurred
attempt_recovery() {
    local exit_code="$1"
    local line_number="$2"

    if type -t log_warn &>/dev/null; then
        log_warn "Attempting automatic recovery..."
    else
        echo "WARNING: Attempting automatic recovery..." >&2
    fi

    # Check for common recoverable errors
    case "$exit_code" in
        1)  # General error
            # Try to continue
            return 0
            ;;
        2)  # Misuse of shell builtin
            return 0
            ;;
        100) # apt lock
            recover_apt_lock
            return $?
            ;;
        *)
            # Unknown error - offer manual intervention
            if type -t confirm_action &>/dev/null; then
                if confirm_action "Unknown error occurred. Would you like to try again?"; then
                    return 0
                else
                    return 1
                fi
            else
                return 1
            fi
            ;;
    esac
}

# Recover from APT/dpkg lock issues
# This function waits for other package managers to finish and cleans up stale locks
recover_apt_lock() {
    if type -t log_info &>/dev/null; then
        log_info "Attempting to recover from APT lock..."
    else
        echo "INFO: Attempting to recover from APT lock..." >&2
    fi

    # Wait for other apt processes
    local timeout=60
    local waited=0

    while fuser /var/lib/dpkg/lock-frontend &>/dev/null; do
        sleep 5
        ((waited += 5))

        if [[ $waited -ge $timeout ]]; then
            if type -t log_error &>/dev/null; then
                log_error "Timeout waiting for APT lock"
            else
                echo "ERROR: Timeout waiting for APT lock" >&2
            fi
            return 1
        fi

        if type -t log_info &>/dev/null; then
            log_info "Waiting for APT lock... ($waited/$timeout seconds)"
        else
            echo "INFO: Waiting for APT lock... ($waited/$timeout seconds)" >&2
        fi
    done

    # Clean up any stale locks (requires root)
    if [[ "$(id -u)" -eq 0 ]]; then
        rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
        rm -f /var/lib/apt/lists/lock 2>/dev/null || true
        rm -f /var/cache/apt/archives/lock 2>/dev/null || true

        dpkg --configure -a 2>/dev/null || true
    fi

    if type -t log_success &>/dev/null; then
        log_success "APT lock recovered"
    else
        echo "SUCCESS: APT lock recovered" >&2
    fi
    return 0
}

# ============================================================================
# SAFE EXECUTION WRAPPERS
# ============================================================================

# Execute command with retry logic
# Args:
#   $1 - max_attempts: Maximum number of retry attempts (default: 3)
#   $2 - delay: Delay in seconds between retries (default: 5)
#   $@ - command: The command and its arguments to execute
# Returns:
#   0 if command succeeds, 1 if all attempts fail
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    shift 2
    local cmd=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if type -t log_debug &>/dev/null; then
            log_debug "Attempt $attempt/$max_attempts: ${cmd[*]}"
        fi

        if "${cmd[@]}"; then
            return 0
        fi

        if type -t log_warn &>/dev/null; then
            log_warn "Attempt $attempt failed, retrying in ${delay}s..."
        else
            echo "WARNING: Attempt $attempt failed, retrying in ${delay}s..." >&2
        fi
        sleep "$delay"
        ((attempt++))
    done

    if type -t log_error &>/dev/null; then
        log_error "All $max_attempts attempts failed for: ${cmd[*]}"
    else
        echo "ERROR: All $max_attempts attempts failed for: ${cmd[*]}" >&2
    fi
    return 1
}

# Execute command in critical section (errors are fatal)
# Args:
#   $@ - command: The command and its arguments to execute
# Returns:
#   The exit code of the command
critical() {
    local old_critical="$CRITICAL_SECTION"
    CRITICAL_SECTION=true

    "$@"
    local result=$?

    CRITICAL_SECTION="$old_critical"
    return $result
}

# Execute command with timeout
# Args:
#   $1 - timeout: Timeout duration (e.g., "30s", "5m")
#   $@ - command: The command and its arguments to execute
# Returns:
#   The exit code of the command, or 124 if timeout occurred
with_timeout() {
    local timeout="$1"
    shift

    timeout "$timeout" "$@"
    local result=$?

    if [[ $result -eq 124 ]]; then
        if type -t log_error &>/dev/null; then
            log_error "Command timed out after ${timeout}s: $*"
        else
            echo "ERROR: Command timed out after ${timeout}s: $*" >&2
        fi
    fi

    return $result
}

# Execute command with cleanup on failure
# Args:
#   $1 - cleanup_cmd: Cleanup command to run if the main command fails
#   $@ - command: The command and its arguments to execute
# Returns:
#   0 if command succeeds, 1 if command fails (after running cleanup)
with_cleanup() {
    local cleanup_cmd="$1"
    shift

    if ! "$@"; then
        if type -t log_warn &>/dev/null; then
            log_warn "Command failed, running cleanup..."
        else
            echo "WARNING: Command failed, running cleanup..." >&2
        fi
        eval "$cleanup_cmd"
        return 1
    fi

    return 0
}
