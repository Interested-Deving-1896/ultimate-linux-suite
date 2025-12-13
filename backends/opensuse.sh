#!/usr/bin/env bash
#
# opensuse.sh - openSUSE backend for Ultimate Linux Suite
#
# Supports: openSUSE Leap, openSUSE Tumbleweed, SLES
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_OPENSUSE_LOADED:-}" ]] && return 0
readonly _BACKEND_OPENSUSE_LOADED=1

# Backend identification
readonly BACKEND_NAME="opensuse"
readonly BACKEND_DESC="openSUSE and SLES"

# Package name mappings for openSUSE
declare -gA OPENSUSE_PKG_MAP=(
    [build-essential]="devel_basis"
    [kernel-headers]="kernel-default-devel"
    [dkms]="dkms"
    [git]="git"
    [curl]="curl"
    [wget]="wget"
    [vim]="vim"
    [htop]="htop"
    [neofetch]="neofetch"
    [dialog]="dialog"
    [firefox]="MozillaFirefox"
    [chromium]="chromium"
    [vlc]="vlc"
    [ffmpeg]="ffmpeg"
    [gimp]="gimp"
    [libreoffice]="libreoffice"
    [steam]="steam"
    [wine]="wine"
    [docker]="docker"
    [nodejs]="nodejs"
    [python3]="python3"
    [python3-pip]="python3-pip"
    [net-tools]="net-tools"
    [nmap]="nmap"
    [wireshark]="wireshark"
    [tcpdump]="tcpdump"
    [aircrack-ng]="aircrack-ng"
    [nvidia-driver]="nvidia-driver"
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
    [gparted]="gparted"
    [gnome-disk-utility]="gnome-disk-utility"
    [lutris]="lutris"
    [mangohud]="mangohud"
    [joystick]="joystick"
    [john]="john"
    [hashcat]="hashcat"
    [nikto]="nikto"
    [dirb]="dirb"
    [netcat]="netcat"
    [httpie]="httpie"
    [man-db]="man"
    [logrotate]="logrotate"
    [imagemagick]="ImageMagick"
    [ncdu]="ncdu"
)

# Get openSUSE-specific package name
backend_pkg_name() {
    local generic="$1"
    echo "${OPENSUSE_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_FAMILY" == "suse" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "openSUSE backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "openSUSE backend: post-install"
}

# Add Packman repository (multimedia codecs)
backend_enable_packman() {
    log_info "Adding Packman repository..."

    local suse_version
    if [[ "$OS_ID" == "opensuse-tumbleweed" ]]; then
        suse_version="tumbleweed"
    else
        suse_version="$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release)"
    fi

    zypper ar -cfp 90 "https://ftp.gwdg.de/pub/linux/misc/packman/suse/${suse_version}/" packman 2>/dev/null || true
    zypper refresh

    log_success "Packman repository added"
}

# Special handling for openSUSE
backend_special_setup() {
    log_info "openSUSE-specific setup options:"
    printf "  - Use YaST for system configuration\n"
    printf "  - Add Packman repo for multimedia codecs\n"
    printf "  - zypper patterns for package groups\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA options:\n"
            printf "  Use YaST > Hardware > NVIDIA Configuration\n"
            printf "  Or add NVIDIA repo and: zypper install nvidia-driver\n"
            ;;
        amd)
            printf "AMD: Usually works out-of-box\n"
            printf "  zypper install Mesa-dri libvulkan_radeon\n"
            ;;
        wifi-broadcom)
            printf "Broadcom: zypper install broadcom-wl-dkms\n"
            ;;
        intel)
            printf "Intel: zypper install intel-media-driver\n"
            ;;
    esac
}

# Install using pattern
backend_install_pattern() {
    local pattern="$1"
    log_info "Installing pattern: $pattern"
    zypper install -t pattern "$pattern"
}

# Switch to Packman versions (for full multimedia)
backend_packman_switch() {
    log_info "Switching packages to Packman versions..."
    zypper dup --from packman --allow-vendor-change
    log_success "Switched to Packman packages"
}
