#!/usr/bin/env bash
#
# generic.sh - Generic/fallback backend for Ultimate Linux Suite
#
# Used when distro cannot be identified or is unsupported
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_GENERIC_LOADED:-}" ]] && return 0
readonly _BACKEND_GENERIC_LOADED=1

# Backend identification
readonly BACKEND_NAME="generic"
readonly BACKEND_DESC="Generic Linux (fallback)"

# Package name mappings for generic systems
# Returns the most common package name
backend_pkg_name() {
    local generic="$1"
    case "$generic" in
        build-essential) echo "gcc make" ;;
        kernel-headers)  echo "kernel-headers" ;;
        *)               echo "$generic" ;;
    esac
}

# Check if this backend can handle the current system
backend_can_handle() {
    # Generic always returns true as fallback
    return 0
}

# Pre-install hooks
backend_pre_install() {
    log_warn "Using generic backend - some features may not work correctly"
}

# Post-install hooks
backend_post_install() {
    :
}

# Get recommended repos (none for generic)
backend_get_repos() {
    :
}

# Special handling for this distro
backend_special_setup() {
    log_info "No special setup for generic backend"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    log_warn "Driver installation for '$driver_type' may require manual steps on this system"
}
