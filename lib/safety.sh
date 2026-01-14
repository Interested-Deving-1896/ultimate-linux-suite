#!/usr/bin/env bash
# Unified Suite - Safety System (Snapshots/Rollback)
# Source: OffTrack Suite (updated)
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_SAFETY_LOADED:-}" ]] && return 0
readonly _UNIFIED_SAFETY_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"
[[ -z "${_UNIFIED_OS_DETECT_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/os_detect.sh"

# ============================================================
# SAFETY CONFIGURATION
# ============================================================

readonly SNAPSHOT_DIR="${HOME}/.unified-suite/snapshots"
readonly SNAPSHOT_METADATA="${SNAPSHOT_DIR}/metadata"
readonly BACKUP_DIR="/var/backups/unified-suite"

# ============================================================
# SNAPSHOT FUNCTIONS
# ============================================================

# Initialize safety system
safety_init() {
    mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || true
    mkdir -p "$SNAPSHOT_METADATA" 2>/dev/null || true
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
}

# Create a safety checkpoint
safety_checkpoint() {
    local name="${1:-checkpoint}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local snapshot_name="snapshot-${name}-${timestamp}"
    local snapshot_path="${SNAPSHOT_DIR}/${snapshot_name}"

    log_debug "Creating safety checkpoint: $snapshot_name"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would create checkpoint: $snapshot_name"
        return 0
    fi

    mkdir -p "$snapshot_path"

    # Backup critical system configs
    local -a configs_to_backup=(
        "/etc/sysctl.conf"
        "/etc/sysctl.d"
        "/etc/modprobe.d"
        "/etc/fstab"
        "/etc/default/grub"
    )

    for config in "${configs_to_backup[@]}"; do
        if [[ -e "$config" ]]; then
            cp -a "$config" "$snapshot_path/" 2>/dev/null || true
        fi
    done

    # Create metadata
    cat > "${SNAPSHOT_METADATA}/${snapshot_name}.json" << EOF
{
    "name": "$snapshot_name",
    "label": "$name",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "os": "$OS_PRETTY_NAME",
    "kernel": "$(uname -r)",
    "user": "$USER"
}
EOF

    log_debug "Checkpoint created: $snapshot_name"
    echo "$snapshot_name"
}

# List snapshots
safety_list_snapshots() {
    log_section "Available Snapshots"

    if [[ ! -d "$SNAPSHOT_DIR" ]] || [[ -z "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]]; then
        echo "  No snapshots found"
        return 0
    fi

    printf "  %-40s %-20s\n" "NAME" "DATE"
    echo "  $(printf '=%.0s' {1..60})"

    for meta in "$SNAPSHOT_METADATA"/*.json; do
        [[ -f "$meta" ]] || continue
        local name=$(basename "$meta" .json)
        local timestamp=$(grep -o '"timestamp": "[^"]*"' "$meta" | cut -d'"' -f4)
        printf "  %-40s %-20s\n" "$name" "$timestamp"
    done
}

# Delete a snapshot
safety_delete_snapshot() {
    local snapshot_name="$1"

    if [[ -z "$snapshot_name" ]]; then
        log_error "Snapshot name required"
        return 1
    fi

    local snapshot_path="${SNAPSHOT_DIR}/${snapshot_name}"
    local meta_file="${SNAPSHOT_METADATA}/${snapshot_name}.json"

    if [[ ! -d "$snapshot_path" ]]; then
        log_error "Snapshot not found: $snapshot_name"
        return 1
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would delete snapshot: $snapshot_name"
        return 0
    fi

    rm -rf "$snapshot_path"
    rm -f "$meta_file"

    log_success "Deleted snapshot: $snapshot_name"
}

# Restore from snapshot
safety_restore() {
    local snapshot_name="$1"

    if [[ -z "$snapshot_name" ]]; then
        log_error "Snapshot name required"
        return 1
    fi

    local snapshot_path="${SNAPSHOT_DIR}/${snapshot_name}"

    if [[ ! -d "$snapshot_path" ]]; then
        log_error "Snapshot not found: $snapshot_name"
        return 1
    fi

    log_warn "This will restore system configuration from: $snapshot_name"

    if ! confirm "Are you sure you want to restore?"; then
        log_info "Restore cancelled"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would restore from: $snapshot_name"
        return 0
    fi

    require_root

    # Restore configs
    for item in "$snapshot_path"/*; do
        local basename=$(basename "$item")
        case "$basename" in
            sysctl.conf)
                cp -a "$item" /etc/sysctl.conf
                ;;
            sysctl.d)
                cp -a "$item"/* /etc/sysctl.d/ 2>/dev/null || true
                ;;
            modprobe.d)
                cp -a "$item"/* /etc/modprobe.d/ 2>/dev/null || true
                ;;
            fstab)
                cp -a "$item" /etc/fstab
                ;;
        esac
    done

    # Apply sysctl
    sysctl --system 2>/dev/null || true

    log_success "Restored from snapshot: $snapshot_name"
    log_warn "A reboot may be required for all changes to take effect"
}

# Create file backup
create_backup() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local backup_path="${BACKUP_DIR}/$(basename "$file").${timestamp}.bak"
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$backup_path"
    log_debug "Backed up: $file -> $backup_path"
}

# Initialize on source
safety_init
