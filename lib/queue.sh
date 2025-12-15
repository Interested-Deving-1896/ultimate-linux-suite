#!/usr/bin/env bash
#
# queue.sh - Queue System for Ultimate Linux Suite
#
# Provides a queue-based execution system where actions are staged
# for review before execution. Nothing executes immediately.
#

# Prevent multiple sourcing
[[ -n "${_QUEUE_LOADED:-}" ]] && return 0
readonly _QUEUE_LOADED=1

# Allowed queue types (security whitelist)
readonly -a QUEUE_ALLOWED_TYPES=(
    "pkg_install"
    "pkg_remove"
    "sysctl"
    "service"
    "file_write"
)

# Allowed sysctl keys (security whitelist)
readonly -a QUEUE_ALLOWED_SYSCTL=(
    "vm.swappiness"
    "vm.vfs_cache_pressure"
    "vm.dirty_ratio"
    "vm.dirty_background_ratio"
    "vm.dirty_expire_centisecs"
    "vm.dirty_writeback_centisecs"
    "vm.laptop_mode"
    "fs.file-max"
    "net.ipv4.tcp_congestion_control"
    "net.core.default_qdisc"
    "net.ipv6.conf.all.disable_ipv6"
    "net.ipv6.conf.default.disable_ipv6"
    "net.core.rmem_max"
    "net.core.wmem_max"
    "net.core.somaxconn"
    "net.core.netdev_max_backlog"
    "net.ipv4.tcp_rmem"
    "net.ipv4.tcp_wmem"
    "net.ipv4.tcp_max_syn_backlog"
    "kernel.nmi_watchdog"
)

# Allowed service actions (security whitelist)
readonly -a QUEUE_ALLOWED_SERVICE_ACTIONS=(
    "start"
    "stop"
    "restart"
    "reload"
    "enable"
    "disable"
)

# Validate package name (alphanumeric, dots, dashes, underscores, plus)
# Returns 0 if valid, 1 if invalid
_queue_validate_package() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1
    [[ ${#pkg} -gt 128 ]] && return 1
    [[ "$pkg" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]] || return 1
    return 0
}

# Validate sysctl key against whitelist
# Returns 0 if valid, 1 if invalid
_queue_validate_sysctl_key() {
    local key="$1"
    local allowed
    for allowed in "${QUEUE_ALLOWED_SYSCTL[@]}"; do
        [[ "$key" == "$allowed" ]] && return 0
    done
    return 1
}

# Validate service action against whitelist
# Returns 0 if valid, 1 if invalid
_queue_validate_service_action() {
    local action="$1"
    local allowed
    for allowed in "${QUEUE_ALLOWED_SERVICE_ACTIONS[@]}"; do
        [[ "$action" == "$allowed" ]] && return 0
    done
    return 1
}

# Validate service name (alphanumeric, dashes, underscores, dots, @)
# Returns 0 if valid, 1 if invalid
_queue_validate_service_name() {
    local name="$1"
    [[ -z "$name" ]] && return 1
    [[ ${#name} -gt 256 ]] && return 1
    [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._@-]*$ ]] || return 1
    return 0
}

# Validate queue type against whitelist
# Returns 0 if valid, 1 if invalid
_queue_validate_type() {
    local type="$1"
    local allowed
    for allowed in "${QUEUE_ALLOWED_TYPES[@]}"; do
        [[ "$type" == "$allowed" ]] && return 0
    done
    return 1
}

# Queue storage
declare -ga QUEUE_ITEMS=()
declare -ga QUEUE_TYPES=()
declare -ga QUEUE_DESCRIPTIONS=()

# Queue file for persistence
declare -g QUEUE_FILE=""

# Initialize queue system
queue_init() {
    QUEUE_ITEMS=()
    QUEUE_TYPES=()
    QUEUE_DESCRIPTIONS=()

    # Set up queue file for persistence with secure permissions
    if [[ "$(id -u)" -eq 0 ]]; then
        QUEUE_FILE="/var/cache/ultimate-linux-suite/queue.txt"
    else
        QUEUE_FILE="${HOME}/.cache/ultimate-linux-suite/queue.txt"
    fi

    # Create directory with restrictive permissions
    local queue_dir
    queue_dir="$(dirname "$QUEUE_FILE")"
    if [[ ! -d "$queue_dir" ]]; then
        mkdir -p "$queue_dir" 2>/dev/null && chmod 700 "$queue_dir"
    fi

    # Create queue file with restrictive permissions if it doesn't exist
    if [[ ! -f "$QUEUE_FILE" ]]; then
        touch "$QUEUE_FILE" 2>/dev/null && chmod 600 "$QUEUE_FILE"
    fi

    # Load saved queue if exists and is safe
    queue_load

    log_debug "Queue system initialized"
}

# Add item to queue
# Usage: queue_add TYPE ITEM DESCRIPTION
queue_add() {
    local type="$1"
    local item="$2"
    local desc="${3:-$item}"

    QUEUE_TYPES+=("$type")
    QUEUE_ITEMS+=("$item")
    QUEUE_DESCRIPTIONS+=("$desc")

    log_debug "Queued [$type]: $item"
}

# Add package to install queue
queue_pkg_install() {
    local pkg="$1"
    local desc="${2:-Install package: $pkg}"
    queue_add "pkg_install" "$pkg" "$desc"
}

# Add package to remove queue
queue_pkg_remove() {
    local pkg="$1"
    local desc="${2:-Remove package: $pkg}"
    queue_add "pkg_remove" "$pkg" "$desc"
}

# Add sysctl setting to queue
queue_sysctl() {
    local key="$1"
    local value="$2"
    local desc="${3:-Set $key = $value}"
    queue_add "sysctl" "$key=$value" "$desc"
}

# DEPRECATED: Arbitrary command execution disabled for security
# Use specific queue functions instead (queue_sysctl, queue_service, etc.)
queue_command() {
    log_error "queue_command is disabled for security reasons"
    log_info "Use queue_sysctl, queue_service, or queue_file_write instead"
    return 1
}

# Add file write to queue (for sysctl persistence, etc.)
# Usage: queue_file_write CONTENT FILEPATH [DESCRIPTION]
queue_file_write() {
    local content="$1"
    local filepath="$2"
    local desc="${3:-Write to: $filepath}"
    # Security: only allow specific paths
    if [[ ! "$filepath" =~ ^/etc/sysctl\.d/[a-zA-Z0-9._-]+\.conf$ ]] && \
       [[ "$filepath" != "/etc/sysctl.conf" ]]; then
        log_error "Cannot queue write to disallowed path: $filepath"
        return 1
    fi
    queue_add "file_write" "${content}|${filepath}" "$desc"
}

# Add service action to queue
queue_service() {
    local action="$1"
    local service="$2"
    local desc="${3:-$action service: $service}"
    queue_add "service" "$action:$service" "$desc"
}

# Remove item from queue by index
queue_remove() {
    local idx="$1"

    if [[ "$idx" -ge 0 ]] && [[ "$idx" -lt ${#QUEUE_ITEMS[@]} ]]; then
        unset 'QUEUE_ITEMS[idx]'
        unset 'QUEUE_TYPES[idx]'
        unset 'QUEUE_DESCRIPTIONS[idx]'

        # Rebuild arrays to remove gaps
        QUEUE_ITEMS=("${QUEUE_ITEMS[@]}")
        QUEUE_TYPES=("${QUEUE_TYPES[@]}")
        QUEUE_DESCRIPTIONS=("${QUEUE_DESCRIPTIONS[@]}")

        log_debug "Removed queue item $idx"
        return 0
    fi
    return 1
}

# Clear queue
queue_clear() {
    QUEUE_ITEMS=()
    QUEUE_TYPES=()
    QUEUE_DESCRIPTIONS=()
    log_info "Queue cleared"
}

# Get queue count
queue_count() {
    echo "${#QUEUE_ITEMS[@]}"
}

# Check if queue is empty
queue_is_empty() {
    [[ ${#QUEUE_ITEMS[@]} -eq 0 ]]
}

# Preview queue
queue_preview() {
    local count=${#QUEUE_ITEMS[@]}

    if [[ $count -eq 0 ]]; then
        log_info "Queue is empty"
        return 0
    fi

    log_section "Queue Preview ($count items)"
    printf "\n"

    local i=0
    for item in "${QUEUE_ITEMS[@]}"; do
        local type="${QUEUE_TYPES[$i]}"
        local desc="${QUEUE_DESCRIPTIONS[$i]}"
        printf "  %2d. [%-12s] %s\n" "$((i+1))" "$type" "$desc"
        ((i++))
    done

    printf "\n"
}

# Show queue menu
queue_menu() {
    while true; do
        local count=${#QUEUE_ITEMS[@]}

        show_menu "Queue Management ($count items)" \
            "1) Preview queue" \
            "2) Execute queue" \
            "3) Dry-run (preview execution)" \
            "4) Remove item from queue" \
            "5) Reorder queue" \
            "6) Clear queue" \
            "7) Save queue to file" \
            "8) Load queue from file" \
            "0) Back"

        case "$MENU_CHOICE" in
            1) queue_preview; pause ;;
            2)
                if queue_is_empty; then
                    log_warn "Queue is empty"
                else
                    queue_preview
                    if confirm "Execute all queued actions?"; then
                        queue_execute
                    fi
                fi
                pause
                ;;
            3)
                queue_execute --dry-run
                pause
                ;;
            4)
                if queue_is_empty; then
                    log_warn "Queue is empty"
                else
                    queue_preview
                    printf "Enter item number to remove (1-%d) or 0 to cancel: " "$count"
                    read -r num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -gt 0 ]] && [[ "$num" -le "$count" ]]; then
                        queue_remove "$((num-1))"
                        log_success "Item removed"
                    fi
                fi
                pause
                ;;
            5)
                queue_reorder_menu
                ;;
            6)
                if ! queue_is_empty; then
                    if confirm "Clear all $count queued items?"; then
                        queue_clear
                    fi
                else
                    log_info "Queue is already empty"
                fi
                pause
                ;;
            7)
                queue_save
                log_success "Queue saved to $QUEUE_FILE"
                pause
                ;;
            8)
                if queue_load; then
                    log_success "Queue loaded"
                else
                    log_warn "No saved queue found"
                fi
                pause
                ;;
            0) return 0 ;;
        esac
    done
}

# Reorder queue menu
queue_reorder_menu() {
    if queue_is_empty; then
        log_warn "Queue is empty"
        pause
        return
    fi

    queue_preview
    printf "Enter item number to move: "
    read -r from_num
    printf "Enter new position: "
    read -r to_num

    if [[ "$from_num" =~ ^[0-9]+$ ]] && [[ "$to_num" =~ ^[0-9]+$ ]]; then
        queue_move "$((from_num-1))" "$((to_num-1))"
    fi
    pause
}

# Move item in queue
queue_move() {
    local from_idx="$1"
    local to_idx="$2"
    local count=${#QUEUE_ITEMS[@]}

    if [[ "$from_idx" -lt 0 ]] || [[ "$from_idx" -ge "$count" ]]; then
        return 1
    fi
    if [[ "$to_idx" -lt 0 ]]; then
        to_idx=0
    fi
    if [[ "$to_idx" -ge "$count" ]]; then
        to_idx=$((count - 1))
    fi

    local item="${QUEUE_ITEMS[$from_idx]}"
    local type="${QUEUE_TYPES[$from_idx]}"
    local desc="${QUEUE_DESCRIPTIONS[$from_idx]}"

    # Remove from old position
    queue_remove "$from_idx"

    # Insert at new position
    local new_items=()
    local new_types=()
    local new_descs=()
    local i=0

    for ((i=0; i<${#QUEUE_ITEMS[@]}+1; i++)); do
        if [[ $i -eq $to_idx ]]; then
            new_items+=("$item")
            new_types+=("$type")
            new_descs+=("$desc")
        fi
        if [[ $i -lt ${#QUEUE_ITEMS[@]} ]]; then
            new_items+=("${QUEUE_ITEMS[$i]}")
            new_types+=("${QUEUE_TYPES[$i]}")
            new_descs+=("${QUEUE_DESCRIPTIONS[$i]}")
        fi
    done

    QUEUE_ITEMS=("${new_items[@]}")
    QUEUE_TYPES=("${new_types[@]}")
    QUEUE_DESCRIPTIONS=("${new_descs[@]}")

    log_debug "Moved item from $from_idx to $to_idx"
}

# Execute queue
queue_execute() {
    local dry_run=0
    [[ "$1" == "--dry-run" ]] && dry_run=1

    if queue_is_empty; then
        log_info "Queue is empty, nothing to execute"
        return 0
    fi

    local count=${#QUEUE_ITEMS[@]}
    local success=0
    local failed=0

    if [[ $dry_run -eq 1 ]]; then
        log_section "Dry Run ($count items)"
    else
        log_section "Executing Queue ($count items)"
    fi

    local pkg_install_list=()
    local pkg_remove_list=()

    # First pass: batch package operations
    for ((i=0; i<count; i++)); do
        local type="${QUEUE_TYPES[$i]}"
        local item="${QUEUE_ITEMS[$i]}"

        case "$type" in
            pkg_install) pkg_install_list+=("$item") ;;
            pkg_remove) pkg_remove_list+=("$item") ;;
        esac
    done

    # Execute batched package installs
    if [[ ${#pkg_install_list[@]} -gt 0 ]]; then
        log_step 1 "" "Installing ${#pkg_install_list[@]} packages"
        if [[ $dry_run -eq 1 ]]; then
            printf "  Would install: %s\n" "${pkg_install_list[*]}"
        else
            if pkg_install "${pkg_install_list[@]}"; then
                ((success += ${#pkg_install_list[@]}))
            else
                ((failed += ${#pkg_install_list[@]}))
            fi
        fi
    fi

    # Execute batched package removes
    if [[ ${#pkg_remove_list[@]} -gt 0 ]]; then
        log_step 2 "" "Removing ${#pkg_remove_list[@]} packages"
        if [[ $dry_run -eq 1 ]]; then
            printf "  Would remove: %s\n" "${pkg_remove_list[*]}"
        else
            if pkg_remove "${pkg_remove_list[@]}"; then
                ((success += ${#pkg_remove_list[@]}))
            else
                ((failed += ${#pkg_remove_list[@]}))
            fi
        fi
    fi

    # Execute other items
    local step=3
    for ((i=0; i<count; i++)); do
        local type="${QUEUE_TYPES[$i]}"
        local item="${QUEUE_ITEMS[$i]}"
        local desc="${QUEUE_DESCRIPTIONS[$i]}"

        case "$type" in
            pkg_install|pkg_remove)
                # Already handled above
                continue
                ;;
            sysctl)
                log_step $step "" "$desc"
                local key value
                key="${item%%=*}"
                value="${item#*=}"
                # Security: validate sysctl key against whitelist
                if ! _queue_validate_sysctl_key "$key"; then
                    log_error "Blocked disallowed sysctl key: $key"
                    ((failed++))
                    ((step++))
                    continue
                fi
                # Validate value is reasonable (numeric or simple string)
                if [[ ! "$value" =~ ^[a-zA-Z0-9\ _.-]+$ ]]; then
                    log_error "Invalid sysctl value format: $value"
                    ((failed++))
                    ((step++))
                    continue
                fi
                if [[ $dry_run -eq 1 ]]; then
                    printf "  Would set: %s\n" "$item"
                else
                    if sysctl -w "$key=$value" &>/dev/null; then
                        # Persist sysctl changes to config file
                        local conf="/etc/sysctl.d/99-ultimate-linux-suite.conf"
                        if [[ ! -f "$conf" ]]; then
                            printf '# Ultimate Linux Suite optimizations\n' > "$conf" 2>/dev/null
                        fi
                        # Update existing or append new entry
                        if grep -q "^${key}[[:space:]]*=" "$conf" 2>/dev/null; then
                            sed -i "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "$conf" 2>/dev/null
                        else
                            printf '%s = %s\n' "$key" "$value" >> "$conf" 2>/dev/null
                        fi
                        ((success++))
                    else
                        ((failed++))
                        log_warn "Failed to set $key"
                    fi
                fi
                ((step++))
                ;;
            file_write)
                # Safe file write operation (content|path format)
                log_step $step "" "$desc"
                local content="${item%%|*}"
                local filepath="${item#*|}"
                # Security: only allow specific paths
                if [[ ! "$filepath" =~ ^/etc/sysctl\.d/ ]] && \
                   [[ ! "$filepath" =~ ^/etc/sysctl\.conf$ ]]; then
                    log_error "Blocked write to disallowed path: $filepath"
                    ((failed++))
                    ((step++))
                    continue
                fi
                if [[ $dry_run -eq 1 ]]; then
                    printf "  Would write to: %s\n" "$filepath"
                else
                    if printf '%s\n' "$content" > "$filepath" 2>/dev/null; then
                        ((success++))
                    else
                        ((failed++))
                        log_warn "Failed to write: $filepath"
                    fi
                fi
                ((step++))
                ;;
            service)
                log_step $step "" "$desc"
                local action="${item%%:*}"
                local service="${item#*:}"
                # Security: validate action and service name
                if ! _queue_validate_service_action "$action"; then
                    log_error "Blocked invalid service action: $action"
                    ((failed++))
                    ((step++))
                    continue
                fi
                if ! _queue_validate_service_name "$service"; then
                    log_error "Blocked invalid service name: $service"
                    ((failed++))
                    ((step++))
                    continue
                fi
                if [[ $dry_run -eq 1 ]]; then
                    printf "  Would %s: %s\n" "$action" "$service"
                else
                    if systemctl "$action" "$service" &>/dev/null; then
                        ((success++))
                    else
                        ((failed++))
                        log_warn "Service action failed: $action $service"
                    fi
                fi
                ((step++))
                ;;
        esac
    done

    if [[ $dry_run -eq 1 ]]; then
        log_info "Dry run complete - no changes made"
    else
        # Clear queue after execution
        queue_clear

        if [[ $failed -eq 0 ]]; then
            log_success "All $success operations completed successfully"
        else
            log_warn "$success succeeded, $failed failed"
        fi
    fi
}

# Save queue to file
queue_save() {
    [[ -z "$QUEUE_FILE" ]] && return 1

    local count=${#QUEUE_ITEMS[@]}
    {
        echo "# Ultimate Linux Suite Queue"
        echo "# Saved: $(date)"
        echo ""
        for ((i=0; i<count; i++)); do
            echo "${QUEUE_TYPES[$i]}|${QUEUE_ITEMS[$i]}|${QUEUE_DESCRIPTIONS[$i]}"
        done
    } > "$QUEUE_FILE"

    log_debug "Queue saved to $QUEUE_FILE"
}

# Load queue from file with validation
queue_load() {
    [[ -z "$QUEUE_FILE" ]] && return 1
    [[ ! -f "$QUEUE_FILE" ]] && return 1

    # Security: verify file ownership matches current user or root
    local file_owner
    file_owner=$(stat -c '%u' "$QUEUE_FILE" 2>/dev/null)
    local current_user
    current_user=$(id -u)
    if [[ "$file_owner" != "$current_user" ]] && [[ "$file_owner" != "0" ]]; then
        log_error "Queue file has unsafe ownership, refusing to load"
        return 1
    fi

    local skipped=0
    while IFS='|' read -r type item desc || [[ -n "$type" ]]; do
        # Skip comments and empty lines
        [[ "$type" =~ ^#.*$ ]] && continue
        [[ -z "$type" ]] && continue

        # Validate type against whitelist
        if ! _queue_validate_type "$type"; then
            log_warn "Skipping invalid queue type: $type"
            ((skipped++))
            continue
        fi

        # Validate item based on type
        case "$type" in
            pkg_install|pkg_remove)
                if ! _queue_validate_package "$item"; then
                    log_warn "Skipping invalid package name: $item"
                    ((skipped++))
                    continue
                fi
                ;;
            sysctl)
                local key="${item%%=*}"
                if ! _queue_validate_sysctl_key "$key"; then
                    log_warn "Skipping disallowed sysctl key: $key"
                    ((skipped++))
                    continue
                fi
                ;;
            service)
                local action="${item%%:*}"
                local service="${item#*:}"
                if ! _queue_validate_service_action "$action"; then
                    log_warn "Skipping invalid service action: $action"
                    ((skipped++))
                    continue
                fi
                if ! _queue_validate_service_name "$service"; then
                    log_warn "Skipping invalid service name: $service"
                    ((skipped++))
                    continue
                fi
                ;;
        esac

        QUEUE_TYPES+=("$type")
        QUEUE_ITEMS+=("$item")
        QUEUE_DESCRIPTIONS+=("$desc")
    done < "$QUEUE_FILE"

    if [[ $skipped -gt 0 ]]; then
        log_warn "Skipped $skipped invalid queue items for security"
    fi

    log_debug "Queue loaded from $QUEUE_FILE"
    return 0
}

# Quick add with confirmation
# Usage: queue_quick_add TYPE ITEM [DESCRIPTION]
queue_quick_add() {
    local type="$1"
    local item="$2"
    local desc="${3:-$item}"

    printf "Add to queue: [%s] %s\n" "$type" "$desc"
    if confirm "Queue this action?"; then
        queue_add "$type" "$item" "$desc"
        log_success "Added to queue"
        return 0
    fi
    return 1
}
