#!/usr/bin/env bash
#
# pkg_cascade.sh - Cascade Installation System for Ultimate Linux Suite
#
# Implements the "try all installers" pattern from the compass document.
# When installing an application, tries installation methods in priority order
# (native → flatpak → snap → appimage) and handles failures gracefully.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_PKG_CASCADE_LOADED:-}" ]] && return 0
readonly _PKG_CASCADE_LOADED=1

# ============================================================================
# Dependencies
# ============================================================================

# Source required modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
        log_section() { echo ""; echo "=== $* ==="; echo ""; }
        log_divider() { echo "────────────────────────────────────────"; }
        log_step() { echo "[$1${2:+/$2}] $3"; }
    }
fi

# Source pkg.sh with fallback
if ! declare -f pkg_install &>/dev/null; then
    source "${SCRIPT_DIR}/pkg.sh" 2>/dev/null || {
        log_error "Cannot load pkg.sh - package operations will be limited"
        # Provide minimal fallback functions
        pkg_install() { log_error "pkg_install not available"; return 1; }
        pkg_is_installed() { return 1; }
        flatpak_available() { command -v flatpak &>/dev/null; }
        flatpak_is_installed() { flatpak list --app 2>/dev/null | grep -q "$1"; }
        flatpak_install() { flatpak install -y flathub "$1"; }
        snap_available() { command -v snap &>/dev/null; }
        snap_is_installed() { snap list "$1" &>/dev/null; }
        snap_install() { snap install "$1"; }
        flatpak_setup_flathub() { flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null; }
    }
fi

# ============================================================================
# Global Variables
# ============================================================================

# Transaction and state directories
declare -g CASCADE_STATE_DIR="${HOME}/.local/state/ultimate-linux-suite"
declare -g CASCADE_TRANSACTION_LOG="${CASCADE_STATE_DIR}/transactions.log"
declare -g CASCADE_SNAPSHOT_DIR="${CASCADE_STATE_DIR}/snapshots"
declare -g CASCADE_APPIMAGE_DIR="${HOME}/.local/bin"
declare -g CASCADE_DESKTOP_DIR="${HOME}/.local/share/applications"

# Installation method priority (can be customized)
declare -ga PKG_METHOD_PRIORITY=(
    "native"
    "flatpak"
    "snap"
    "appimage"
    "source"
)

# Application installation methods storage
# Format: app_id → "native:pkg_name|flatpak:app.id|snap:name|appimage:url"
declare -gA APP_INSTALL_METHODS=()

# ============================================================================
# Initialization
# ============================================================================

# Initialize cascade system
_cascade_init() {
    # Create necessary directories
    mkdir -p "$CASCADE_STATE_DIR" 2>/dev/null || log_warn "Cannot create state directory: $CASCADE_STATE_DIR"
    mkdir -p "$CASCADE_SNAPSHOT_DIR" 2>/dev/null || log_warn "Cannot create snapshot directory: $CASCADE_SNAPSHOT_DIR"
    mkdir -p "$CASCADE_APPIMAGE_DIR" 2>/dev/null || log_warn "Cannot create AppImage directory: $CASCADE_APPIMAGE_DIR"
    mkdir -p "$CASCADE_DESKTOP_DIR" 2>/dev/null || log_warn "Cannot create desktop directory: $CASCADE_DESKTOP_DIR"

    # Ensure transaction log exists
    touch "$CASCADE_TRANSACTION_LOG" 2>/dev/null || log_warn "Cannot create transaction log: $CASCADE_TRANSACTION_LOG"
}

# Run initialization
_cascade_init

# ============================================================================
# Method Priority Configuration
# ============================================================================

# Set custom method priority
# Usage: pkg_set_method_priority METHOD1 METHOD2 METHOD3 ...
pkg_set_method_priority() {
    local methods=("$@")

    if [[ ${#methods[@]} -eq 0 ]]; then
        log_error "No methods specified for priority"
        return 1
    fi

    # Validate all methods
    local valid_methods=("native" "flatpak" "snap" "appimage" "source")
    for method in "${methods[@]}"; do
        local found=0
        for valid in "${valid_methods[@]}"; do
            [[ "$method" == "$valid" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            log_error "Invalid method: $method"
            return 1
        fi
    done

    # Update priority
    PKG_METHOD_PRIORITY=("${methods[@]}")
    log_info "Method priority updated: ${PKG_METHOD_PRIORITY[*]}"
}

# Get current method priority
pkg_get_method_priority() {
    echo "${PKG_METHOD_PRIORITY[@]}"
}

# ============================================================================
# Transaction Logging
# ============================================================================

# Log installation transaction
# Format: timestamp|app_id|method|status|version|details
pkg_transaction_log() {
    local app_id="$1"
    local method="$2"
    local status="$3"
    local version="${4:-unknown}"
    local details="${5:-}"

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local log_entry="${timestamp}|${app_id}|${method}|${status}|${version}|${details}"

    if [[ -w "$CASCADE_TRANSACTION_LOG" ]]; then
        echo "$log_entry" >> "$CASCADE_TRANSACTION_LOG"
    else
        log_warn "Cannot write to transaction log"
    fi
}

# Show transaction history for an app
pkg_transaction_history() {
    local app_id="${1:-}"

    if [[ ! -f "$CASCADE_TRANSACTION_LOG" ]]; then
        log_warn "No transaction log found"
        return 1
    fi

    if [[ -n "$app_id" ]]; then
        log_info "Transaction history for: $app_id"
        grep "|${app_id}|" "$CASCADE_TRANSACTION_LOG" | tail -n 20
    else
        log_info "Recent transaction history:"
        tail -n 50 "$CASCADE_TRANSACTION_LOG"
    fi
}

# Clear old transaction logs (keep last 1000 entries)
pkg_transaction_cleanup() {
    if [[ -f "$CASCADE_TRANSACTION_LOG" ]]; then
        local temp_log="${CASCADE_TRANSACTION_LOG}.tmp"
        tail -n 1000 "$CASCADE_TRANSACTION_LOG" > "$temp_log"
        mv "$temp_log" "$CASCADE_TRANSACTION_LOG"
        log_info "Transaction log cleaned up"
    fi
}

# ============================================================================
# Snapshot and Rollback System
# ============================================================================

# Create installation snapshot
pkg_snapshot_create() {
    local snapshot_name="${1:-auto-$(date +%Y%m%d-%H%M%S)}"
    local snapshot_file="${CASCADE_SNAPSHOT_DIR}/${snapshot_name}.snapshot"

    log_info "Creating snapshot: $snapshot_name"

    {
        echo "# Snapshot created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Hostname: $(hostname)"
        echo ""
        echo "[NATIVE_PACKAGES]"
        case "$PKG_MANAGER" in
            apt) dpkg -l | grep "^ii" | awk '{print $2 " " $3}' ;;
            dnf|yum) rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n' ;;
            pacman) pacman -Q ;;
            zypper) rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n' ;;
            apk) apk info -v ;;
            *) echo "# Unsupported package manager: $PKG_MANAGER" ;;
        esac

        echo ""
        echo "[FLATPAK_PACKAGES]"
        if flatpak_available; then
            flatpak list --app --columns=application,version 2>/dev/null || echo "# None"
        else
            echo "# Flatpak not available"
        fi

        echo ""
        echo "[SNAP_PACKAGES]"
        if snap_available; then
            snap list 2>/dev/null | tail -n +2 || echo "# None"
        else
            echo "# Snap not available"
        fi

        echo ""
        echo "[APPIMAGE_FILES]"
        if [[ -d "$CASCADE_APPIMAGE_DIR" ]]; then
            find "$CASCADE_APPIMAGE_DIR" -name "*.AppImage" -type f 2>/dev/null || echo "# None"
        else
            echo "# AppImage directory not found"
        fi
    } > "$snapshot_file"

    if [[ -f "$snapshot_file" ]]; then
        log_success "Snapshot created: $snapshot_file"
        pkg_transaction_log "SYSTEM" "snapshot" "SUCCESS" "N/A" "Created: $snapshot_name"
        return 0
    else
        log_error "Failed to create snapshot"
        return 1
    fi
}

# List available snapshots
pkg_snapshot_list() {
    if [[ ! -d "$CASCADE_SNAPSHOT_DIR" ]]; then
        log_warn "No snapshot directory found"
        return 1
    fi

    local snapshots
    snapshots=$(find "$CASCADE_SNAPSHOT_DIR" -name "*.snapshot" -type f 2>/dev/null | sort -r)

    if [[ -z "$snapshots" ]]; then
        log_info "No snapshots available"
        return 0
    fi

    log_info "Available snapshots:"
    echo ""
    while IFS= read -r snapshot; do
        local basename
        basename=$(basename "$snapshot" .snapshot)
        local created
        created=$(grep "# Snapshot created:" "$snapshot" | cut -d: -f2- | xargs)
        printf "  %s - %s\n" "$basename" "$created"
    done <<< "$snapshots"
}

# Restore from snapshot (requires manual intervention for safety)
pkg_snapshot_restore() {
    local snapshot_name="$1"

    if [[ -z "$snapshot_name" ]]; then
        log_error "Snapshot name required"
        pkg_snapshot_list
        return 1
    fi

    local snapshot_file="${CASCADE_SNAPSHOT_DIR}/${snapshot_name}.snapshot"

    if [[ ! -f "$snapshot_file" ]]; then
        log_error "Snapshot not found: $snapshot_name"
        return 1
    fi

    log_warn "Snapshot restore is a manual operation for safety"
    log_info "Snapshot file: $snapshot_file"
    log_info "Review the snapshot and manually restore packages as needed"
    log_info "Use: less $snapshot_file"

    pkg_transaction_log "SYSTEM" "snapshot" "RESTORE_REQUESTED" "N/A" "Snapshot: $snapshot_name"
}

# Delete old snapshots (keep last N)
pkg_snapshot_prune() {
    local keep_count="${1:-5}"

    log_info "Pruning snapshots (keeping last $keep_count)"

    local snapshots
    snapshots=$(find "$CASCADE_SNAPSHOT_DIR" -name "*.snapshot" -type f 2>/dev/null | sort -r)

    local count=0
    while IFS= read -r snapshot; do
        ((count++))
        if [[ $count -gt $keep_count ]]; then
            log_debug "Removing old snapshot: $(basename "$snapshot")"
            rm -f "$snapshot"
        fi
    done <<< "$snapshots"

    log_success "Snapshot pruning complete"
}

# ============================================================================
# Individual Method Installers
# ============================================================================

# Try native package installation
_cascade_try_native() {
    local pkg_name="$1"

    log_info "Attempting native installation: $pkg_name"

    # Check if already installed
    if pkg_is_installed "$pkg_name"; then
        log_success "Package already installed (native): $pkg_name"
        return 0
    fi

    # Attempt installation
    if pkg_install "$pkg_name" 2>&1 | grep -v "^$"; then
        if pkg_is_installed "$pkg_name"; then
            log_success "Native installation succeeded: $pkg_name"
            return 0
        fi
    fi

    log_warn "Native installation failed: $pkg_name"
    return 1
}

# Try Flatpak installation
_cascade_try_flatpak() {
    local app_id="$1"
    local user_flag="${2:---user}"

    log_info "Attempting Flatpak installation: $app_id"

    if ! flatpak_available; then
        log_warn "Flatpak not available"
        return 1
    fi

    # Ensure Flathub is configured
    flatpak_setup_flathub 2>/dev/null || true

    # Check if already installed
    if flatpak_is_installed "$app_id"; then
        log_success "Package already installed (Flatpak): $app_id"
        return 0
    fi

    # Attempt installation
    if flatpak_install "$app_id" "$user_flag" 2>&1 | grep -v "^$"; then
        if flatpak_is_installed "$app_id"; then
            log_success "Flatpak installation succeeded: $app_id"
            return 0
        fi
    fi

    log_warn "Flatpak installation failed: $app_id"
    return 1
}

# Try Snap installation
_cascade_try_snap() {
    local pkg_name="$1"
    local snap_flag="${2:-}"

    log_info "Attempting Snap installation: $pkg_name"

    if ! snap_available; then
        log_warn "Snap not available"
        return 1
    fi

    # Check if already installed
    if snap_is_installed "$pkg_name"; then
        log_success "Package already installed (Snap): $pkg_name"
        return 0
    fi

    # Attempt installation
    if snap_install "$pkg_name" "$snap_flag" 2>&1 | grep -v "^$"; then
        if snap_is_installed "$pkg_name"; then
            log_success "Snap installation succeeded: $pkg_name"
            return 0
        fi
    fi

    log_warn "Snap installation failed: $pkg_name"
    return 1
}

# Try AppImage installation
_cascade_try_appimage() {
    local name="$1"
    local url="$2"
    local icon_url="${3:-}"

    log_info "Attempting AppImage installation: $name"

    local appimage_path="${CASCADE_APPIMAGE_DIR}/${name}.AppImage"

    # Check if already exists
    if [[ -f "$appimage_path" ]]; then
        log_success "AppImage already installed: $name"
        return 0
    fi

    # Download AppImage
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$appimage_path" "$url" || {
            log_error "Failed to download AppImage"
            rm -f "$appimage_path"
            return 1
        }
    elif command -v curl &>/dev/null; then
        curl -L -o "$appimage_path" "$url" || {
            log_error "Failed to download AppImage"
            rm -f "$appimage_path"
            return 1
        }
    else
        log_error "Neither wget nor curl available"
        return 1
    fi

    # Make executable
    chmod +x "$appimage_path" || {
        log_error "Failed to make AppImage executable"
        rm -f "$appimage_path"
        return 1
    }

    # Create desktop entry
    pkg_appimage_create_desktop "$name" "$appimage_path" "$icon_url"

    log_success "AppImage installation succeeded: $name"
    return 0
}

# Try source compilation (placeholder)
_cascade_try_source() {
    local app_id="$1"

    log_warn "Source compilation not yet implemented for: $app_id"
    return 1
}

# ============================================================================
# AppImage Management
# ============================================================================

# Create desktop entry for AppImage
pkg_appimage_create_desktop() {
    local name="$1"
    local appimage_path="$2"
    local icon_url="${3:-}"

    local desktop_file="${CASCADE_DESKTOP_DIR}/${name}.desktop"

    # Download icon if URL provided
    local icon_path=""
    if [[ -n "$icon_url" ]]; then
        local icon_ext="${icon_url##*.}"
        icon_path="${HOME}/.local/share/icons/${name}.${icon_ext}"
        mkdir -p "$(dirname "$icon_path")" 2>/dev/null

        if command -v wget &>/dev/null; then
            wget -q -O "$icon_path" "$icon_url" 2>/dev/null || icon_path=""
        elif command -v curl &>/dev/null; then
            curl -s -o "$icon_path" "$icon_url" 2>/dev/null || icon_path=""
        fi
    fi

    # Create desktop entry
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${name}
Comment=${name} (AppImage)
Exec=${appimage_path}
Icon=${icon_path:-application-x-executable}
Categories=Utility;
Terminal=false
EOF

    chmod +x "$desktop_file" 2>/dev/null
    log_debug "Created desktop entry: $desktop_file"
}

# Install AppImage manually
pkg_appimage_install() {
    local name="$1"
    local url="$2"
    local icon_url="${3:-}"

    if [[ -z "$name" ]] || [[ -z "$url" ]]; then
        log_error "Usage: pkg_appimage_install NAME URL [ICON_URL]"
        return 1
    fi

    if _cascade_try_appimage "$name" "$url" "$icon_url"; then
        pkg_transaction_log "$name" "appimage" "SUCCESS" "N/A" "URL: $url"
        return 0
    else
        pkg_transaction_log "$name" "appimage" "FAILED" "N/A" "URL: $url"
        return 1
    fi
}

# Remove AppImage
pkg_appimage_remove() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Usage: pkg_appimage_remove NAME"
        return 1
    fi

    local appimage_path="${CASCADE_APPIMAGE_DIR}/${name}.AppImage"
    local desktop_file="${CASCADE_DESKTOP_DIR}/${name}.desktop"

    local removed=0

    if [[ -f "$appimage_path" ]]; then
        rm -f "$appimage_path" && {
            log_success "Removed AppImage: $appimage_path"
            removed=1
        }
    fi

    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file" && {
            log_debug "Removed desktop entry: $desktop_file"
        }
    fi

    if [[ $removed -eq 1 ]]; then
        pkg_transaction_log "$name" "appimage" "REMOVED" "N/A" ""
        return 0
    else
        log_warn "AppImage not found: $name"
        return 1
    fi
}

# List installed AppImages
pkg_appimage_list() {
    log_info "Installed AppImages:"

    if [[ ! -d "$CASCADE_APPIMAGE_DIR" ]]; then
        log_warn "AppImage directory not found"
        return 1
    fi

    local appimages
    appimages=$(find "$CASCADE_APPIMAGE_DIR" -name "*.AppImage" -type f 2>/dev/null)

    if [[ -z "$appimages" ]]; then
        echo "  None"
        return 0
    fi

    while IFS= read -r appimage; do
        local name
        name=$(basename "$appimage" .AppImage)
        local size
        size=$(du -h "$appimage" | cut -f1)
        printf "  %s (%s)\n" "$name" "$size"
    done <<< "$appimages"
}

# ============================================================================
# Installation Verification
# ============================================================================

# Check if app is installed by any method
pkg_cascade_verify() {
    local app_id="$1"

    if [[ -z "$app_id" ]]; then
        log_error "Usage: pkg_cascade_verify APP_ID"
        return 1
    fi

    # Check native
    if pkg_is_installed "$app_id"; then
        echo "native"
        return 0
    fi

    # Check Flatpak
    if flatpak_is_installed "$app_id"; then
        echo "flatpak"
        return 0
    fi

    # Check Snap
    if snap_is_installed "$app_id"; then
        echo "snap"
        return 0
    fi

    # Check AppImage
    if [[ -f "${CASCADE_APPIMAGE_DIR}/${app_id}.AppImage" ]]; then
        echo "appimage"
        return 0
    fi

    return 1
}

# Get installed version (best effort)
pkg_cascade_version() {
    local app_id="$1"
    local method

    method=$(pkg_cascade_verify "$app_id")

    case "$method" in
        native)
            case "$PKG_MANAGER" in
                apt) dpkg -l "$app_id" 2>/dev/null | grep "^ii" | awk '{print $3}' ;;
                dnf|yum) rpm -q "$app_id" --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null ;;
                pacman) pacman -Q "$app_id" 2>/dev/null | awk '{print $2}' ;;
                *) echo "unknown" ;;
            esac
            ;;
        flatpak)
            flatpak list --app --columns=application,version 2>/dev/null | grep "$app_id" | awk '{print $2}'
            ;;
        snap)
            snap list "$app_id" 2>/dev/null | tail -n +2 | awk '{print $2}'
            ;;
        appimage)
            echo "appimage"
            ;;
        *)
            echo "not_installed"
            ;;
    esac
}

# ============================================================================
# Core Cascade Installation
# ============================================================================

# Parse installation method string
# Format: "native:pkg_name|flatpak:app.id|snap:name:--classic|appimage:url:icon_url"
_parse_install_methods() {
    local method_string="$1"
    declare -gA PARSED_METHODS=()

    IFS='|' read -ra METHODS <<< "$method_string"
    for method_spec in "${METHODS[@]}"; do
        IFS=':' read -ra PARTS <<< "$method_spec"
        local method="${PARTS[0]}"
        local identifier="${PARTS[1]}"
        local extra1="${PARTS[2]:-}"
        local extra2="${PARTS[3]:-}"

        case "$method" in
            native|flatpak|snap)
                PARSED_METHODS["$method"]="${identifier}${extra1:+:$extra1}"
                ;;
            appimage)
                PARSED_METHODS["$method"]="${identifier}:${extra1}"
                ;;
        esac
    done
}

# Main cascade installation function
# Usage: pkg_cascade_install APP_ID [PREFERRED_METHOD]
pkg_cascade_install() {
    local app_id="$1"
    local preferred="${2:-}"

    if [[ -z "$app_id" ]]; then
        log_error "Usage: pkg_cascade_install APP_ID [PREFERRED_METHOD]"
        return 1
    fi

    # Check if app is already installed
    local existing_method
    existing_method=$(pkg_cascade_verify "$app_id" 2>/dev/null)
    if [[ -n "$existing_method" ]]; then
        log_success "Already installed via $existing_method: $app_id"
        return 0
    fi

    # Get installation methods for this app
    local method_string="${APP_INSTALL_METHODS[$app_id]:-}"
    if [[ -z "$method_string" ]]; then
        log_error "No installation methods defined for: $app_id"
        log_info "Define methods using: APP_INSTALL_METHODS[$app_id]=\"native:pkg|flatpak:id|...\""
        return 1
    fi

    # Parse methods
    _parse_install_methods "$method_string"

    # Build priority list (preferred first if specified)
    local priority_list=()
    if [[ -n "$preferred" ]] && [[ -n "${PARSED_METHODS[$preferred]:-}" ]]; then
        priority_list+=("$preferred")
    fi

    # Add remaining methods in configured priority order
    for method in "${PKG_METHOD_PRIORITY[@]}"; do
        if [[ -n "${PARSED_METHODS[$method]:-}" ]] && [[ "$method" != "$preferred" ]]; then
            priority_list+=("$method")
        fi
    done

    # Try each method in order
    log_info "Installing '$app_id' using cascade method"
    log_debug "Priority: ${priority_list[*]}"

    for method in "${priority_list[@]}"; do
        local method_spec="${PARSED_METHODS[$method]}"

        case "$method" in
            native)
                local pkg_name="$method_spec"
                if _cascade_try_native "$pkg_name"; then
                    local version
                    version=$(pkg_cascade_version "$app_id")
                    pkg_transaction_log "$app_id" "native" "SUCCESS" "$version" "Package: $pkg_name"
                    log_success "Successfully installed '$app_id' via native package manager"
                    return 0
                fi
                ;;
            flatpak)
                IFS=':' read -r flat_id flat_flag <<< "$method_spec"
                if _cascade_try_flatpak "$flat_id" "${flat_flag:---user}"; then
                    local version
                    version=$(pkg_cascade_version "$app_id")
                    pkg_transaction_log "$app_id" "flatpak" "SUCCESS" "$version" "ID: $flat_id"
                    log_success "Successfully installed '$app_id' via Flatpak"
                    return 0
                fi
                ;;
            snap)
                IFS=':' read -r snap_name snap_flag <<< "$method_spec"
                if _cascade_try_snap "$snap_name" "$snap_flag"; then
                    local version
                    version=$(pkg_cascade_version "$app_id")
                    pkg_transaction_log "$app_id" "snap" "SUCCESS" "$version" "Package: $snap_name"
                    log_success "Successfully installed '$app_id' via Snap"
                    return 0
                fi
                ;;
            appimage)
                IFS=':' read -r app_url app_icon <<< "$method_spec"
                if _cascade_try_appimage "$app_id" "$app_url" "$app_icon"; then
                    pkg_transaction_log "$app_id" "appimage" "SUCCESS" "N/A" "URL: $app_url"
                    log_success "Successfully installed '$app_id' via AppImage"
                    return 0
                fi
                ;;
        esac
    done

    # All methods failed
    log_error "All installation methods failed for: $app_id"
    pkg_transaction_log "$app_id" "cascade" "FAILED" "N/A" "All methods exhausted"
    return 1
}

# ============================================================================
# Batch Installation
# ============================================================================

# Install multiple applications with cascade logic
pkg_cascade_batch() {
    local apps=("$@")

    if [[ ${#apps[@]} -eq 0 ]]; then
        log_error "Usage: pkg_cascade_batch APP_ID1 APP_ID2 ..."
        return 1
    fi

    local total=${#apps[@]}
    local current=0
    local succeeded=0
    local failed=0

    declare -a success_list=()
    declare -a failure_list=()

    log_section "Batch Installation: $total applications"

    for app in "${apps[@]}"; do
        ((current++))
        log_step "$current" "$total" "Installing: $app"

        if pkg_cascade_install "$app"; then
            ((succeeded++))
            success_list+=("$app")
        else
            ((failed++))
            failure_list+=("$app")
        fi

        echo ""
    done

    # Summary
    log_divider
    log_info "Batch installation complete"
    log_info "Total: $total | Succeeded: $succeeded | Failed: $failed"

    if [[ ${#success_list[@]} -gt 0 ]]; then
        log_success "Successfully installed:"
        for app in "${success_list[@]}"; do
            printf "  - %s\n" "$app"
        done
    fi

    if [[ ${#failure_list[@]} -gt 0 ]]; then
        log_error "Failed installations:"
        for app in "${failure_list[@]}"; do
            printf "  - %s\n" "$app"
        done
        return 1
    fi

    return 0
}

# ============================================================================
# Application Definitions
# ============================================================================

# Common applications with their installation methods
# Format: app_id → "native:pkg_name|flatpak:app.id|snap:name|appimage:url"
declare -gA APP_DEFINITIONS=(
    # Web Browsers
    [firefox]="native:firefox|flatpak:org.mozilla.firefox|snap:firefox"
    [chromium]="native:chromium|flatpak:org.chromium.Chromium|snap:chromium"
    [brave]="flatpak:com.brave.Browser|snap:brave"

    # Media Players
    [vlc]="native:vlc|flatpak:org.videolan.VLC|snap:vlc"
    [mpv]="native:mpv|flatpak:io.mpv.Mpv"

    # Development Tools
    [code]="flatpak:com.visualstudio.code|snap:code:--classic"
    [vscode]="flatpak:com.visualstudio.code|snap:code:--classic"
    [sublime]="flatpak:com.sublimetext.three|snap:sublime-text:--classic"
    [atom]="flatpak:io.atom.Atom|snap:atom:--classic"

    # Communication
    [discord]="flatpak:com.discordapp.Discord|snap:discord"
    [telegram]="native:telegram-desktop|flatpak:org.telegram.desktop|snap:telegram-desktop"
    [slack]="flatpak:com.slack.Slack|snap:slack:--classic"
    [teams]="flatpak:com.microsoft.Teams|snap:teams"
    [zoom]="flatpak:us.zoom.Zoom|snap:zoom-client"

    # Gaming
    [steam]="native:steam|flatpak:com.valvesoftware.Steam"
    [lutris]="native:lutris|flatpak:net.lutris.Lutris"

    # Music
    [spotify]="flatpak:com.spotify.Client|snap:spotify"

    # Graphics
    [gimp]="native:gimp|flatpak:org.gimp.GIMP|snap:gimp"
    [inkscape]="native:inkscape|flatpak:org.inkscape.Inkscape|snap:inkscape"
    [blender]="native:blender|flatpak:org.blender.Blender|snap:blender:--classic"
    [krita]="native:krita|flatpak:org.kde.krita"

    # Video Editing
    [obs]="native:obs-studio|flatpak:com.obsproject.Studio"
    [kdenlive]="native:kdenlive|flatpak:org.kde.kdenlive"

    # Office
    [libreoffice]="native:libreoffice|flatpak:org.libreoffice.LibreOffice|snap:libreoffice"

    # Utilities
    [keepassxc]="native:keepassxc|flatpak:org.keepassxc.KeePassXC|snap:keepassxc"
    [transmission]="native:transmission-gtk|flatpak:com.transmissionbt.Transmission"
    [filezilla]="native:filezilla|flatpak:org.filezillaproject.Filezilla"

    # Terminals
    [kitty]="native:kitty|flatpak:io.github.KittyTerminal|snap:kitty"
    [alacritty]="native:alacritty|flatpak:io.alacritty.Alacritty|snap:alacritty:--classic"
)

# Load application definitions into APP_INSTALL_METHODS
for app_id in "${!APP_DEFINITIONS[@]}"; do
    APP_INSTALL_METHODS["$app_id"]="${APP_DEFINITIONS[$app_id]}"
done

# ============================================================================
# Helper Functions
# ============================================================================

# Add custom application definition
pkg_cascade_define() {
    local app_id="$1"
    local methods="$2"

    if [[ -z "$app_id" ]] || [[ -z "$methods" ]]; then
        log_error "Usage: pkg_cascade_define APP_ID 'native:pkg|flatpak:id|...'"
        return 1
    fi

    APP_INSTALL_METHODS["$app_id"]="$methods"
    log_info "Defined installation methods for: $app_id"
}

# Show available app definitions
pkg_cascade_list_apps() {
    log_info "Available application definitions:"
    echo ""

    local sorted_apps
    sorted_apps=$(printf '%s\n' "${!APP_INSTALL_METHODS[@]}" | sort)

    while IFS= read -r app; do
        local installed=""
        if pkg_cascade_verify "$app" &>/dev/null; then
            local method
            method=$(pkg_cascade_verify "$app")
            installed=" [installed: $method]"
        fi
        printf "  %s%s\n" "$app" "$installed"
    done <<< "$sorted_apps"
}

# Show methods for specific app
pkg_cascade_show_methods() {
    local app_id="$1"

    if [[ -z "$app_id" ]]; then
        log_error "Usage: pkg_cascade_show_methods APP_ID"
        return 1
    fi

    local methods="${APP_INSTALL_METHODS[$app_id]:-}"
    if [[ -z "$methods" ]]; then
        log_error "No methods defined for: $app_id"
        return 1
    fi

    log_info "Installation methods for '$app_id':"
    _parse_install_methods "$methods"

    for method in "${PKG_METHOD_PRIORITY[@]}"; do
        local spec="${PARSED_METHODS[$method]:-}"
        if [[ -n "$spec" ]]; then
            printf "  %s: %s\n" "$method" "$spec"
        fi
    done
}

# ============================================================================
# USAGE EXAMPLES AND DOCUMENTATION
# ============================================================================
#
# CASCADE INSTALLATION SYSTEM
# ============================
#
# This module implements a comprehensive cascade installation system that tries
# multiple package sources in priority order until one succeeds.
#
# BASIC USAGE:
# ------------
#
#   # Install Firefox (tries native → flatpak → snap)
#   pkg_cascade_install firefox
#
#   # Install with preferred method
#   pkg_cascade_install firefox flatpak
#
#   # Batch installation
#   pkg_cascade_batch firefox vlc gimp discord
#
# CUSTOM APP DEFINITIONS:
# -----------------------
#
#   # Define custom app with methods
#   pkg_cascade_define myapp "native:myapp-pkg|flatpak:com.example.MyApp"
#
#   # Install custom app
#   pkg_cascade_install myapp
#
# VERIFICATION:
# -------------
#
#   # Check if installed and by which method
#   pkg_cascade_verify firefox
#   # Output: native, flatpak, snap, appimage, or nothing
#
#   # Get installed version
#   pkg_cascade_version firefox
#
#   # Show available methods for an app
#   pkg_cascade_show_methods firefox
#
# TRANSACTION HISTORY:
# --------------------
#
#   # View all transaction history
#   pkg_transaction_history
#
#   # View history for specific app
#   pkg_transaction_history firefox
#
#   # Clean old transactions
#   pkg_transaction_cleanup
#
# SNAPSHOTS:
# ----------
#
#   # Create system snapshot
#   pkg_snapshot_create my-snapshot
#
#   # List snapshots
#   pkg_snapshot_list
#
#   # Show snapshot for manual restore
#   pkg_snapshot_restore my-snapshot
#
#   # Prune old snapshots (keep last 5)
#   pkg_snapshot_prune 5
#
# APPIMAGE MANAGEMENT:
# --------------------
#
#   # Install AppImage manually
#   pkg_appimage_install myapp https://example.com/app.AppImage
#
#   # Remove AppImage
#   pkg_appimage_remove myapp
#
#   # List installed AppImages
#   pkg_appimage_list
#
# METHOD PRIORITY:
# ----------------
#
#   # Show current priority
#   pkg_get_method_priority
#
#   # Set custom priority
#   pkg_set_method_priority flatpak snap native appimage
#
# LIST AVAILABLE APPS:
# --------------------
#
#   # Show all defined applications
#   pkg_cascade_list_apps
#
# ADVANCED EXAMPLES:
# ------------------
#
#   # Install development tools
#   pkg_cascade_batch code sublime atom
#
#   # Install communication apps with snapshots
#   pkg_snapshot_create before-comm-apps
#   pkg_cascade_batch discord telegram slack zoom
#
#   # Prefer Flatpak for security
#   pkg_set_method_priority flatpak native snap appimage
#   pkg_cascade_install firefox
#
# TRANSACTION LOG FORMAT:
# -----------------------
#   timestamp|app_id|method|status|version|details
#   2025-12-22 10:30:45|firefox|native|SUCCESS|123.0|Package: firefox
#
# ============================================================================