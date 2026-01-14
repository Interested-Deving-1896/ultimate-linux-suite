#!/usr/bin/env bash
# Unified Suite - Core Foundation
# Source: OffTrack Suite + Extensions
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_CORE_LOADED:-}" ]] && return 0
readonly _UNIFIED_CORE_LOADED=1

# ============================================================
# SUITE METADATA
# ============================================================

readonly SUITE_NAME="Unified Linux Suite"
readonly SUITE_CODENAME="Sovereign Optimization Protocol"
readonly SUITE_VERSION=$(cat "${SUITE_ROOT:-$(dirname "${BASH_SOURCE[0]}")/..}/VERSION" 2>/dev/null || echo "1.0.0")
readonly SUITE_URL="https://github.com/unified-suite/unified-linux-suite"

# ============================================================
# EXIT CODES
# ============================================================

# Standard codes (0-8)
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_PERMISSION=3
readonly EXIT_NETWORK=4
readonly EXIT_DEPENDENCY=5
readonly EXIT_TOOL_MISSING=6
readonly EXIT_SNAPSHOT_FAILED=7
readonly EXIT_ROLLBACK_REQUIRED=8

# Signal codes
readonly EXIT_USER_ABORT=130        # SIGINT (Ctrl+C)

# Optimization codes (10-19)
readonly EXIT_OPTIMIZATION_FAILED=10
readonly EXIT_KERNEL_PARAM_FAILED=11
readonly EXIT_ZRAM_FAILED=12
readonly EXIT_SWAP_FAILED=13
readonly EXIT_SERVICE_FAILED=14

# Hardware codes (20-29)
readonly EXIT_DRIVER_FAILED=20
readonly EXIT_HARDWARE_UNSUPPORTED=21
readonly EXIT_FIRMWARE_MISSING=22

# App installation codes (30-39)
readonly EXIT_APP_INSTALL_FAILED=30
readonly EXIT_APP_NOT_FOUND=31
readonly EXIT_REPO_FAILED=32

# Security codes (40-49)
readonly EXIT_SECURITY_FAILED=40
readonly EXIT_VAULT_FAILED=41
readonly EXIT_KVM_FAILED=42

# ============================================================
# GLOBAL FLAGS
# ============================================================

declare -g DRY_RUN=${DRY_RUN:-0}
declare -g FORCE_YES=${FORCE_YES:-0}
declare -g VERBOSE=${VERBOSE:-0}
declare -g DEBUG_MODE=${DEBUG_MODE:-0}
declare -g INTERACTIVE=${INTERACTIVE:-1}

# ============================================================
# CLEANUP REGISTRY (LIFO)
# ============================================================

declare -a _CLEANUP_REGISTRY=()

register_cleanup() {
    local func="$1"
    for existing in "${_CLEANUP_REGISTRY[@]}"; do
        [[ "$existing" == "$func" ]] && return 0
    done
    _CLEANUP_REGISTRY+=("$func")
}

_unified_cleanup() {
    local exit_code=$?
    for ((i=${#_CLEANUP_REGISTRY[@]}-1; i>=0; i--)); do
        local func="${_CLEANUP_REGISTRY[i]}"
        if declare -F "$func" &>/dev/null; then
            "$func" 2>/dev/null || true
        fi
    done
    return $exit_code
}

# ============================================================
# ERROR HANDLING
# ============================================================

error_handler() {
    local exit_code="${1:-1}"
    local line_no="${2:-unknown}"
    local func_name="${FUNCNAME[1]:-main}"
    local bash_source="${BASH_SOURCE[1]:-unknown}"

    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m at $func_name ($bash_source:$line_no) exit=$exit_code" >&2

        # Stack trace
        echo "Stack trace:" >&2
        for ((i=1; i<${#FUNCNAME[@]}; i++)); do
            echo "    at ${FUNCNAME[$i]} (${BASH_SOURCE[$i]}:${BASH_LINENO[$((i-1))]})" >&2
        done
    fi
}

# ============================================================
# TRAPS
# ============================================================

trap 'error_handler $? $LINENO' ERR
trap '_unified_cleanup' EXIT
trap 'exit $EXIT_USER_ABORT' INT TERM

# Enable strict mode
set -o pipefail

# ============================================================
# CORE UTILITY FUNCTIONS
# ============================================================

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Require root privileges
require_root() {
    if ! is_root; then
        echo -e "\033[0;31m[ERROR]\033[0m This operation requires root privileges" >&2
        exit $EXIT_PERMISSION
    fi
}

# Check command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Require command
require_command() {
    local cmd="$1"
    local pkg="${2:-$cmd}"
    if ! command_exists "$cmd"; then
        echo -e "\033[0;31m[ERROR]\033[0m Required command not found: $cmd (install: $pkg)" >&2
        exit $EXIT_TOOL_MISSING
    fi
}

# Safe execution wrapper (respects DRY_RUN)
safe_exec() {
    local cmd="$*"
    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "\033[0;36m[DRY-RUN]\033[0m Would execute: $cmd"
        return 0
    fi
    "$@"
}

# Confirmation prompt (respects FORCE_YES and INTERACTIVE)
confirm() {
    local message="$1"
    local default="${2:-n}"

    [[ $FORCE_YES -eq 1 ]] && return 0
    [[ $INTERACTIVE -eq 0 ]] && return 0

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi

    printf "%s" "$prompt"
    read -r response

    case "${response,,}" in
        y|yes) return 0 ;;
        n|no)  return 1 ;;
        "")    [[ "$default" == "y" ]] && return 0 || return 1 ;;
        *)     return 1 ;;
    esac
}

# ============================================================
# SYSTEM DETECTION HELPERS
# ============================================================

# Get total RAM in MB
get_total_ram_mb() {
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

# Get available RAM in MB
get_available_ram_mb() {
    awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo
}

# Get CPU count
get_cpu_count() {
    nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo
}

# Check if system is laptop
is_laptop() {
    [[ -d /sys/class/power_supply/BAT0 ]] || \
    [[ -d /sys/class/power_supply/BAT1 ]] || \
    { [[ -f /sys/class/dmi/id/chassis_type ]] && \
    grep -qE "^(8|9|10|11|14)$" /sys/class/dmi/id/chassis_type 2>/dev/null; }
}

# Get storage type for device
get_storage_type() {
    local device="${1:-sda}"
    device="${device##*/}"  # Remove path prefix

    local rotational="/sys/block/${device}/queue/rotational"
    if [[ -f "$rotational" ]]; then
        if [[ $(cat "$rotational") -eq 0 ]]; then
            if [[ "$device" == nvme* ]]; then
                echo "nvme"
            else
                echo "ssd"
            fi
        else
            echo "hdd"
        fi
    else
        echo "unknown"
    fi
}

# Get primary storage device
get_primary_storage() {
    lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1; exit}'
}

# ============================================================
# BANNER
# ============================================================

print_banner() {
    echo -e "\033[1;36m"
    cat << 'EOF'
 _   _ _   _ ___ _____ ___ _____ ____    ____  _   _ ___ _____ _____
| | | | \ | |_ _|  ___|_ _| ____|  _ \  / ___|| | | |_ _|_   _| ____|
| | | |  \| || || |_   | ||  _| | | | | \___ \| | | || |  | | |  _|
| |_| | |\  || ||  _|  | || |___| |_| |  ___) | |_| || |  | | | |___
 \___/|_| \_|___|_|   |___|_____|____/  |____/ \___/|___| |_| |_____|
EOF
    echo -e "           v${SUITE_VERSION} - ${SUITE_CODENAME}\033[0m"
    echo ""
}
