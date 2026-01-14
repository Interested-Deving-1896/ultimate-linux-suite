#!/usr/bin/env bash
# Unified Suite - Configuration Management
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_CONFIG_LOADED:-}" ]] && return 0
readonly _UNIFIED_CONFIG_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"
[[ -z "${_UNIFIED_SAFETY_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/safety.sh"

# ============================================================
# CONFIGURATION PATHS
# ============================================================

readonly CONFIG_BASE_DIR="/etc/unified-suite"
readonly CONFIG_SYSCTL_DIR="/etc/sysctl.d"
readonly CONFIG_MODPROBE_DIR="/etc/modprobe.d"
readonly CONFIG_SYSTEMD_DIR="/etc/systemd/system"
readonly CONFIG_UDEV_DIR="/etc/udev/rules.d"

# User configuration
readonly USER_CONFIG_DIR="${HOME}/.unified-suite"
readonly USER_SETTINGS_FILE="${USER_CONFIG_DIR}/settings.conf"

# ============================================================
# CONFIGURATION TRACKING
# ============================================================

declare -A CONFIG_CHANGES

# Register a configuration change
register_config_change() {
    local config_type="$1"
    local config_file="$2"
    local description="${3:-}"

    CONFIG_CHANGES["$config_file"]="$config_type:$description"
    log_debug "Registered config change: $config_file ($config_type)"
}

# Get all configuration changes
get_config_changes() {
    for file in "${!CONFIG_CHANGES[@]}"; do
        echo "$file: ${CONFIG_CHANGES[$file]}"
    done
}

# ============================================================
# CONFIGURATION FILE OPERATIONS
# ============================================================

# Write configuration file with backup
write_config() {
    local file="$1"
    local content="$2"
    local config_type="${3:-general}"

    log_info "Writing configuration: $file"

    # Create backup
    if [[ -f "$file" ]]; then
        create_backup "$file"
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would write to $file:"
        echo "$content" | head -20
        [[ $(echo "$content" | wc -l) -gt 20 ]] && echo "..."
        return 0
    fi

    # Ensure directory exists
    mkdir -p "$(dirname "$file")"

    # Write content
    echo "$content" > "$file"

    # Register change
    register_config_change "$config_type" "$file"

    log_success "Configuration written: $file"
}

# Append to configuration file
append_config() {
    local file="$1"
    local content="$2"
    local marker="${3:-# Unified Suite}"

    # Check if already present
    if grep -q "$marker" "$file" 2>/dev/null; then
        log_debug "Configuration already present in $file"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would append to $file"
        return 0
    fi

    # Backup original
    if [[ -f "$file" ]]; then
        create_backup "$file"
    fi

    # Append with marker
    {
        echo ""
        echo "$marker - BEGIN"
        echo "$content"
        echo "$marker - END"
    } >> "$file"

    log_success "Configuration appended to $file"
}

# ============================================================
# USER SETTINGS
# ============================================================

# Initialize user settings
init_user_settings() {
    mkdir -p "$USER_CONFIG_DIR"

    if [[ ! -f "$USER_SETTINGS_FILE" ]]; then
        cat > "$USER_SETTINGS_FILE" << 'EOF'
# Unified Suite User Settings
# Generated automatically

# Optimization settings
OPTIMIZATION_PROFILE=auto
SWAPPINESS_OVERRIDE=
ZRAM_ENABLED=auto

# Application settings
APP_INSTALL_METHOD=auto
FLATPAK_ENABLED=true
SNAP_ENABLED=true

# MacBook settings
MACBOOK_AUTO_DETECT=true
MACBOOK_AUTO_FIX=false

# UI settings
TUI_BACKEND=auto
COLOR_ENABLED=true
VERBOSE_OUTPUT=false
EOF
        log_debug "Created default user settings"
    fi
}

# Load user settings
load_user_settings() {
    if [[ -f "$USER_SETTINGS_FILE" ]]; then
        source "$USER_SETTINGS_FILE"
        log_debug "Loaded user settings"
    fi
}

# Save user setting
save_user_setting() {
    local key="$1"
    local value="$2"

    init_user_settings

    # Safer approach: delete existing line and append new one
    # This avoids issues with special characters in the value
    sed -i "/^${key}=/d" "$USER_SETTINGS_FILE" 2>/dev/null || true
    echo "${key}=${value}" >> "$USER_SETTINGS_FILE"

    log_debug "Saved user setting: $key=$value"
}

# Get user setting
get_user_setting() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$USER_SETTINGS_FILE" ]]; then
        local value=$(grep "^${key}=" "$USER_SETTINGS_FILE" 2>/dev/null | cut -d= -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Initialize on source
init_user_settings
