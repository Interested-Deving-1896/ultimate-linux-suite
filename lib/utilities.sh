#!/usr/bin/env bash
#
# utilities.sh - Utility Installation Matrix for Ultimate Linux Suite
#
# Provides categorized utility installation with multi-method support.
# Tries native packages first, then falls back to cargo, pip, npm,
# or direct binary downloads as needed.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_UTILITIES_LOADED:-}" ]] && return 0
readonly _UTILITIES_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_section() { echo ""; echo "=== $* ==="; }
        log_divider() { echo "────────────────────────────────────────"; }
        # Define colors for fallback
        GREEN='\033[0;32m'
        RED='\033[0;31m'
        RESET='\033[0m'
    }
fi

# Source pkg.sh with fallback
if ! declare -f pkg_install &>/dev/null; then
    source "${SCRIPT_DIR}/pkg.sh" 2>/dev/null || {
        log_warn "pkg.sh not available - native package installation disabled"
    }
fi

# ============================================================================
# Global Variables
# ============================================================================

# Binary installation directory
declare -g UTIL_BIN_DIR="${HOME}/.local/bin"

# State tracking
declare -g UTIL_STATE_DIR="${HOME}/.local/state/ultimate-linux-suite/utilities"
declare -g UTIL_INSTALL_LOG="${UTIL_STATE_DIR}/install.log"

# ============================================================================
# Initialization
# ============================================================================

_utilities_init() {
    mkdir -p "$UTIL_BIN_DIR" 2>/dev/null || log_warn "Cannot create bin directory"
    mkdir -p "$UTIL_STATE_DIR" 2>/dev/null || log_warn "Cannot create state directory"

    # Ensure ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$UTIL_BIN_DIR:"* ]]; then
        export PATH="$UTIL_BIN_DIR:$PATH"
    fi
}

_utilities_init

# ============================================================================
# Package Name Mappings (Distro-specific)
# ============================================================================

# Map generic names to distro-specific package names
declare -gA PKG_NAMES_APT=(
    # Download Tools
    [curl]="curl"
    [wget]="wget"
    [aria2]="aria2"
    [axel]="axel"

    # Compression
    [tar]="tar"
    [gzip]="gzip"
    [bzip2]="bzip2"
    [xz]="xz-utils"
    [zip]="zip unzip"
    [7z]="p7zip-full"
    [zstd]="zstd"
    [pigz]="pigz"
    [lz4]="lz4"

    # Version Control
    [git]="git"
    [mercurial]="mercurial"
    [svn]="subversion"

    # Build Tools
    [make]="make"
    [cmake]="cmake"
    [meson]="meson"
    [ninja]="ninja-build"
    [gcc]="build-essential"
    [clang]="clang"
    [rust]="rustc cargo"

    # Modern CLI
    [htop]="htop"
    [btop]="btop"
    [ncdu]="ncdu"
    [tree]="tree"
    [fd]="fd-find"
    [ripgrep]="ripgrep"
    [bat]="bat"
    [eza]="eza"
    [fzf]="fzf"
    [jq]="jq"
    [yq]="yq"
    [tldr]="tldr"
    [neofetch]="neofetch"
    [fastfetch]="fastfetch"
    [duf]="duf"
    [dust]="dust"
    [procs]="procs"
    [bottom]="bottom"
    [zoxide]="zoxide"
    [starship]="starship"
    [delta]="git-delta"
    [hyperfine]="hyperfine"
    [tokei]="tokei"

    # Network
    [nmap]="nmap"
    [netcat]="netcat-openbsd"
    [socat]="socat"
    [tcpdump]="tcpdump"
    [mtr]="mtr"
    [iperf3]="iperf3"
    [nload]="nload"
    [iftop]="iftop"
    [nethogs]="nethogs"
    [bandwhich]="bandwhich"
    [httpie]="httpie"
    [curlie]="curlie"

    # Editors
    [vim]="vim"
    [neovim]="neovim"
    [nano]="nano"
    [micro]="micro"
    [helix]="helix"
    [emacs]="emacs"

    # Shell
    [zsh]="zsh"
    [fish]="fish"
    [bash]="bash"
    [tmux]="tmux"
    [screen]="screen"
    [zellij]="zellij"

    # Disk Tools
    [gparted]="gparted"
    [parted]="parted"
    [lsblk]="util-linux"
    [smartmontools]="smartmontools"
    [hdparm]="hdparm"

    # System Monitoring
    [sysstat]="sysstat"
    [iotop]="iotop"
    [lsof]="lsof"
    [strace]="strace"
    [ltrace]="ltrace"
    [perf]="linux-perf"

    # File Tools
    [rsync]="rsync"
    [rclone]="rclone"
    [borg]="borgbackup"
    [restic]="restic"

    # Misc
    [imagemagick]="imagemagick"
    [ffmpeg]="ffmpeg"
    [pandoc]="pandoc"
    [poppler]="poppler-utils"
)

declare -gA PKG_NAMES_DNF=(
    [curl]="curl"
    [wget]="wget"
    [aria2]="aria2"
    [axel]="axel"
    [xz]="xz"
    [zip]="zip unzip"
    [7z]="p7zip p7zip-plugins"
    [zstd]="zstd"
    [git]="git"
    [make]="make"
    [cmake]="cmake"
    [meson]="meson"
    [ninja]="ninja-build"
    [gcc]="gcc gcc-c++"
    [htop]="htop"
    [btop]="btop"
    [ncdu]="ncdu"
    [tree]="tree"
    [fd]="fd-find"
    [ripgrep]="ripgrep"
    [bat]="bat"
    [eza]="eza"
    [fzf]="fzf"
    [jq]="jq"
    [nmap]="nmap"
    [netcat]="nmap-ncat"
    [socat]="socat"
    [tcpdump]="tcpdump"
    [mtr]="mtr"
    [vim]="vim-enhanced"
    [neovim]="neovim"
    [nano]="nano"
    [zsh]="zsh"
    [fish]="fish"
    [tmux]="tmux"
    [rsync]="rsync"
    [ffmpeg]="ffmpeg"
    [neofetch]="neofetch"
    [fastfetch]="fastfetch"
)

declare -gA PKG_NAMES_PACMAN=(
    [curl]="curl"
    [wget]="wget"
    [aria2]="aria2"
    [axel]="axel"
    [xz]="xz"
    [zip]="zip unzip"
    [7z]="p7zip"
    [zstd]="zstd"
    [git]="git"
    [make]="make"
    [cmake]="cmake"
    [meson]="meson"
    [ninja]="ninja"
    [gcc]="base-devel"
    [htop]="htop"
    [btop]="btop"
    [ncdu]="ncdu"
    [tree]="tree"
    [fd]="fd"
    [ripgrep]="ripgrep"
    [bat]="bat"
    [eza]="eza"
    [fzf]="fzf"
    [jq]="jq"
    [yq]="yq"
    [nmap]="nmap"
    [netcat]="openbsd-netcat"
    [socat]="socat"
    [tcpdump]="tcpdump"
    [mtr]="mtr"
    [vim]="vim"
    [neovim]="neovim"
    [nano]="nano"
    [micro]="micro"
    [helix]="helix"
    [zsh]="zsh"
    [fish]="fish"
    [tmux]="tmux"
    [zellij]="zellij"
    [rsync]="rsync"
    [ffmpeg]="ffmpeg"
    [neofetch]="neofetch"
    [fastfetch]="fastfetch"
    [zoxide]="zoxide"
    [starship]="starship"
    [delta]="git-delta"
    [dust]="dust"
    [procs]="procs"
    [bottom]="bottom"
    [hyperfine]="hyperfine"
    [tokei]="tokei"
    [bandwhich]="bandwhich"
)

declare -gA PKG_NAMES_ZYPPER=(
    [curl]="curl"
    [wget]="wget"
    [aria2]="aria2"
    [xz]="xz"
    [zip]="zip unzip"
    [7z]="p7zip"
    [git]="git"
    [make]="make"
    [cmake]="cmake"
    [meson]="meson"
    [ninja]="ninja"
    [htop]="htop"
    [tree]="tree"
    [fzf]="fzf"
    [jq]="jq"
    [vim]="vim"
    [neovim]="neovim"
    [nano]="nano"
    [zsh]="zsh"
    [fish]="fish"
    [tmux]="tmux"
    [rsync]="rsync"
)

# ============================================================================
# Utility Categories
# ============================================================================

# Define utility categories and their components
declare -gA UTIL_CATEGORIES=(
    [download]="curl wget aria2 axel"
    [compression]="tar gzip bzip2 xz zip 7z zstd pigz lz4"
    [vcs]="git mercurial svn"
    [build]="make cmake meson ninja gcc clang"
    [modern-cli]="htop btop ncdu tree fd ripgrep bat eza fzf jq yq tldr"
    [network]="nmap netcat socat tcpdump mtr iperf3 nload iftop nethogs httpie"
    [editors]="vim neovim nano micro"
    [shell]="zsh fish tmux screen zellij"
    [disk]="gparted parted smartmontools hdparm"
    [monitoring]="sysstat iotop lsof strace perf"
    [backup]="rsync rclone borg restic"
    [media]="imagemagick ffmpeg pandoc poppler"
    [rust-tools]="fd ripgrep bat eza dust procs bottom zoxide starship delta hyperfine tokei bandwhich"
    [essential]="curl wget git vim htop tree fzf jq rsync tmux"
    [developer]="git vim neovim make cmake jq fd ripgrep bat fzf tmux"
    [sysadmin]="htop iotop lsof strace nmap tcpdump rsync tmux vim"
)

# ============================================================================
# Package Name Resolution
# ============================================================================

# Get package name for current distro
_get_pkg_name() {
    local generic_name="$1"
    local pkg_name=""

    case "$PKG_MANAGER" in
        apt)
            pkg_name="${PKG_NAMES_APT[$generic_name]:-$generic_name}"
            ;;
        dnf|yum)
            pkg_name="${PKG_NAMES_DNF[$generic_name]:-$generic_name}"
            ;;
        pacman)
            pkg_name="${PKG_NAMES_PACMAN[$generic_name]:-$generic_name}"
            ;;
        zypper)
            pkg_name="${PKG_NAMES_ZYPPER[$generic_name]:-$generic_name}"
            ;;
        *)
            pkg_name="$generic_name"
            ;;
    esac

    echo "$pkg_name"
}

# ============================================================================
# Installation Method Detection
# ============================================================================

# Check if cargo (Rust) is available
_has_cargo() {
    command -v cargo &>/dev/null
}

# Check if pip is available
_has_pip() {
    command -v pip3 &>/dev/null || command -v pip &>/dev/null
}

# Check if npm is available
_has_npm() {
    command -v npm &>/dev/null
}

# Check if go is available
_has_go() {
    command -v go &>/dev/null
}

# ============================================================================
# Alternative Installation Methods
# ============================================================================

# Install via Cargo (Rust)
_install_cargo() {
    local pkg="$1"
    local crate_name="${2:-$pkg}"

    if ! _has_cargo; then
        log_debug "Cargo not available"
        return 1
    fi

    log_info "Installing $pkg via Cargo..."
    cargo install "$crate_name" 2>&1 && {
        log_success "Installed $pkg via Cargo"
        return 0
    }

    return 1
}

# Install via pip
_install_pip() {
    local pkg="$1"
    local pip_name="${2:-$pkg}"

    if ! _has_pip; then
        log_debug "pip not available"
        return 1
    fi

    log_info "Installing $pkg via pip..."
    pip3 install --user "$pip_name" 2>&1 || pip install --user "$pip_name" 2>&1 && {
        log_success "Installed $pkg via pip"
        return 0
    }

    return 1
}

# Install via npm
_install_npm() {
    local pkg="$1"
    local npm_name="${2:-$pkg}"

    if ! _has_npm; then
        log_debug "npm not available"
        return 1
    fi

    log_info "Installing $pkg via npm..."
    npm install -g "$npm_name" 2>&1 && {
        log_success "Installed $pkg via npm"
        return 0
    }

    return 1
}

# Install via Go
_install_go() {
    local pkg="$1"
    local go_path="$2"

    if ! _has_go; then
        log_debug "Go not available"
        return 1
    fi

    if [[ -z "$go_path" ]]; then
        log_debug "Go install path not specified"
        return 1
    fi

    log_info "Installing $pkg via Go..."
    go install "$go_path" 2>&1 && {
        log_success "Installed $pkg via Go"
        return 0
    }

    return 1
}

# Download binary directly
_install_binary() {
    local name="$1"
    local url="$2"
    local target="${UTIL_BIN_DIR}/${name}"

    if [[ -z "$url" ]]; then
        log_debug "No URL specified for binary download"
        return 1
    fi

    log_info "Downloading binary: $name"

    # Download
    if command -v wget &>/dev/null; then
        wget -q -O "$target" "$url" || return 1
    elif command -v curl &>/dev/null; then
        curl -sL -o "$target" "$url" || return 1
    else
        log_error "Neither wget nor curl available"
        return 1
    fi

    # Make executable
    chmod +x "$target" && {
        log_success "Installed binary: $name"
        return 0
    }

    return 1
}

# ============================================================================
# Cascade Installation for Utilities
# ============================================================================

# Alternative installation specs for utilities that may not be in native repos
declare -gA UTIL_ALTERNATIVES=(
    # Rust tools - cargo fallback
    [fd]="cargo:fd-find"
    [ripgrep]="cargo:ripgrep"
    [bat]="cargo:bat"
    [eza]="cargo:eza"
    [dust]="cargo:du-dust"
    [procs]="cargo:procs"
    [bottom]="cargo:bottom"
    [zoxide]="cargo:zoxide"
    [starship]="cargo:starship"
    [delta]="cargo:git-delta"
    [hyperfine]="cargo:hyperfine"
    [tokei]="cargo:tokei"
    [bandwhich]="cargo:bandwhich"

    # Python tools
    [httpie]="pip:httpie"
    [tldr]="pip:tldr"
    [yq]="pip:yq"

    # Node tools
    [tldr]="npm:tldr"

    # Go tools
    [lazygit]="go:github.com/jesseduffield/lazygit@latest"
    [glow]="go:github.com/charmbracelet/glow@latest"
    [fzf]="go:github.com/junegunn/fzf@latest"
)

# Install a single utility with cascade fallback
util_install() {
    local util="$1"

    if [[ -z "$util" ]]; then
        log_error "Usage: util_install UTILITY"
        return 1
    fi

    # Check if already installed
    if command -v "$util" &>/dev/null; then
        log_success "Already installed: $util"
        return 0
    fi

    log_info "Installing utility: $util"

    # Try native package first
    local pkg_name
    pkg_name=$(_get_pkg_name "$util")

    if [[ -n "$pkg_name" ]]; then
        log_debug "Trying native package: $pkg_name"
        # shellcheck disable=SC2086
        if pkg_install $pkg_name 2>/dev/null; then
            if command -v "$util" &>/dev/null; then
                log_success "Installed $util via native package"
                _log_install "$util" "native" "$pkg_name"
                return 0
            fi
        fi
    fi

    # Try alternative installation methods
    local alt="${UTIL_ALTERNATIVES[$util]:-}"
    if [[ -n "$alt" ]]; then
        local method="${alt%%:*}"
        local spec="${alt#*:}"

        case "$method" in
            cargo)
                if _install_cargo "$util" "$spec"; then
                    _log_install "$util" "cargo" "$spec"
                    return 0
                fi
                ;;
            pip)
                if _install_pip "$util" "$spec"; then
                    _log_install "$util" "pip" "$spec"
                    return 0
                fi
                ;;
            npm)
                if _install_npm "$util" "$spec"; then
                    _log_install "$util" "npm" "$spec"
                    return 0
                fi
                ;;
            go)
                if _install_go "$util" "$spec"; then
                    _log_install "$util" "go" "$spec"
                    return 0
                fi
                ;;
            binary)
                if _install_binary "$util" "$spec"; then
                    _log_install "$util" "binary" "$spec"
                    return 0
                fi
                ;;
        esac
    fi

    log_error "Failed to install: $util"
    return 1
}

# Log installation for tracking
_log_install() {
    local util="$1"
    local method="$2"
    local spec="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "${timestamp}|${util}|${method}|${spec}" >> "$UTIL_INSTALL_LOG" 2>/dev/null
}

# ============================================================================
# Category Installation
# ============================================================================

# Install all utilities in a category
util_install_category() {
    local category="$1"

    if [[ -z "$category" ]]; then
        log_error "Usage: util_install_category CATEGORY"
        util_list_categories
        return 1
    fi

    local utils="${UTIL_CATEGORIES[$category]:-}"

    if [[ -z "$utils" ]]; then
        log_error "Unknown category: $category"
        util_list_categories
        return 1
    fi

    log_section "Installing $category utilities"

    local total=0
    local succeeded=0
    local failed=0
    local skipped=0

    for util in $utils; do
        ((total++))

        # Check if already installed
        if command -v "$util" &>/dev/null; then
            log_debug "Already installed: $util"
            ((skipped++))
            continue
        fi

        if util_install "$util"; then
            ((succeeded++))
        else
            ((failed++))
        fi
    done

    log_divider
    log_info "Category $category: Total=$total Installed=$succeeded Skipped=$skipped Failed=$failed"

    [[ $failed -eq 0 ]]
}

# Install multiple categories
util_install_categories() {
    local categories=("$@")
    local overall_failed=0

    for cat in "${categories[@]}"; do
        if ! util_install_category "$cat"; then
            ((overall_failed++))
        fi
    done

    [[ $overall_failed -eq 0 ]]
}

# ============================================================================
# Preset Bundles
# ============================================================================

# Install essential utilities bundle
util_install_essentials() {
    log_section "Installing Essential Utilities"
    util_install_category "essential"
}

# Install developer utilities bundle
util_install_developer() {
    log_section "Installing Developer Utilities"
    util_install_categories "essential" "vcs" "build" "developer"
}

# Install sysadmin utilities bundle
util_install_sysadmin() {
    log_section "Installing Sysadmin Utilities"
    util_install_categories "essential" "network" "monitoring" "sysadmin"
}

# Install modern CLI replacements
util_install_modern_cli() {
    log_section "Installing Modern CLI Tools"
    util_install_category "modern-cli"
}

# Install Rust-based modern tools
util_install_rust_tools() {
    log_section "Installing Rust-based Tools"

    # Ensure Rust is installed
    if ! _has_cargo; then
        log_warn "Cargo not installed. Installing Rust..."
        if ! _install_rust; then
            log_error "Failed to install Rust. Cannot proceed with Rust tools."
            return 1
        fi
    fi

    util_install_category "rust-tools"
}

# Install Rust (rustup)
_install_rust() {
    log_info "Installing Rust via rustup..."

    if command -v rustup &>/dev/null; then
        log_success "Rust is already installed"
        return 0
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && {
        # Source cargo environment
        if [[ -f "$HOME/.cargo/env" ]]; then
            # shellcheck source=/dev/null
            source "$HOME/.cargo/env"
        fi
        log_success "Rust installed successfully"
        return 0
    }

    log_error "Failed to install Rust"
    return 1
}

# ============================================================================
# Listing and Information
# ============================================================================

# List all utility categories
util_list_categories() {
    log_info "Available utility categories:"
    echo ""

    for cat in "${!UTIL_CATEGORIES[@]}"; do
        local utils="${UTIL_CATEGORIES[$cat]}"
        local count
        count=$(echo "$utils" | wc -w)
        printf "  %-15s (%d utilities)\n" "$cat" "$count"
    done | sort
}

# List utilities in a category
util_list_category() {
    local category="$1"

    if [[ -z "$category" ]]; then
        log_error "Usage: util_list_category CATEGORY"
        return 1
    fi

    local utils="${UTIL_CATEGORIES[$category]:-}"

    if [[ -z "$utils" ]]; then
        log_error "Unknown category: $category"
        return 1
    fi

    log_info "Utilities in '$category':"
    echo ""

    for util in $utils; do
        local status="[ ]"
        if command -v "$util" &>/dev/null; then
            status="[x]"
        fi
        printf "  %s %s\n" "$status" "$util"
    done
}

# Show status of all utilities
util_status() {
    log_section "Utility Installation Status"

    local installed=0
    local missing=0

    for cat in "${!UTIL_CATEGORIES[@]}"; do
        echo ""
        echo "=== $cat ==="

        local utils="${UTIL_CATEGORIES[$cat]}"
        for util in $utils; do
            if command -v "$util" &>/dev/null; then
                printf "  ${GREEN}[x]${RESET} %s\n" "$util"
                ((installed++))
            else
                printf "  ${RED}[ ]${RESET} %s\n" "$util"
                ((missing++))
            fi
        done
    done

    echo ""
    log_info "Summary: Installed=$installed Missing=$missing"
}

# Check what's installed vs missing
util_check() {
    local utils=("$@")

    if [[ ${#utils[@]} -eq 0 ]]; then
        log_error "Usage: util_check UTIL1 UTIL2 ..."
        return 1
    fi

    local installed=()
    local missing=()

    for util in "${utils[@]}"; do
        if command -v "$util" &>/dev/null; then
            installed+=("$util")
        else
            missing+=("$util")
        fi
    done

    if [[ ${#installed[@]} -gt 0 ]]; then
        log_success "Installed: ${installed[*]}"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing: ${missing[*]}"
        return 1
    fi

    return 0
}

# ============================================================================
# Installation History
# ============================================================================

# Show installation history
util_history() {
    if [[ ! -f "$UTIL_INSTALL_LOG" ]]; then
        log_info "No installation history found"
        return 0
    fi

    log_info "Utility installation history:"
    echo ""
    printf "%-20s %-15s %-10s %s\n" "TIMESTAMP" "UTILITY" "METHOD" "SPEC"
    log_divider

    tail -n 50 "$UTIL_INSTALL_LOG" | while IFS='|' read -r timestamp util method spec; do
        printf "%-20s %-15s %-10s %s\n" "$timestamp" "$util" "$method" "$spec"
    done
}

# ============================================================================
# Quick Install Functions
# ============================================================================

# Install common download tools
util_install_download_tools() {
    util_install curl
    util_install wget
    util_install aria2
}

# Install common compression tools
util_install_compression_tools() {
    util_install_category "compression"
}

# Install version control tools
util_install_vcs_tools() {
    util_install_category "vcs"
}

# Install build tools
util_install_build_tools() {
    util_install_category "build"
}

# Install networking tools
util_install_network_tools() {
    util_install_category "network"
}

# Install all editors
util_install_editors() {
    util_install_category "editors"
}

# Install shell enhancements
util_install_shell_tools() {
    util_install_category "shell"
}

# ============================================================================
# Batch Installation
# ============================================================================

# Install multiple utilities at once
util_batch_install() {
    local utils=("$@")

    if [[ ${#utils[@]} -eq 0 ]]; then
        log_error "Usage: util_batch_install UTIL1 UTIL2 ..."
        return 1
    fi

    local total=${#utils[@]}
    local succeeded=0
    local failed=0
    local failed_list=()

    log_section "Batch Installing $total Utilities"

    for util in "${utils[@]}"; do
        if util_install "$util"; then
            ((succeeded++))
        else
            ((failed++))
            failed_list+=("$util")
        fi
    done

    log_divider
    log_info "Batch complete: Succeeded=$succeeded Failed=$failed"

    if [[ ${#failed_list[@]} -gt 0 ]]; then
        log_warn "Failed to install: ${failed_list[*]}"
        return 1
    fi

    return 0
}

# ============================================================================
# Interactive Installation
# ============================================================================

# Interactive category selector (requires fzf or similar)
util_interactive_install() {
    if command -v fzf &>/dev/null; then
        local category
        category=$(printf '%s\n' "${!UTIL_CATEGORIES[@]}" | sort | \
                   fzf --prompt="Select category: " --height=40%)

        if [[ -n "$category" ]]; then
            util_install_category "$category"
        fi
    elif command -v gum &>/dev/null; then
        local category
        category=$(printf '%s\n' "${!UTIL_CATEGORIES[@]}" | sort | \
                   gum choose --header="Select category to install:")

        if [[ -n "$category" ]]; then
            util_install_category "$category"
        fi
    else
        log_warn "Interactive mode requires fzf or gum"
        util_list_categories
        return 1
    fi
}

# ============================================================================
# USAGE DOCUMENTATION
# ============================================================================
#
# UTILITIES.SH - Utility Installation Matrix
# ==========================================
#
# SINGLE UTILITY INSTALLATION:
#
#   util_install ripgrep
#   util_install fd
#   util_install bat
#
# CATEGORY INSTALLATION:
#
#   # List categories
#   util_list_categories
#
#   # Install a category
#   util_install_category modern-cli
#   util_install_category network
#
#   # Install multiple categories
#   util_install_categories essential vcs build
#
# PRESET BUNDLES:
#
#   # Essential utilities
#   util_install_essentials
#
#   # Developer setup
#   util_install_developer
#
#   # Sysadmin setup
#   util_install_sysadmin
#
#   # Modern CLI replacements
#   util_install_modern_cli
#
#   # Rust-based tools (with auto Rust install)
#   util_install_rust_tools
#
# QUICK INSTALL FUNCTIONS:
#
#   util_install_download_tools
#   util_install_compression_tools
#   util_install_vcs_tools
#   util_install_build_tools
#   util_install_network_tools
#   util_install_editors
#   util_install_shell_tools
#
# BATCH INSTALLATION:
#
#   util_batch_install fd ripgrep bat eza fzf
#
# STATUS AND LISTING:
#
#   # Show all utility status
#   util_status
#
#   # List utilities in category
#   util_list_category modern-cli
#
#   # Check specific utilities
#   util_check git vim curl
#
#   # View installation history
#   util_history
#
# INTERACTIVE:
#
#   util_interactive_install
#
# AVAILABLE CATEGORIES:
#
#   download    - curl, wget, aria2, axel
#   compression - tar, gzip, bzip2, xz, zip, 7z, zstd
#   vcs         - git, mercurial, svn
#   build       - make, cmake, meson, ninja, gcc
#   modern-cli  - htop, btop, fd, ripgrep, bat, eza, fzf, etc.
#   network     - nmap, netcat, socat, tcpdump, mtr, etc.
#   editors     - vim, neovim, nano, micro
#   shell       - zsh, fish, tmux, screen, zellij
#   disk        - gparted, parted, smartmontools
#   monitoring  - sysstat, iotop, lsof, strace
#   backup      - rsync, rclone, borg, restic
#   media       - imagemagick, ffmpeg, pandoc
#   rust-tools  - All Rust-based modern tools
#   essential   - Core utilities everyone needs
#   developer   - Developer-focused utilities
#   sysadmin    - System administration utilities
#
# ============================================================================
