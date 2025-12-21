#!/usr/bin/env bash
# pkg_aur.sh - Comprehensive AUR (Arch User Repository) support
# Part of Ultimate Linux Suite
#
# This module provides complete AUR package management functionality
# for Arch-based distributions (Arch, Manjaro, EndeavourOS, etc.)
#
# Dependencies: logging.sh, os_detect.sh, pkg.sh

# Guard against multiple sourcing
[[ -n "${_PKG_AUR_LOADED:-}" ]] && return 0
readonly _PKG_AUR_LOADED=1

# Source dependencies
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/logging.sh" 2>/dev/null || source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/logging.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/os_detect.sh" 2>/dev/null || source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/os_detect.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/pkg.sh" 2>/dev/null || source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/pkg.sh"

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

# List of supported AUR helpers in order of preference
declare -ga AUR_HELPERS=("paru" "yay" "pikaur" "trizen" "aurman")

# Currently detected AUR helper
declare -g AUR_HELPER=""

# AUR build configuration
declare -gA AUR_BUILD_CONFIG=(
    [clean_build]=1
    [keep_src]=0
    [skip_pgp]=0
    [build_dir]="$HOME/.cache/ultimate-linux-suite/aur-builds"
)

# AUR API endpoint
readonly AUR_RPC_URL="https://aur.archlinux.org/rpc/v5"
readonly AUR_GIT_URL="https://aur.archlinux.org"

#==============================================================================
# SYSTEM AVAILABILITY CHECKS
#==============================================================================

#------------------------------------------------------------------------------
# Check if AUR is available on this system
# Returns: 0 if on Arch-based system, 1 otherwise
#------------------------------------------------------------------------------
aur_is_available() {
    [[ "$OS_FAMILY" == "arch" ]] || [[ "$PKG_MANAGER" == "pacman" ]]
}

#==============================================================================
# AUR HELPER DETECTION AND MANAGEMENT
#==============================================================================

#------------------------------------------------------------------------------
# Detect installed AUR helper
# Sets AUR_HELPER global variable
# Returns: 0 if helper found, 1 otherwise
#------------------------------------------------------------------------------
aur_detect_helper() {
    for helper in "${AUR_HELPERS[@]}"; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            log_debug "Detected AUR helper: $helper"
            return 0
        fi
    done
    log_debug "No AUR helper detected"
    return 1
}

#------------------------------------------------------------------------------
# Get the current AUR helper
# Prints: Name of AUR helper or empty string
#------------------------------------------------------------------------------
aur_get_helper() {
    if [[ -z "$AUR_HELPER" ]]; then
        aur_detect_helper
    fi
    echo "$AUR_HELPER"
}

#==============================================================================
# AUR HELPER INSTALLATION
#==============================================================================

#------------------------------------------------------------------------------
# Install an AUR helper from source
# Arguments:
#   $1 - Helper name (default: paru)
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_install_helper() {
    local helper="${1:-paru}"

    if ! aur_is_available; then
        log_error "AUR helpers are only available on Arch-based systems"
        return 1
    fi

    log_info "Installing AUR helper: $helper"

    # Check if helper is already installed
    if command -v "$helper" &>/dev/null; then
        log_success "$helper is already installed"
        AUR_HELPER="$helper"
        return 0
    fi

    # Ensure base-devel and git are installed
    log_info "Ensuring base-devel and git are installed..."
    if ! sudo pacman -S --needed --noconfirm base-devel git; then
        log_error "Failed to install base-devel and git"
        return 1
    fi

    # Create temporary build directory
    local build_dir
    build_dir=$(mktemp -d)
    log_debug "Using temporary build directory: $build_dir"

    # Clone AUR helper repository
    log_info "Cloning $helper from AUR..."
    if ! git clone "${AUR_GIT_URL}/${helper}.git" "$build_dir/$helper"; then
        log_error "Failed to clone $helper repository"
        rm -rf "$build_dir"
        return 1
    fi

    # Build and install
    log_info "Building and installing $helper..."
    if ! (cd "$build_dir/$helper" && makepkg -si --noconfirm); then
        log_error "Failed to build and install $helper"
        rm -rf "$build_dir"
        return 1
    fi

    # Cleanup
    log_debug "Cleaning up build directory"
    rm -rf "$build_dir"

    # Verify installation
    if command -v "$helper" &>/dev/null; then
        AUR_HELPER="$helper"
        log_success "$helper installed successfully"
        return 0
    else
        log_error "Installation completed but $helper command not found"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Install paru AUR helper (recommended, written in Rust)
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_install_paru() {
    aur_install_helper "paru"
}

#------------------------------------------------------------------------------
# Install yay AUR helper (popular, written in Go)
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_install_yay() {
    aur_install_helper "yay"
}

#==============================================================================
# PACKAGE OPERATIONS
#==============================================================================

#------------------------------------------------------------------------------
# Install AUR package(s)
# Arguments:
#   $@ - Package names to install
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_install() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for installation"
        return 1
    fi

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    if ! aur_detect_helper; then
        log_error "No AUR helper installed. Run aur_install_helper first."
        return 1
    fi

    log_info "Installing AUR packages: ${packages[*]}"

    case "$AUR_HELPER" in
        paru)
            paru -S --noconfirm "${packages[@]}"
            ;;
        yay)
            yay -S --noconfirm "${packages[@]}"
            ;;
        pikaur)
            pikaur -S --noconfirm "${packages[@]}"
            ;;
        trizen)
            trizen -S --noconfirm --noedit "${packages[@]}"
            ;;
        aurman)
            aurman -S --noconfirm --noedit "${packages[@]}"
            ;;
        *)
            $AUR_HELPER -S "${packages[@]}"
            ;;
    esac

    local ret=$?
    if [[ $ret -eq 0 ]]; then
        log_success "AUR packages installed successfully"
    else
        log_error "Failed to install AUR packages"
    fi
    return $ret
}

#------------------------------------------------------------------------------
# Remove AUR package(s)
# Arguments:
#   $@ - Package names to remove
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_remove() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for removal"
        return 1
    fi

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    log_info "Removing AUR packages: ${packages[*]}"

    # Use pacman directly for removal
    sudo pacman -Rns --noconfirm "${packages[@]}"

    local ret=$?
    if [[ $ret -eq 0 ]]; then
        log_success "AUR packages removed successfully"
    else
        log_error "Failed to remove AUR packages"
    fi
    return $ret
}

#------------------------------------------------------------------------------
# Update AUR packages
# Arguments:
#   $@ - Optional: specific packages to update (default: all)
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_update() {
    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    if ! aur_detect_helper; then
        log_error "No AUR helper installed. Run aur_install_helper first."
        return 1
    fi

    log_info "Updating AUR packages..."

    if [[ $# -gt 0 ]]; then
        # Update specific packages
        case "$AUR_HELPER" in
            paru)
                paru -S --noconfirm "$@"
                ;;
            yay)
                yay -S --noconfirm "$@"
                ;;
            *)
                $AUR_HELPER -S "$@"
                ;;
        esac
    else
        # Update all AUR packages
        case "$AUR_HELPER" in
            paru)
                paru -Syu --noconfirm
                ;;
            yay)
                yay -Syu --noconfirm
                ;;
            pikaur)
                pikaur -Syu --noconfirm
                ;;
            trizen)
                trizen -Syu --noconfirm --noedit
                ;;
            aurman)
                aurman -Syu --noconfirm --noedit
                ;;
            *)
                $AUR_HELPER -Syu
                ;;
        esac
    fi

    local ret=$?
    if [[ $ret -eq 0 ]]; then
        log_success "AUR packages updated successfully"
    else
        log_error "Failed to update AUR packages"
    fi
    return $ret
}

#------------------------------------------------------------------------------
# Search AUR for packages
# Arguments:
#   $1 - Search query
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_search() {
    local query="$1"

    if [[ -z "$query" ]]; then
        log_error "No search query specified"
        return 1
    fi

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    if ! aur_detect_helper; then
        log_warning "No AUR helper found, using API search"
        # Search via API
        local response
        response=$(curl -s "${AUR_RPC_URL}/search?arg=${query}")
        echo "$response" | grep -o '"Name":"[^"]*"' | sed 's/"Name":"//;s/"//'
        return 0
    fi

    case "$AUR_HELPER" in
        paru)
            paru -Ss "$query"
            ;;
        yay)
            yay -Ss "$query"
            ;;
        *)
            $AUR_HELPER -Ss "$query"
            ;;
    esac
}

#------------------------------------------------------------------------------
# Get package info from AUR
# Arguments:
#   $1 - Package name
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_info() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "No package specified"
        return 1
    fi

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    if ! aur_detect_helper; then
        log_warning "No AUR helper found, using API info"
        # Get info via API
        curl -s "${AUR_RPC_URL}/info?arg[]=${pkg}"
        return 0
    fi

    case "$AUR_HELPER" in
        paru)
            paru -Si "$pkg"
            ;;
        yay)
            yay -Si "$pkg"
            ;;
        *)
            $AUR_HELPER -Si "$pkg"
            ;;
    esac
}

#==============================================================================
# AUR PACKAGE VERIFICATION
#==============================================================================

#------------------------------------------------------------------------------
# Check if package exists in AUR
# Arguments:
#   $1 - Package name
# Returns: 0 if exists, 1 otherwise
#------------------------------------------------------------------------------
aur_package_exists() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "No package specified"
        return 1
    fi

    if ! aur_is_available; then
        return 1
    fi

    # Query AUR RPC API
    local response
    response=$(curl -s "${AUR_RPC_URL}/info?arg[]=${pkg}")

    if echo "$response" | grep -q '"resultcount":1'; then
        log_debug "Package $pkg exists in AUR"
        return 0
    else
        log_debug "Package $pkg not found in AUR"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Check if AUR package is installed
# Arguments:
#   $1 - Package name
# Returns: 0 if installed, 1 otherwise
#------------------------------------------------------------------------------
aur_is_installed() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "No package specified"
        return 1
    fi

    if ! aur_is_available; then
        return 1
    fi

    # Check if package is installed and is foreign (from AUR)
    pacman -Qm "$pkg" &>/dev/null
}

#------------------------------------------------------------------------------
# List installed AUR packages
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_list_installed() {
    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    # List all foreign packages (typically from AUR)
    pacman -Qm
}

#==============================================================================
# PKGBUILD OPERATIONS
#==============================================================================

#------------------------------------------------------------------------------
# View PKGBUILD before installation
# Arguments:
#   $1 - Package name
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_show_pkgbuild() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "No package specified"
        return 1
    fi

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    log_info "Fetching PKGBUILD for $pkg..."

    # Fetch and display PKGBUILD from AUR
    local pkgbuild
    pkgbuild=$(curl -sL "${AUR_GIT_URL}/cgit/aur.git/plain/PKGBUILD?h=${pkg}")

    if [[ -z "$pkgbuild" ]]; then
        log_error "Failed to fetch PKGBUILD for $pkg"
        return 1
    fi

    echo "$pkgbuild"
}

#------------------------------------------------------------------------------
# Download PKGBUILD without installing
# Arguments:
#   $1 - Package name
#   $2 - Destination directory (default: current directory)
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_download_pkgbuild() {
    local pkg="$1"
    local dest="${2:-.}"

    if [[ -z "$pkg" ]]; then
        log_error "No package specified"
        return 1
    fi

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    log_info "Downloading PKGBUILD for $pkg to $dest..."

    # Clone AUR repository
    if git clone "${AUR_GIT_URL}/${pkg}.git" "$dest/$pkg"; then
        log_success "PKGBUILD downloaded to $dest/$pkg"
        return 0
    else
        log_error "Failed to download PKGBUILD for $pkg"
        return 1
    fi
}

#==============================================================================
# BUILD CONFIGURATION
#==============================================================================

#------------------------------------------------------------------------------
# Set AUR build configuration option
# Arguments:
#   $1 - Configuration key
#   $2 - Configuration value
#------------------------------------------------------------------------------
aur_config_set() {
    local key="$1"
    local value="$2"

    if [[ -z "$key" ]]; then
        log_error "No configuration key specified"
        return 1
    fi

    AUR_BUILD_CONFIG["$key"]="$value"
    log_debug "Set AUR config: $key=$value"
}

#------------------------------------------------------------------------------
# Get AUR build configuration option
# Arguments:
#   $1 - Configuration key
# Prints: Configuration value
#------------------------------------------------------------------------------
aur_config_get() {
    local key="$1"

    if [[ -z "$key" ]]; then
        log_error "No configuration key specified"
        return 1
    fi

    echo "${AUR_BUILD_CONFIG[$key]}"
}

#------------------------------------------------------------------------------
# Clean old build directories
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_clean_builds() {
    local build_dir="${AUR_BUILD_CONFIG[build_dir]}"

    if [[ ! -d "$build_dir" ]]; then
        log_info "No build directory to clean"
        return 0
    fi

    log_info "Cleaning AUR build directory: $build_dir"

    if rm -rf "${build_dir:?}"/*; then
        log_success "Build directory cleaned"
        return 0
    else
        log_error "Failed to clean build directory"
        return 1
    fi
}

#==============================================================================
# AUR STATISTICS
#==============================================================================

#------------------------------------------------------------------------------
# Get AUR package statistics
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_stats() {
    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    echo "=== AUR Package Statistics ==="

    # Count installed AUR packages
    local installed_count
    installed_count=$(pacman -Qm 2>/dev/null | wc -l)
    echo "Installed AUR packages: $installed_count"

    # Show AUR helper
    if aur_detect_helper; then
        echo "AUR helper: $AUR_HELPER"
    else
        echo "AUR helper: none"
    fi

    # Show total size of AUR packages
    if [[ $installed_count -gt 0 ]]; then
        echo ""
        echo "Top 10 largest AUR packages:"
        pacman -Qm | while read -r pkg _; do
            size=$(pacman -Qi "$pkg" 2>/dev/null | grep "Installed Size" | awk '{print $4, $5}')
            echo "  $pkg: $size"
        done | sort -k2 -hr | head -10
    fi

    # Show recently installed
    echo ""
    echo "Recently installed AUR packages:"
    expac -Q '%l\t%n' 2>/dev/null | grep -f <(pacman -Qm | awk '{print $1}') | sort -rn | head -5 | awk '{print "  " $2}'
}

#==============================================================================
# ORPHAN PACKAGE MANAGEMENT
#==============================================================================

#------------------------------------------------------------------------------
# List orphan packages (no longer required as dependencies)
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_list_orphans() {
    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    log_info "Listing orphan packages..."
    pacman -Qdt 2>/dev/null

    local count
    count=$(pacman -Qdtq 2>/dev/null | wc -l)

    if [[ $count -eq 0 ]]; then
        log_info "No orphan packages found"
    else
        log_info "Found $count orphan package(s)"
    fi
}

#------------------------------------------------------------------------------
# Remove orphan packages
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
aur_remove_orphans() {
    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        return 1
    fi

    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null)

    if [[ -z "$orphans" ]]; then
        log_info "No orphan packages to remove"
        return 0
    fi

    local count
    count=$(echo "$orphans" | wc -l)
    log_info "Removing $count orphan package(s)..."

    # shellcheck disable=SC2086
    if sudo pacman -Rns --noconfirm $orphans; then
        log_success "Orphan packages removed successfully"
        return 0
    else
        log_error "Failed to remove orphan packages"
        return 1
    fi
}

#==============================================================================
# ERROR HANDLING AND LOGGING
#==============================================================================

#------------------------------------------------------------------------------
# Wrapper for AUR operations with proper error handling
# Arguments:
#   $1 - Command name
#   $@ - Command arguments
# Returns: Command exit status
#------------------------------------------------------------------------------
_aur_run() {
    local cmd="$1"
    shift

    if ! aur_is_available; then
        log_error "AUR is only available on Arch-based systems"
        log_error "Detected OS: $OS_NAME (Family: $OS_FAMILY)"
        return 1
    fi

    log_debug "AUR: $cmd $*"

    # Execute command
    "$cmd" "$@"
    local ret=$?

    if [[ $ret -ne 0 ]]; then
        log_error "AUR operation failed: $cmd (exit code: $ret)"
    fi

    return $ret
}

#==============================================================================
# INITIALIZATION
#==============================================================================

# Auto-detect AUR helper on module load
if aur_is_available; then
    aur_detect_helper
fi

#==============================================================================
# DOCUMENTATION AND USAGE
#==============================================================================

: <<'DOCUMENTATION'
================================================================================
AUR Package Management Module
================================================================================

OVERVIEW:
    This module provides comprehensive support for the Arch User Repository
    (AUR), enabling installation and management of AUR packages on Arch-based
    Linux distributions.

REQUIREMENTS:
    - Arch-based distribution (Arch Linux, Manjaro, EndeavourOS, etc.)
    - base-devel package group
    - git

SUPPORTED AUR HELPERS:
    - paru (recommended, Rust-based, modern features)
    - yay (popular, Go-based, feature-rich)
    - pikaur (Python-based, user-friendly)
    - trizen (Perl-based, lightweight)
    - aurman (feature-rich, development paused)

BASIC USAGE:
    # Check if AUR is available
    aur_is_available

    # Install an AUR helper (recommended first step)
    aur_install_paru
    # or
    aur_install_yay
    # or
    aur_install_helper <helper_name>

    # Install AUR packages
    aur_install package1 package2

    # Update AUR packages
    aur_update

    # Search for packages
    aur_search "search term"

    # Get package information
    aur_info package_name

    # Remove packages
    aur_remove package_name

ADVANCED USAGE:
    # Check if package exists in AUR
    if aur_package_exists "package_name"; then
        aur_install "package_name"
    fi

    # View PKGBUILD before installing
    aur_show_pkgbuild package_name

    # Download PKGBUILD for manual review/modification
    aur_download_pkgbuild package_name /tmp/builds

    # List installed AUR packages
    aur_list_installed

    # Check if specific package is installed
    if aur_is_installed "package_name"; then
        echo "Package is installed"
    fi

    # Get statistics
    aur_stats

    # Manage orphan packages
    aur_list_orphans
    aur_remove_orphans

CONFIGURATION:
    # Set build directory
    aur_config_set build_dir "/custom/path"

    # Clean build directory
    aur_clean_builds

EXAMPLES:
    # Example 1: Install a package from AUR
    aur_install_paru
    aur_install visual-studio-code-bin

    # Example 2: Update all AUR packages
    aur_update

    # Example 3: Search and install
    aur_search "browser"
    aur_install brave-bin

    # Example 4: Review before installing
    aur_show_pkgbuild package_name | less
    aur_install package_name

    # Example 5: Clean up system
    aur_remove_orphans
    aur_clean_builds

RETURN CODES:
    0 - Success
    1 - Error (not Arch-based system, helper not found, operation failed)

NOTES:
    - Always review PKGBUILDs before installing for security
    - AUR packages are user-maintained and not officially supported
    - Some packages may require manual intervention during build
    - Keep your AUR helper updated for best compatibility

SECURITY CONSIDERATIONS:
    - AUR packages are user-submitted and not verified by Arch developers
    - Always review PKGBUILD and .install files before building
    - Use aur_show_pkgbuild to inspect packages before installation
    - Consider using paru or yay which offer better security features

TROUBLESHOOTING:
    Problem: "No AUR helper installed"
    Solution: Run aur_install_paru or aur_install_yay

    Problem: Build fails with PGP key errors
    Solution: Import the required PGP keys or set skip_pgp=1

    Problem: Out of disk space during build
    Solution: Run aur_clean_builds and clear pacman cache

    Problem: Package conflicts
    Solution: Check with pacman -Si and resolve manually

================================================================================
DOCUMENTATION

log_debug "AUR module loaded successfully"
