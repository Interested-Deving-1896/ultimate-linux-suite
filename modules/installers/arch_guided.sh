#!/usr/bin/env bash
# OffTrack Suite - Guided Arch Linux Installer
# License: GPL-3.0-or-later

[[ -n "${_ARCH_GUIDED_LOADED:-}" ]] && return 0
readonly _ARCH_GUIDED_LOADED=1

arch_guided_install() {
    log_section "Guided Arch Linux Installation"

    tui_msgbox "Arch Linux Installer" "This guided installer will help you install Arch Linux.\n\nWARNING: This can modify disk partitions and erase data!\n\nMake sure you have:\n- Booted from Arch Linux live ISO\n- Internet connectivity\n- Backup of important data"

    # Check if running from live environment
    if [[ ! -d /run/archiso ]]; then
        log_warn "Not running from Arch Linux live environment"
        if ! tui_yesno "Continue?" "This doesn't appear to be an Arch Linux live environment.\n\nContinue anyway?"; then
            return 1
        fi
    fi

    # Step 1: Verify boot mode
    log_info "Checking boot mode..."
    if [[ -d /sys/firmware/efi/efivars ]]; then
        log_info "UEFI boot mode detected"
        local boot_mode="uefi"
    else
        log_info "BIOS/Legacy boot mode detected"
        local boot_mode="bios"
    fi

    # Step 2: Select disk
    local disks=$(lsblk -dpno NAME,SIZE,MODEL | grep -E "^/dev/(sd|nvme|vd)")
    local disk
    disk=$(tui_inputbox "Select Disk" "Available disks:\n$disks\n\nEnter disk device (e.g., /dev/sda):" "")

    [[ -z "$disk" ]] && return 1

    if ! [[ -b "$disk" ]]; then
        log_error "Invalid disk: $disk"
        return 1
    fi

    # Confirm disk selection
    if ! tui_yesno "Confirm Disk" "WARNING: All data on $disk will be ERASED!\n\nAre you absolutely sure?"; then
        return 1
    fi

    log_warn "This is a placeholder for the full Arch installer"
    log_info "For a complete Arch installation, please refer to:"
    log_info "  https://wiki.archlinux.org/title/Installation_guide"

    tui_msgbox "Not Implemented" "The full guided Arch installer is under development.\n\nPlease use the official Arch installation guide or archinstall."
}
