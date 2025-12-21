#!/usr/bin/env bash
#
# profile_aliases.sh - Profile Aliases Installation Management
#
# Manages installation of modern CLI tool aliases to /etc/profile.d/
# for system-wide availability, or ~/.bashrc for user-level installation.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_PROFILE_ALIASES_LOADED:-}" ]] && return 0
readonly _PROFILE_ALIASES_LOADED=1

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
    }
fi

# ============================================================================
# Configuration
# ============================================================================

# Source file location
declare -gr ALIAS_SOURCE_FILE="${SCRIPT_DIR}/../configs/modern-cli.sh"

# System-wide installation path
declare -gr ALIAS_SYSTEM_PATH="/etc/profile.d/modern-cli.sh"

# User-level installation paths
declare -gr ALIAS_USER_PROFILE="${HOME}/.profile"
declare -gr ALIAS_USER_BASHRC="${HOME}/.bashrc"
declare -gr ALIAS_USER_DIR="${HOME}/.config/ultimate-linux-suite"
declare -gr ALIAS_USER_FILE="${ALIAS_USER_DIR}/modern-cli.sh"

# ============================================================================
# Detection Functions
# ============================================================================

# Check if system-level aliases are installed
is_system_aliases_installed() {
    [[ -f "$ALIAS_SYSTEM_PATH" ]]
}

# Check if user-level aliases are installed
is_user_aliases_installed() {
    [[ -f "$ALIAS_USER_FILE" ]] && grep -q "modern-cli.sh" "$ALIAS_USER_BASHRC" 2>/dev/null
}

# Check if aliases are installed (either level)
is_aliases_installed() {
    is_system_aliases_installed || is_user_aliases_installed
}

# Get installed alias path
get_alias_path() {
    if is_system_aliases_installed; then
        echo "$ALIAS_SYSTEM_PATH"
    elif is_user_aliases_installed; then
        echo "$ALIAS_USER_FILE"
    else
        echo "not installed"
    fi
}

# ============================================================================
# System-Level Installation (requires root)
# ============================================================================

# Install aliases system-wide to /etc/profile.d/
install_system_aliases() {
    if [[ $EUID -ne 0 ]]; then
        log_error "System-level alias installation requires root privileges"
        return 1
    fi

    if [[ ! -f "$ALIAS_SOURCE_FILE" ]]; then
        log_error "Alias source file not found: $ALIAS_SOURCE_FILE"
        return 1
    fi

    log_info "Installing system-wide aliases to $ALIAS_SYSTEM_PATH"

    # Copy the alias file
    cp "$ALIAS_SOURCE_FILE" "$ALIAS_SYSTEM_PATH"
    chmod 644 "$ALIAS_SYSTEM_PATH"

    log_success "System aliases installed"
    log_info "Aliases will be active for all users on next login"

    return 0
}

# Remove system-level aliases
remove_system_aliases() {
    if [[ $EUID -ne 0 ]]; then
        log_error "System-level alias removal requires root privileges"
        return 1
    fi

    if [[ ! -f "$ALIAS_SYSTEM_PATH" ]]; then
        log_info "System aliases not installed"
        return 0
    fi

    log_info "Removing system-wide aliases"
    rm -f "$ALIAS_SYSTEM_PATH"

    log_success "System aliases removed"
    return 0
}

# ============================================================================
# User-Level Installation
# ============================================================================

# Install aliases for current user only
install_user_aliases() {
    if [[ ! -f "$ALIAS_SOURCE_FILE" ]]; then
        log_error "Alias source file not found: $ALIAS_SOURCE_FILE"
        return 1
    fi

    log_info "Installing user-level aliases"

    # Create config directory
    mkdir -p "$ALIAS_USER_DIR"

    # Copy alias file
    cp "$ALIAS_SOURCE_FILE" "$ALIAS_USER_FILE"
    chmod 644 "$ALIAS_USER_FILE"

    # Add source line to .bashrc if not present
    local source_line="# Ultimate Linux Suite - Modern CLI aliases"
    local source_cmd="[[ -f \"$ALIAS_USER_FILE\" ]] && source \"$ALIAS_USER_FILE\""

    if ! grep -q "modern-cli.sh" "$ALIAS_USER_BASHRC" 2>/dev/null; then
        log_info "Adding alias source to $ALIAS_USER_BASHRC"
        {
            echo ""
            echo "$source_line"
            echo "$source_cmd"
        } >> "$ALIAS_USER_BASHRC"
    else
        log_debug "Alias source already in .bashrc"
    fi

    log_success "User aliases installed"
    log_info "Run 'source ~/.bashrc' or open a new terminal to activate"

    return 0
}

# Remove user-level aliases
remove_user_aliases() {
    log_info "Removing user-level aliases"

    # Remove alias file
    if [[ -f "$ALIAS_USER_FILE" ]]; then
        rm -f "$ALIAS_USER_FILE"
    fi

    # Remove source line from .bashrc
    if [[ -f "$ALIAS_USER_BASHRC" ]]; then
        # Create backup
        cp "$ALIAS_USER_BASHRC" "${ALIAS_USER_BASHRC}.bak"

        # Remove the lines
        sed -i '/Ultimate Linux Suite - Modern CLI aliases/d' "$ALIAS_USER_BASHRC"
        sed -i '/modern-cli\.sh/d' "$ALIAS_USER_BASHRC"

        log_debug "Removed alias source from .bashrc"
    fi

    log_success "User aliases removed"
    return 0
}

# ============================================================================
# Unified Installation Function
# ============================================================================

# Install aliases (auto-detects root vs user)
install_aliases() {
    local mode="${1:-auto}"

    case "$mode" in
        system)
            install_system_aliases
            ;;
        user)
            install_user_aliases
            ;;
        auto)
            if [[ $EUID -eq 0 ]]; then
                install_system_aliases
            else
                install_user_aliases
            fi
            ;;
        *)
            log_error "Unknown mode: $mode (use: system, user, auto)"
            return 1
            ;;
    esac
}

# Remove aliases (auto-detects level)
remove_aliases() {
    local removed=0

    if is_system_aliases_installed && [[ $EUID -eq 0 ]]; then
        remove_system_aliases && ((removed++))
    fi

    if is_user_aliases_installed; then
        remove_user_aliases && ((removed++))
    fi

    if [[ $removed -eq 0 ]]; then
        log_info "No aliases were installed"
    fi

    return 0
}

# ============================================================================
# Status and Information
# ============================================================================

# Show alias installation status
show_alias_status() {
    echo "=== Modern CLI Alias Status ==="
    echo ""

    echo "Source file: $ALIAS_SOURCE_FILE"
    if [[ -f "$ALIAS_SOURCE_FILE" ]]; then
        echo "  Status: Available"
    else
        echo "  Status: MISSING"
    fi
    echo ""

    echo "System-level (/etc/profile.d/):"
    if is_system_aliases_installed; then
        echo "  Status: Installed"
        echo "  Path: $ALIAS_SYSTEM_PATH"
    else
        echo "  Status: Not installed"
    fi
    echo ""

    echo "User-level (~/.config/):"
    if is_user_aliases_installed; then
        echo "  Status: Installed"
        echo "  Path: $ALIAS_USER_FILE"
    else
        echo "  Status: Not installed"
    fi
    echo ""

    # Show which modern tools are available
    echo "Available modern tools:"
    local tools=("eza" "bat" "fd" "fdfind" "rg" "dust" "btop" "zoxide" "tldr" "delta" "jq" "yq")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            printf "  %-10s : installed\n" "$tool"
        fi
    done
}

# List the aliases that would be created
list_aliases() {
    echo "Modern CLI Aliases (when tools are installed):"
    echo ""
    echo "  ls   -> eza --icons --group-directories-first"
    echo "  ll   -> eza -l --icons --group-directories-first"
    echo "  la   -> eza -la --icons --group-directories-first"
    echo "  lt   -> eza --tree --icons --level=2"
    echo "  cat  -> bat --style=plain --paging=never"
    echo "  grep -> rg --color=auto"
    echo "  du   -> dust"
    echo "  top  -> btop"
    echo "  help -> tldr"
    echo "  lg   -> lazygit"
    echo ""
    echo "Original commands available with 'o' suffix (e.g., 'grepo', 'duo')"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Apply aliases to current shell (for immediate use)
apply_aliases_now() {
    if [[ -f "$ALIAS_SOURCE_FILE" ]]; then
        log_info "Applying aliases to current shell"
        source "$ALIAS_SOURCE_FILE"
        log_success "Aliases active in current shell"
    elif is_system_aliases_installed; then
        source "$ALIAS_SYSTEM_PATH"
        log_success "Aliases active in current shell"
    elif is_user_aliases_installed; then
        source "$ALIAS_USER_FILE"
        log_success "Aliases active in current shell"
    else
        log_error "No alias file found to source"
        return 1
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f is_system_aliases_installed
export -f is_user_aliases_installed
export -f is_aliases_installed
export -f get_alias_path
export -f install_system_aliases
export -f remove_system_aliases
export -f install_user_aliases
export -f remove_user_aliases
export -f install_aliases
export -f remove_aliases
export -f show_alias_status
export -f list_aliases
export -f apply_aliases_now
