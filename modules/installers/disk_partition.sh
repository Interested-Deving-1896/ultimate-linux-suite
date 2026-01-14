#!/usr/bin/env bash
# OffTrack Suite - Disk Partitioning Helper
# License: GPL-3.0-or-later

[[ -n "${_DISK_PARTITION_LOADED:-}" ]] && return 0
readonly _DISK_PARTITION_LOADED=1

disk_partition_helper() {
    log_section "Disk Partitioning Helper"

    # List available disks
    log_info "Available disks:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part"

    tui_msgbox "Disk Partitioning" "This helper provides guided disk partitioning.\n\nWARNING: Incorrect partitioning can destroy data!\n\nFor safety, consider using:\n- GParted (graphical)\n- fdisk (interactive)\n- parted (command line)"

    local choice
    choice=$(tui_menu "Partitioning Tool" "Select partitioning method:" \
        "1" "Launch GParted (graphical)" \
        "2" "Launch fdisk (interactive)" \
        "3" "Show disk info only" \
        "0" "Back")

    case "$choice" in
        1)
            if command_exists gparted; then
                safe_exec sudo gparted
            else
                log_info "Installing GParted..."
                pkg_install gparted
                safe_exec sudo gparted
            fi
            ;;
        2)
            local disk
            disk=$(tui_inputbox "Select Disk" "Enter disk to partition (e.g., /dev/sda):" "")
            if [[ -b "$disk" ]]; then
                safe_exec sudo fdisk "$disk"
            else
                log_error "Invalid disk: $disk"
            fi
            ;;
        3)
            log_info "Disk Information:"
            lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID
            echo ""
            df -h
            ;;
    esac
}
