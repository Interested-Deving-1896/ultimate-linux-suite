#!/usr/bin/env bash
#
# arch.sh - Arch Linux backend for Ultimate Linux Suite
#
# Supports: Arch Linux, Manjaro, EndeavourOS, Garuda, Artix
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_ARCH_LOADED:-}" ]] && return 0
readonly _BACKEND_ARCH_LOADED=1

# Backend identification
readonly BACKEND_NAME="arch"
readonly BACKEND_DESC="Arch Linux and derivatives"

# Package name mappings for Arch-based systems
declare -gA ARCH_PKG_MAP=(
    [build-essential]="base-devel"
    [kernel-headers]="linux-headers"
    [dkms]="dkms"
    [git]="git"
    [curl]="curl"
    [wget]="wget"
    [vim]="vim"
    [htop]="htop"
    [neofetch]="neofetch"
    [dialog]="dialog"
    [firefox]="firefox"
    [chromium]="chromium"
    [vlc]="vlc"
    [ffmpeg]="ffmpeg"
    [gimp]="gimp"
    [libreoffice]="libreoffice-fresh"
    [steam]="steam"
    [wine]="wine"
    [docker]="docker"
    [nodejs]="nodejs"
    [python3]="python"
    [python3-pip]="python-pip"
    [net-tools]="net-tools"
    [nmap]="nmap"
    [wireshark]="wireshark-qt"
    [tcpdump]="tcpdump"
    [aircrack-ng]="aircrack-ng"
    [nvidia-driver]="nvidia"
    [p7zip]="p7zip"
    [unzip]="unzip"
    [tmux]="tmux"
    [screen]="screen"
    [tree]="tree"
    [jq]="jq"
    [neovim]="neovim"
    [iotop]="iotop"
    [iftop]="iftop"
    [fail2ban]="fail2ban"
    [rsync]="rsync"
)

# Get Arch-specific package name
backend_pkg_name() {
    local generic="$1"
    echo "${ARCH_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_FAMILY" == "arch" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Arch backend: pre-install"
    # Sync package database if stale
    if [[ -n "$(find /var/lib/pacman/sync -maxdepth 0 -mtime +1 2>/dev/null)" ]]; then
        log_info "Syncing package database..."
        pacman -Sy --noconfirm
    fi
}

# Post-install hooks
backend_post_install() {
    log_debug "Arch backend: post-install"
}

# Enable multilib repository
backend_enable_multilib() {
    local pacman_conf="/etc/pacman.conf"
    if ! grep -q "^\[multilib\]" "$pacman_conf" 2>/dev/null; then
        log_info "Enabling multilib repository..."
        cat >> "$pacman_conf" << 'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
        pacman -Sy --noconfirm
        log_success "Multilib enabled"
    fi
}

# Special handling for Arch
backend_special_setup() {
    log_info "Arch-specific setup options:"
    printf "  - Enable multilib for 32-bit support (gaming, wine)\n"
    printf "  - Install yay/paru for AUR access\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA options:\n"
            printf "  nvidia       - Latest for current kernel\n"
            printf "  nvidia-lts   - For LTS kernel\n"
            printf "  nvidia-dkms  - DKMS version (any kernel)\n"
            ;;
        amd)
            printf "AMD: Install mesa vulkan-radeon lib32-vulkan-radeon\n"
            ;;
        wifi-broadcom)
            printf "Broadcom: Install broadcom-wl-dkms from AUR\n"
            ;;
    esac
}

# Check for AUR helper
backend_has_aur() {
    command -v yay &>/dev/null || command -v paru &>/dev/null
}

# Install from AUR
backend_aur_install() {
    local pkg="$1"
    if command -v yay &>/dev/null; then
        yay -S --noconfirm "$pkg"
    elif command -v paru &>/dev/null; then
        paru -S --noconfirm "$pkg"
    else
        log_error "No AUR helper found. Install yay or paru first."
        return 1
    fi
}
