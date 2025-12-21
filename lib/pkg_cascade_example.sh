#!/usr/bin/env bash
#
# pkg_cascade_example.sh - Usage examples for the cascade installation system
#
# This file demonstrates how to use the pkg_cascade.sh module

# Source required modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/pkg.sh"
source "${SCRIPT_DIR}/pkg_cascade.sh"

# ============================================================================
# Example 1: Basic Installation
# ============================================================================

example_basic_installation() {
    log_section "Example 1: Basic Installation"

    # Install Firefox using cascade method
    # Will try: native → flatpak → snap in order
    pkg_cascade_install firefox

    # Check what method was used
    local method
    method=$(pkg_cascade_verify firefox)
    log_info "Firefox installed via: $method"

    # Get version
    local version
    version=$(pkg_cascade_version firefox)
    log_info "Firefox version: $version"
}

# ============================================================================
# Example 2: Preferred Method Installation
# ============================================================================

example_preferred_method() {
    log_section "Example 2: Installing with Preferred Method"

    # Prefer Flatpak installation for security/sandboxing
    pkg_cascade_install discord flatpak

    # Or prefer native for better system integration
    pkg_cascade_install vlc native
}

# ============================================================================
# Example 3: Batch Installation
# ============================================================================

example_batch_installation() {
    log_section "Example 3: Batch Installation"

    # Install multiple applications at once
    local apps=(
        firefox
        vlc
        gimp
        telegram
        keepassxc
    )

    pkg_cascade_batch "${apps[@]}"
}

# ============================================================================
# Example 4: Custom App Definition
# ============================================================================

example_custom_app() {
    log_section "Example 4: Custom Application Definition"

    # Define installation methods for custom app
    pkg_cascade_define my-custom-app \
        "native:custom-pkg|flatpak:com.example.CustomApp|snap:custom-app"

    # Show available methods
    pkg_cascade_show_methods my-custom-app

    # Install the custom app
    # pkg_cascade_install my-custom-app
}

# ============================================================================
# Example 5: AppImage Installation
# ============================================================================

example_appimage() {
    log_section "Example 5: AppImage Installation"

    # Install AppImage manually (example with balenaEtcher)
    local app_url="https://github.com/balena-io/etcher/releases/download/v1.18.11/balenaEtcher-1.18.11-x64.AppImage"
    local icon_url="https://raw.githubusercontent.com/balena-io/etcher/master/assets/icon.png"

    # pkg_appimage_install balena-etcher "$app_url" "$icon_url"

    # List installed AppImages
    pkg_appimage_list

    # Remove AppImage
    # pkg_appimage_remove balena-etcher
}

# ============================================================================
# Example 6: Snapshots and Rollback
# ============================================================================

example_snapshots() {
    log_section "Example 6: System Snapshots"

    # Create snapshot before major changes
    pkg_snapshot_create before-dev-tools

    # Install development tools
    pkg_cascade_batch code sublime atom

    # List all snapshots
    pkg_snapshot_list

    # If something went wrong, view snapshot for manual restore
    # pkg_snapshot_restore before-dev-tools

    # Prune old snapshots (keep last 5)
    pkg_snapshot_prune 5
}

# ============================================================================
# Example 7: Transaction History
# ============================================================================

example_transaction_history() {
    log_section "Example 7: Transaction History"

    # View all recent transactions
    pkg_transaction_history

    # View transactions for specific app
    pkg_transaction_history firefox

    # Clean up old transaction logs
    pkg_transaction_cleanup
}

# ============================================================================
# Example 8: Custom Method Priority
# ============================================================================

example_custom_priority() {
    log_section "Example 8: Custom Method Priority"

    # Show current priority
    log_info "Current priority: $(pkg_get_method_priority)"

    # Prefer Flatpak for better sandboxing
    pkg_set_method_priority flatpak native snap appimage

    log_info "New priority: $(pkg_get_method_priority)"

    # Now all installations will prefer Flatpak first
    pkg_cascade_install firefox
}

# ============================================================================
# Example 9: Installation Verification
# ============================================================================

example_verification() {
    log_section "Example 9: Installation Verification"

    local apps=(firefox vlc gimp discord code)

    for app in "${apps[@]}"; do
        local method
        method=$(pkg_cascade_verify "$app" 2>/dev/null)

        if [[ -n "$method" ]]; then
            local version
            version=$(pkg_cascade_version "$app" 2>/dev/null)
            log_success "$app: installed via $method (version: $version)"
        else
            log_warn "$app: not installed"
        fi
    done
}

# ============================================================================
# Example 10: Complete Workflow
# ============================================================================

example_complete_workflow() {
    log_section "Example 10: Complete Workflow"

    # 1. Create snapshot before changes
    pkg_snapshot_create complete-workflow-$(date +%Y%m%d)

    # 2. Set preferred method priority
    pkg_set_method_priority flatpak native snap appimage

    # 3. Define custom apps if needed
    pkg_cascade_define my-tool "native:mytool|flatpak:com.example.MyTool"

    # 4. Install applications
    local apps=(
        firefox
        vlc
        gimp
        discord
        telegram
        keepassxc
        my-tool
    )

    pkg_cascade_batch "${apps[@]}"

    # 5. Verify installations
    for app in "${apps[@]}"; do
        if pkg_cascade_verify "$app" &>/dev/null; then
            log_success "$app installed successfully"
        else
            log_error "$app installation failed"
        fi
    done

    # 6. View transaction history
    pkg_transaction_history | tail -20

    # 7. Create post-installation snapshot
    pkg_snapshot_create after-installation-$(date +%Y%m%d)

    # 8. List all snapshots
    pkg_snapshot_list
}

# ============================================================================
# Example 11: List Available Apps
# ============================================================================

example_list_apps() {
    log_section "Example 11: Available Applications"

    # Show all defined applications
    pkg_cascade_list_apps
}

# ============================================================================
# Example 12: Safe Installation with Rollback Plan
# ============================================================================

example_safe_installation() {
    log_section "Example 12: Safe Installation with Rollback Plan"

    local app="$1"

    # Create snapshot
    log_info "Creating safety snapshot..."
    pkg_snapshot_create "before-${app}-$(date +%s)"

    # Attempt installation
    log_info "Installing $app..."
    if pkg_cascade_install "$app"; then
        log_success "$app installed successfully"

        # Verify it works (add your own verification logic)
        local method
        method=$(pkg_cascade_verify "$app")
        log_info "Installed via: $method"

        # Create post-install snapshot
        pkg_snapshot_create "after-${app}-$(date +%s)"
    else
        log_error "$app installation failed"
        log_warn "You can restore from snapshot if needed"
        pkg_snapshot_list
        return 1
    fi
}

# ============================================================================
# Main Menu
# ============================================================================

show_menu() {
    cat <<EOF

=============================================================================
PKG CASCADE INSTALLATION SYSTEM - EXAMPLES
=============================================================================

Choose an example to run:

 1. Basic Installation (firefox)
 2. Preferred Method Installation
 3. Batch Installation (multiple apps)
 4. Custom App Definition
 5. AppImage Installation
 6. Snapshots and Rollback
 7. Transaction History
 8. Custom Method Priority
 9. Installation Verification
10. Complete Workflow
11. List Available Apps
12. Safe Installation with Rollback Plan

 0. Exit

EOF
}

main() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        # Running as script
        log_section "PKG Cascade Examples"

        while true; do
            show_menu
            read -rp "Select example (0-12): " choice

            case "$choice" in
                1) example_basic_installation ;;
                2) example_preferred_method ;;
                3) example_batch_installation ;;
                4) example_custom_app ;;
                5) example_appimage ;;
                6) example_snapshots ;;
                7) example_transaction_history ;;
                8) example_custom_priority ;;
                9) example_verification ;;
                10) example_complete_workflow ;;
                11) example_list_apps ;;
                12)
                    read -rp "Enter app to install: " app
                    example_safe_installation "$app"
                    ;;
                0) log_info "Exiting..."; exit 0 ;;
                *) log_error "Invalid choice" ;;
            esac

            echo ""
            read -rp "Press Enter to continue..."
        done
    fi
}

# Run main if executed directly
main "$@"
