#!/usr/bin/env bash
#
# os_detect.sh - Operating System Detection for Ultimate Linux Suite
#

# shellcheck disable=SC2034  # Variables exported for use by other modules

# Prevent multiple sourcing
[[ -n "${_OS_DETECT_LOADED:-}" ]] && return 0
readonly _OS_DETECT_LOADED=1

# OS Detection variables
declare -g OS_ID=""
declare -g OS_ID_LIKE=""
declare -g OS_NAME=""
declare -g OS_VERSION=""
declare -g OS_VERSION_ID=""
declare -g OS_PRETTY=""
declare -g OS_FAMILY=""
declare -g PKG_MANAGER=""

# Additional system variables
declare -g INIT_SYSTEM=""
declare -g DESKTOP_ENV=""
declare -g SESSION_TYPE=""

# Exported canonical variable as requested
declare -g ULS_DISTRO=""

# Parse /etc/os-release safely (without sourcing to avoid variable conflicts)
_parse_os_release() {
    local file="/etc/os-release"
    [[ -r "$file" ]] || return 1

    # Parse without sourcing (avoid variable conflicts - especially VERSION on Fedora)
    OS_ID=$(grep -oP '^ID=\K.*' "$file" 2>/dev/null | tr -d '"' | head -1)
    OS_ID_LIKE=$(grep -oP '^ID_LIKE=\K.*' "$file" 2>/dev/null | tr -d '"' | head -1)
    OS_NAME=$(grep -oP '^NAME=\K.*' "$file" 2>/dev/null | tr -d '"' | head -1)
    OS_VERSION=$(grep -oP '^VERSION=\K.*' "$file" 2>/dev/null | tr -d '"' | head -1)
    OS_VERSION_ID=$(grep -oP '^VERSION_ID=\K.*' "$file" 2>/dev/null | tr -d '"' | head -1)
    OS_PRETTY=$(grep -oP '^PRETTY_NAME=\K.*' "$file" 2>/dev/null | tr -d '"' | head -1)

    [[ -n "$OS_ID" ]]
}

# Fallback detection methods
_fallback_detect() {
    if command -v lsb_release &>/dev/null; then
        OS_ID=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
        OS_VERSION_ID=$(lsb_release -sr 2>/dev/null)
        [[ -n "$OS_ID" ]] && return 0
    fi

    if [[ -f /etc/debian_version ]]; then
        OS_ID="debian"
        OS_VERSION_ID=$(cat /etc/debian_version)
        return 0
    fi

    if [[ -f /etc/redhat-release ]]; then
        OS_ID="rhel"
        return 0
    fi

    if [[ -f /etc/arch-release ]]; then
        OS_ID="arch"
        return 0
    fi

    return 1
}

# Determine OS family from ID
_determine_family() {
    local id="${OS_ID,,}"
    local id_like="${OS_ID_LIKE,,}"

    # Direct matches first
    case "$id" in
        debian|ubuntu|linuxmint|mint|pop|elementary|kali|parrot|zorin|mx|lmde|antix)
            OS_FAMILY="debian"
            return 0
            ;;
        fedora|rhel|centos|rocky|alma|almalinux|oracle|oraclelinux)
            OS_FAMILY="fedora"
            return 0
            ;;
        arch|manjaro|endeavouros|garuda|artix|arcolinux|cachyos)
            OS_FAMILY="arch"
            return 0
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed|sles|suse)
            OS_FAMILY="suse"
            return 0
            ;;
        alpine)
            OS_FAMILY="alpine"
            return 0
            ;;
        void)
            OS_FAMILY="void"
            return 0
            ;;
        clear-linux-os|clearlinux)
            OS_FAMILY="clearlinux"
            return 0
            ;;
        solus)
            OS_FAMILY="solus"
            return 0
            ;;
        mageia)
            OS_FAMILY="mageia"
            return 0
            ;;
    esac

    # Check ID_LIKE for derivatives
    if [[ "$id_like" == *"debian"* ]] || [[ "$id_like" == *"ubuntu"* ]]; then
        OS_FAMILY="debian"
        return 0
    fi

    if [[ "$id_like" == *"fedora"* ]] || [[ "$id_like" == *"rhel"* ]]; then
        OS_FAMILY="fedora"
        return 0
    fi

    if [[ "$id_like" == *"arch"* ]]; then
        OS_FAMILY="arch"
        return 0
    fi

    if [[ "$id_like" == *"suse"* ]]; then
        OS_FAMILY="suse"
        return 0
    fi

    OS_FAMILY="unknown"
    return 1
}

# Set package manager based on family
_set_pkg_manager() {
    case "$OS_FAMILY" in
        debian)
            PKG_MANAGER="apt"
            ;;
        fedora)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        arch)
            PKG_MANAGER="pacman"
            ;;
        suse)
            PKG_MANAGER="zypper"
            ;;
        alpine)
            PKG_MANAGER="apk"
            ;;
        void)
            PKG_MANAGER="xbps"
            ;;
        clearlinux)
            PKG_MANAGER="swupd"
            ;;
        solus)
            PKG_MANAGER="eopkg"
            ;;
        mageia)
            PKG_MANAGER="urpmi"
            ;;
        *)
            # Try to detect by availability
            if command -v apt &>/dev/null; then
                PKG_MANAGER="apt"
            elif command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            elif command -v pacman &>/dev/null; then
                PKG_MANAGER="pacman"
            elif command -v zypper &>/dev/null; then
                PKG_MANAGER="zypper"
            elif command -v apk &>/dev/null; then
                PKG_MANAGER="apk"
            elif command -v xbps-install &>/dev/null; then
                PKG_MANAGER="xbps"
            elif command -v swupd &>/dev/null; then
                PKG_MANAGER="swupd"
            elif command -v eopkg &>/dev/null; then
                PKG_MANAGER="eopkg"
            elif command -v urpmi &>/dev/null; then
                PKG_MANAGER="urpmi"
            else
                PKG_MANAGER="unknown"
                return 1
            fi
            ;;
    esac
    return 0
}

# Set ULS_DISTRO canonical variable
_set_uls_distro() {
    local id="${OS_ID,,}"

    case "$id" in
        arch|manjaro|endeavouros|garuda|artix|arcolinux|cachyos)
            ULS_DISTRO="arch"
            ;;
        debian)
            ULS_DISTRO="debian"
            ;;
        ubuntu|pop|elementary|zorin)
            ULS_DISTRO="ubuntu"
            ;;
        linuxmint|mint|lmde)
            ULS_DISTRO="mint"
            ;;
        mx|antix)
            ULS_DISTRO="debian"
            ;;
        fedora)
            ULS_DISTRO="fedora"
            ;;
        rhel|centos|rocky|alma|almalinux|oracle|oraclelinux)
            ULS_DISTRO="fedora"
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed|sles|suse)
            ULS_DISTRO="opensuse"
            ;;
        kali)
            ULS_DISTRO="kali"
            ;;
        parrot)
            ULS_DISTRO="parrot"
            ;;
        alpine)
            ULS_DISTRO="alpine"
            ;;
        void)
            ULS_DISTRO="void"
            ;;
        clear-linux-os|clearlinux)
            ULS_DISTRO="clearlinux"
            ;;
        solus)
            ULS_DISTRO="solus"
            ;;
        mageia)
            ULS_DISTRO="mageia"
            ;;
        *)
            ULS_DISTRO="generic"
            ;;
    esac

    export ULS_DISTRO
}

# Detect init system
_detect_init_system() {
    if [[ -d /run/systemd/system ]]; then
        INIT_SYSTEM="systemd"
    elif [[ -f /sbin/openrc-run ]] || [[ -d /etc/openrc ]]; then
        INIT_SYSTEM="openrc"
    elif [[ -f /etc/init.d/cron ]] && [[ ! -d /run/systemd ]]; then
        INIT_SYSTEM="sysvinit"
    elif [[ -f /sbin/runit ]]; then
        INIT_SYSTEM="runit"
    elif [[ -f /sbin/s6-svscan ]]; then
        INIT_SYSTEM="s6"
    else
        INIT_SYSTEM="unknown"
    fi
    export INIT_SYSTEM
}

# Detect desktop environment
_detect_desktop_env() {
    DESKTOP_ENV=""

    # Check XDG_CURRENT_DESKTOP first (most reliable)
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        case "${XDG_CURRENT_DESKTOP,,}" in
            *gnome*)     DESKTOP_ENV="gnome" ;;
            *kde*)       DESKTOP_ENV="kde" ;;
            *xfce*)      DESKTOP_ENV="xfce" ;;
            *cinnamon*)  DESKTOP_ENV="cinnamon" ;;
            *mate*)      DESKTOP_ENV="mate" ;;
            *lxqt*)      DESKTOP_ENV="lxqt" ;;
            *lxde*)      DESKTOP_ENV="lxde" ;;
            *budgie*)    DESKTOP_ENV="budgie" ;;
            *pantheon*)  DESKTOP_ENV="pantheon" ;;
            *deepin*)    DESKTOP_ENV="deepin" ;;
            *i3*)        DESKTOP_ENV="i3" ;;
            *sway*)      DESKTOP_ENV="sway" ;;
            *hyprland*)  DESKTOP_ENV="hyprland" ;;
            *unity*)     DESKTOP_ENV="unity" ;;
            *)           DESKTOP_ENV="${XDG_CURRENT_DESKTOP,,}" ;;
        esac
    fi

    # Fallback to DESKTOP_SESSION
    if [[ -z "$DESKTOP_ENV" ]] && [[ -n "${DESKTOP_SESSION:-}" ]]; then
        case "${DESKTOP_SESSION,,}" in
            *gnome*)     DESKTOP_ENV="gnome" ;;
            *plasma*)    DESKTOP_ENV="kde" ;;
            *kde*)       DESKTOP_ENV="kde" ;;
            *xfce*)      DESKTOP_ENV="xfce" ;;
            *cinnamon*)  DESKTOP_ENV="cinnamon" ;;
            *mate*)      DESKTOP_ENV="mate" ;;
            *)           DESKTOP_ENV="${DESKTOP_SESSION,,}" ;;
        esac
    fi

    # Final fallback - check running processes
    if [[ -z "$DESKTOP_ENV" ]]; then
        if pgrep -x "gnome-shell" &>/dev/null; then
            DESKTOP_ENV="gnome"
        elif pgrep -x "plasmashell" &>/dev/null; then
            DESKTOP_ENV="kde"
        elif pgrep -x "xfce4-session" &>/dev/null; then
            DESKTOP_ENV="xfce"
        elif pgrep -x "cinnamon" &>/dev/null; then
            DESKTOP_ENV="cinnamon"
        elif pgrep -x "mate-session" &>/dev/null; then
            DESKTOP_ENV="mate"
        else
            DESKTOP_ENV="none"
        fi
    fi

    export DESKTOP_ENV
}

# Detect session type (X11 or Wayland)
_detect_session_type() {
    if [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
        SESSION_TYPE="${XDG_SESSION_TYPE,,}"
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        SESSION_TYPE="wayland"
    elif [[ -n "${DISPLAY:-}" ]]; then
        SESSION_TYPE="x11"
    else
        SESSION_TYPE="tty"
    fi
    export SESSION_TYPE
}

# Main detection function
detect_os() {
    log_debug "Starting OS detection..."

    if ! _parse_os_release; then
        log_debug "os-release failed, trying fallback"
        if ! _fallback_detect; then
            log_warn "Could not detect operating system"
            OS_ID="unknown"
            OS_FAMILY="unknown"
        fi
    fi

    OS_ID="${OS_ID,,}"
    _determine_family
    _set_pkg_manager
    _set_uls_distro

    # Detect additional system properties
    _detect_init_system
    _detect_desktop_env
    _detect_session_type

    log_debug "OS: $OS_ID ($OS_FAMILY)"
    log_debug "ULS_DISTRO: $ULS_DISTRO"
    log_debug "Version: $OS_VERSION_ID"
    log_debug "Package Manager: $PKG_MANAGER"
    log_debug "Init System: $INIT_SYSTEM"
    log_debug "Desktop: $DESKTOP_ENV"
    log_debug "Session: $SESSION_TYPE"

    return 0
}

# Print OS info
print_os_info() {
    printf "Distribution: %s\n" "${OS_PRETTY:-$OS_ID}"
    printf "Family: %s\n" "$OS_FAMILY"
    printf "Version: %s\n" "${OS_VERSION_ID:-unknown}"
    printf "Package Manager: %s\n" "$PKG_MANAGER"
    printf "Init System: %s\n" "$INIT_SYSTEM"
    printf "Desktop: %s\n" "${DESKTOP_ENV:-none}"
    printf "Session: %s\n" "${SESSION_TYPE:-tty}"
}

# Output distribution info as JSON
detect_distribution_json() {
    # Escape any quotes in values for JSON safety
    local json_id="${OS_ID//\"/\\\"}"
    local json_id_like="${OS_ID_LIKE//\"/\\\"}"
    local json_version="${OS_VERSION_ID//\"/\\\"}"
    local json_pretty="${OS_PRETTY//\"/\\\"}"
    local json_family="${OS_FAMILY//\"/\\\"}"
    local json_pkg_manager="${PKG_MANAGER//\"/\\\"}"

    # Build JSON output
    cat <<EOF
{
  "id": "${json_id}",
  "id_like": "${json_id_like}",
  "version": "${json_version}",
  "pretty_name": "${json_pretty}",
  "family": "${json_family}",
  "package_manager": "${json_pkg_manager}"
}
EOF
}

# ============================================================================
# Helper functions for distro detection
# These use ULS_DISTRO for simplified checks
# ============================================================================

# Check if Arch-based
is_arch() { [[ "$OS_FAMILY" == "arch" ]]; }
uls_is_arch() { [[ "$ULS_DISTRO" == "arch" ]]; }

# Check if Debian family
is_debian() { [[ "$OS_FAMILY" == "debian" ]]; }
uls_is_debian_family() { [[ "$OS_FAMILY" == "debian" ]]; }

# Check if specifically Ubuntu
uls_is_ubuntu() { [[ "$ULS_DISTRO" == "ubuntu" ]]; }

# Check if specifically Debian
uls_is_debian() { [[ "$OS_ID" == "debian" ]]; }

# Check if Linux Mint
uls_is_mint() { [[ "$ULS_DISTRO" == "mint" ]]; }

# Check if Fedora family
is_fedora() { [[ "$OS_FAMILY" == "fedora" ]]; }
uls_is_fedora() { [[ "$ULS_DISTRO" == "fedora" ]]; }

# Check if openSUSE
is_suse() { [[ "$OS_FAMILY" == "suse" ]]; }
uls_is_opensuse() { [[ "$ULS_DISTRO" == "opensuse" ]]; }

# Check if Kali Linux
uls_is_kali() { [[ "$ULS_DISTRO" == "kali" ]]; }

# Check if Parrot OS
uls_is_parrot() { [[ "$ULS_DISTRO" == "parrot" ]]; }

# Check if Alpine Linux
uls_is_alpine() { [[ "$ULS_DISTRO" == "alpine" ]]; }

# Check if Void Linux
uls_is_void() { [[ "$ULS_DISTRO" == "void" ]]; }

# Check if generic/unknown
uls_is_generic() { [[ "$ULS_DISTRO" == "generic" ]]; }

# Check if security distro (Kali or Parrot)
uls_is_security_distro() {
    [[ "$ULS_DISTRO" == "kali" ]] || [[ "$ULS_DISTRO" == "parrot" ]]
}

# Get canonical distro name
uls_get_distro() {
    echo "$ULS_DISTRO"
}

# Get package manager
uls_get_pkg_manager() {
    echo "$PKG_MANAGER"
}

# ============================================================================
# Init system helpers
# ============================================================================

# Check if systemd
uls_is_systemd() { [[ "$INIT_SYSTEM" == "systemd" ]]; }

# Check if openrc
uls_is_openrc() { [[ "$INIT_SYSTEM" == "openrc" ]]; }

# Get init system
uls_get_init_system() { echo "$INIT_SYSTEM"; }

# ============================================================================
# Desktop environment helpers
# ============================================================================

# Check desktop environment
uls_is_gnome() { [[ "$DESKTOP_ENV" == "gnome" ]]; }
uls_is_kde() { [[ "$DESKTOP_ENV" == "kde" ]]; }
uls_is_xfce() { [[ "$DESKTOP_ENV" == "xfce" ]]; }
uls_is_cinnamon() { [[ "$DESKTOP_ENV" == "cinnamon" ]]; }
uls_is_mate() { [[ "$DESKTOP_ENV" == "mate" ]]; }

# Get desktop environment
uls_get_desktop() { echo "$DESKTOP_ENV"; }

# ============================================================================
# Session type helpers
# ============================================================================

# Check session type
uls_is_wayland() { [[ "$SESSION_TYPE" == "wayland" ]]; }
uls_is_x11() { [[ "$SESSION_TYPE" == "x11" ]]; }
uls_is_tty() { [[ "$SESSION_TYPE" == "tty" ]]; }

# Get session type
uls_get_session_type() { echo "$SESSION_TYPE"; }
