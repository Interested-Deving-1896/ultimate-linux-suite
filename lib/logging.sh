#!/usr/bin/env bash
#
# logging.sh - Logging functions for Ultimate Linux Suite
#

# Prevent multiple sourcing
[[ -n "${_LOGGING_LOADED:-}" ]] && return 0
readonly _LOGGING_LOADED=1

# ============================================================================
# Color definitions (only if terminal supports them)
# ============================================================================

if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly BOLD='\033[1m'
    readonly RESET='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly MAGENTA=''
    readonly BOLD=''
    readonly RESET=''
fi

# ============================================================================
# Log level system
# ============================================================================

# Log level priorities (lower number = more verbose)
declare -gA LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

# Log level colors
declare -gA LOG_COLORS=(
    [DEBUG]="${CYAN}"
    [INFO]="${BLUE}"
    [WARN]="${YELLOW}"
    [ERROR]="${RED}"
    [FATAL]="${MAGENTA}"
    [RESET]="${RESET}"
)

# Current log level (can be set via environment variable)
declare -g LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ============================================================================
# File logging configuration
# ============================================================================

# Log file location (will be set by logging_init)
declare -g LOG_FILE=""
declare -g LOG_DIR=""
declare -g LOG_ENABLED=0

# Initialize file logging
# Called automatically when suite.sh starts
logging_init() {
    local log_dir=""

    # Determine log directory based on permissions
    if [[ "$(id -u)" -eq 0 ]]; then
        log_dir="/var/log/ultimate-linux-suite"
    else
        log_dir="${HOME}/.ultimate-linux-suite/logs"
    fi

    LOG_DIR="$log_dir"

    # Create directory if it doesn't exist
    if mkdir -p "$log_dir" 2>/dev/null; then
        LOG_FILE="${log_dir}/suite-$(date +%Y%m%d).log"
        LOG_ENABLED=1

        # Rotate old logs (keep last 7 days)
        find "$log_dir" -name "suite-*.log" -mtime +7 -delete 2>/dev/null || true

        # Write session start marker
        {
            echo ""
            echo "========================================"
            echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Hostname: $(hostname)"
            echo "Kernel: $(uname -r)"
            echo "User: $(whoami)"
            echo "Log Level: $LOG_LEVEL"
            echo "========================================"
        } >> "$LOG_FILE" 2>/dev/null || LOG_ENABLED=0
    fi
}

# Write to log file (internal)
_log_to_file() {
    local level="$1"
    local message="$2"
    local source="${3:-}"
    local caller_info="${4:-}"

    if [[ "$LOG_ENABLED" -eq 1 ]] && [[ -n "$LOG_FILE" ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local source_info=""
        [[ -n "$source" ]] && source_info="[$source] "

        local caller_str=""
        [[ -n "$caller_info" ]] && caller_str="[$caller_info] "

        printf "[%s] [%s] %s%s%s\n" "$timestamp" "$level" "$caller_str" "$source_info" "$message" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Internal logging function with level filtering
_log() {
    local level="$1"
    shift
    local message="$*"

    # Get current log level priority
    local current_level_priority=${LOG_LEVELS[$LOG_LEVEL]:-1}
    local msg_level_priority=${LOG_LEVELS[$level]:-1}

    # Filter out messages below the current log level
    [[ $msg_level_priority -lt $current_level_priority ]] && return 0

    # Get caller information (function:line)
    local caller="${FUNCNAME[2]:-main}:${BASH_LINENO[1]:-0}"

    # Log to file with caller info
    _log_to_file "$level" "$message" "" "$caller"

    # Console output with colors
    local color="${LOG_COLORS[$level]}"
    local reset="${LOG_COLORS[RESET]}"

    case "$level" in
        DEBUG|WARN|ERROR|FATAL)
            printf "%b[%s]%b %s\n" "$color" "$level" "$reset" "$message" >&2
            ;;
        INFO)
            printf "%b[%s]%b %s\n" "$color" "$level" "$reset" "$message"
            ;;
    esac
}

# ============================================================================
# Console logging functions
# ============================================================================

# Log debug message (uses _log for level filtering)
log_debug() {
    _log DEBUG "$@"
}

# Log info message (uses _log for level filtering)
log_info() {
    _log INFO "$@"
}

# Log warning message (uses _log for level filtering)
log_warn() {
    _log WARN "$@"
}

# Log error message (uses _log for level filtering)
log_error() {
    _log ERROR "$@"
}

# Log fatal message and exit
log_fatal() {
    _log FATAL "$@"
    exit 1
}

# Log success message (green) - kept for backward compatibility
log_success() {
    printf "${GREEN}[OK]${RESET} %s\n" "$*"
    local caller="${FUNCNAME[1]:-main}:${BASH_LINENO[0]:-0}"
    _log_to_file "OK" "$*" "" "$caller"
}

# ============================================================================
# Formatting functions
# ============================================================================

# Print a section header
log_section() {
    local title="$1"
    printf "\n${BOLD}=== %s ===${RESET}\n\n" "$title"
    local caller="${FUNCNAME[1]:-main}:${BASH_LINENO[0]:-0}"
    _log_to_file "SECTION" "$title" "" "$caller"
}

# Print a divider line
log_divider() {
    local line="────────────────────────────────────────────────────────────"
    printf "%s\n" "$line"
}

# Print a step indicator
log_step() {
    local step="$1"
    local total="${2:-}"
    local message="$3"

    if [[ -n "$total" ]]; then
        printf "${BLUE}[%d/%d]${RESET} %s\n" "$step" "$total" "$message"
    else
        printf "${BLUE}[%d]${RESET} %s\n" "$step" "$message"
    fi
    local caller="${FUNCNAME[1]:-main}:${BASH_LINENO[0]:-0}"
    _log_to_file "STEP" "[$step${total:+/$total}] $message" "" "$caller"
}

# ============================================================================
# Progress indicators
# ============================================================================

# Simple spinner (use in background)
log_spinner() {
    local pid="$1"
    local msg="${2:-Working...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}%s${RESET} %s " "${spin:i++%${#spin}:1}" "$msg"
        sleep 0.1
    done
    printf "\r\033[K"
}

# Progress bar (manual update)
# Usage: log_progress CURRENT TOTAL [MESSAGE]
log_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r%b%s:%b [" "${BLUE}" "$message" "${RESET}"
    printf "%*s" "$filled" "" | tr ' ' '#'
    printf "%*s" "$empty" "" | tr ' ' '-'
    printf "] %3d%%" "$percent"

    # Newline when complete
    [[ "$current" -eq "$total" ]] && printf "\n"
}

# ============================================================================
# Structured logging (for programmatic use)
# ============================================================================

# Log with module/source context
log_with_source() {
    local level="$1"
    local source="$2"
    local message="$3"

    case "$level" in
        info)    printf "${BLUE}[INFO]${RESET} [%s] %s\n" "$source" "$message" ;;
        success) printf "${GREEN}[OK]${RESET} [%s] %s\n" "$source" "$message" ;;
        warn)    printf "${YELLOW}[WARN]${RESET} [%s] %s\n" "$source" "$message" >&2 ;;
        error)   printf "${RED}[ERROR]${RESET} [%s] %s\n" "$source" "$message" >&2 ;;
        debug)   [[ "${DEBUG:-0}" == "1" ]] && printf "${CYAN}[DEBUG]${RESET} [%s] %s\n" "$source" "$message" >&2 ;;
    esac

    _log_to_file "${level^^}" "$message" "$source"
}

# ============================================================================
# Log file utilities
# ============================================================================

# Get current log file path
log_get_file() {
    echo "$LOG_FILE"
}

# View recent log entries
log_tail() {
    local lines="${1:-50}"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "$lines" "$LOG_FILE"
    else
        log_warn "No log file available"
    fi
}

# Search log file
log_grep() {
    local pattern="$1"
    if [[ -f "$LOG_FILE" ]]; then
        grep -i "$pattern" "$LOG_FILE"
    else
        log_warn "No log file available"
    fi
}

# ============================================================================
# Advanced logging functions
# ============================================================================

# Command execution wrapper with logging
# Logs command execution, captures output, and logs results
log_cmd() {
    local cmd="$*"
    log_debug "Executing: $cmd"

    local output
    local exit_code

    # Execute command and capture output
    output=$("$@" 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Command failed with exit code $exit_code: $cmd"
        log_debug "Output: $output"
    else
        log_debug "Command succeeded: $cmd"
    fi

    # Return the output for potential use by caller
    echo "$output"
    return $exit_code
}

# Structured JSON logging for event tracking
# Usage: log_json LEVEL EVENT DATA
# Example: log_json INFO package_installed '{"name":"vim","version":"9.0"}'
log_json() {
    local level="$1"
    local event="$2"
    shift 2
    local data="$*"

    # Only log if LOG_DIR is set
    if [[ -z "$LOG_DIR" ]]; then
        return 0
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")

    local json_file="${LOG_DIR}/events.jsonl"

    # Ensure log directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || return 1

    # Append JSON event (one per line)
    cat >> "$json_file" <<EOF
{"timestamp":"$timestamp","level":"$level","event":"$event","data":$data}
EOF
}

# ============================================================================
# ENHANCED LOGGING FEATURES DOCUMENTATION
# ============================================================================
#
# This logging library provides comprehensive logging capabilities:
#
# 1. LOG LEVEL SYSTEM:
#    - Set LOG_LEVEL environment variable to control verbosity
#    - Available levels: DEBUG(0), INFO(1), WARN(2), ERROR(3), FATAL(4)
#    - Lower number = more verbose
#    - Example: LOG_LEVEL=DEBUG ./suite.sh
#
# 2. CALLER INFORMATION:
#    - All log messages include caller info (function:line) in log files
#    - Helps with debugging and tracing execution flow
#    - Format: [timestamp] [LEVEL] [function:line] message
#
# 3. LOG ROTATION:
#    - Automatically deletes logs older than 7 days on initialization
#    - Keeps disk space under control
#    - Runs on each logging_init() call
#
# 4. NEW LOGGING FUNCTIONS:
#    - log_fatal(): Logs a fatal error and exits with code 1
#    - log_cmd(): Wrapper for command execution with automatic logging
#    - log_json(): Structured JSON logging to events.jsonl
#
# 5. BACKWARD COMPATIBILITY:
#    - All existing functions preserved and working
#    - log_info, log_success, log_warn, log_error, log_debug
#    - log_section, log_divider, log_step
#    - log_spinner, log_progress
#    - log_with_source, log_get_file, log_tail, log_grep
#
# 6. COLOR SUPPORT:
#    - Automatic color detection (terminal capability check)
#    - Colors: DEBUG=cyan, INFO=blue, WARN=yellow, ERROR=red, FATAL=magenta
#    - Clean output without colors in non-terminal environments
#
# USAGE EXAMPLES:
#
#   # Set log level
#   export LOG_LEVEL=DEBUG
#
#   # Basic logging
#   log_info "Starting installation"
#   log_warn "Configuration file not found, using defaults"
#   log_error "Failed to connect to server"
#   log_fatal "Critical error, cannot continue"
#
#   # Command wrapper
#   if log_cmd apt-get update; then
#       log_success "Update completed"
#   fi
#
#   # JSON logging
#   log_json INFO package_installed '{"name":"nginx","version":"1.18.0"}'
#
# ============================================================================
