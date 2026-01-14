#!/usr/bin/env bash
# OffTrack Suite - Universal System Updater
# License: GPL-3.0-or-later

[[ -n "${_UPDATE_ALL_LOADED:-}" ]] && return 0
readonly _UPDATE_ALL_LOADED=1

# Universal update function
update_all() {
    log_section "Universal System Update"

    # Create snapshot before updates
    safety_checkpoint "system-update"

    local update_count=0

    # System packages
    log_info "Updating system packages..."
    if pkg_update; then
        ((update_count++))
        log_success "System packages updated"
    else
        log_warn "System package update had issues"
    fi

    # Flatpak
    if command_exists flatpak; then
        log_info "Updating Flatpak applications..."
        if safe_exec flatpak update -y; then
            ((update_count++))
            log_success "Flatpak apps updated"
        fi
    fi

    # Snap
    if command_exists snap; then
        log_info "Updating Snap packages..."
        if safe_exec sudo snap refresh; then
            ((update_count++))
            log_success "Snap packages updated"
        fi
    fi

    # Firmware (fwupd)
    if command_exists fwupdmgr; then
        log_info "Checking for firmware updates..."
        safe_exec fwupdmgr refresh 2>/dev/null || true
        safe_exec fwupdmgr update -y 2>/dev/null || true
    fi

    # Rust/Cargo
    if command_exists rustup; then
        log_info "Updating Rust toolchain..."
        safe_exec rustup update 2>/dev/null || true
    fi

    # Summary
    log_section "Update Summary"
    echo "Components updated: $update_count"
    echo ""

    # Check if reboot needed
    if [[ -f /var/run/reboot-required ]] || needs_reboot; then
        log_warn "A system reboot is recommended"
    fi

    log_success "System update complete"
}

# Check if reboot is needed
needs_reboot() {
    # Check for kernel update
    local running_kernel=$(uname -r)
    local installed_kernel=""

    case "$OS_FAMILY" in
        fedora)
            installed_kernel=$(rpm -q --last kernel | head -1 | awk '{print $1}' | sed 's/kernel-//')
            ;;
        debian)
            installed_kernel=$(dpkg -l linux-image-* 2>/dev/null | grep ^ii | tail -1 | awk '{print $2}' | sed 's/linux-image-//')
            ;;
        arch)
            installed_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}')
            ;;
    esac

    if [[ -n "$installed_kernel" ]] && [[ "$running_kernel" != *"$installed_kernel"* ]]; then
        return 0
    fi

    return 1
}
