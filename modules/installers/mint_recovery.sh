#!/usr/bin/env bash
# OffTrack Suite - Linux Mint Recovery
# License: GPL-3.0-or-later

[[ -n "${_MINT_RECOVERY_LOADED:-}" ]] && return 0
readonly _MINT_RECOVERY_LOADED=1

mint_recovery() {
    log_section "Linux Mint Recovery"

    local choice
    choice=$(tui_menu "Mint Recovery" "Select recovery option:" \
        "1" "Fix broken packages" \
        "2" "Repair GRUB bootloader" \
        "3" "Reset desktop to defaults" \
        "4" "Reinstall drivers" \
        "5" "Check filesystem" \
        "0" "Back")

    case "$choice" in
        1)
            mint_fix_packages
            ;;
        2)
            mint_repair_grub
            ;;
        3)
            mint_reset_desktop
            ;;
        4)
            mint_reinstall_drivers
            ;;
        5)
            mint_check_filesystem
            ;;
    esac
}

mint_fix_packages() {
    log_info "Fixing broken packages..."

    safe_exec sudo dpkg --configure -a
    safe_exec sudo apt-get install -f -y
    safe_exec sudo apt-get update
    safe_exec sudo apt-get dist-upgrade -y

    log_success "Package repair complete"
}

mint_repair_grub() {
    log_info "Repairing GRUB bootloader..."

    safe_exec sudo update-grub
    safe_exec sudo grub-install --recheck /dev/sda 2>/dev/null || true

    log_success "GRUB repair attempted"
}

mint_reset_desktop() {
    log_info "Resetting desktop settings..."

    local user="${SUDO_USER:-$USER}"
    local desktop="${XDG_CURRENT_DESKTOP:-cinnamon}"

    case "${desktop,,}" in
        *cinnamon*)
            safe_exec dconf reset -f /org/cinnamon/
            ;;
        *mate*)
            safe_exec dconf reset -f /org/mate/
            ;;
        *xfce*)
            rm -rf ~/.config/xfce4/
            ;;
    esac

    log_success "Desktop settings reset"
    log_info "Log out and back in to see changes"
}

mint_reinstall_drivers() {
    log_info "Reinstalling drivers..."

    safe_exec sudo apt-get install --reinstall -y \
        xserver-xorg-video-all \
        xserver-xorg-input-all

    log_success "Drivers reinstalled"
}

mint_check_filesystem() {
    log_info "Checking filesystem..."

    # This should be run from recovery mode ideally
    log_warn "Filesystem checks should be run from recovery mode or live USB"

    if tui_yesno "Continue?" "Run filesystem check? This may take a while."; then
        safe_exec sudo touch /forcefsck
        log_info "Filesystem check scheduled for next reboot"
    fi
}
