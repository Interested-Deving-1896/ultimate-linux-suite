#!/usr/bin/env bash
#
# debian.sh - Debian backend for Ultimate Linux Suite
#
# Supports: Debian stable/testing/unstable
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_DEBIAN_LOADED:-}" ]] && return 0
readonly _BACKEND_DEBIAN_LOADED=1

# Backend identification
readonly BACKEND_NAME="debian"
readonly BACKEND_DESC="Debian GNU/Linux"

# Package name mappings for Debian
declare -gA DEBIAN_PKG_MAP=(
    [build-essential]="build-essential"
    [kernel-headers]="linux-headers-$(uname -r)"
    [dkms]="dkms"
    [git]="git"
    [curl]="curl"
    [wget]="wget"
    [vim]="vim"
    [htop]="htop"
    [neofetch]="neofetch"
    [dialog]="dialog"
    [firefox]="firefox-esr"
    [chromium]="chromium"
    [vlc]="vlc"
    [ffmpeg]="ffmpeg"
    [gimp]="gimp"
    [libreoffice]="libreoffice"
    [steam]="steam"
    [wine]="wine"
    [docker]="docker.io"
    [nodejs]="nodejs"
    [python3]="python3"
    [python3-pip]="python3-pip"
    [net-tools]="net-tools"
    [nmap]="nmap"
    [wireshark]="wireshark"
    [tcpdump]="tcpdump"
    [aircrack-ng]="aircrack-ng"
    [nvidia-driver]="nvidia-driver"
    [p7zip]="p7zip-full"
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
    [gparted]="gparted"
    [gnome-disk-utility]="gnome-disk-utility"
    [lutris]="lutris"
    [mangohud]="mangohud"
    [joystick]="joystick"
    [john]="john"
    [hashcat]="hashcat"
    [nikto]="nikto"
    [dirb]="dirb"
    [netcat]="netcat-openbsd"
    [httpie]="httpie"
    [man-db]="man-db"
    [logrotate]="logrotate"
    [imagemagick]="imagemagick"
    [ncdu]="ncdu"
)

# Get Debian-specific package name
backend_pkg_name() {
    local generic="$1"
    # Special case for kernel headers
    if [[ "$generic" == "kernel-headers" ]]; then
        echo "linux-headers-$(uname -r)"
        return
    fi
    echo "${DEBIAN_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_ID" == "debian" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Debian backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "Debian backend: post-install"
}

# Enable non-free repositories
backend_enable_nonfree() {
    log_info "Checking for non-free repositories..."
    local sources="/etc/apt/sources.list"

    if ! grep -qE "non-free|non-free-firmware" "$sources" 2>/dev/null; then
        log_info "Adding non-free repositories..."
        # Backup original
        cp "$sources" "$sources.uls-backup-$(date +%Y%m%d%H%M%S)"

        # Add non-free to existing lines
        sed -i 's/main$/main contrib non-free non-free-firmware/' "$sources"
        apt-get update -qq
        log_success "Non-free repositories enabled"
    else
        log_info "Non-free repositories already enabled"
    fi
}

# Special handling for Debian
backend_special_setup() {
    log_info "Debian-specific setup options:"
    printf "  - Enable non-free/contrib repos for proprietary drivers\n"
    printf "  - Install firmware packages\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA: Enable non-free repo, then:\n"
            printf "  apt install nvidia-driver\n"
            ;;
        amd)
            printf "AMD: Install firmware-amd-graphics mesa-vulkan-drivers\n"
            ;;
        wifi-broadcom)
            printf "Broadcom options:\n"
            printf "  broadcom-sta-dkms  - STA driver\n"
            printf "  firmware-b43-installer - b43 firmware\n"
            ;;
        intel)
            printf "Intel: Install intel-media-va-driver vainfo\n"
            ;;
    esac
}

# Install common firmware packages
backend_install_firmware() {
    log_info "Installing common firmware packages..."
    backend_enable_nonfree
    pkg_install firmware-linux firmware-linux-nonfree
}
