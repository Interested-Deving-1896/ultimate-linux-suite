#!/usr/bin/env bash
# Unified Suite - Package Manager Abstraction
# Source: OffTrack Suite + Ultimate Suite merged
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_PKG_LOADED:-}" ]] && return 0
readonly _UNIFIED_PKG_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"
[[ -z "${_UNIFIED_OS_DETECT_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/os_detect.sh"

# ============================================================
# PACKAGE MANAGEMENT FUNCTIONS
# ============================================================

# Update package lists
pkg_update() {
    log_info "Updating package lists..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would update package lists"
        return 0
    fi

    case "$OS_PACKAGE_MANAGER" in
        apt)
            sudo apt update
            ;;
        dnf)
            sudo dnf check-update || true
            ;;
        pacman)
            sudo pacman -Sy
            ;;
        zypper)
            sudo zypper refresh
            ;;
        *)
            log_error "Unsupported package manager: $OS_PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

# Install packages
pkg_install() {
    local -a packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warn "No packages specified"
        return 0
    fi

    log_info "Installing: ${packages[*]}"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would install: ${packages[*]}"
        return 0
    fi

    case "$OS_PACKAGE_MANAGER" in
        apt)
            sudo apt install -y "${packages[@]}"
            ;;
        dnf)
            sudo dnf install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -S --noconfirm --needed "${packages[@]}"
            ;;
        zypper)
            sudo zypper install -y "${packages[@]}"
            ;;
        *)
            log_error "Unsupported package manager: $OS_PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

# Remove packages
pkg_remove() {
    local -a packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Removing: ${packages[*]}"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would remove: ${packages[*]}"
        return 0
    fi

    case "$OS_PACKAGE_MANAGER" in
        apt)
            sudo apt remove -y "${packages[@]}"
            ;;
        dnf)
            sudo dnf remove -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -R --noconfirm "${packages[@]}"
            ;;
        zypper)
            sudo zypper remove -y "${packages[@]}"
            ;;
        *)
            log_error "Unsupported package manager"
            return 1
            ;;
    esac
}

# Check if package is installed
pkg_is_installed() {
    local package="$1"

    case "$OS_PACKAGE_MANAGER" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        dnf)
            rpm -q "$package" &>/dev/null
            ;;
        pacman)
            pacman -Q "$package" &>/dev/null
            ;;
        zypper)
            rpm -q "$package" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Full system upgrade
pkg_upgrade() {
    log_info "Upgrading system packages..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would upgrade system"
        return 0
    fi

    case "$OS_PACKAGE_MANAGER" in
        apt)
            sudo apt upgrade -y
            ;;
        dnf)
            sudo dnf upgrade -y
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        zypper)
            sudo zypper update -y
            ;;
        *)
            log_error "Unsupported package manager"
            return 1
            ;;
    esac
}

# Clean package cache
pkg_clean() {
    log_info "Cleaning package cache..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would clean cache"
        return 0
    fi

    case "$OS_PACKAGE_MANAGER" in
        apt)
            sudo apt autoremove -y
            sudo apt clean
            ;;
        dnf)
            sudo dnf autoremove -y
            sudo dnf clean all
            ;;
        pacman)
            sudo pacman -Sc --noconfirm
            ;;
        zypper)
            sudo zypper clean
            ;;
    esac
}

# Search for package
pkg_search() {
    local query="$1"

    case "$OS_PACKAGE_MANAGER" in
        apt)
            apt search "$query" 2>/dev/null
            ;;
        dnf)
            dnf search "$query"
            ;;
        pacman)
            pacman -Ss "$query"
            ;;
        zypper)
            zypper search "$query"
            ;;
    esac
}

# Install Flatpak package
flatpak_install() {
    local app="$1"

    if ! command_exists flatpak; then
        log_warn "Flatpak not installed"
        return 1
    fi

    log_info "Installing Flatpak: $app"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would install flatpak: $app"
        return 0
    fi

    flatpak install -y flathub "$app"
}

# Install Snap package
snap_install() {
    local app="$1"

    if ! command_exists snap; then
        log_warn "Snap not installed"
        return 1
    fi

    log_info "Installing Snap: $app"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would install snap: $app"
        return 0
    fi

    sudo snap install "$app"
}

# Install and configure Flatpak with Flathub
pkg_install_flatpak() {
    log_info "Installing and configuring Flatpak..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would install flatpak and configure Flathub"
        return 0
    fi

    # Install flatpak package
    if ! command_exists flatpak; then
        case "$OS_PACKAGE_MANAGER" in
            apt)
                sudo apt install -y flatpak
                # Install GNOME Software plugin if GNOME detected
                if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
                    sudo apt install -y gnome-software-plugin-flatpak 2>/dev/null || true
                fi
                ;;
            dnf)
                sudo dnf install -y flatpak
                ;;
            pacman)
                sudo pacman -S --noconfirm --needed flatpak
                ;;
            zypper)
                sudo zypper install -y flatpak
                ;;
            *)
                log_error "Cannot install flatpak: unsupported package manager"
                return 1
                ;;
        esac
    fi

    # Add Flathub remote if not present
    if ! flatpak remote-list 2>/dev/null | grep -q "flathub"; then
        log_info "Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    log_success "Flatpak configured with Flathub"
}
