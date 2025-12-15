#!/usr/bin/env bash
#
# recovery.sh - System Recovery Module for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# Prevent multiple sourcing
[[ -n "${_RECOVERY_MODULE_LOADED:-}" ]] && return 0
readonly _RECOVERY_MODULE_LOADED=1

# Fix broken packages
fix_packages() {
    log_section "Package Repair"

    log_info "Attempting to fix broken packages..."

    case "$PKG_MANAGER" in
        apt)
            log_info "Running dpkg --configure -a"
            dpkg --configure -a || true

            log_info "Running apt-get install -f"
            apt-get install -f -y || true

            log_info "Running apt-get update"
            apt-get update || true

            log_success "Package repair attempted"
            ;;
        dnf)
            log_info "Running dnf distro-sync"
            dnf distro-sync -y || true
            log_success "Package repair attempted"
            ;;
        pacman)
            log_info "Refreshing package database"
            pacman -Syyu --noconfirm || true
            log_success "Package refresh attempted"
            ;;
        zypper)
            log_info "Running zypper verify"
            zypper verify --recommends || true
            log_success "Package verification complete"
            ;;
        *)
            log_error "Unknown package manager: $PKG_MANAGER"
            ;;
    esac

    pause
}

# Clean package cache
clean_packages() {
    log_section "Package Cache Cleanup"

    log_info "Cleaning package cache..."

    case "$PKG_MANAGER" in
        apt)
            apt-get autoremove -y
            apt-get autoclean
            apt-get clean
            log_success "APT cache cleaned"
            ;;
        dnf)
            dnf autoremove -y
            dnf clean all
            log_success "DNF cache cleaned"
            ;;
        pacman)
            pacman -Sc --noconfirm
            log_success "Pacman cache cleaned"
            ;;
        zypper)
            zypper clean -a
            log_success "Zypper cache cleaned"
            ;;
    esac

    # Show freed space
    log_info "Cache cleanup complete"
    pause
}

# Rebuild initramfs
rebuild_initramfs() {
    log_section "Initramfs Rebuild"

    log_warn "Rebuilding initramfs. Do not interrupt!"

    case "$OS_FAMILY" in
        debian)
            if cmd_exists update-initramfs; then
                log_info "Running update-initramfs -u -k all"
                update-initramfs -u -k all
                log_success "Initramfs rebuilt"
            else
                log_error "update-initramfs not found"
            fi
            ;;
        fedora)
            if cmd_exists dracut; then
                log_info "Running dracut --regenerate-all -f"
                dracut --regenerate-all -f
                log_success "Initramfs rebuilt"
            else
                log_error "dracut not found"
            fi
            ;;
        arch)
            if cmd_exists mkinitcpio; then
                log_info "Running mkinitcpio -P"
                mkinitcpio -P
                log_success "Initramfs rebuilt"
            else
                log_error "mkinitcpio not found"
            fi
            ;;
        suse)
            if cmd_exists dracut; then
                log_info "Running dracut -f"
                dracut -f
                log_success "Initramfs rebuilt"
            else
                log_error "dracut not found"
            fi
            ;;
        *)
            log_error "Unknown OS family for initramfs rebuild"
            ;;
    esac

    pause
}

# Update GRUB
update_grub() {
    log_section "GRUB Update"

    if cmd_exists update-grub; then
        log_info "Running update-grub"
        update-grub
        log_success "GRUB updated"
    elif cmd_exists grub2-mkconfig; then
        log_info "Running grub2-mkconfig"
        if [[ -f /boot/grub2/grub.cfg ]]; then
            grub2-mkconfig -o /boot/grub2/grub.cfg
        elif [[ -f /boot/efi/EFI/fedora/grub.cfg ]]; then
            grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
        else
            grub2-mkconfig -o /boot/grub/grub.cfg
        fi
        log_success "GRUB updated"
    elif cmd_exists grub-mkconfig; then
        log_info "Running grub-mkconfig"
        grub-mkconfig -o /boot/grub/grub.cfg
        log_success "GRUB updated"
    else
        log_error "No GRUB update tool found"
    fi

    pause
}

# Network reset
reset_network() {
    log_section "Network Reset"

    log_info "Resetting network configuration..."

    # Restart NetworkManager if available
    if cmd_exists systemctl; then
        if systemctl is-active NetworkManager &>/dev/null; then
            log_info "Restarting NetworkManager..."
            systemctl restart NetworkManager
            log_success "NetworkManager restarted"
        elif systemctl is-active systemd-networkd &>/dev/null; then
            log_info "Restarting systemd-networkd..."
            systemctl restart systemd-networkd
            log_success "systemd-networkd restarted"
        fi
    fi

    # Flush DNS cache
    if cmd_exists systemd-resolve; then
        log_info "Flushing DNS cache..."
        systemd-resolve --flush-caches 2>/dev/null || true
    fi

    # Release/renew DHCP
    if confirm "Release and renew DHCP lease?"; then
        if cmd_exists dhclient; then
            dhclient -r 2>/dev/null || true
            dhclient 2>/dev/null || true
            log_success "DHCP lease renewed"
        fi
    fi

    log_success "Network reset complete"
    pause
}

# DNS Reset
reset_dns() {
    log_section "DNS Reset"

    printf "Current DNS configuration:\n\n"

    # Show current resolv.conf
    if [[ -f /etc/resolv.conf ]]; then
        printf "  /etc/resolv.conf:\n"
        cat /etc/resolv.conf | sed 's/^/    /'
        printf "\n"
    fi

    # Check if systemd-resolved is managing DNS
    local dns_manager="unknown"
    if [[ -L /etc/resolv.conf ]]; then
        local target
        target=$(readlink -f /etc/resolv.conf)
        if [[ "$target" == *"systemd"* ]]; then
            dns_manager="systemd-resolved"
        fi
    fi
    printf "DNS Manager: %s\n\n" "$dns_manager"

    simple_menu "DNS Reset Options" \
        "Flush DNS cache" \
        "Reset to Cloudflare (1.1.1.1)" \
        "Reset to Google (8.8.8.8)" \
        "Reset to Quad9 (9.9.9.9)" \
        "Restore DHCP DNS"

    case "$MENU_CHOICE" in
        1)
            # Flush caches
            if cmd_exists systemd-resolve; then
                systemd-resolve --flush-caches
                log_success "systemd-resolved cache flushed"
            fi
            if cmd_exists resolvectl; then
                resolvectl flush-caches
                log_success "resolvectl cache flushed"
            fi
            if [[ -f /etc/init.d/nscd ]]; then
                /etc/init.d/nscd restart 2>/dev/null || true
            fi
            ;;
        2)
            _set_dns "1.1.1.1" "1.0.0.1"
            ;;
        3)
            _set_dns "8.8.8.8" "8.8.4.4"
            ;;
        4)
            _set_dns "9.9.9.9" "149.112.112.112"
            ;;
        5)
            if confirm "Restore DHCP-provided DNS?"; then
                if cmd_exists nmcli; then
                    local conn
                    conn=$(nmcli -t -f NAME,DEVICE con show --active | head -1 | cut -d: -f1)
                    if [[ -n "$conn" ]]; then
                        nmcli con mod "$conn" ipv4.ignore-auto-dns no
                        nmcli con up "$conn"
                        log_success "DHCP DNS restored"
                    fi
                else
                    rm -f /etc/resolv.conf
                    systemctl restart NetworkManager 2>/dev/null || systemctl restart systemd-networkd 2>/dev/null
                    log_success "DNS reset to DHCP"
                fi
            fi
            ;;
    esac
    pause
}

_set_dns() {
    local primary="$1"
    local secondary="$2"

    if confirm "Set DNS to $primary, $secondary?"; then
        if cmd_exists nmcli; then
            local conn
            conn=$(nmcli -t -f NAME,DEVICE con show --active | head -1 | cut -d: -f1)
            if [[ -n "$conn" ]]; then
                nmcli con mod "$conn" ipv4.dns "$primary $secondary"
                nmcli con mod "$conn" ipv4.ignore-auto-dns yes
                nmcli con up "$conn"
                log_success "DNS set via NetworkManager"
                return
            fi
        fi

        # Fallback: direct resolv.conf modification
        uls_backup /etc/resolv.conf
        {
            echo "# Generated by Ultimate Linux Suite"
            echo "nameserver $primary"
            echo "nameserver $secondary"
        } > /etc/resolv.conf
        log_success "DNS set in /etc/resolv.conf"
    fi
}

# Cleanup orphan packages
cleanup_orphans() {
    log_section "Orphan Package Cleanup"

    printf "Orphan packages are dependencies no longer needed.\n\n"

    case "$PKG_MANAGER" in
        apt)
            log_info "Checking for orphan packages..."
            local orphans
            orphans=$(apt-get autoremove --dry-run 2>/dev/null | grep "^Remv" | wc -l)
            printf "Found %s packages that can be removed.\n\n" "$orphans"

            if [[ "$orphans" -gt 0 ]]; then
                apt-get autoremove --dry-run 2>/dev/null | grep "^Remv" | head -20
                printf "\n"
                if confirm "Remove these orphan packages?"; then
                    apt-get autoremove -y
                    log_success "Orphan packages removed"
                fi
            else
                log_info "No orphan packages found"
            fi
            ;;
        dnf)
            log_info "Checking for orphan packages..."
            local orphans
            orphans=$(dnf autoremove --assumeno 2>/dev/null | grep "^Remove" | wc -l)
            printf "Found %s packages that can be removed.\n\n" "$orphans"

            if [[ "$orphans" -gt 0 ]]; then
                if confirm "Remove orphan packages?"; then
                    dnf autoremove -y
                    log_success "Orphan packages removed"
                fi
            else
                log_info "No orphan packages found"
            fi
            ;;
        pacman)
            log_info "Checking for orphan packages..."
            local -a orphan_list=()
            # Safely read orphan packages into array
            while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && orphan_list+=("$pkg")
            done < <(pacman -Qdtq 2>/dev/null)

            if [[ ${#orphan_list[@]} -gt 0 ]]; then
                printf "Orphan packages found (%d):\n" "${#orphan_list[@]}"
                printf "  %s\n" "${orphan_list[@]}"
                printf "\n"
                if confirm "Remove these orphan packages?"; then
                    pacman -Rns --noconfirm "${orphan_list[@]}"
                    log_success "Orphan packages removed"
                fi
            else
                log_info "No orphan packages found"
            fi
            ;;
        zypper)
            log_info "Checking for orphan packages..."
            if confirm "Remove orphan packages?"; then
                zypper packages --orphaned | tail -n +5 | awk '{print $5}' | xargs zypper remove -y 2>/dev/null || true
                log_success "Orphan cleanup attempted"
            fi
            ;;
    esac
    pause
}

# Clear temp files
clear_temp_files() {
    log_section "Temporary File Cleanup"

    local tmp_size user_cache_size

    # Calculate sizes
    tmp_size=$(du -sh /tmp 2>/dev/null | cut -f1)
    printf "  /tmp: %s\n" "$tmp_size"

    if [[ -d /var/tmp ]]; then
        local var_tmp_size
        var_tmp_size=$(du -sh /var/tmp 2>/dev/null | cut -f1)
        printf "  /var/tmp: %s\n" "$var_tmp_size"
    fi

    if [[ -d "$HOME/.cache" ]]; then
        user_cache_size=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1)
        printf "  User cache (~/.cache): %s\n" "$user_cache_size"
    fi

    printf "\n"

    simple_menu "Cleanup Options" \
        "Clear /tmp (safe)" \
        "Clear /var/tmp" \
        "Clear user cache" \
        "Clear all"

    case "$MENU_CHOICE" in
        1)
            find /tmp -type f -atime +7 -delete 2>/dev/null
            log_success "Old /tmp files removed"
            ;;
        2)
            find /var/tmp -type f -atime +7 -delete 2>/dev/null
            log_success "Old /var/tmp files removed"
            ;;
        3)
            if confirm "Clear user cache? Some apps may need to rebuild caches."; then
                rm -rf "$HOME/.cache/"* 2>/dev/null
                log_success "User cache cleared"
            fi
            ;;
        4)
            if confirm "Clear all temporary files?"; then
                find /tmp -type f -atime +7 -delete 2>/dev/null
                find /var/tmp -type f -atime +7 -delete 2>/dev/null
                rm -rf "$HOME/.cache/"* 2>/dev/null
                log_success "All temporary files cleared"
            fi
            ;;
    esac
    pause
}

# Check disk health
check_disk_health() {
    log_section "Disk Health Check"

    if ! cmd_exists smartctl; then
        log_warn "smartctl not found. Install smartmontools for SMART data."
        if confirm "Install smartmontools?"; then
            pkg_install smartmontools
        else
            pause
            return 0
        fi
    fi

    # List disks
    printf "Available disks:\n"
    lsblk -d -o NAME,SIZE,MODEL | grep -v "^NAME"

    printf "\nEnter disk to check (e.g., sda, nvme0n1) or press Enter to skip: "
    read -r disk

    if [[ -n "$disk" ]]; then
        # Security: validate disk name to prevent path traversal
        if [[ ! "$disk" =~ ^[a-zA-Z0-9]+$ ]]; then
            log_error "Invalid disk name format: $disk"
            pause
            return 1
        fi
        # Verify it's actually a block device
        if [[ ! -b "/dev/$disk" ]]; then
            log_error "Device /dev/$disk does not exist or is not a block device"
            pause
            return 1
        fi
        log_info "Checking /dev/$disk..."
        smartctl -H "/dev/$disk" || true
        smartctl -A "/dev/$disk" 2>/dev/null | head -20 || true
    fi

    pause
}

# Filesystem check info
fsck_info() {
    log_section "Filesystem Check"

    log_warn "Running fsck on a mounted filesystem is DANGEROUS!"
    printf "\nTo safely check your root filesystem:\n"
    printf "  1. Reboot into recovery mode, OR\n"
    printf "  2. Boot from a live USB, OR\n"
    printf "  3. Schedule check on next reboot:\n"
    printf "     sudo touch /forcefsck\n"

    printf "\nCurrent mount status:\n"
    findmnt -t ext4,xfs,btrfs 2>/dev/null || lsblk

    if confirm "Schedule fsck on next reboot?"; then
        touch /forcefsck
        log_success "fsck scheduled for next reboot"
    fi

    pause
}

# Show system journal errors
show_journal_errors() {
    log_section "Recent System Errors"

    if cmd_exists journalctl; then
        log_info "Last 50 error/critical messages:"
        printf "\n"
        journalctl -p err -n 50 --no-pager || true
    else
        log_info "Using dmesg for kernel messages:"
        dmesg | grep -iE "error|fail|warn" | tail -30 || true
    fi

    pause
}

# Backup package list
backup_package_list() {
    log_section "Backup Package List"

    local backup_dir="/root/suite-backups"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$backup_dir/packages-$timestamp.txt"

    mkdir -p "$backup_dir"

    log_info "Backing up installed package list..."

    case "$PKG_MANAGER" in
        apt)
            dpkg --get-selections > "$backup_file"
            ;;
        dnf|yum)
            rpm -qa > "$backup_file"
            ;;
        pacman)
            pacman -Qe > "$backup_file"
            ;;
        zypper)
            rpm -qa > "$backup_file"
            ;;
    esac

    log_success "Package list saved to: $backup_file"
    printf "Packages: %s\n" "$(wc -l < "$backup_file")"

    pause
}

# Module initialization
recovery_init() {
    log_debug "Recovery module initialized"
}

# Module main entry point
recovery_main() {
    while true; do
        simple_menu "System Recovery" \
            "Fix Broken Packages" \
            "Clean Package Cache" \
            "Remove Orphan Packages" \
            "Clear Temporary Files" \
            "Rebuild Initramfs" \
            "Update GRUB Bootloader" \
            "Reset Network" \
            "Reset DNS" \
            "Check Disk Health (SMART)" \
            "Filesystem Check Info" \
            "Show Journal Errors" \
            "Backup Package List"

        case "$MENU_CHOICE" in
            1) fix_packages ;;
            2) clean_packages ;;
            3) cleanup_orphans ;;
            4) clear_temp_files ;;
            5) rebuild_initramfs ;;
            6) update_grub ;;
            7) reset_network ;;
            8) reset_dns ;;
            9) check_disk_health ;;
            10) fsck_info ;;
            11) show_journal_errors ;;
            12) backup_package_list ;;
            0) return 0 ;;
        esac
    done
}
