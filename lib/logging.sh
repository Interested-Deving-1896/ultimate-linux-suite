#!/usr/bin/env bash
# Unified Suite - Logging System
# Source: OffTrack Suite + Ultimate Suite merged
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_LOGGING_LOADED:-}" ]] && return 0
readonly _UNIFIED_LOGGING_LOADED=1

# Source colors if not loaded
[[ -z "${_UNIFIED_COLORS_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/colors.sh"

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Current log level (default: INFO)
declare -g LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log directory and file
declare -g LOG_DIR="${LOG_DIR:-${HOME}/.unified-suite/logs}"
declare -g LOG_FILE=""

# Initialize logging
log_init() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/unified-$(date +%Y%m%d).log"
    touch "$LOG_FILE"
}

# Internal log function
_log() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    local message="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Console output (if level >= current level)
    if [[ $level_num -ge $LOG_LEVEL ]]; then
        echo -e "${color}[${level}]${C_RESET} ${message}"
    fi

    # File output (always)
    if [[ -n "$LOG_FILE" ]] && [[ -w "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Log functions
log_debug() {
    _log "DEBUG" $LOG_LEVEL_DEBUG "$C_CYAN" "$*"
}

log_info() {
    _log "INFO" $LOG_LEVEL_INFO "$C_BLUE" "$*"
}

log_warn() {
    _log "WARN" $LOG_LEVEL_WARN "$C_YELLOW" "$*"
}

log_error() {
    _log "ERROR" $LOG_LEVEL_ERROR "$C_RED" "$*"
}

log_fatal() {
    _log "FATAL" $LOG_LEVEL_FATAL "$C_BMAGENTA" "$*"
    exit ${EXIT_FAILURE:-1}
}

log_success() {
    echo -e "${C_GREEN}[OK]${C_RESET} $*"
    if [[ -n "$LOG_FILE" ]] && [[ -w "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $*" >> "$LOG_FILE"
    fi
}

# Section header
log_section() {
    local title="$1"
    local line=$(printf '=%.0s' {1..60})
    echo ""
    echo -e "${C_BCYAN}╔${line}╗${C_RESET}"
    echo -e "${C_BCYAN}║  ${title}${C_RESET}"
    echo -e "${C_BCYAN}╚${line}╝${C_RESET}"
    echo ""

    if [[ -n "$LOG_FILE" ]] && [[ -w "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SECTION] $title" >> "$LOG_FILE"
    fi
}

# Header box (Ultimate Suite style)
log_header() {
    local title="$1"
    local width=62
    local padding=$(( (width - ${#title} - 2) / 2 ))
    local line=$(printf '=%.0s' $(seq 1 $width))

    echo ""
    echo -e "${C_BCYAN}╔${line}╗${C_RESET}"
    printf "${C_BCYAN}║%*s%s%*s║${C_RESET}\n" $padding "" "$title" $((width - padding - ${#title})) ""
    echo -e "${C_BCYAN}╚${line}╝${C_RESET}"
    echo ""
}

# Progress indicator
log_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-}"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r${C_CYAN}[%3d%%]${C_RESET} [" "$percent"
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %s" "$message"

    [[ $current -eq $total ]] && echo ""
}

# Set log level from string
set_log_level() {
    case "${1,,}" in
        debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info)  LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn)  LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *)     LOG_LEVEL=$LOG_LEVEL_INFO ;;
    esac
}

# Initialize on source
log_init
