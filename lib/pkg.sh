#!/usr/bin/env bash
#
# pkg.sh - Package Management Abstraction for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# Prevent multiple sourcing
[[ -n "${_PKG_LOADED:-}" ]] && return 0
readonly _PKG_LOADED=1

# Update package lists
pkg_update() {
    log_info "Updating package lists..."

    case "$PKG_MANAGER" in
        apt)
            apt-get update -qq
            ;;
        dnf)
            dnf check-update -q || true  # returns 100 if updates available
            ;;
        yum)
            yum check-update -q || true
            ;;
        pacman)
            pacman -Sy --noconfirm
            ;;
        zypper)
            zypper refresh -q
            ;;
        *)
            log_error "Unsupported package manager: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Package lists updated"
}

# Install packages
# Usage: pkg_install pkg1 pkg2 pkg3 ...
pkg_install() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warn "No packages specified"
        return 0
    fi

    log_info "Installing: ${packages[*]}"

    case "$PKG_MANAGER" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"
            ;;
        dnf)
            dnf install -y -q "${packages[@]}"
            ;;
        yum)
            yum install -y -q "${packages[@]}"
            ;;
        pacman)
            pacman -S --noconfirm --needed "${packages[@]}"
            ;;
        zypper)
            zypper install -y -q "${packages[@]}"
            ;;
        *)
            log_error "Unsupported package manager: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Installation complete"
}

# Remove packages
pkg_remove() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Removing: ${packages[*]}"

    case "$PKG_MANAGER" in
        apt)
            apt-get remove -y -qq "${packages[@]}"
            ;;
        dnf)
            dnf remove -y -q "${packages[@]}"
            ;;
        yum)
            yum remove -y -q "${packages[@]}"
            ;;
        pacman)
            pacman -R --noconfirm "${packages[@]}"
            ;;
        zypper)
            zypper remove -y -q "${packages[@]}"
            ;;
        *)
            log_error "Unsupported package manager: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Removal complete"
}

# Check if package is installed
pkg_is_installed() {
    local pkg="$1"

    case "$PKG_MANAGER" in
        apt)
            dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
            ;;
        dnf|yum)
            rpm -q "$pkg" &>/dev/null
            ;;
        pacman)
            pacman -Qi "$pkg" &>/dev/null
            ;;
        zypper)
            rpm -q "$pkg" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Search for packages
pkg_search() {
    local query="$1"

    case "$PKG_MANAGER" in
        apt)
            apt-cache search "$query"
            ;;
        dnf)
            dnf search "$query"
            ;;
        yum)
            yum search "$query"
            ;;
        pacman)
            pacman -Ss "$query"
            ;;
        zypper)
            zypper search "$query"
            ;;
        *)
            log_error "Unsupported package manager"
            return 1
            ;;
    esac
}

# Get package name mapping for cross-distro compatibility
# Usage: pkg_name GENERIC_NAME
# Returns the distro-specific package name
pkg_name() {
    local generic="$1"

    # Define mappings for common packages
    declare -A apt_map=(
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
    )

    declare -A dnf_map=(
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
    )

    declare -A pacman_map=(
        [build-essential]="base-devel"
        [kernel-headers]="linux-headers"
        [dkms]="dkms"
        [git]="git"
        [curl]="curl"
        [wget]="wget"
        [vim]="vim"
        [htop]="htop"
        [neofetch]="neofetch"
        [dialog]="dialog"
    )

    declare -A zypper_map=(
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
    )

    case "$PKG_MANAGER" in
        apt)
            echo "${apt_map[$generic]:-$generic}"
            ;;
        dnf|yum)
            echo "${dnf_map[$generic]:-$generic}"
            ;;
        pacman)
            echo "${pacman_map[$generic]:-$generic}"
            ;;
        zypper)
            echo "${zypper_map[$generic]:-$generic}"
            ;;
        *)
            echo "$generic"
            ;;
    esac
}

# Ensure a package is installed
pkg_ensure() {
    local pkg="$1"
    local mapped
    mapped=$(pkg_name "$pkg")

    if ! pkg_is_installed "$mapped"; then
        log_info "Installing required package: $mapped"
        pkg_install "$mapped"
    fi
}

# Fix broken packages
pkg_fix() {
    log_info "Attempting to fix broken packages..."

    case "$PKG_MANAGER" in
        apt)
            dpkg --configure -a
            apt-get install -f -y
            ;;
        dnf)
            dnf distro-sync -y
            ;;
        yum)
            yum distro-sync -y
            ;;
        pacman)
            pacman -Syyu --noconfirm
            ;;
        zypper)
            zypper verify --recommends
            ;;
        *)
            log_error "Unsupported package manager"
            return 1
            ;;
    esac

    log_success "Package repair complete"
}

# Clean package cache
pkg_clean() {
    log_info "Cleaning package cache..."

    case "$PKG_MANAGER" in
        apt)
            apt-get autoremove -y -qq
            apt-get clean -qq
            ;;
        dnf)
            dnf autoremove -y -q
            dnf clean all -q
            ;;
        yum)
            yum autoremove -y -q
            yum clean all -q
            ;;
        pacman)
            pacman -Sc --noconfirm
            ;;
        zypper)
            zypper clean -a
            ;;
        *)
            log_error "Unsupported package manager"
            return 1
            ;;
    esac

    log_success "Cache cleaned"
}
