#!/usr/bin/env bash
#
# demo_pkg_universal.sh - Demonstration of Universal Package Manager Module
#
# This script demonstrates the capabilities of the pkg_universal.sh module
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Source dependencies
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/os_detect.sh"
source "$LIB_DIR/pkg.sh"
source "$LIB_DIR/pkg_universal.sh"

# Initialize
logging_init
detect_os

# ============================================================================
# Demo Functions
# ============================================================================

demo_detection() {
    log_section "Detection Demo"

    echo "Detecting all universal package managers..."
    universal_detect_all

    echo ""
    echo "Individual checks:"
    universal_has_flatpak && echo "  ✓ Flatpak is available" || echo "  ✗ Flatpak not found"
    universal_has_snap && echo "  ✓ Snap is available" || echo "  ✗ Snap not found"
    universal_has_nix && echo "  ✓ Nix is available" || echo "  ✗ Nix not found"
    universal_has_homebrew && echo "  ✓ Homebrew is available" || echo "  ✗ Homebrew not found"
    universal_has_appimage_support && echo "  ✓ AppImage support available" || echo "  ✗ AppImage support not found"

    if is_arch; then
        universal_has_aur_helper && echo "  ✓ AUR helper is available: $(universal_get_aur_helper)" || echo "  ✗ AUR helper not found"
    fi

    echo ""
}

demo_status() {
    log_section "Status Demo"
    universal_status
}

demo_package_counts() {
    log_section "Package Count Demo"
    universal_package_counts
}

demo_config() {
    log_section "Configuration Demo"

    echo "Configuration file: $UNIVERSAL_CONFIG_FILE"
    echo ""

    echo "Current settings:"
    echo "  FLATPAK_ENABLE_BETA: $(universal_config_get FLATPAK_ENABLE_BETA)"
    echo "  NIX_ENABLE_FLAKES: $(universal_config_get NIX_ENABLE_FLAKES)"
    echo "  AUR_HELPER: $(universal_config_get AUR_HELPER)"
    echo ""
}

demo_install_help() {
    log_section "Installation Help"

    echo "To install universal package managers:"
    echo ""
    echo "  Flatpak:   universal_install flatpak"
    echo "  Snap:      universal_install snap"
    echo "  Nix:       universal_install nix"
    echo "  Homebrew:  universal_install homebrew"
    echo "  AppImage:  universal_install appimage"

    if is_arch; then
        echo "  AUR:       universal_install aur"
    fi

    echo ""
    echo "Package installation examples:"
    echo ""
    echo "  Flatpak:   flatpak install flathub org.mozilla.firefox"
    echo "  Snap:      snap install firefox"
    echo "  Nix:       universal_nix_install firefox"
    echo "  Homebrew:  universal_brew_install neofetch"

    if is_arch; then
        echo "  AUR:       universal_aur_install google-chrome"
    fi

    echo ""
}

# ============================================================================
# Main Demo
# ============================================================================

main() {
    log_section "Universal Package Manager Module Demo"

    echo "This demo showcases the pkg_universal.sh module capabilities."
    echo "Distribution: $OS_PRETTY"
    echo "Package Manager: $PKG_MANAGER"
    echo ""

    # Run demos
    demo_detection
    demo_status
    demo_package_counts
    demo_config
    demo_install_help

    log_section "Demo Complete"
    echo "For more information, see the documentation in pkg_universal.sh"
    echo ""
}

main "$@"
