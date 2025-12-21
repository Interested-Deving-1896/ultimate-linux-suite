#!/usr/bin/env bash
#
# pkg_universal.sh - Universal Package Manager Installation and Management
#
# Handles installation and configuration of universal package managers:
# - Flatpak (with Flathub and other remotes)
# - Snap (snapd with classic support)
# - Nix Package Manager (with flakes)
# - Homebrew/Linuxbrew
# - AppImage support (AppImageLauncher/Gear Lever)
# - AUR helpers (paru/yay) for Arch-based systems
#

# Prevent multiple sourcing
[[ -n "${_PKG_UNIVERSAL_LOADED:-}" ]] && return 0
readonly _PKG_UNIVERSAL_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

_PKG_UNI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${_PKG_UNI_SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_section() { echo ""; echo "=== $* ==="; }
    }
fi

# Source os_detect with fallback
if [[ -z "${OS_FAMILY:-}" ]]; then
    source "${_PKG_UNI_SCRIPT_DIR}/os_detect.sh" 2>/dev/null && {
        declare -f detect_os &>/dev/null && detect_os 2>/dev/null || true
    }
fi

# Source pkg.sh with fallback
if ! declare -f pkg_install &>/dev/null; then
    source "${_PKG_UNI_SCRIPT_DIR}/pkg.sh" 2>/dev/null || {
        log_warn "pkg.sh not available - some features disabled"
    }
fi

# ============================================================================
# Configuration
# ============================================================================

# Configuration directory
readonly UNIVERSAL_CONFIG_DIR="${HOME}/.config/ultimate-linux-suite"
readonly UNIVERSAL_CONFIG_FILE="${UNIVERSAL_CONFIG_DIR}/universal-pkg.conf"

# AppImage directory
readonly APPIMAGE_DIR="${HOME}/Applications"

# Nix installer URL
readonly NIX_INSTALLER_URL="https://nixos.org/nix/install"

# Homebrew installer URL
readonly HOMEBREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# Detection flags (set by universal_detect_all)
declare -g UNIVERSAL_HAS_FLATPAK=0
declare -g UNIVERSAL_HAS_SNAP=0
declare -g UNIVERSAL_HAS_NIX=0
declare -g UNIVERSAL_HAS_HOMEBREW=0
declare -g UNIVERSAL_HAS_APPIMAGE=0
declare -g UNIVERSAL_HAS_AUR=0

# ============================================================================
# Distro-specific Package Mappings
# ============================================================================

declare -gA FLATPAK_PKG_NAMES=(
    [apt]="flatpak gnome-software-plugin-flatpak"
    [dnf]="flatpak"
    [pacman]="flatpak"
    [zypper]="flatpak"
    [apk]="flatpak"
    [xbps]="flatpak"
)

declare -gA SNAP_PKG_NAMES=(
    [apt]="snapd"
    [dnf]="snapd"
    [pacman]="snapd"
    [zypper]="snapd"
    [xbps]="snapd"
)

declare -gA NIX_BUILD_DEPS=(
    [apt]="curl xz-utils"
    [dnf]="curl xz"
    [pacman]="curl xz"
    [zypper]="curl xz"
    [apk]="curl xz"
    [xbps]="curl xz"
)

declare -gA HOMEBREW_BUILD_DEPS=(
    [apt]="build-essential procps curl file git"
    [dnf]="procps-ng curl file git"
    [pacman]="base-devel procps-ng curl file git"
    [zypper]="curl file git"
    [apk]="build-base curl file git"
    [xbps]="base-devel curl file git"
)

# ============================================================================
# Configuration Management
# ============================================================================

# Initialize configuration directory
_universal_init_config() {
    if [[ ! -d "$UNIVERSAL_CONFIG_DIR" ]]; then
        mkdir -p "$UNIVERSAL_CONFIG_DIR" 2>/dev/null || {
            log_warn "Failed to create config directory: $UNIVERSAL_CONFIG_DIR"
            return 1
        }
    fi

    if [[ ! -f "$UNIVERSAL_CONFIG_FILE" ]]; then
        cat > "$UNIVERSAL_CONFIG_FILE" <<'EOF'
# Ultimate Linux Suite - Universal Package Manager Configuration
# Auto-generated - edit as needed

# Flatpak settings
FLATPAK_AUTO_UPDATE=1
FLATPAK_ENABLE_BETA=0
FLATPAK_ENABLE_GNOME_NIGHTLY=0

# Snap settings
SNAP_AUTO_REFRESH=1

# Nix settings
NIX_ENABLE_FLAKES=1
NIX_MULTI_USER=1

# Homebrew settings
HOMEBREW_NO_ANALYTICS=1
HOMEBREW_AUTO_UPDATE=1

# AUR helper preference (paru or yay)
AUR_HELPER=paru
EOF
    fi
}

# Get configuration value
universal_config_get() {
    local key="$1"
    local default="${2:-}"

    _universal_init_config

    if [[ -f "$UNIVERSAL_CONFIG_FILE" ]]; then
        local value
        value=$(grep -E "^${key}=" "$UNIVERSAL_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Set configuration value
universal_config_set() {
    local key="$1"
    local value="$2"

    _universal_init_config

    if grep -q "^${key}=" "$UNIVERSAL_CONFIG_FILE" 2>/dev/null; then
        # Update existing value
        sed -i "s|^${key}=.*|${key}=${value}|" "$UNIVERSAL_CONFIG_FILE"
    else
        # Add new value
        echo "${key}=${value}" >> "$UNIVERSAL_CONFIG_FILE"
    fi

    log_debug "Config set: ${key}=${value}"
}

# ============================================================================
# Detection Functions
# ============================================================================

# Check if Flatpak is installed
universal_has_flatpak() {
    command -v flatpak &>/dev/null
}

# Check if Snap is installed and running
universal_has_snap() {
    if command -v snap &>/dev/null; then
        # Check if snapd service is running
        if uls_is_systemd; then
            systemctl is-active --quiet snapd.socket 2>/dev/null || \
            systemctl is-active --quiet snapd 2>/dev/null
        else
            pgrep -x snapd &>/dev/null
        fi
    else
        return 1
    fi
}

# Check if Nix is installed
universal_has_nix() {
    command -v nix &>/dev/null || [[ -d /nix ]]
}

# Check if Homebrew is installed
universal_has_homebrew() {
    command -v brew &>/dev/null
}

# Check if AppImage support is available
universal_has_appimage_support() {
    command -v appimagelauncherd &>/dev/null || \
    command -v ail-cli &>/dev/null || \
    flatpak list --app 2>/dev/null | grep -q "it.mijorus.gearlever"
}

# Check if AUR helper is available (Arch-based only)
universal_has_aur_helper() {
    command -v paru &>/dev/null || command -v yay &>/dev/null
}

# Get installed AUR helper name
universal_get_aur_helper() {
    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    else
        echo ""
    fi
}

# Detect all universal package managers
universal_detect_all() {
    log_debug "Detecting universal package managers..."

    UNIVERSAL_HAS_FLATPAK=0
    UNIVERSAL_HAS_SNAP=0
    UNIVERSAL_HAS_NIX=0
    UNIVERSAL_HAS_HOMEBREW=0
    UNIVERSAL_HAS_APPIMAGE=0
    UNIVERSAL_HAS_AUR=0

    universal_has_flatpak && UNIVERSAL_HAS_FLATPAK=1
    universal_has_snap && UNIVERSAL_HAS_SNAP=1
    universal_has_nix && UNIVERSAL_HAS_NIX=1
    universal_has_homebrew && UNIVERSAL_HAS_HOMEBREW=1
    universal_has_appimage_support && UNIVERSAL_HAS_APPIMAGE=1
    universal_has_aur_helper && UNIVERSAL_HAS_AUR=1

    log_debug "Detection complete: Flatpak=$UNIVERSAL_HAS_FLATPAK Snap=$UNIVERSAL_HAS_SNAP Nix=$UNIVERSAL_HAS_NIX Brew=$UNIVERSAL_HAS_HOMEBREW AppImage=$UNIVERSAL_HAS_APPIMAGE AUR=$UNIVERSAL_HAS_AUR"
}

# ============================================================================
# Flatpak Installation and Configuration
# ============================================================================

# Install Flatpak
universal_install_flatpak() {
    if universal_has_flatpak; then
        log_info "Flatpak is already installed"
        return 0
    fi

    log_info "Installing Flatpak..."

    local packages="${FLATPAK_PKG_NAMES[$PKG_MANAGER]:-flatpak}"

    case "$PKG_MANAGER" in
        apt|dnf|yum|pacman|zypper|apk|xbps)
            # shellcheck disable=SC2086
            pkg_install $packages || {
                log_error "Failed to install Flatpak"
                return 1
            }
            ;;
        *)
            log_error "Flatpak installation not supported for package manager: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Flatpak installed successfully"
    UNIVERSAL_HAS_FLATPAK=1

    # Setup Flathub by default
    universal_setup_flatpak_remotes

    return 0
}

# Configure Flatpak remotes
universal_setup_flatpak_remotes() {
    if ! universal_has_flatpak; then
        log_error "Flatpak is not installed"
        return 1
    fi

    log_info "Configuring Flatpak remotes..."

    # Add Flathub (main repository)
    if ! flatpak remotes 2>/dev/null | grep -q "^flathub"; then
        log_info "Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || {
            log_error "Failed to add Flathub remote"
            return 1
        }
        log_success "Flathub remote added"
    else
        log_debug "Flathub remote already exists"
    fi

    # Add Flathub-beta if enabled
    if [[ "$(universal_config_get FLATPAK_ENABLE_BETA 0)" == "1" ]]; then
        if ! flatpak remotes 2>/dev/null | grep -q "^flathub-beta"; then
            log_info "Adding Flathub-beta remote..."
            flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo || {
                log_warn "Failed to add Flathub-beta remote"
            }
        fi
    fi

    # Add GNOME Nightly if enabled
    if [[ "$(universal_config_get FLATPAK_ENABLE_GNOME_NIGHTLY 0)" == "1" ]]; then
        if ! flatpak remotes 2>/dev/null | grep -q "^gnome-nightly"; then
            log_info "Adding GNOME Nightly remote..."
            flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo || {
                log_warn "Failed to add GNOME Nightly remote"
            }
        fi
    fi

    log_success "Flatpak remotes configured"
    return 0
}

# Install Flatseal for permission management
universal_install_flatseal() {
    if ! universal_has_flatpak; then
        log_error "Flatpak is not installed"
        return 1
    fi

    log_info "Installing Flatseal..."

    flatpak install -y flathub com.github.tchx84.Flatseal 2>/dev/null || {
        log_error "Failed to install Flatseal"
        return 1
    }

    log_success "Flatseal installed successfully"
    return 0
}

# ============================================================================
# Snap Installation and Configuration
# ============================================================================

# Wait for snapd to be ready
universal_snap_wait_ready() {
    local timeout=60
    local elapsed=0

    log_info "Waiting for snapd to be ready..."

    while [[ $elapsed -lt $timeout ]]; do
        if snap wait system seed.loaded 2>/dev/null; then
            log_success "snapd is ready"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_warn "Timeout waiting for snapd (this may be normal on first install)"
    return 0
}

# Install Snap
universal_install_snap() {
    if universal_has_snap; then
        log_info "Snap is already installed"
        return 0
    fi

    log_info "Installing Snap..."

    local packages="${SNAP_PKG_NAMES[$PKG_MANAGER]:-snapd}"

    case "$PKG_MANAGER" in
        apt|dnf|yum|pacman|zypper|xbps)
            # shellcheck disable=SC2086
            pkg_install $packages || {
                log_error "Failed to install snapd"
                return 1
            }
            ;;
        *)
            log_error "Snap installation not supported for package manager: $PKG_MANAGER"
            return 1
            ;;
    esac

    # Enable and start snapd service
    if uls_is_systemd; then
        log_info "Enabling snapd service..."
        systemctl enable --now snapd.socket 2>/dev/null || true
        systemctl enable --now snapd 2>/dev/null || true
    fi

    # Create /snap symlink for non-Ubuntu systems
    if [[ ! -e /snap ]] && [[ "$OS_ID" != "ubuntu" ]]; then
        log_info "Creating /snap symlink..."
        ln -s /var/lib/snapd/snap /snap 2>/dev/null || {
            log_debug "Could not create /snap symlink (may require root)"
        }
    fi

    # Wait for snapd to be ready
    universal_snap_wait_ready

    # Install core snap for classic support
    log_info "Installing core snap..."
    snap install core 2>/dev/null || log_debug "Core snap installation skipped"

    log_success "Snap installed successfully"
    UNIVERSAL_HAS_SNAP=1

    return 0
}

# ============================================================================
# Nix Package Manager Installation and Configuration
# ============================================================================

# Install Nix Package Manager
universal_install_nix() {
    if universal_has_nix; then
        log_info "Nix is already installed"
        return 0
    fi

    log_info "Installing Nix Package Manager..."

    # Install build dependencies
    local deps="${NIX_BUILD_DEPS[$PKG_MANAGER]:-curl xz}"
    # shellcheck disable=SC2086
    pkg_install $deps || {
        log_warn "Failed to install dependencies, continuing anyway..."
    }

    # Determine installation mode
    local nix_mode="daemon"
    if [[ "$(universal_config_get NIX_MULTI_USER 1)" == "0" ]]; then
        nix_mode="single-user"
    fi

    log_info "Installing Nix in ${nix_mode} mode..."

    # Download and run installer
    if [[ "$nix_mode" == "daemon" ]]; then
        # Multi-user installation (recommended)
        sh <(curl -L "$NIX_INSTALLER_URL") --daemon --yes 2>&1 | tee /tmp/nix-install.log || {
            log_error "Nix installation failed. Check /tmp/nix-install.log for details"
            return 1
        }
    else
        # Single-user installation
        sh <(curl -L "$NIX_INSTALLER_URL") --no-daemon --yes 2>&1 | tee /tmp/nix-install.log || {
            log_error "Nix installation failed. Check /tmp/nix-install.log for details"
            return 1
        }
    fi

    # Source Nix profile
    if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Setup Nix channels
    universal_setup_nix_channels

    log_success "Nix installed successfully"
    log_info "You may need to log out and back in for Nix to work properly"

    UNIVERSAL_HAS_NIX=1
    return 0
}

# Configure Nix channels
universal_setup_nix_channels() {
    if ! universal_has_nix; then
        log_error "Nix is not installed"
        return 1
    fi

    log_info "Configuring Nix channels..."

    # Add nixpkgs-unstable channel
    if ! nix-channel --list 2>/dev/null | grep -q nixpkgs; then
        nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs || {
            log_warn "Failed to add nixpkgs channel"
        }
        nix-channel --update || {
            log_warn "Failed to update Nix channels"
        }
    fi

    # Enable flakes if configured
    if [[ "$(universal_config_get NIX_ENABLE_FLAKES 1)" == "1" ]]; then
        log_info "Enabling Nix flakes experimental feature..."
        mkdir -p "$HOME/.config/nix"
        if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
            echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
        fi
    fi

    log_success "Nix channels configured"
    return 0
}

# Install package via Nix
universal_nix_install() {
    if ! universal_has_nix; then
        log_error "Nix is not installed"
        return 1
    fi

    local package="$1"
    if [[ -z "$package" ]]; then
        log_error "Package name required"
        return 1
    fi

    log_info "Installing Nix package: $package"
    nix-env -iA "nixpkgs.${package}" || {
        log_error "Failed to install $package via Nix"
        return 1
    }

    log_success "Installed $package via Nix"
    return 0
}

# ============================================================================
# Homebrew/Linuxbrew Installation and Configuration
# ============================================================================

# Add Homebrew to PATH
universal_homebrew_setup_path() {
    local brew_path=""

    # Detect Homebrew installation path
    if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        brew_path="/home/linuxbrew/.linuxbrew"
    elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        brew_path="$HOME/.linuxbrew"
    elif [[ -x "/opt/homebrew/bin/brew" ]]; then
        brew_path="/opt/homebrew"
    else
        return 1
    fi

    # Add to PATH if not already present
    if [[ ":$PATH:" != *":${brew_path}/bin:"* ]]; then
        export PATH="${brew_path}/bin:${brew_path}/sbin:$PATH"
    fi

    # Evaluate brew shellenv
    eval "$("${brew_path}/bin/brew" shellenv)"

    return 0
}

# Install Homebrew
universal_install_homebrew() {
    if universal_has_homebrew; then
        log_info "Homebrew is already installed"
        return 0
    fi

    log_info "Installing Homebrew..."

    # Install build dependencies
    local deps="${HOMEBREW_BUILD_DEPS[$PKG_MANAGER]:-curl file git}"
    # shellcheck disable=SC2086
    pkg_install $deps || {
        log_warn "Failed to install dependencies, continuing anyway..."
    }

    # Set environment variables for non-interactive installation
    export NONINTERACTIVE=1
    if [[ "$(universal_config_get HOMEBREW_NO_ANALYTICS 1)" == "1" ]]; then
        export HOMEBREW_NO_ANALYTICS=1
    fi

    # Download and run installer
    log_info "Downloading and running Homebrew installer..."
    bash -c "$(curl -fsSL "$HOMEBREW_INSTALLER_URL")" 2>&1 | tee /tmp/brew-install.log || {
        log_error "Homebrew installation failed. Check /tmp/brew-install.log for details"
        return 1
    }

    # Setup PATH
    universal_homebrew_setup_path || {
        log_warn "Failed to setup Homebrew PATH automatically"
        log_info "You may need to add Homebrew to your PATH manually"
    }

    log_success "Homebrew installed successfully"
    log_info "You may need to log out and back in for Homebrew to work properly"

    UNIVERSAL_HAS_HOMEBREW=1
    return 0
}

# Install package via Homebrew
universal_brew_install() {
    if ! universal_has_homebrew; then
        # Try to setup PATH first
        if ! universal_homebrew_setup_path || ! universal_has_homebrew; then
            log_error "Homebrew is not installed"
            return 1
        fi
    fi

    local package="$1"
    if [[ -z "$package" ]]; then
        log_error "Package name required"
        return 1
    fi

    log_info "Installing Homebrew package: $package"
    brew install "$package" || {
        log_error "Failed to install $package via Homebrew"
        return 1
    }

    log_success "Installed $package via Homebrew"
    return 0
}

# ============================================================================
# AppImage Support Installation
# ============================================================================

# Setup AppImage directory
universal_setup_appimage_dir() {
    if [[ ! -d "$APPIMAGE_DIR" ]]; then
        log_info "Creating AppImage directory: $APPIMAGE_DIR"
        mkdir -p "$APPIMAGE_DIR" || {
            log_error "Failed to create AppImage directory"
            return 1
        }
    fi

    # Make directory executable
    chmod +x "$APPIMAGE_DIR" 2>/dev/null || true

    log_success "AppImage directory ready: $APPIMAGE_DIR"
    return 0
}

# Install AppImage support
universal_install_appimage_support() {
    if universal_has_appimage_support; then
        log_info "AppImage support is already installed"
        return 0
    fi

    log_info "Installing AppImage support..."

    # Setup AppImage directory
    universal_setup_appimage_dir

    # Try AppImageLauncher first (native package)
    local installed=0

    case "$PKG_MANAGER" in
        apt)
            log_info "Attempting to install AppImageLauncher..."
            if wget -q "https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb" -O /tmp/appimagelauncher.deb 2>/dev/null; then
                dpkg -i /tmp/appimagelauncher.deb 2>/dev/null || apt-get install -f -y
                rm -f /tmp/appimagelauncher.deb
                installed=1
            fi
            ;;
        pacman)
            log_info "Installing AppImageLauncher from AUR..."
            if universal_has_aur_helper; then
                local helper
                helper=$(universal_get_aur_helper)
                $helper -S --noconfirm appimagelauncher 2>/dev/null && installed=1
            fi
            ;;
        dnf|zypper)
            log_debug "AppImageLauncher not available for $PKG_MANAGER via native packages"
            ;;
    esac

    # Fallback to Gear Lever (Flatpak)
    if [[ $installed -eq 0 ]]; then
        if universal_has_flatpak; then
            log_info "Installing Gear Lever (Flatpak AppImage manager)..."
            flatpak install -y flathub it.mijorus.gearlever 2>/dev/null || {
                log_error "Failed to install AppImage support"
                return 1
            }
            installed=1
        else
            log_warn "AppImage support requires either Flatpak or native packages"
            log_info "AppImages can still be run manually from $APPIMAGE_DIR"
            return 0
        fi
    fi

    log_success "AppImage support installed successfully"
    UNIVERSAL_HAS_APPIMAGE=1

    return 0
}

# ============================================================================
# AUR Helper Installation (Arch-based only)
# ============================================================================

# Install AUR helper
universal_install_aur_helper() {
    if ! is_arch; then
        log_error "AUR helpers are only available on Arch-based distributions"
        return 1
    fi

    if universal_has_aur_helper; then
        log_info "AUR helper is already installed: $(universal_get_aur_helper)"
        return 0
    fi

    local helper="${1:-$(universal_config_get AUR_HELPER paru)}"

    log_info "Installing AUR helper: $helper"

    # Install build dependencies
    pkg_install base-devel git || {
        log_error "Failed to install build dependencies"
        return 1
    }

    # Clone AUR helper repository
    local tmpdir
    tmpdir=$(mktemp -d)

    case "$helper" in
        paru)
            git clone https://aur.archlinux.org/paru.git "$tmpdir/paru" || {
                log_error "Failed to clone paru repository"
                rm -rf "$tmpdir"
                return 1
            }

            cd "$tmpdir/paru" || return 1
            makepkg -si --noconfirm || {
                log_error "Failed to build paru"
                cd - >/dev/null || true
                rm -rf "$tmpdir"
                return 1
            }
            cd - >/dev/null || true
            ;;

        yay)
            git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" || {
                log_error "Failed to clone yay repository"
                rm -rf "$tmpdir"
                return 1
            }

            cd "$tmpdir/yay" || return 1
            makepkg -si --noconfirm || {
                log_error "Failed to build yay"
                cd - >/dev/null || true
                rm -rf "$tmpdir"
                return 1
            }
            cd - >/dev/null || true
            ;;

        *)
            log_error "Unsupported AUR helper: $helper (supported: paru, yay)"
            rm -rf "$tmpdir"
            return 1
            ;;
    esac

    # Cleanup
    rm -rf "$tmpdir"

    log_success "AUR helper $helper installed successfully"
    UNIVERSAL_HAS_AUR=1

    return 0
}

# Install package from AUR
universal_aur_install() {
    if ! is_arch; then
        log_error "AUR is only available on Arch-based distributions"
        return 1
    fi

    if ! universal_has_aur_helper; then
        log_error "No AUR helper installed"
        log_info "Install one with: universal_install_aur_helper"
        return 1
    fi

    local package="$1"
    if [[ -z "$package" ]]; then
        log_error "Package name required"
        return 1
    fi

    local helper
    helper=$(universal_get_aur_helper)

    log_info "Installing AUR package: $package (using $helper)"
    $helper -S --noconfirm "$package" || {
        log_error "Failed to install $package from AUR"
        return 1
    }

    log_success "Installed $package from AUR"
    return 0
}

# ============================================================================
# Status and Information Functions
# ============================================================================

# Count packages by manager
universal_package_counts() {
    local flatpak_count=0
    local snap_count=0
    local nix_count=0
    local brew_count=0

    if universal_has_flatpak; then
        flatpak_count=$(flatpak list --app 2>/dev/null | wc -l)
    fi

    if universal_has_snap; then
        snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l)
    fi

    if universal_has_nix; then
        nix_count=$(nix-env -q 2>/dev/null | wc -l)
    fi

    if universal_has_homebrew || universal_homebrew_setup_path; then
        brew_count=$(brew list 2>/dev/null | wc -l)
    fi

    cat <<EOF
Flatpak: $flatpak_count packages
Snap: $snap_count packages
Nix: $nix_count packages
Homebrew: $brew_count packages
EOF
}

# Get comprehensive status of all universal managers
universal_status() {
    log_section "Universal Package Manager Status"

    # Re-detect all managers
    universal_detect_all

    printf "%-20s %-15s %s\n" "Manager" "Status" "Details"
    log_divider

    # Flatpak status
    if [[ $UNIVERSAL_HAS_FLATPAK -eq 1 ]]; then
        local remotes
        remotes=$(flatpak remotes 2>/dev/null | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
        local count
        count=$(flatpak list --app 2>/dev/null | wc -l)
        printf "%-20s ${GREEN}%-15s${RESET} %s\n" "Flatpak" "Installed" "Remotes: $remotes, Packages: $count"
    else
        printf "%-20s ${RED}%-15s${RESET} %s\n" "Flatpak" "Not installed" ""
    fi

    # Snap status
    if [[ $UNIVERSAL_HAS_SNAP -eq 1 ]]; then
        local count
        count=$(snap list 2>/dev/null | tail -n +2 | wc -l)
        printf "%-20s ${GREEN}%-15s${RESET} %s\n" "Snap" "Installed" "Packages: $count"
    else
        printf "%-20s ${RED}%-15s${RESET} %s\n" "Snap" "Not installed" ""
    fi

    # Nix status
    if [[ $UNIVERSAL_HAS_NIX -eq 1 ]]; then
        local count
        count=$(nix-env -q 2>/dev/null | wc -l)
        local version
        version=$(nix --version 2>/dev/null | cut -d' ' -f3)
        printf "%-20s ${GREEN}%-15s${RESET} %s\n" "Nix" "Installed" "Version: $version, Packages: $count"
    else
        printf "%-20s ${RED}%-15s${RESET} %s\n" "Nix" "Not installed" ""
    fi

    # Homebrew status
    if [[ $UNIVERSAL_HAS_HOMEBREW -eq 1 ]] || universal_homebrew_setup_path; then
        local count
        count=$(brew list 2>/dev/null | wc -l)
        local version
        version=$(brew --version 2>/dev/null | head -1 | cut -d' ' -f2)
        printf "%-20s ${GREEN}%-15s${RESET} %s\n" "Homebrew" "Installed" "Version: $version, Packages: $count"
    else
        printf "%-20s ${RED}%-15s${RESET} %s\n" "Homebrew" "Not installed" ""
    fi

    # AppImage status
    if [[ $UNIVERSAL_HAS_APPIMAGE -eq 1 ]]; then
        local manager="Unknown"
        command -v appimagelauncherd &>/dev/null && manager="AppImageLauncher"
        flatpak list --app 2>/dev/null | grep -q "it.mijorus.gearlever" && manager="Gear Lever"
        printf "%-20s ${GREEN}%-15s${RESET} %s\n" "AppImage Support" "Installed" "Manager: $manager"
    else
        printf "%-20s ${RED}%-15s${RESET} %s\n" "AppImage Support" "Not installed" ""
    fi

    # AUR status (Arch only)
    if is_arch; then
        if [[ $UNIVERSAL_HAS_AUR -eq 1 ]]; then
            local helper
            helper=$(universal_get_aur_helper)
            printf "%-20s ${GREEN}%-15s${RESET} %s\n" "AUR Helper" "Installed" "Helper: $helper"
        else
            printf "%-20s ${RED}%-15s${RESET} %s\n" "AUR Helper" "Not installed" ""
        fi
    fi

    echo ""
}

# ============================================================================
# Unified Installation Interface
# ============================================================================

# Install a universal package manager by name
universal_install() {
    local manager="$1"

    if [[ -z "$manager" ]]; then
        log_error "Manager name required"
        echo "Usage: universal_install <flatpak|snap|nix|homebrew|brew|appimage|aur>"
        return 1
    fi

    case "$manager" in
        flatpak)
            universal_install_flatpak
            ;;
        snap)
            universal_install_snap
            ;;
        nix)
            universal_install_nix
            ;;
        homebrew|brew)
            universal_install_homebrew
            ;;
        appimage)
            universal_install_appimage_support
            ;;
        aur)
            if is_arch; then
                universal_install_aur_helper
            else
                log_error "AUR is only available on Arch-based distributions"
                return 1
            fi
            ;;
        *)
            log_error "Unknown manager: $manager"
            echo "Available managers: flatpak, snap, nix, homebrew, appimage, aur (Arch only)"
            return 1
            ;;
    esac
}

# ============================================================================
# USAGE EXAMPLES AND DOCUMENTATION
# ============================================================================
#
# This module provides comprehensive universal package manager support.
#
# BASIC USAGE:
#
#   # Detect all available managers
#   universal_detect_all
#
#   # Show status of all managers
#   universal_status
#
#   # Install a specific manager
#   universal_install flatpak
#   universal_install snap
#   universal_install nix
#   universal_install homebrew
#   universal_install appimage
#   universal_install aur  # Arch only
#
# FLATPAK:
#
#   # Install Flatpak and setup Flathub
#   universal_install_flatpak
#
#   # Configure additional remotes
#   universal_config_set FLATPAK_ENABLE_BETA 1
#   universal_setup_flatpak_remotes
#
#   # Install Flatseal for permission management
#   universal_install_flatseal
#
# SNAP:
#
#   # Install Snap
#   universal_install_snap
#
#   # Wait for snapd to be ready
#   universal_snap_wait_ready
#
# NIX:
#
#   # Install Nix in multi-user mode (default)
#   universal_install_nix
#
#   # Install Nix in single-user mode
#   universal_config_set NIX_MULTI_USER 0
#   universal_install_nix
#
#   # Install a package
#   universal_nix_install firefox
#
# HOMEBREW:
#
#   # Install Homebrew
#   universal_install_homebrew
#
#   # Install a package
#   universal_brew_install neofetch
#
# APPIMAGE:
#
#   # Install AppImage support
#   universal_install_appimage_support
#
#   # Setup custom AppImage directory
#   universal_setup_appimage_dir
#
# AUR (ARCH ONLY):
#
#   # Install AUR helper (paru by default)
#   universal_install_aur_helper
#
#   # Install specific helper
#   universal_install_aur_helper yay
#
#   # Install package from AUR
#   universal_aur_install google-chrome
#
# CONFIGURATION:
#
#   # Get configuration value
#   universal_config_get FLATPAK_ENABLE_BETA
#
#   # Set configuration value
#   universal_config_set FLATPAK_ENABLE_BETA 1
#   universal_config_set AUR_HELPER paru
#
# DETECTION:
#
#   # Check individual managers
#   universal_has_flatpak && echo "Flatpak is available"
#   universal_has_snap && echo "Snap is available"
#   universal_has_nix && echo "Nix is available"
#   universal_has_homebrew && echo "Homebrew is available"
#   universal_has_aur_helper && echo "AUR helper available"
#
#   # Get AUR helper name
#   helper=$(universal_get_aur_helper)  # Returns "paru" or "yay" or ""
#
# PACKAGE COUNTS:
#
#   # Show package counts for all managers
#   universal_package_counts
#
# ============================================================================
