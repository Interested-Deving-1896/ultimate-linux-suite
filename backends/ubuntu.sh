#!/usr/bin/env bash
#
# ubuntu.sh - Ubuntu backend for Ultimate Linux Suite
#
# Supports: Ubuntu, Pop!_OS, elementary OS, Zorin OS
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_UBUNTU_LOADED:-}" ]] && return 0
readonly _BACKEND_UBUNTU_LOADED=1

# Backend identification
readonly BACKEND_NAME="ubuntu"
readonly BACKEND_DESC="Ubuntu and derivatives"

# Package name mappings for Ubuntu
declare -gA UBUNTU_PKG_MAP=(
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
    [firefox]="firefox"
    [chromium]="chromium-browser"
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
    [nvidia-driver]="nvidia-driver-535"
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

# Get Ubuntu-specific package name
backend_pkg_name() {
    local generic="$1"
    if [[ "$generic" == "kernel-headers" ]]; then
        echo "linux-headers-$(uname -r)"
        return
    fi
    echo "${UBUNTU_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_ID" == "ubuntu" ]] || [[ "$OS_ID" == "pop" ]] || [[ "$OS_ID" == "elementary" ]] || [[ "$OS_ID" == "zorin" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Ubuntu backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "Ubuntu backend: post-install"
}

# Enable universe/multiverse repositories
backend_enable_universe() {
    log_info "Enabling universe and multiverse repositories..."
    add-apt-repository -y universe 2>/dev/null || true
    add-apt-repository -y multiverse 2>/dev/null || true
    apt-get update -qq
    log_success "Repositories enabled"
}

# Special handling for Ubuntu
backend_special_setup() {
    log_info "Ubuntu-specific setup options:"
    printf "  - Enable universe/multiverse repos\n"
    printf "  - Add PPAs for newer software\n"
    printf "  - Use ubuntu-drivers for GPU detection\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA options:\n"
            printf "  ubuntu-drivers autoinstall  - Auto-detect and install\n"
            printf "  apt install nvidia-driver-535 - Specific version\n"
            ;;
        amd)
            printf "AMD: Usually works out-of-box\n"
            printf "  apt install mesa-vulkan-drivers\n"
            ;;
        wifi-broadcom)
            printf "Broadcom: apt install bcmwl-kernel-source\n"
            ;;
        intel)
            printf "Intel: apt install intel-media-va-driver\n"
            ;;
    esac
}

# Use ubuntu-drivers for automatic detection
backend_auto_drivers() {
    if command -v ubuntu-drivers &>/dev/null; then
        log_info "Detecting recommended drivers..."
        ubuntu-drivers devices

        if confirm "Auto-install recommended drivers?"; then
            ubuntu-drivers autoinstall
            log_success "Drivers installed"
        fi
    else
        log_warn "ubuntu-drivers not available"
    fi
}
