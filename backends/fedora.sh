#!/usr/bin/env bash
#
# fedora.sh - Fedora backend for Ultimate Linux Suite
#
# Supports: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_FEDORA_LOADED:-}" ]] && return 0
readonly _BACKEND_FEDORA_LOADED=1

# Backend identification
readonly BACKEND_NAME="fedora"
readonly BACKEND_DESC="Fedora and RHEL family"

# Package name mappings for Fedora/RHEL
declare -gA FEDORA_PKG_MAP=(
    [build-essential]="@development-tools"
    [kernel-headers]="kernel-devel"
    [dkms]="dkms"
    [git]="git"
    [curl]="curl"
    [wget]="wget"
    [vim]="vim-enhanced"
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
    [docker]="docker"
    [nodejs]="nodejs"
    [python3]="python3"
    [python3-pip]="python3-pip"
    [net-tools]="net-tools"
    [nmap]="nmap"
    [wireshark]="wireshark"
    [tcpdump]="tcpdump"
    [aircrack-ng]="aircrack-ng"
    [nvidia-driver]="akmod-nvidia"
    [p7zip]="p7zip p7zip-plugins"
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
    [netcat]="nmap-ncat"
    [httpie]="httpie"
    [man-db]="man-db"
    [logrotate]="logrotate"
    [imagemagick]="ImageMagick"
    [ncdu]="ncdu"
)

# Get Fedora-specific package name
backend_pkg_name() {
    local generic="$1"
    echo "${FEDORA_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_FAMILY" == "fedora" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Fedora backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "Fedora backend: post-install"
}

# Enable RPM Fusion repositories
backend_enable_rpmfusion() {
    log_info "Enabling RPM Fusion repositories..."

    local fedora_version
    fedora_version=$(rpm -E %fedora 2>/dev/null || echo "")

    if [[ -z "$fedora_version" ]]; then
        log_warn "Cannot determine Fedora version for RPM Fusion"
        return 1
    fi

    # Check if already installed
    if rpm -q rpmfusion-free-release &>/dev/null; then
        log_info "RPM Fusion already enabled"
        return 0
    fi

    dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"

    log_success "RPM Fusion enabled"
}

# Special handling for Fedora
backend_special_setup() {
    log_info "Fedora-specific setup options:"
    printf "  - Enable RPM Fusion for additional packages\n"
    printf "  - Use dnf group install for package groups\n"
    printf "  - Flatpak available via Flathub\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA (requires RPM Fusion):\n"
            printf "  dnf install akmod-nvidia xorg-x11-drv-nvidia\n"
            printf "  Wait for kernel module to build after install\n"
            ;;
        amd)
            printf "AMD: Works out-of-box\n"
            printf "  dnf install mesa-vulkan-drivers mesa-va-drivers\n"
            ;;
        wifi-broadcom)
            printf "Broadcom (requires RPM Fusion):\n"
            printf "  dnf install broadcom-wl\n"
            ;;
        intel)
            printf "Intel: dnf install intel-media-driver libva-intel-driver\n"
            ;;
    esac
}

# Install NVIDIA with proper wait
backend_nvidia_install() {
    backend_enable_rpmfusion

    log_info "Installing NVIDIA drivers..."
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia

    log_warn "Waiting for kernel module to build..."
    log_info "This may take a few minutes..."

    # Wait for akmods to finish
    akmods --force 2>/dev/null || true

    log_success "NVIDIA installation complete. Reboot required."
}
