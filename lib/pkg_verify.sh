#!/usr/bin/env bash
#
# pkg_verify.sh - Package Verification and Health System
#
# Provides comprehensive package verification, dependency checking,
# health monitoring, and rollback capabilities for Ultimate Linux Suite.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_PKG_VERIFY_LOADED:-}" ]] && return 0
readonly _PKG_VERIFY_LOADED=1

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
        log_section() { echo ""; echo "=== $* ==="; echo ""; }
        log_divider() { echo "────────────────────────────────────────"; }
    }
fi

# Source pkg.sh with fallback
if ! declare -f pkg_install &>/dev/null; then
    source "${SCRIPT_DIR}/pkg.sh" 2>/dev/null || {
        log_warn "pkg.sh not available - limited functionality"
    }
fi

# ============================================================================
# Global Variables
# ============================================================================

# State directory for package verification
declare -g PKG_VERIFY_STATE_DIR="${HOME}/.local/state/ultimate-linux-suite/pkg"
declare -g PKG_CHECKPOINT_DIR="${PKG_VERIFY_STATE_DIR}/checkpoints"
declare -g PKG_VERIFY_LOG="${PKG_VERIFY_STATE_DIR}/verify.log"

# ============================================================================
# Initialization
# ============================================================================

_pkg_verify_init() {
    mkdir -p "$PKG_VERIFY_STATE_DIR" 2>/dev/null || log_warn "Cannot create state directory"
    mkdir -p "$PKG_CHECKPOINT_DIR" 2>/dev/null || log_warn "Cannot create checkpoint directory"
    touch "$PKG_VERIFY_LOG" 2>/dev/null || log_warn "Cannot create verify log"
}

_pkg_verify_init

# ============================================================================
# Package Installation Verification
# ============================================================================

# Verify a package is installed using multiple methods
# Returns: 0 if installed, 1 if not
verify_package_installed() {
    local pkg="$1"
    local method="${2:-auto}"

    if [[ -z "$pkg" ]]; then
        log_error "Usage: verify_package_installed PACKAGE [METHOD]"
        return 1
    fi

    log_debug "Verifying package: $pkg (method: $method)"

    case "$method" in
        native|auto)
            # Try native package manager first
            if pkg_is_installed "$pkg"; then
                log_debug "Package verified via native: $pkg"
                return 0
            fi
            ;;&  # Fall through for auto
        flatpak|auto)
            # Check Flatpak
            if flatpak_available && flatpak_is_installed "$pkg"; then
                log_debug "Package verified via Flatpak: $pkg"
                return 0
            fi
            ;;&
        snap|auto)
            # Check Snap
            if snap_available && snap_is_installed "$pkg"; then
                log_debug "Package verified via Snap: $pkg"
                return 0
            fi
            ;;&
        command|auto)
            # Check if command exists
            if command -v "$pkg" &>/dev/null; then
                log_debug "Package verified via command: $pkg"
                return 0
            fi
            ;;
    esac

    log_debug "Package not found: $pkg"
    return 1
}

# Verify multiple packages at once
# Returns: 0 if all installed, 1 if any missing
verify_packages_installed() {
    local packages=("$@")
    local missing=()

    for pkg in "${packages[@]}"; do
        if ! verify_package_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing packages: ${missing[*]}"
        return 1
    fi

    log_success "All packages verified: ${packages[*]}"
    return 0
}

# ============================================================================
# Version Extraction
# ============================================================================

# Get package version
get_package_version() {
    local pkg="$1"
    local version=""

    if [[ -z "$pkg" ]]; then
        log_error "Usage: get_package_version PACKAGE"
        return 1
    fi

    # Try native package manager
    case "$PKG_MANAGER" in
        apt)
            version=$(dpkg -l "$pkg" 2>/dev/null | grep "^ii" | awk '{print $3}')
            ;;
        dnf|yum)
            version=$(rpm -q "$pkg" --qf '%{VERSION}-%{RELEASE}' 2>/dev/null)
            ;;
        pacman)
            version=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
            ;;
        zypper)
            version=$(rpm -q "$pkg" --qf '%{VERSION}-%{RELEASE}' 2>/dev/null)
            ;;
        apk)
            version=$(apk info "$pkg" 2>/dev/null | head -1 | sed 's/.*-//')
            ;;
        xbps)
            version=$(xbps-query -S "$pkg" 2>/dev/null | grep "^pkgver" | cut -d: -f2-)
            ;;
    esac

    # Try Flatpak if native fails
    if [[ -z "$version" ]] && flatpak_available; then
        version=$(flatpak list --app --columns=application,version 2>/dev/null | \
                  grep -i "$pkg" | awk '{print $2}' | head -1)
    fi

    # Try Snap if still empty
    if [[ -z "$version" ]] && snap_available; then
        version=$(snap list 2>/dev/null | grep -i "^$pkg " | awk '{print $2}')
    fi

    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    else
        echo "unknown"
        return 1
    fi
}

# ============================================================================
# Dependency Checking
# ============================================================================

# Check if a package's dependencies are satisfied
check_dependencies() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "Usage: check_dependencies PACKAGE"
        return 1
    fi

    log_info "Checking dependencies for: $pkg"

    case "$PKG_MANAGER" in
        apt)
            apt-cache depends "$pkg" 2>/dev/null | grep "Depends:" | while read -r _ dep; do
                dep="${dep%%:*}"  # Remove architecture suffix
                if ! dpkg -l "$dep" 2>/dev/null | grep -q "^ii"; then
                    echo "MISSING: $dep"
                fi
            done
            ;;
        dnf|yum)
            local deps
            deps=$(dnf repoquery --requires "$pkg" 2>/dev/null | grep -v "^$")
            while IFS= read -r dep; do
                if ! rpm -q "$dep" &>/dev/null; then
                    echo "MISSING: $dep"
                fi
            done <<< "$deps"
            ;;
        pacman)
            local deps
            deps=$(pacman -Si "$pkg" 2>/dev/null | grep "^Depends On" | cut -d: -f2-)
            for dep in $deps; do
                dep="${dep%%[<>=]*}"  # Remove version constraints
                if [[ "$dep" != "None" ]] && ! pacman -Q "$dep" &>/dev/null; then
                    echo "MISSING: $dep"
                fi
            done
            ;;
        *)
            log_warn "Dependency checking not implemented for: $PKG_MANAGER"
            return 1
            ;;
    esac

    return 0
}

# Install missing dependencies for a package
install_missing_dependencies() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "Usage: install_missing_dependencies PACKAGE"
        return 1
    fi

    local missing
    missing=$(check_dependencies "$pkg" 2>/dev/null | grep "^MISSING:" | cut -d: -f2-)

    if [[ -z "$missing" ]]; then
        log_success "All dependencies satisfied for: $pkg"
        return 0
    fi

    log_info "Installing missing dependencies: $missing"

    # shellcheck disable=SC2086
    pkg_install $missing
}

# ============================================================================
# Package Manager Health Checks
# ============================================================================

# Check package manager health
check_pkg_manager_health() {
    log_section "Package Manager Health Check"

    local issues=0
    local health_report=""

    # Check package manager is available
    if ! command -v "$PKG_MANAGER" &>/dev/null; then
        log_error "Package manager not found: $PKG_MANAGER"
        return 1
    fi
    health_report+="Package Manager: $PKG_MANAGER OK\n"

    case "$PKG_MANAGER" in
        apt)
            # Check dpkg status
            if ! dpkg --audit 2>/dev/null; then
                health_report+="dpkg audit: ISSUES FOUND\n"
                ((issues++))
            else
                health_report+="dpkg audit: OK\n"
            fi

            # Check apt-get
            if apt-get check 2>/dev/null; then
                health_report+="apt-get check: OK\n"
            else
                health_report+="apt-get check: ISSUES FOUND\n"
                ((issues++))
            fi

            # Check for broken packages
            local broken
            broken=$(dpkg -l | grep -E "^[uirphUFW]" | wc -l)
            if [[ "$broken" -gt 0 ]]; then
                health_report+="Broken packages: $broken\n"
                ((issues++))
            else
                health_report+="Broken packages: None\n"
            fi

            # Check cache size
            local cache_size
            cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
            health_report+="APT cache size: ${cache_size:-unknown}\n"
            ;;

        dnf|yum)
            # Check for broken dependencies
            if dnf check 2>/dev/null; then
                health_report+="dnf check: OK\n"
            else
                health_report+="dnf check: ISSUES FOUND\n"
                ((issues++))
            fi

            # Check cache
            local cache_size
            cache_size=$(du -sh /var/cache/dnf 2>/dev/null | cut -f1)
            health_report+="DNF cache size: ${cache_size:-unknown}\n"
            ;;

        pacman)
            # Check for orphans
            local orphans
            orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
            health_report+="Orphan packages: $orphans\n"

            # Check for foreign packages
            local foreign
            foreign=$(pacman -Qmq 2>/dev/null | wc -l)
            health_report+="Foreign packages (AUR): $foreign\n"

            # Check keyring
            if pacman-key --list-keys &>/dev/null; then
                health_report+="Keyring: OK\n"
            else
                health_report+="Keyring: ISSUES\n"
                ((issues++))
            fi

            # Check cache
            local cache_size
            cache_size=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
            health_report+="Pacman cache size: ${cache_size:-unknown}\n"
            ;;

        zypper)
            # Verify system
            if zypper verify 2>/dev/null; then
                health_report+="zypper verify: OK\n"
            else
                health_report+="zypper verify: ISSUES FOUND\n"
                ((issues++))
            fi
            ;;

        *)
            health_report+="Health check not implemented for: $PKG_MANAGER\n"
            ;;
    esac

    # Check universal package managers
    if command -v flatpak &>/dev/null; then
        local flatpak_apps
        flatpak_apps=$(flatpak list --app 2>/dev/null | wc -l)
        health_report+="Flatpak apps: $flatpak_apps\n"
    fi

    if command -v snap &>/dev/null; then
        local snap_apps
        snap_apps=$(snap list 2>/dev/null | tail -n +2 | wc -l)
        health_report+="Snap packages: $snap_apps\n"
    fi

    # Display report
    echo -e "$health_report"

    if [[ $issues -gt 0 ]]; then
        log_warn "Found $issues issues"
        return 1
    else
        log_success "Package manager is healthy"
        return 0
    fi
}

# Repair package manager issues
repair_pkg_manager() {
    log_section "Attempting Package Manager Repair"

    case "$PKG_MANAGER" in
        apt)
            log_info "Fixing broken packages..."
            dpkg --configure -a 2>/dev/null || true
            apt-get install -f -y 2>/dev/null || true

            log_info "Cleaning APT cache..."
            apt-get clean 2>/dev/null || true
            apt-get autoclean 2>/dev/null || true

            log_info "Removing orphan packages..."
            apt-get autoremove -y 2>/dev/null || true
            ;;

        dnf|yum)
            log_info "Cleaning DNF cache..."
            dnf clean all 2>/dev/null || true

            log_info "Rebuilding DNF cache..."
            dnf makecache 2>/dev/null || true

            log_info "Removing orphan packages..."
            dnf autoremove -y 2>/dev/null || true
            ;;

        pacman)
            log_info "Refreshing package database..."
            pacman -Sy 2>/dev/null || true

            log_info "Fixing keyring..."
            pacman-key --init 2>/dev/null || true
            pacman-key --populate archlinux 2>/dev/null || true

            # Don't auto-remove orphans on Arch - too risky
            log_info "Listing orphan packages (manual removal recommended):"
            pacman -Qdtq 2>/dev/null || echo "  None"
            ;;

        zypper)
            log_info "Refreshing repositories..."
            zypper refresh 2>/dev/null || true

            log_info "Cleaning cache..."
            zypper clean --all 2>/dev/null || true
            ;;

        *)
            log_warn "Repair not implemented for: $PKG_MANAGER"
            return 1
            ;;
    esac

    log_success "Repair operations completed"
    return 0
}

# ============================================================================
# Package Listing and Comparison
# ============================================================================

# Get list of installed packages
get_installed_packages() {
    local output_format="${1:-list}"  # list, json, or count

    case "$PKG_MANAGER" in
        apt)
            case "$output_format" in
                count)
                    dpkg -l | grep "^ii" | wc -l
                    ;;
                json)
                    echo "["
                    dpkg -l | grep "^ii" | awk '{printf "{\"name\":\"%s\",\"version\":\"%s\"},\n", $2, $3}' | sed '$ s/,$//'
                    echo "]"
                    ;;
                *)
                    dpkg -l | grep "^ii" | awk '{print $2}'
                    ;;
            esac
            ;;

        dnf|yum)
            case "$output_format" in
                count)
                    rpm -qa | wc -l
                    ;;
                json)
                    echo "["
                    rpm -qa --qf '{"name":"%{NAME}","version":"%{VERSION}-%{RELEASE}"},\n' | sed '$ s/,$//'
                    echo "]"
                    ;;
                *)
                    rpm -qa --qf '%{NAME}\n'
                    ;;
            esac
            ;;

        pacman)
            case "$output_format" in
                count)
                    pacman -Q | wc -l
                    ;;
                json)
                    echo "["
                    pacman -Q | awk '{printf "{\"name\":\"%s\",\"version\":\"%s\"},\n", $1, $2}' | sed '$ s/,$//'
                    echo "]"
                    ;;
                *)
                    pacman -Qq
                    ;;
            esac
            ;;

        zypper)
            case "$output_format" in
                count)
                    rpm -qa | wc -l
                    ;;
                *)
                    rpm -qa --qf '%{NAME}\n'
                    ;;
            esac
            ;;

        apk)
            case "$output_format" in
                count)
                    apk info | wc -l
                    ;;
                *)
                    apk info
                    ;;
            esac
            ;;

        xbps)
            case "$output_format" in
                count)
                    xbps-query -l | wc -l
                    ;;
                *)
                    xbps-query -l | awk '{print $2}' | cut -d- -f1
                    ;;
            esac
            ;;

        *)
            log_error "Unsupported package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Compare package lists (before/after or two files)
diff_packages() {
    local before="$1"
    local after="$2"

    if [[ -z "$before" ]] || [[ -z "$after" ]]; then
        log_error "Usage: diff_packages BEFORE_FILE AFTER_FILE"
        return 1
    fi

    if [[ ! -f "$before" ]] || [[ ! -f "$after" ]]; then
        log_error "Both files must exist"
        return 1
    fi

    log_section "Package Differences"

    echo "=== ADDED PACKAGES ==="
    comm -13 <(sort "$before") <(sort "$after")

    echo ""
    echo "=== REMOVED PACKAGES ==="
    comm -23 <(sort "$before") <(sort "$after")

    # Statistics
    local before_count after_count added removed
    before_count=$(wc -l < "$before")
    after_count=$(wc -l < "$after")
    added=$(comm -13 <(sort "$before") <(sort "$after") | wc -l)
    removed=$(comm -23 <(sort "$before") <(sort "$after") | wc -l)

    echo ""
    log_info "Summary: Before=$before_count After=$after_count Added=$added Removed=$removed"
}

# ============================================================================
# Checkpoint and Rollback System
# ============================================================================

# Create a package checkpoint
pkg_checkpoint_create() {
    local name="${1:-checkpoint-$(date +%Y%m%d-%H%M%S)}"
    local checkpoint_file="${PKG_CHECKPOINT_DIR}/${name}.packages"

    log_info "Creating package checkpoint: $name"

    # Save package list
    get_installed_packages > "$checkpoint_file"

    # Save metadata
    local meta_file="${PKG_CHECKPOINT_DIR}/${name}.meta"
    cat > "$meta_file" <<EOF
CHECKPOINT_NAME=$name
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
PACKAGE_MANAGER=$PKG_MANAGER
PACKAGE_COUNT=$(wc -l < "$checkpoint_file")
HOSTNAME=$(hostname)
USER=$USER
EOF

    if [[ -f "$checkpoint_file" ]]; then
        log_success "Checkpoint created: $checkpoint_file"
        return 0
    else
        log_error "Failed to create checkpoint"
        return 1
    fi
}

# List available checkpoints
pkg_checkpoint_list() {
    if [[ ! -d "$PKG_CHECKPOINT_DIR" ]]; then
        log_warn "No checkpoint directory found"
        return 1
    fi

    local checkpoints
    checkpoints=$(find "$PKG_CHECKPOINT_DIR" -name "*.packages" -type f 2>/dev/null | sort -r)

    if [[ -z "$checkpoints" ]]; then
        log_info "No checkpoints available"
        return 0
    fi

    log_info "Available checkpoints:"
    echo ""

    while IFS= read -r checkpoint; do
        local name
        name=$(basename "$checkpoint" .packages)
        local meta_file="${PKG_CHECKPOINT_DIR}/${name}.meta"
        local created pkg_count

        if [[ -f "$meta_file" ]]; then
            created=$(grep "^CREATED=" "$meta_file" | cut -d= -f2-)
            pkg_count=$(grep "^PACKAGE_COUNT=" "$meta_file" | cut -d= -f2-)
        else
            created="unknown"
            pkg_count=$(wc -l < "$checkpoint")
        fi

        printf "  %s - %s (%s packages)\n" "$name" "$created" "$pkg_count"
    done <<< "$checkpoints"
}

# Show diff from a checkpoint
pkg_checkpoint_diff() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Usage: pkg_checkpoint_diff CHECKPOINT_NAME"
        pkg_checkpoint_list
        return 1
    fi

    local checkpoint_file="${PKG_CHECKPOINT_DIR}/${name}.packages"

    if [[ ! -f "$checkpoint_file" ]]; then
        log_error "Checkpoint not found: $name"
        return 1
    fi

    # Create temp file with current packages
    local current_file
    current_file=$(mktemp)
    get_installed_packages > "$current_file"

    # Compare
    diff_packages "$checkpoint_file" "$current_file"

    # Cleanup
    rm -f "$current_file"
}

# Generate rollback commands from checkpoint
pkg_checkpoint_rollback() {
    local name="$1"
    local dry_run="${2:-1}"  # Default to dry run

    if [[ -z "$name" ]]; then
        log_error "Usage: pkg_checkpoint_rollback CHECKPOINT_NAME [DRY_RUN=1]"
        return 1
    fi

    local checkpoint_file="${PKG_CHECKPOINT_DIR}/${name}.packages"

    if [[ ! -f "$checkpoint_file" ]]; then
        log_error "Checkpoint not found: $name"
        return 1
    fi

    # Get current packages
    local current_file
    current_file=$(mktemp)
    get_installed_packages > "$current_file"

    # Find added packages (need to remove)
    local to_remove
    to_remove=$(comm -13 <(sort "$checkpoint_file") <(sort "$current_file"))

    # Find removed packages (need to install)
    local to_install
    to_install=$(comm -23 <(sort "$checkpoint_file") <(sort "$current_file"))

    rm -f "$current_file"

    log_section "Rollback Plan for: $name"

    if [[ -n "$to_remove" ]]; then
        echo "=== Packages to REMOVE ==="
        echo "$to_remove"
        echo ""
    fi

    if [[ -n "$to_install" ]]; then
        echo "=== Packages to INSTALL ==="
        echo "$to_install"
        echo ""
    fi

    if [[ -z "$to_remove" ]] && [[ -z "$to_install" ]]; then
        log_success "System already matches checkpoint"
        return 0
    fi

    if [[ "$dry_run" == "0" ]]; then
        log_warn "Executing rollback..."

        # Remove added packages
        if [[ -n "$to_remove" ]]; then
            log_info "Removing packages..."
            # shellcheck disable=SC2086
            pkg_remove $to_remove || log_warn "Some removals failed"
        fi

        # Install missing packages
        if [[ -n "$to_install" ]]; then
            log_info "Installing packages..."
            # shellcheck disable=SC2086
            pkg_install $to_install || log_warn "Some installations failed"
        fi

        log_success "Rollback completed"
    else
        log_info "Dry run mode - no changes made"
        log_info "To execute, run: pkg_checkpoint_rollback '$name' 0"
    fi
}

# Delete a checkpoint
pkg_checkpoint_delete() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Usage: pkg_checkpoint_delete CHECKPOINT_NAME"
        return 1
    fi

    local checkpoint_file="${PKG_CHECKPOINT_DIR}/${name}.packages"
    local meta_file="${PKG_CHECKPOINT_DIR}/${name}.meta"

    if [[ ! -f "$checkpoint_file" ]]; then
        log_error "Checkpoint not found: $name"
        return 1
    fi

    rm -f "$checkpoint_file" "$meta_file"
    log_success "Checkpoint deleted: $name"
}

# Prune old checkpoints (keep last N)
pkg_checkpoint_prune() {
    local keep="${1:-5}"

    log_info "Pruning checkpoints (keeping last $keep)"

    local checkpoints
    checkpoints=$(find "$PKG_CHECKPOINT_DIR" -name "*.packages" -type f 2>/dev/null | sort -r)

    local count=0
    while IFS= read -r checkpoint; do
        ((count++))
        if [[ $count -gt $keep ]]; then
            local name
            name=$(basename "$checkpoint" .packages)
            pkg_checkpoint_delete "$name"
        fi
    done <<< "$checkpoints"

    log_success "Checkpoint pruning complete"
}

# ============================================================================
# Package Query Utilities
# ============================================================================

# Search for a package that provides a file/command
pkg_provides() {
    local target="$1"

    if [[ -z "$target" ]]; then
        log_error "Usage: pkg_provides FILE_OR_COMMAND"
        return 1
    fi

    log_info "Searching for package that provides: $target"

    case "$PKG_MANAGER" in
        apt)
            dpkg -S "$target" 2>/dev/null || apt-file search "$target" 2>/dev/null
            ;;
        dnf|yum)
            dnf provides "$target" 2>/dev/null
            ;;
        pacman)
            pacman -F "$target" 2>/dev/null || pkgfile "$target" 2>/dev/null
            ;;
        zypper)
            zypper search --provides "$target" 2>/dev/null
            ;;
        apk)
            apk info --who-owns "$target" 2>/dev/null
            ;;
        xbps)
            xbps-query -Ro "$target" 2>/dev/null
            ;;
        *)
            log_warn "Package search not implemented for: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# List files installed by a package
pkg_list_files() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "Usage: pkg_list_files PACKAGE"
        return 1
    fi

    case "$PKG_MANAGER" in
        apt)
            dpkg -L "$pkg" 2>/dev/null
            ;;
        dnf|yum)
            rpm -ql "$pkg" 2>/dev/null
            ;;
        pacman)
            pacman -Ql "$pkg" 2>/dev/null | awk '{print $2}'
            ;;
        zypper)
            rpm -ql "$pkg" 2>/dev/null
            ;;
        apk)
            apk info -L "$pkg" 2>/dev/null
            ;;
        xbps)
            xbps-query -f "$pkg" 2>/dev/null
            ;;
        *)
            log_warn "File listing not implemented for: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Verify package file integrity
pkg_verify_integrity() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "Usage: pkg_verify_integrity PACKAGE"
        return 1
    fi

    log_info "Verifying file integrity for: $pkg"

    case "$PKG_MANAGER" in
        apt)
            dpkg --verify "$pkg" 2>/dev/null
            ;;
        dnf|yum)
            rpm -V "$pkg" 2>/dev/null
            ;;
        pacman)
            pacman -Qkk "$pkg" 2>/dev/null
            ;;
        *)
            log_warn "Integrity verification not implemented for: $PKG_MANAGER"
            return 1
            ;;
    esac

    local ret=$?
    if [[ $ret -eq 0 ]]; then
        log_success "Package integrity OK: $pkg"
    else
        log_warn "Integrity issues found for: $pkg"
    fi
    return $ret
}

# ============================================================================
# Package Statistics
# ============================================================================

# Show package statistics
pkg_stats() {
    log_section "Package Statistics"

    local native_count=0
    local flatpak_count=0
    local snap_count=0

    # Native packages
    native_count=$(get_installed_packages count)
    echo "Native packages ($PKG_MANAGER): $native_count"

    # Flatpak
    if command -v flatpak &>/dev/null; then
        flatpak_count=$(flatpak list --app 2>/dev/null | wc -l)
        echo "Flatpak apps: $flatpak_count"
    fi

    # Snap
    if command -v snap &>/dev/null; then
        snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l)
        echo "Snap packages: $snap_count"
    fi

    # Total
    local total=$((native_count + flatpak_count + snap_count))
    echo ""
    echo "Total packages: $total"

    # Package manager cache sizes
    echo ""
    echo "Cache sizes:"
    case "$PKG_MANAGER" in
        apt)
            du -sh /var/cache/apt/archives 2>/dev/null || echo "  APT cache: unknown"
            ;;
        dnf)
            du -sh /var/cache/dnf 2>/dev/null || echo "  DNF cache: unknown"
            ;;
        pacman)
            du -sh /var/cache/pacman/pkg 2>/dev/null || echo "  Pacman cache: unknown"
            ;;
    esac

    # Checkpoint info
    if [[ -d "$PKG_CHECKPOINT_DIR" ]]; then
        local checkpoint_count
        checkpoint_count=$(find "$PKG_CHECKPOINT_DIR" -name "*.packages" 2>/dev/null | wc -l)
        echo ""
        echo "Saved checkpoints: $checkpoint_count"
    fi
}

# ============================================================================
# USAGE DOCUMENTATION
# ============================================================================
#
# PKG_VERIFY.SH - Package Verification and Health System
# ======================================================
#
# VERIFICATION:
#
#   # Verify single package
#   verify_package_installed firefox
#
#   # Verify multiple packages
#   verify_packages_installed git vim curl
#
#   # Get package version
#   get_package_version firefox
#
# DEPENDENCIES:
#
#   # Check dependencies
#   check_dependencies firefox
#
#   # Install missing dependencies
#   install_missing_dependencies firefox
#
# HEALTH CHECKS:
#
#   # Check package manager health
#   check_pkg_manager_health
#
#   # Repair package manager
#   repair_pkg_manager
#
# PACKAGE LISTING:
#
#   # List all installed packages
#   get_installed_packages
#
#   # Get package count
#   get_installed_packages count
#
#   # Get as JSON
#   get_installed_packages json
#
#   # Compare package lists
#   diff_packages before.txt after.txt
#
# CHECKPOINTS:
#
#   # Create checkpoint
#   pkg_checkpoint_create my-checkpoint
#
#   # List checkpoints
#   pkg_checkpoint_list
#
#   # Show changes since checkpoint
#   pkg_checkpoint_diff my-checkpoint
#
#   # Generate rollback commands (dry run)
#   pkg_checkpoint_rollback my-checkpoint
#
#   # Execute rollback
#   pkg_checkpoint_rollback my-checkpoint 0
#
#   # Delete checkpoint
#   pkg_checkpoint_delete my-checkpoint
#
#   # Prune old checkpoints
#   pkg_checkpoint_prune 5
#
# QUERY UTILITIES:
#
#   # Find package that provides a file
#   pkg_provides /usr/bin/python
#
#   # List files in a package
#   pkg_list_files firefox
#
#   # Verify package integrity
#   pkg_verify_integrity firefox
#
# STATISTICS:
#
#   # Show package statistics
#   pkg_stats
#
# ============================================================================
