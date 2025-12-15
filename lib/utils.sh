#!/usr/bin/env bash
#
# utils.sh - Utility functions for Ultimate Linux Suite
#

# Prevent multiple sourcing
[[ -n "${_UTILS_LOADED:-}" ]] && return 0
readonly _UTILS_LOADED=1

# Suite version
readonly SUITE_VERSION="1.1.0"
readonly SUITE_NAME="Ultimate Linux Suite"

# ============================================================================
# Core utility functions
# ============================================================================

# Check if running as root
is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

# Alias for consistency
uls_is_root() {
    is_root
}

# Require root or exit with helpful message
require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges."
        log_info "Please run with: sudo $0"
        exit 1
    fi
}

# Alias with uls_ prefix
uls_require_root() {
    require_root
}

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Alias with uls_ prefix
uls_command_exists() {
    cmd_exists "$@"
}

# Require a command or warn (does not exit)
require_cmd() {
    local cmd="$1"
    local pkg="${2:-$cmd}"
    if ! cmd_exists "$cmd"; then
        log_warn "Command '$cmd' not found. Install package: $pkg"
        return 1
    fi
    return 0
}

# ============================================================================
# User interaction functions
# ============================================================================

# Prompt for yes/no confirmation
# Usage: confirm "Question?" [default]
# Returns: 0 for yes, 1 for no
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    local response

    if [[ "${default,,}" == "y" ]]; then
        printf "%s [Y/n]: " "$prompt"
    else
        printf "%s [y/N]: " "$prompt"
    fi

    read -r response
    response="${response:-$default}"

    [[ "${response,,}" =~ ^y(es)?$ ]]
}

# Alias with uls_ prefix
uls_confirm() {
    confirm "$@"
}

# Press any key to continue
pause() {
    local msg="${1:-Press any key to continue...}"
    printf "%s" "$msg"
    read -r -n 1 -s
    printf "\n"
}

# ============================================================================
# Download helpers
# ============================================================================

# Download a file using curl or wget
# Usage: uls_download URL DESTINATION
uls_download() {
    local url="$1"
    local dest="$2"

    if [[ -z "$url" ]] || [[ -z "$dest" ]]; then
        log_error "Usage: uls_download URL DESTINATION"
        return 1
    fi

    if cmd_exists curl; then
        curl -fsSL -o "$dest" "$url"
    elif cmd_exists wget; then
        wget -q -O "$dest" "$url"
    else
        log_error "Neither curl nor wget available"
        return 1
    fi
}

# Download and execute a script (with confirmation)
uls_download_and_run() {
    local url="$1"
    local tmpfile
    tmpfile=$(mktemp)

    log_info "Downloading: $url"

    if ! uls_download "$url" "$tmpfile"; then
        rm -f "$tmpfile"
        return 1
    fi

    log_warn "About to execute downloaded script"
    if confirm "Review script before execution?"; then
        ${PAGER:-less} "$tmpfile"
    fi

    if confirm "Execute script?"; then
        bash "$tmpfile"
        local ret=$?
        rm -f "$tmpfile"
        return $ret
    fi

    rm -f "$tmpfile"
    return 1
}

# ============================================================================
# File backup helpers
# ============================================================================

# Backup a file with timestamp
# Usage: uls_backup FILE
uls_backup() {
    local file="$1"
    local suffix="uls-backup-$(date +%Y%m%d%H%M%S)"

    if [[ ! -f "$file" ]]; then
        log_debug "No file to backup: $file"
        return 0
    fi

    cp -p "$file" "${file}.${suffix}"
    log_debug "Backed up: $file -> ${file}.${suffix}"
}

# ============================================================================
# Version and help
# ============================================================================

# Print version
print_version() {
    printf "%s v%s\n" "$SUITE_NAME" "$SUITE_VERSION"
}

# Print help
print_help() {
    cat << EOF
$SUITE_NAME v$SUITE_VERSION

A comprehensive Linux system optimization and management toolkit.

Usage: sudo ./suite.sh [OPTIONS]

Options:
  -h, --help      Show this help message
  -v, --version   Show version
  --debug         Enable debug output

Modules:
  - Apps          Install recommended applications
  - Drivers       Manage hardware drivers
  - Optimization  System performance tuning
  - Recovery      System repair tools
  - Profiles      Quick setup profiles

Supported distributions:
  - Arch Linux, Manjaro, EndeavourOS
  - Debian, Ubuntu, Linux Mint
  - Fedora, RHEL, CentOS, Rocky, AlmaLinux
  - openSUSE Leap, openSUSE Tumbleweed
  - Kali Linux
  - Parrot OS

EOF
}

# ============================================================================
# Terminal utilities
# ============================================================================

# Get terminal width
term_width() {
    tput cols 2>/dev/null || echo 80
}

# Center text
center_text() {
    local text="$1"
    local width
    width=$(term_width)
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%*s%s\n" "$padding" "" "$text"
}

# ============================================================================
# String utilities
# ============================================================================

# Trim whitespace from string
uls_trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Check if string is empty or whitespace
uls_is_empty() {
    local trimmed
    trimmed=$(uls_trim "$1")
    [[ -z "$trimmed" ]]
}

# ============================================================================
# Array utilities
# ============================================================================

# Check if array contains element
# Usage: uls_array_contains ELEMENT "${ARRAY[@]}"
uls_array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# ============================================================================
# System information
# ============================================================================

# Get system uptime in human-readable format
uls_uptime() {
    uptime -p 2>/dev/null || uptime | sed 's/.*up/up/'
}

# Get available disk space on root partition
uls_disk_free() {
    df -h / 2>/dev/null | awk 'NR==2 {print $4}'
}

# Get memory usage percentage
uls_memory_usage() {
    free 2>/dev/null | awk '/Mem:/ {printf "%.0f%%", $3/$2 * 100}'
}
