#!/usr/bin/env bash
#
# Ultimate Linux Suite - Main Entry Point
#
# A comprehensive Linux system optimization and management toolkit.
# Run with: sudo ./suite.sh
#
# This script avoids `set -e` to handle errors gracefully and provide
# meaningful error messages instead of silent failures.
#

# Use nounset to catch undefined variables, but not errexit
set -u
set -o pipefail

# Resolve script directory (handles symlinks)
_get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir

    while [[ -L "$source" ]]; do
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="$dir/$source"
    done

    cd -P "$(dirname "$source")" && pwd
}

# Suite root directory
export SUITE_ROOT="$(_get_script_dir)"

# ============================================================================
# Source all library files (order matters - logging first)
# ============================================================================

source "$SUITE_ROOT/lib/logging.sh"
source "$SUITE_ROOT/lib/utils.sh"
source "$SUITE_ROOT/lib/os_detect.sh"
source "$SUITE_ROOT/lib/hardware_detect.sh"
source "$SUITE_ROOT/lib/pkg.sh"
source "$SUITE_ROOT/lib/menu.sh"
source "$SUITE_ROOT/lib/queue.sh"

# ============================================================================
# Source application database
# ============================================================================

source "$SUITE_ROOT/apps/database.sh"

# ============================================================================
# Source all modules
# ============================================================================

source "$SUITE_ROOT/modules/apps.sh"
source "$SUITE_ROOT/modules/drivers.sh"
source "$SUITE_ROOT/modules/optimize.sh"
source "$SUITE_ROOT/modules/recovery.sh"
source "$SUITE_ROOT/modules/services.sh"
source "$SUITE_ROOT/modules/firewall.sh"
source "$SUITE_ROOT/modules/setup_profiles.sh"

# ============================================================================
# Source menus
# ============================================================================

source "$SUITE_ROOT/menus/main_menu.sh"
source "$SUITE_ROOT/menus/apps_menu.sh"
source "$SUITE_ROOT/menus/drivers_menu.sh"
source "$SUITE_ROOT/menus/optimize_menu.sh"
source "$SUITE_ROOT/menus/recovery_menu.sh"

# ============================================================================
# Source backend for current distro (optional - provides enhanced mappings)
# ============================================================================

_load_backend() {
    local backend_dir="$SUITE_ROOT/backends"
    local backend_file=""

    # Determine which backend to load based on ULS_DISTRO
    case "${ULS_DISTRO:-generic}" in
        arch)     backend_file="$backend_dir/arch.sh" ;;
        debian)   backend_file="$backend_dir/debian.sh" ;;
        ubuntu)   backend_file="$backend_dir/ubuntu.sh" ;;
        mint)     backend_file="$backend_dir/mint.sh" ;;
        fedora)   backend_file="$backend_dir/fedora.sh" ;;
        opensuse) backend_file="$backend_dir/opensuse.sh" ;;
        kali)     backend_file="$backend_dir/kali.sh" ;;
        parrot)   backend_file="$backend_dir/parrot.sh" ;;
        *)        backend_file="$backend_dir/generic.sh" ;;
    esac

    if [[ -f "$backend_file" ]]; then
        # shellcheck source=/dev/null
        source "$backend_file"
        log_debug "Loaded backend: $backend_file"
    fi
}

# ============================================================================
# Parse command line arguments
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_help
                exit 0
                ;;
            -v|--version)
                print_version
                exit 0
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            --non-interactive)
                # For CI/testing - just verify script loads
                export NON_INTERACTIVE=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Check system requirements
# ============================================================================

check_requirements() {
    # Bash version check
    if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
        log_error "Bash 4.0+ required (found: $BASH_VERSION)"
        exit 1
    fi

    # Basic commands
    local missing=()
    for cmd in grep sed awk cat; do
        if ! cmd_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# ============================================================================
# Initialize the suite
# ============================================================================

initialize() {
    # Initialize logging first
    logging_init

    log_debug "Initializing $SUITE_NAME v$SUITE_VERSION"
    log_debug "Suite root: $SUITE_ROOT"

    # Detect OS
    log_debug "Detecting operating system..."
    detect_os

    # Load appropriate backend
    _load_backend

    # Detect hardware
    log_debug "Detecting hardware..."
    detect_hardware

    # Initialize queue system
    queue_init

    # Initialize modules (allow failures - they're optional)
    apps_init 2>/dev/null || true
    drivers_init 2>/dev/null || true
    optimize_init 2>/dev/null || true
    recovery_init 2>/dev/null || true
    services_init 2>/dev/null || true
    firewall_init 2>/dev/null || true
    profiles_init 2>/dev/null || true

    log_debug "Initialization complete"
}

# ============================================================================
# Cleanup on exit
# ============================================================================

cleanup() {
    log_debug "Cleanup called"
    # Remove temp files if any
    rm -f /tmp/suite-*.tmp 2>/dev/null || true
}

# ============================================================================
# Main function
# ============================================================================

main() {
    # Parse arguments
    parse_args "$@"

    # Check requirements
    check_requirements

    # Handle root requirement with helpful message
    if ! is_root; then
        log_error "This tool requires root privileges for most operations."
        log_info "Run with: sudo $0"
        echo ""
        log_info "Some read-only operations may work without root."
        if ! confirm "Continue without root? (Limited functionality)"; then
            exit 1
        fi
    fi

    # Set up cleanup trap
    trap cleanup EXIT

    # Initialize
    initialize

    # Non-interactive mode for CI testing
    if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        log_info "Non-interactive mode - verification successful"
        print_os_info
        exit 0
    fi

    # Run main menu
    run_main_menu
}

# ============================================================================
# Run main
# ============================================================================

main "$@"
