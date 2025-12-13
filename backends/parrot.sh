#!/usr/bin/env bash
#
# parrot.sh - Parrot OS backend for Ultimate Linux Suite
#
# Supports: Parrot Security, Parrot Home
#

# Prevent multiple sourcing
[[ -n "${_BACKEND_PARROT_LOADED:-}" ]] && return 0
readonly _BACKEND_PARROT_LOADED=1

# Backend identification
readonly BACKEND_NAME="parrot"
readonly BACKEND_DESC="Parrot OS"

# Package name mappings for Parrot (Debian-based)
declare -gA PARROT_PKG_MAP=(
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
    [sqlmap]="sqlmap"
    [hydra]="hydra"
    [gobuster]="gobuster"
)

# Get Parrot-specific package name
backend_pkg_name() {
    local generic="$1"
    if [[ "$generic" == "kernel-headers" ]]; then
        echo "linux-headers-$(uname -r)"
        return
    fi
    echo "${PARROT_PKG_MAP[$generic]:-$generic}"
}

# Check if this backend can handle the current system
backend_can_handle() {
    [[ "$OS_ID" == "parrot" ]]
}

# Pre-install hooks
backend_pre_install() {
    log_debug "Parrot backend: pre-install"
}

# Post-install hooks
backend_post_install() {
    log_debug "Parrot backend: post-install"
}

# Special handling for Parrot
backend_special_setup() {
    log_info "Parrot OS-specific setup options:"
    printf "  - Use parrot-upgrade for system updates\n"
    printf "  - Install parrot metapackages for tool categories\n"
    printf "  - AnonSurf for anonymity features\n"
}

# Install Parrot metapackages
backend_install_meta() {
    local meta="$1"
    log_info "Installing Parrot metapackage: $meta"
    apt-get install -y "parrot-tools-$meta" 2>/dev/null || \
        apt-get install -y "$meta"
}

# List available metapackages
backend_list_metas() {
    printf "Parrot tool metapackages:\n"
    printf "  parrot-tools-full       - Full security toolkit\n"
    printf "  parrot-tools-web        - Web testing tools\n"
    printf "  parrot-tools-wireless   - Wireless tools\n"
    printf "  parrot-tools-forensics  - Forensics tools\n"
    printf "  parrot-tools-pwn        - Exploitation tools\n"
    printf "  parrot-tools-crypto     - Cryptography tools\n"
    printf "  parrot-tools-cloud      - Cloud pentesting\n"
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
            printf "Check: apt search realtek-rtl\n"
            ;;
    esac
}

# Enable AnonSurf
backend_anonsurf() {
    if command -v anonsurf &>/dev/null; then
        log_info "AnonSurf controls:"
        printf "  anonsurf start  - Start anonymization\n"
        printf "  anonsurf stop   - Stop anonymization\n"
        printf "  anonsurf status - Check status\n"
        printf "  anonsurf myip   - Check current IP\n"
    else
        log_warn "AnonSurf not installed"
        if confirm "Install AnonSurf?"; then
            apt-get install -y anonsurf
        fi
    fi
}
