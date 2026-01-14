#!/usr/bin/env bash
# Unified Suite - OS Detection
# Source: OffTrack Suite (updated)
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_OS_DETECT_LOADED:-}" ]] && return 0
readonly _UNIFIED_OS_DETECT_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"

# ============================================================
# OS DETECTION GLOBALS
# ============================================================

declare -g OS_ID=""
declare -g OS_ID_LIKE=""
declare -g OS_VERSION=""
declare -g OS_PRETTY_NAME=""
declare -g OS_FAMILY=""
declare -g OS_PACKAGE_MANAGER=""

# ============================================================
# DETECTION FUNCTIONS
# ============================================================

# Detect OS from /etc/os-release
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release

        OS_ID="${ID:-unknown}"
        OS_ID_LIKE="${ID_LIKE:-}"
        OS_VERSION="${VERSION_ID:-}"
        OS_PRETTY_NAME="${PRETTY_NAME:-$OS_ID}"
    else
        OS_ID="unknown"
        OS_PRETTY_NAME="Unknown Linux"
    fi

    # Determine OS family
    case "$OS_ID" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|parrot|mx)
            OS_FAMILY="debian"
            OS_PACKAGE_MANAGER="apt"
            ;;
        fedora|rhel|centos|rocky|alma|nobara)
            OS_FAMILY="fedora"
            OS_PACKAGE_MANAGER="dnf"
            ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos)
            OS_FAMILY="arch"
            OS_PACKAGE_MANAGER="pacman"
            ;;
        opensuse*|suse*)
            OS_FAMILY="suse"
            OS_PACKAGE_MANAGER="zypper"
            ;;
        gentoo)
            OS_FAMILY="gentoo"
            OS_PACKAGE_MANAGER="emerge"
            ;;
        void)
            OS_FAMILY="void"
            OS_PACKAGE_MANAGER="xbps"
            ;;
        alpine)
            OS_FAMILY="alpine"
            OS_PACKAGE_MANAGER="apk"
            ;;
        *)
            # Try to detect from ID_LIKE
            if [[ "$OS_ID_LIKE" == *"debian"* ]] || [[ "$OS_ID_LIKE" == *"ubuntu"* ]]; then
                OS_FAMILY="debian"
                OS_PACKAGE_MANAGER="apt"
            elif [[ "$OS_ID_LIKE" == *"fedora"* ]] || [[ "$OS_ID_LIKE" == *"rhel"* ]]; then
                OS_FAMILY="fedora"
                OS_PACKAGE_MANAGER="dnf"
            elif [[ "$OS_ID_LIKE" == *"arch"* ]]; then
                OS_FAMILY="arch"
                OS_PACKAGE_MANAGER="pacman"
            else
                OS_FAMILY="unknown"
                OS_PACKAGE_MANAGER=""
            fi
            ;;
    esac

    log_debug "Detected OS: $OS_PRETTY_NAME (Family: $OS_FAMILY, PM: $OS_PACKAGE_MANAGER)"
}

# Check if specific OS
is_debian() { [[ "$OS_FAMILY" == "debian" ]]; }
is_fedora() { [[ "$OS_FAMILY" == "fedora" ]]; }
is_arch()   { [[ "$OS_FAMILY" == "arch" ]]; }
is_suse()   { [[ "$OS_FAMILY" == "suse" ]]; }

# Get kernel version
get_kernel_version() {
    uname -r
}

# Get kernel major version
get_kernel_major() {
    uname -r | cut -d. -f1
}

# Check systemd
has_systemd() {
    [[ -d /run/systemd/system ]] || command -v systemctl &>/dev/null
}

# Print OS info
print_os_info() {
    echo "OS: $OS_PRETTY_NAME"
    echo "Family: $OS_FAMILY"
    echo "Package Manager: $OS_PACKAGE_MANAGER"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
}

# Initialize on source
detect_os
