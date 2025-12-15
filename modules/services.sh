#!/usr/bin/env bash
#
# services.sh - Service Management Module for Ultimate Linux Suite
#
# Provides systemd/openrc service management interface
#

# Prevent multiple sourcing
[[ -n "${_SERVICES_MODULE_LOADED:-}" ]] && return 0
readonly _SERVICES_MODULE_LOADED=1

# ============================================================================
# Service Backend Detection
# ============================================================================

# Check if systemd is available
_svc_is_systemd() {
    [[ "$INIT_SYSTEM" == "systemd" ]] || [[ -d /run/systemd/system ]]
}

# Check if openrc is available
_svc_is_openrc() {
    [[ "$INIT_SYSTEM" == "openrc" ]] || command -v rc-service &>/dev/null
}

# ============================================================================
# Service Operations
# ============================================================================

# Get service status
# Usage: svc_status SERVICE
svc_status() {
    local service="$1"

    if _svc_is_systemd; then
        systemctl status "$service" 2>/dev/null
    elif _svc_is_openrc; then
        rc-service "$service" status 2>/dev/null
    else
        log_error "Unknown init system"
        return 1
    fi
}

# Check if service is active
# Usage: svc_is_active SERVICE
svc_is_active() {
    local service="$1"

    if _svc_is_systemd; then
        systemctl is-active "$service" &>/dev/null
    elif _svc_is_openrc; then
        rc-service "$service" status &>/dev/null
    else
        return 1
    fi
}

# Check if service is enabled
# Usage: svc_is_enabled SERVICE
svc_is_enabled() {
    local service="$1"

    if _svc_is_systemd; then
        systemctl is-enabled "$service" &>/dev/null
    elif _svc_is_openrc; then
        rc-update show default 2>/dev/null | grep -q "$service"
    else
        return 1
    fi
}

# Start service
# Usage: svc_start SERVICE
svc_start() {
    local service="$1"
    log_info "Starting $service..."

    if _svc_is_systemd; then
        systemctl start "$service"
    elif _svc_is_openrc; then
        rc-service "$service" start
    else
        log_error "Unknown init system"
        return 1
    fi

    if svc_is_active "$service"; then
        log_success "$service started"
    else
        log_error "Failed to start $service"
        return 1
    fi
}

# Stop service
# Usage: svc_stop SERVICE
svc_stop() {
    local service="$1"
    log_info "Stopping $service..."

    if _svc_is_systemd; then
        systemctl stop "$service"
    elif _svc_is_openrc; then
        rc-service "$service" stop
    else
        log_error "Unknown init system"
        return 1
    fi

    if ! svc_is_active "$service"; then
        log_success "$service stopped"
    else
        log_warn "$service may still be running"
    fi
}

# Restart service
# Usage: svc_restart SERVICE
svc_restart() {
    local service="$1"
    log_info "Restarting $service..."

    if _svc_is_systemd; then
        systemctl restart "$service"
    elif _svc_is_openrc; then
        rc-service "$service" restart
    else
        log_error "Unknown init system"
        return 1
    fi

    if svc_is_active "$service"; then
        log_success "$service restarted"
    else
        log_error "Failed to restart $service"
        return 1
    fi
}

# Enable service (start on boot)
# Usage: svc_enable SERVICE
svc_enable() {
    local service="$1"
    log_info "Enabling $service..."

    if _svc_is_systemd; then
        systemctl enable "$service"
    elif _svc_is_openrc; then
        rc-update add "$service" default
    else
        log_error "Unknown init system"
        return 1
    fi

    log_success "$service enabled"
}

# Disable service
# Usage: svc_disable SERVICE
svc_disable() {
    local service="$1"
    log_info "Disabling $service..."

    if _svc_is_systemd; then
        systemctl disable "$service"
    elif _svc_is_openrc; then
        rc-update del "$service" default
    else
        log_error "Unknown init system"
        return 1
    fi

    log_success "$service disabled"
}

# Reload service configuration
# Usage: svc_reload SERVICE
svc_reload() {
    local service="$1"
    log_info "Reloading $service..."

    if _svc_is_systemd; then
        systemctl reload "$service" 2>/dev/null || systemctl restart "$service"
    elif _svc_is_openrc; then
        rc-service "$service" reload 2>/dev/null || rc-service "$service" restart
    else
        log_error "Unknown init system"
        return 1
    fi

    log_success "$service reloaded"
}

# ============================================================================
# Service Listing
# ============================================================================

# List all services
svc_list_all() {
    if _svc_is_systemd; then
        systemctl list-units --type=service --all --no-pager
    elif _svc_is_openrc; then
        rc-status --all
    else
        log_error "Unknown init system"
        return 1
    fi
}

# List running services
svc_list_running() {
    if _svc_is_systemd; then
        systemctl list-units --type=service --state=running --no-pager
    elif _svc_is_openrc; then
        rc-status --servicelist
    else
        log_error "Unknown init system"
        return 1
    fi
}

# List failed services
svc_list_failed() {
    if _svc_is_systemd; then
        systemctl list-units --type=service --state=failed --no-pager
    elif _svc_is_openrc; then
        rc-status --crashed
    else
        log_error "Unknown init system"
        return 1
    fi
}

# ============================================================================
# Common Service Presets
# ============================================================================

# Services commonly needed for different use cases
# shellcheck disable=SC2034  # Reserved for future preset functionality
declare -gA SVC_PRESETS=(
    [ssh]="sshd ssh"
    [firewall]="firewalld ufw iptables"
    [web]="nginx apache2 httpd"
    [database]="mysql mariadb postgresql redis mongodb"
    [docker]="docker containerd"
    [network]="NetworkManager systemd-networkd"
    [print]="cups"
    [bluetooth]="bluetooth"
    [audio]="pipewire pulseaudio"
)

# ============================================================================
# Interactive Menu
# ============================================================================

_services_show_status() {
    local service="$1"
    local active enabled

    if svc_is_active "$service"; then
        active="${GREEN}active${RESET}"
    else
        active="${RED}inactive${RESET}"
    fi

    if svc_is_enabled "$service"; then
        enabled="${GREEN}enabled${RESET}"
    else
        enabled="${YELLOW}disabled${RESET}"
    fi

    printf "  %-30s %b / %b\n" "$service" "$active" "$enabled"
}

_services_manage_single() {
    local service="$1"

    log_section "Manage: $service"
    _services_show_status "$service"
    printf "\n"

    simple_menu "Actions" \
        "Start" \
        "Stop" \
        "Restart" \
        "Enable (start on boot)" \
        "Disable" \
        "View status" \
        "View logs"

    case "$MENU_CHOICE" in
        1) svc_start "$service" ;;
        2) svc_stop "$service" ;;
        3) svc_restart "$service" ;;
        4) svc_enable "$service" ;;
        5) svc_disable "$service" ;;
        6) svc_status "$service" | less ;;
        7)
            if _svc_is_systemd; then
                journalctl -u "$service" --no-pager -n 50
            else
                log_warn "Log viewing requires systemd"
            fi
            ;;
    esac
    pause
}

_services_quick_status() {
    log_section "Common Services Status"

    local common_services=(
        "sshd" "nginx" "apache2" "mysql" "postgresql"
        "docker" "NetworkManager" "firewalld" "bluetooth"
    )

    for svc in "${common_services[@]}"; do
        if _svc_is_systemd && systemctl cat "$svc" &>/dev/null; then
            _services_show_status "$svc"
        elif _svc_is_openrc && [[ -f "/etc/init.d/$svc" ]]; then
            _services_show_status "$svc"
        fi
    done

    pause
}

_services_search() {
    printf "Enter service name to search: "
    read -r query

    if [[ -z "$query" ]]; then
        return
    fi

    log_section "Search Results: $query"

    if _svc_is_systemd; then
        systemctl list-units --type=service --all --no-pager | grep -i "$query"
    elif _svc_is_openrc; then
        rc-status --all | grep -i "$query"
    fi

    printf "\nEnter service name to manage (or press Enter to skip): "
    read -r service

    if [[ -n "$service" ]]; then
        _services_manage_single "$service"
    fi

    pause
}

# ============================================================================
# Module Entry Points
# ============================================================================

services_init() {
    log_debug "Services module initialized (init: ${INIT_SYSTEM:-unknown})"
}

services_main() {
    while true; do
        simple_menu "Service Management" \
            "Quick Status (common services)" \
            "List Running Services" \
            "List Failed Services" \
            "List All Services" \
            "Search & Manage Service" \
            "Manage Specific Service"

        case "$MENU_CHOICE" in
            1) _services_quick_status ;;
            2)
                log_section "Running Services"
                svc_list_running | less
                ;;
            3)
                log_section "Failed Services"
                svc_list_failed
                pause
                ;;
            4)
                log_section "All Services"
                svc_list_all | less
                ;;
            5) _services_search ;;
            6)
                printf "Enter service name: "
                read -r svc
                [[ -n "$svc" ]] && _services_manage_single "$svc"
                ;;
            0) return 0 ;;
        esac
    done
}
