#!/usr/bin/env bash
#
# kali.sh - Kali Linux backend for Ultimate Linux Suite
#
# Supports: Kali Linux
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_KALI_LOADED:-}" ]] && return 0
readonly _BACKEND_KALI_LOADED=1

# Backend identification
readonly BACKEND_NAME="kali"
readonly BACKEND_DESC="Kali Linux"

# Package name mappings for Kali (Debian-based with security tools)
declare -gA KALI_PKG_MAP=(
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
    [john]="john"
    [hashcat]="hashcat"
    [nikto]="nikto"
    [dirb]="dirb"
    [netcat]="netcat-openbsd"
    [httpie]="httpie"
    [metasploit]="metasploit-framework"
    [burpsuite]="burpsuite"
    [sqlmap]="sqlmap"
    [hydra]="hydra"
    [gobuster]="gobuster"
)

# Get Kali-specific package name
backend_pkg_name() {
    local generic="$1"
    if [[ "$generic" == "kernel-headers" ]]; then
        echo "linux-headers-$(uname -r)"
        return
    fi
    echo "${KALI_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_ID" == "kali" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Kali backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "Kali backend: post-install"
}

# Special handling for Kali
backend_special_setup() {
    log_info "Kali Linux-specific setup options:"
    printf "  - Use kali-tweaks for configuration\n"
    printf "  - Install kali metapackages for tool categories\n"
    printf "  - Pre-installed security tools available\n"
}

# Install Kali metapackages
backend_install_meta() {
    local meta="$1"
    log_info "Installing Kali metapackage: $meta"
    apt-get install -y "kali-tools-$meta"
}

# List available metapackages
backend_list_metas() {
    printf "Kali tool metapackages:\n"
    printf "  kali-tools-top10        - Top 10 tools\n"
    printf "  kali-tools-web          - Web application testing\n"
    printf "  kali-tools-wireless     - Wireless attacks\n"
    printf "  kali-tools-exploitation - Exploitation tools\n"
    printf "  kali-tools-forensics    - Forensics tools\n"
    printf "  kali-tools-passwords    - Password attacks\n"
    printf "  kali-tools-sniffing     - Sniffing/spoofing\n"
    printf "  kali-tools-reverse-engineering - RE tools\n"
    printf "  kali-linux-default      - Default Kali install\n"
    printf "  kali-linux-large        - Large install\n"
    printf "  kali-linux-everything   - All tools\n"
}

# Driver installation hints
backend_driver_hints() {
    local driver_type="$1"
    case "$driver_type" in
        nvidia)
            printf "NVIDIA: apt install nvidia-driver\n"
            ;;
        wifi)
            printf "Wireless drivers typically included\n"
            printf "For injection: apt install realtek-rtl88xxau-dkms\n"
            ;;
    esac
}

# Configure Kali for wireless injection
backend_wireless_setup() {
    log_info "Setting up wireless injection support..."

    # Common wireless packages
    local packages=(
        "aircrack-ng"
        "reaver"
        "wifite"
        "mdk4"
        "hcxtools"
        "hcxdumptool"
    )

    apt-get install -y "${packages[@]}"

    log_success "Wireless tools installed"
}
