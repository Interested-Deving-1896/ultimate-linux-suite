#!/usr/bin/env bash
#
# mint.sh - Linux Mint backend for Ultimate Linux Suite
#
# Supports: Linux Mint, LMDE
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_MINT_LOADED:-}" ]] && return 0
readonly _BACKEND_MINT_LOADED=1

# Backend identification
readonly BACKEND_NAME="mint"
readonly BACKEND_DESC="Linux Mint and LMDE"

# Package name mappings for Mint (similar to Ubuntu/Debian)
declare -gA MINT_PKG_MAP=(
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

# Get Mint-specific package name
backend_pkg_name() {
    local generic="$1"
    if [[ "$generic" == "kernel-headers" ]]; then
        echo "linux-headers-$(uname -r)"
        return
    fi
    echo "${MINT_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_ID" == "linuxmint" ]] || [[ "$OS_ID" == "mint" ]] || [[ "$OS_ID" == "lmde" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Mint backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "Mint backend: post-install"
}

# Special handling for Mint
backend_special_setup() {
    log_info "Linux Mint-specific setup options:"
    printf "  - Use Driver Manager for GPU drivers\n"
    printf "  - Timeshift for system snapshots\n"
    printf "  - Flatpak comes pre-installed\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA: Use Driver Manager (mintdrivers) or:\n"
            printf "  apt install nvidia-driver-535\n"
            ;;
        amd)
            printf "AMD: Usually works out-of-box\n"
            printf "  apt install mesa-vulkan-drivers\n"
            ;;
        wifi-broadcom)
            printf "Broadcom: apt install bcmwl-kernel-source\n"
            printf "  Or use Driver Manager\n"
            ;;
        intel)
            printf "Intel: apt install intel-media-va-driver\n"
            ;;
    esac
}

# Use Mint's driver manager
backend_driver_manager() {
    if command -v mintdrivers &>/dev/null; then
        log_info "Launching Mint Driver Manager..."
        mintdrivers
    else
        log_warn "mintdrivers not available"
    fi
}
