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
    readonly BOLD='\033[1m'
    readonly RESET='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly BOLD=''
    readonly RESET=''
fi

# ============================================================================
# File logging configuration
# ============================================================================

# Log file location (will be set by logging_init)
declare -g LOG_FILE=""
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

    # Create directory if it doesn't exist
    if mkdir -p "$log_dir" 2>/dev/null; then
        LOG_FILE="${log_dir}/suite-$(date +%Y%m%d).log"
        LOG_ENABLED=1

        # Write session start marker
        {
            echo ""
            echo "========================================"
            echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "User: $(whoami)"
            echo "========================================"
        } >> "$LOG_FILE" 2>/dev/null || LOG_ENABLED=0
    fi
}

# Write to log file (internal)
_log_to_file() {
    local level="$1"
    local message="$2"
    local source="${3:-}"

    if [[ "$LOG_ENABLED" -eq 1 ]] && [[ -n "$LOG_FILE" ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local source_info=""
        [[ -n "$source" ]] && source_info="[$source] "

        printf "[%s] [%s] %s%s\n" "$timestamp" "$level" "$source_info" "$message" >> "$LOG_FILE" 2>/dev/null
    fi
}

# ============================================================================
# Console logging functions
# ============================================================================

# Log info message (blue)
log_info() {
    printf "${BLUE}[INFO]${RESET} %s\n" "$*"
    _log_to_file "INFO" "$*"
}

# Log success message (green)
log_success() {
    printf "${GREEN}[OK]${RESET} %s\n" "$*"
    _log_to_file "OK" "$*"
}

# Log warning message (yellow)
log_warn() {
    printf "${YELLOW}[WARN]${RESET} %s\n" "$*" >&2
    _log_to_file "WARN" "$*"
}

# Log error message (red)
log_error() {
    printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2
    _log_to_file "ERROR" "$*"
}

# Log debug message (only if DEBUG=1)
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        printf "${CYAN}[DEBUG]${RESET} %s\n" "$*" >&2
    fi
    # Always log to file in debug level
    _log_to_file "DEBUG" "$*"
}

# ============================================================================
# Formatting functions
# ============================================================================

# Print a section header
log_section() {
    local title="$1"
    printf "\n${BOLD}=== %s ===${RESET}\n\n" "$title"
    _log_to_file "SECTION" "$title"
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
    _log_to_file "STEP" "[$step${total:+/$total}] $message"
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

    printf "\r${BLUE}%s:${RESET} [" "$message"
    printf "%*s" "$filled" | tr ' ' '#'
    printf "%*s" "$empty" | tr ' ' '-'
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
