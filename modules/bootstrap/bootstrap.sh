#!/usr/bin/env bash
# OffTrack Suite - System Bootstrap
# Cross-distribution workstation setup
# License: GPL-3.0-or-later

[[ -n "${_BOOTSTRAP_LOADED:-}" ]] && return 0
readonly _BOOTSTRAP_LOADED=1

# Bootstrap mode
declare -g BOOTSTRAP_MODE=${BOOTSTRAP_MODE:-""}

# Package lists by category
declare -A BOOTSTRAP_PACKAGES

# Desktop/CLI utilities
BOOTSTRAP_PACKAGES[desktop]="vim neovim htop iotop btop tmux screen fzf bat jq yq curl wget rsync tree ncdu"

# Developer tools
BOOTSTRAP_PACKAGES[dev]="git gcc g++ make cmake python3 python3-pip nodejs npm rust cargo docker podman"

# Container tools
BOOTSTRAP_PACKAGES[containers]="docker docker-compose podman podman-compose"

# Run bootstrap wizard
bootstrap_wizard() {
    log_section "Bootstrap Wizard"

    # Show OS info
    log_info "Detected OS: $OS_PRETTY_NAME"
    log_info "Package Manager: $PKG_MANAGER"
    echo ""

    # Select mode
    local mode
    mode=$(tui_menu "Bootstrap Mode" "Select workstation setup type:" \
        "dev" "Developer Workstation" \
        "desktop" "Desktop Utilities" \
        "containers" "Container Tools" \
        "flatpak" "Flatpak Setup" \
        "full" "Full Setup (Everything)")

    [[ -z "$mode" ]] && return 0

    BOOTSTRAP_MODE="$mode"

    # Confirm
    if tui_yesno "Confirm" "Run $mode bootstrap?\n\nThis will install packages and may modify system configuration."; then
        bootstrap_run
    fi
}

# Run bootstrap
bootstrap_run() {
    local mode="${BOOTSTRAP_MODE:-full}"

    log_section "Running Bootstrap: $mode"

    # Create snapshot
    safety_checkpoint "bootstrap-$mode"

    # Check network
    if ! check_network; then
        log_error "Network connectivity required for bootstrap"
        return 1
    fi

    # Check disk space
    if ! check_disk_space 2000; then
        log_error "Insufficient disk space for bootstrap"
        return 1
    fi

    case "$mode" in
        dev)
            bootstrap_dev
            ;;
        desktop)
            bootstrap_desktop
            ;;
        containers)
            bootstrap_containers
            ;;
        flatpak)
            bootstrap_flatpak
            ;;
        full)
            bootstrap_full
            ;;
        *)
            log_error "Unknown bootstrap mode: $mode"
            return 1
            ;;
    esac

    log_success "Bootstrap complete: $mode"
}

# Desktop utilities
bootstrap_desktop() {
    log_section "Installing Desktop Utilities"

    local packages=()

    case "$OS_FAMILY" in
        fedora)
            packages=(vim neovim htop btop tmux fzf bat jq curl wget rsync tree ncdu ripgrep fd-find)
            ;;
        debian)
            packages=(vim neovim htop btop tmux fzf bat jq curl wget rsync tree ncdu ripgrep fd-find)
            ;;
        arch)
            packages=(vim neovim htop btop tmux fzf bat jq curl wget rsync tree ncdu ripgrep fd)
            ;;
    esac

    if [[ ${#packages[@]} -gt 0 ]]; then
        pkg_install "${packages[@]}"
    fi
}

# Developer workstation
bootstrap_dev() {
    log_section "Installing Developer Tools"

    # First install desktop utilities
    bootstrap_desktop

    local packages=()

    case "$OS_FAMILY" in
        fedora)
            packages=(git gcc gcc-c++ make cmake python3 python3-pip python3-devel nodejs npm golang)
            ;;
        debian)
            packages=(git gcc g++ make cmake python3 python3-pip python3-venv nodejs npm golang)
            ;;
        arch)
            packages=(git gcc make cmake python python-pip nodejs npm go)
            ;;
    esac

    if [[ ${#packages[@]} -gt 0 ]]; then
        pkg_install "${packages[@]}"
    fi

    # Install Rust via rustup
    log_info "Installing Rust via rustup..."
    if ! command_exists rustup; then
        if [[ $DRY_RUN -eq 0 ]]; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        else
            log_info "[DRY-RUN] Would install rustup"
        fi
    fi

    # Configure git if not set
    if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
        log_info "Git user not configured - skipping global config"
    fi
}

# Container tools
bootstrap_containers() {
    log_section "Installing Container Tools"

    case "$OS_FAMILY" in
        fedora)
            pkg_install podman podman-compose docker docker-compose
            # Enable Docker socket
            safe_exec systemctl enable --now docker.socket 2>/dev/null || true
            ;;
        debian)
            pkg_install docker.io docker-compose podman
            safe_exec systemctl enable --now docker.service 2>/dev/null || true
            ;;
        arch)
            pkg_install docker docker-compose podman podman-compose
            safe_exec systemctl enable --now docker.socket 2>/dev/null || true
            ;;
    esac

    # Add current user to docker group
    local user="${SUDO_USER:-$USER}"
    if [[ -n "$user" ]] && [[ "$user" != "root" ]]; then
        safe_exec usermod -aG docker "$user" 2>/dev/null || true
        log_info "Added $user to docker group (re-login required)"
    fi
}

# Flatpak setup
bootstrap_flatpak() {
    log_section "Setting up Flatpak"

    pkg_install_flatpak

    log_success "Flatpak configured with Flathub remote"
}

# Full bootstrap
bootstrap_full() {
    log_section "Full Workstation Bootstrap"

    bootstrap_desktop
    bootstrap_dev
    bootstrap_containers
    bootstrap_flatpak

    log_success "Full bootstrap complete"
}

# Capture package list
bootstrap_capture() {
    local output="${1:-packages-$(date +%Y%m%d).txt}"

    log_info "Capturing installed packages to: $output"

    case "$PKG_MANAGER" in
        apt)
            dpkg --get-selections | awk '$2=="install" {print $1}' > "$output"
            ;;
        dnf|yum)
            rpm -qa --qf '%{NAME}\n' | sort > "$output"
            ;;
        pacman)
            pacman -Qqe > "$output"
            ;;
        zypper)
            rpm -qa --qf '%{NAME}\n' | sort > "$output"
            ;;
        *)
            log_error "Package capture not supported for: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Captured $(wc -l < "$output") packages to $output"
}

# Restore package list
bootstrap_restore() {
    local input="$1"

    [[ -f "$input" ]] || {
        log_error "Package list file not found: $input"
        return 1
    }

    log_info "Restoring packages from: $input"

    # Create snapshot first
    safety_checkpoint "bootstrap-restore"

    # Read packages from file and install
    local packages=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && packages+=("$pkg")
    done < "$input"

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warn "No packages found in: $input"
        return 0
    fi

    log_info "Installing ${#packages[@]} packages..."

    case "$PKG_MANAGER" in
        apt)
            safe_exec apt-get install -y "${packages[@]}"
            ;;
        dnf)
            safe_exec dnf install -y "${packages[@]}"
            ;;
        pacman)
            safe_exec pacman -S --noconfirm --needed "${packages[@]}"
            ;;
        zypper)
            safe_exec zypper install -y "${packages[@]}"
            ;;
        *)
            log_error "Package restore not supported for: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Package restore complete"
}

# Bootstrap menu
bootstrap_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Bootstrap Menu" \
                "wizard" "Bootstrap Wizard" \
                "desktop" "Desktop Utilities" \
                "dev" "Developer Tools" \
                "containers" "Container Tools" \
                "flatpak" "Flatpak Setup" \
                "full" "Full Setup" \
                "capture" "Capture Packages" \
                "restore" "Restore Packages" \
                "back" "Back")
        else
            echo ""
            echo "Bootstrap Menu"
            echo "=============="
            echo ""
            echo "  1) Bootstrap Wizard"
            echo "  2) Desktop Utilities"
            echo "  3) Developer Tools"
            echo "  4) Container Tools"
            echo "  5) Flatpak Setup"
            echo "  6) Full Setup"
            echo "  7) Capture Packages"
            echo "  8) Restore Packages"
            echo "  b) Back"
            echo ""
            read -rp "Select: " num
            case "$num" in
                1) choice="wizard" ;;
                2) choice="desktop" ;;
                3) choice="dev" ;;
                4) choice="containers" ;;
                5) choice="flatpak" ;;
                6) choice="full" ;;
                7) choice="capture" ;;
                8) choice="restore" ;;
                b|B) choice="back" ;;
            esac
        fi

        case "$choice" in
            wizard)
                bootstrap_wizard
                ;;
            desktop)
                BOOTSTRAP_MODE="desktop"
                bootstrap_run
                read -rp "Press Enter to continue..."
                ;;
            dev)
                BOOTSTRAP_MODE="dev"
                bootstrap_run
                read -rp "Press Enter to continue..."
                ;;
            containers)
                BOOTSTRAP_MODE="containers"
                bootstrap_run
                read -rp "Press Enter to continue..."
                ;;
            flatpak)
                BOOTSTRAP_MODE="flatpak"
                bootstrap_run
                read -rp "Press Enter to continue..."
                ;;
            full)
                BOOTSTRAP_MODE="full"
                bootstrap_run
                read -rp "Press Enter to continue..."
                ;;
            capture)
                local outfile="packages-$(date +%Y%m%d).txt"
                read -rp "Output file [$outfile]: " custom
                [[ -n "$custom" ]] && outfile="$custom"
                bootstrap_capture "$outfile"
                read -rp "Press Enter to continue..."
                ;;
            restore)
                read -rp "Package list file: " pkgfile
                if [[ -n "$pkgfile" ]]; then
                    bootstrap_restore "$pkgfile"
                fi
                read -rp "Press Enter to continue..."
                ;;
            back|"")
                return
                ;;
        esac
    done
}
