#!/usr/bin/env bash
#
# firewall.sh - Firewall Management Module for Ultimate Linux Suite
#
# Provides unified interface for ufw and firewalld
#

# Prevent multiple sourcing
[[ -n "${_FIREWALL_MODULE_LOADED:-}" ]] && return 0
readonly _FIREWALL_MODULE_LOADED=1

# ============================================================================
# Firewall Backend Detection
# ============================================================================

# Detect which firewall is available/active
_fw_detect_backend() {
    if command -v ufw &>/dev/null; then
        if ufw status &>/dev/null; then
            echo "ufw"
            return 0
        fi
    fi

    if command -v firewall-cmd &>/dev/null; then
        if systemctl is-active firewalld &>/dev/null; then
            echo "firewalld"
            return 0
        fi
    fi

    if command -v iptables &>/dev/null; then
        echo "iptables"
        return 0
    fi

    echo "none"
    return 1
}

# Check if ufw is available
_fw_is_ufw() {
    command -v ufw &>/dev/null
}

# Check if firewalld is available
_fw_is_firewalld() {
    command -v firewall-cmd &>/dev/null
}

# Check if iptables is available (fallback)
_fw_is_iptables() {
    command -v iptables &>/dev/null
}

# ============================================================================
# Firewall Status
# ============================================================================

# Get firewall status
fw_status() {
    local backend
    backend=$(_fw_detect_backend)

    case "$backend" in
        ufw)
            ufw status verbose
            ;;
        firewalld)
            firewall-cmd --state
            printf "\nDefault zone: %s\n" "$(firewall-cmd --get-default-zone)"
            printf "Active zones:\n"
            firewall-cmd --get-active-zones
            ;;
        iptables)
            printf "iptables rules:\n"
            iptables -L -n -v --line-numbers
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac
}

# Check if firewall is enabled/active
fw_is_active() {
    local backend
    backend=$(_fw_detect_backend)

    case "$backend" in
        ufw)
            ufw status | grep -q "Status: active"
            ;;
        firewalld)
            systemctl is-active firewalld &>/dev/null
            ;;
        iptables)
            # iptables is always "active" if installed
            iptables -L -n &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# Firewall Enable/Disable
# ============================================================================

# Enable firewall
fw_enable() {
    local backend
    backend=$(_fw_detect_backend)
    log_info "Enabling firewall..."

    case "$backend" in
        ufw)
            ufw --force enable
            ;;
        firewalld)
            systemctl enable --now firewalld
            ;;
        iptables)
            log_warn "iptables has no enable concept - rules are applied immediately"
            return 0
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Firewall enabled"
}

# Disable firewall
fw_disable() {
    local backend
    backend=$(_fw_detect_backend)
    log_info "Disabling firewall..."

    case "$backend" in
        ufw)
            ufw disable
            ;;
        firewalld)
            systemctl disable --now firewalld
            ;;
        iptables)
            iptables -F
            iptables -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Firewall disabled"
}

# ============================================================================
# Port Management
# ============================================================================

# Validate port number
_fw_validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]
}

# Validate protocol
_fw_validate_proto() {
    local proto="$1"
    [[ "$proto" =~ ^(tcp|udp|both)$ ]]
}

# Allow a port
# Usage: fw_allow_port PORT [PROTOCOL]
fw_allow_port() {
    local port="$1"
    local proto="${2:-tcp}"
    local backend

    if ! _fw_validate_port "$port"; then
        log_error "Invalid port number: $port"
        return 1
    fi

    if ! _fw_validate_proto "$proto"; then
        log_error "Invalid protocol: $proto (use tcp, udp, or both)"
        return 1
    fi

    backend=$(_fw_detect_backend)
    log_info "Allowing port $port/$proto..."

    case "$backend" in
        ufw)
            if [[ "$proto" == "both" ]]; then
                ufw allow "$port"
            else
                ufw allow "$port/$proto"
            fi
            ;;
        firewalld)
            if [[ "$proto" == "both" ]]; then
                firewall-cmd --permanent --add-port="$port/tcp"
                firewall-cmd --permanent --add-port="$port/udp"
            else
                firewall-cmd --permanent --add-port="$port/$proto"
            fi
            firewall-cmd --reload
            ;;
        iptables)
            if [[ "$proto" == "both" ]]; then
                iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                iptables -A INPUT -p udp --dport "$port" -j ACCEPT
            else
                iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
            fi
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Port $port/$proto allowed"
}

# Deny a port
# Usage: fw_deny_port PORT [PROTOCOL]
fw_deny_port() {
    local port="$1"
    local proto="${2:-tcp}"
    local backend

    if ! _fw_validate_port "$port"; then
        log_error "Invalid port number: $port"
        return 1
    fi

    if ! _fw_validate_proto "$proto"; then
        log_error "Invalid protocol: $proto"
        return 1
    fi

    backend=$(_fw_detect_backend)
    log_info "Denying port $port/$proto..."

    case "$backend" in
        ufw)
            if [[ "$proto" == "both" ]]; then
                ufw deny "$port"
            else
                ufw deny "$port/$proto"
            fi
            ;;
        firewalld)
            if [[ "$proto" == "both" ]]; then
                firewall-cmd --permanent --remove-port="$port/tcp" 2>/dev/null
                firewall-cmd --permanent --remove-port="$port/udp" 2>/dev/null
            else
                firewall-cmd --permanent --remove-port="$port/$proto" 2>/dev/null
            fi
            firewall-cmd --reload
            ;;
        iptables)
            if [[ "$proto" == "both" ]]; then
                iptables -A INPUT -p tcp --dport "$port" -j DROP
                iptables -A INPUT -p udp --dport "$port" -j DROP
            else
                iptables -A INPUT -p "$proto" --dport "$port" -j DROP
            fi
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Port $port/$proto denied"
}

# Delete a port rule
# Usage: fw_delete_port PORT [PROTOCOL]
fw_delete_port() {
    local port="$1"
    local proto="${2:-tcp}"
    local backend

    if ! _fw_validate_port "$port"; then
        log_error "Invalid port number: $port"
        return 1
    fi

    backend=$(_fw_detect_backend)
    log_info "Removing rule for port $port/$proto..."

    case "$backend" in
        ufw)
            if [[ "$proto" == "both" ]]; then
                ufw delete allow "$port" 2>/dev/null || true
                ufw delete deny "$port" 2>/dev/null || true
            else
                ufw delete allow "$port/$proto" 2>/dev/null || true
                ufw delete deny "$port/$proto" 2>/dev/null || true
            fi
            ;;
        firewalld)
            if [[ "$proto" == "both" ]]; then
                firewall-cmd --permanent --remove-port="$port/tcp" 2>/dev/null || true
                firewall-cmd --permanent --remove-port="$port/udp" 2>/dev/null || true
            else
                firewall-cmd --permanent --remove-port="$port/$proto" 2>/dev/null || true
            fi
            firewall-cmd --reload
            ;;
        iptables)
            if [[ "$proto" == "both" ]]; then
                iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null || true
                iptables -D INPUT -p udp --dport "$port" -j DROP 2>/dev/null || true
            else
                iptables -D INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -p "$proto" --dport "$port" -j DROP 2>/dev/null || true
            fi
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Rule for port $port/$proto removed"
}

# ============================================================================
# Service Management (predefined ports)
# ============================================================================

# Common service port mappings
declare -gA FW_SERVICES=(
    [ssh]="22/tcp"
    [http]="80/tcp"
    [https]="443/tcp"
    [ftp]="21/tcp"
    [smtp]="25/tcp"
    [dns]="53/both"
    [mysql]="3306/tcp"
    [postgresql]="5432/tcp"
    [redis]="6379/tcp"
    [mongodb]="27017/tcp"
    [docker]="2375/tcp"
    [vnc]="5900/tcp"
    [rdp]="3389/tcp"
    [samba]="445/tcp"
    [nfs]="2049/both"
)

# Allow a service
# Usage: fw_allow_service SERVICE
fw_allow_service() {
    local service="$1"
    local backend
    backend=$(_fw_detect_backend)

    # Check if it's a predefined service
    if [[ -n "${FW_SERVICES[$service]:-}" ]]; then
        local port_proto="${FW_SERVICES[$service]}"
        local port="${port_proto%%/*}"
        local proto="${port_proto##*/}"
        fw_allow_port "$port" "$proto"
        return $?
    fi

    # Try native service support
    log_info "Allowing service: $service"

    case "$backend" in
        ufw)
            ufw allow "$service"
            ;;
        firewalld)
            firewall-cmd --permanent --add-service="$service"
            firewall-cmd --reload
            ;;
        *)
            log_error "Service '$service' not recognized and backend doesn't support service names"
            return 1
            ;;
    esac

    log_success "Service $service allowed"
}

# Deny a service
# Usage: fw_deny_service SERVICE
fw_deny_service() {
    local service="$1"
    local backend
    backend=$(_fw_detect_backend)

    if [[ -n "${FW_SERVICES[$service]:-}" ]]; then
        local port_proto="${FW_SERVICES[$service]}"
        local port="${port_proto%%/*}"
        local proto="${port_proto##*/}"
        fw_deny_port "$port" "$proto"
        return $?
    fi

    log_info "Denying service: $service"

    case "$backend" in
        ufw)
            ufw deny "$service"
            ;;
        firewalld)
            firewall-cmd --permanent --remove-service="$service" 2>/dev/null || true
            firewall-cmd --reload
            ;;
        *)
            log_error "Service '$service' not recognized"
            return 1
            ;;
    esac

    log_success "Service $service denied"
}

# ============================================================================
# IP Address Rules
# ============================================================================

# Validate IP address (basic validation)
_fw_validate_ip() {
    local ip="$1"
    # Allow single IP, CIDR notation, or 'any'
    [[ "$ip" == "any" ]] && return 0
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]
}

# Allow from IP
# Usage: fw_allow_from IP [PORT]
fw_allow_from() {
    local ip="$1"
    local port="${2:-}"
    local backend

    if ! _fw_validate_ip "$ip"; then
        log_error "Invalid IP address: $ip"
        return 1
    fi

    backend=$(_fw_detect_backend)
    log_info "Allowing connections from $ip${port:+ to port $port}..."

    case "$backend" in
        ufw)
            if [[ -n "$port" ]]; then
                ufw allow from "$ip" to any port "$port"
            else
                ufw allow from "$ip"
            fi
            ;;
        firewalld)
            if [[ -n "$port" ]]; then
                firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$ip port port=$port protocol=tcp accept"
            else
                firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$ip accept"
            fi
            firewall-cmd --reload
            ;;
        iptables)
            if [[ -n "$port" ]]; then
                iptables -A INPUT -s "$ip" -p tcp --dport "$port" -j ACCEPT
            else
                iptables -A INPUT -s "$ip" -j ACCEPT
            fi
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Connections from $ip allowed"
}

# Deny from IP
# Usage: fw_deny_from IP
fw_deny_from() {
    local ip="$1"
    local backend

    if ! _fw_validate_ip "$ip"; then
        log_error "Invalid IP address: $ip"
        return 1
    fi

    backend=$(_fw_detect_backend)
    log_info "Blocking connections from $ip..."

    case "$backend" in
        ufw)
            ufw deny from "$ip"
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$ip drop"
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -s "$ip" -j DROP
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Connections from $ip blocked"
}

# ============================================================================
# Firewall Presets
# ============================================================================

# Apply a security preset
# Usage: fw_apply_preset PRESET
fw_apply_preset() {
    local preset="$1"
    local backend
    backend=$(_fw_detect_backend)

    log_info "Applying firewall preset: $preset"

    case "$preset" in
        minimal)
            # Only allow SSH
            fw_enable
            fw_allow_port 22 tcp
            log_success "Minimal preset applied (SSH only)"
            ;;
        web-server)
            # Web server ports
            fw_enable
            fw_allow_port 22 tcp
            fw_allow_port 80 tcp
            fw_allow_port 443 tcp
            log_success "Web server preset applied (SSH, HTTP, HTTPS)"
            ;;
        database)
            # Database server (internal only)
            fw_enable
            fw_allow_port 22 tcp
            fw_allow_port 3306 tcp
            fw_allow_port 5432 tcp
            log_success "Database preset applied (SSH, MySQL, PostgreSQL)"
            ;;
        development)
            # Development machine (more open)
            fw_enable
            fw_allow_port 22 tcp
            fw_allow_port 80 tcp
            fw_allow_port 443 tcp
            fw_allow_port 3000 tcp  # Node.js
            fw_allow_port 5000 tcp  # Flask
            fw_allow_port 8000 tcp  # Django
            fw_allow_port 8080 tcp  # Alternate HTTP
            log_success "Development preset applied"
            ;;
        *)
            log_error "Unknown preset: $preset"
            log_info "Available presets: minimal, web-server, database, development"
            return 1
            ;;
    esac
}

# ============================================================================
# Firewall Reset
# ============================================================================

# Reset firewall to defaults
fw_reset() {
    local backend
    backend=$(_fw_detect_backend)

    if ! confirm "This will reset ALL firewall rules. Continue?"; then
        return 0
    fi

    log_info "Resetting firewall..."

    case "$backend" in
        ufw)
            ufw --force reset
            ;;
        firewalld)
            # Remove all added rules and reload
            for zone in $(firewall-cmd --get-zones); do
                firewall-cmd --permanent --zone="$zone" --remove-all-ports 2>/dev/null || true
                firewall-cmd --permanent --zone="$zone" --remove-all-services 2>/dev/null || true
            done
            firewall-cmd --reload
            ;;
        iptables)
            iptables -F
            iptables -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac

    log_success "Firewall reset to defaults"
}

# ============================================================================
# List Rules
# ============================================================================

# List all firewall rules
fw_list_rules() {
    local backend
    backend=$(_fw_detect_backend)

    log_section "Firewall Rules"

    case "$backend" in
        ufw)
            ufw status numbered
            ;;
        firewalld)
            printf "Zone: %s\n\n" "$(firewall-cmd --get-default-zone)"
            printf "Services:\n"
            firewall-cmd --list-services
            printf "\nPorts:\n"
            firewall-cmd --list-ports
            printf "\nRich Rules:\n"
            firewall-cmd --list-rich-rules
            ;;
        iptables)
            iptables -L -n -v --line-numbers
            ;;
        *)
            log_error "No firewall detected"
            return 1
            ;;
    esac
}

# ============================================================================
# Interactive Menu
# ============================================================================

_firewall_show_status() {
    local backend
    backend=$(_fw_detect_backend)
    local status_str

    if fw_is_active; then
        status_str="${GREEN}active${RESET}"
    else
        status_str="${RED}inactive${RESET}"
    fi

    printf "  Backend: %s\n" "$backend"
    printf "  Status:  %b\n" "$status_str"
}

_firewall_manage_port() {
    local action="$1"
    local port proto

    printf "Enter port number: "
    read -r port

    if ! _fw_validate_port "$port"; then
        log_error "Invalid port number"
        return 1
    fi

    printf "Protocol (tcp/udp/both) [tcp]: "
    read -r proto
    proto="${proto:-tcp}"

    case "$action" in
        allow) fw_allow_port "$port" "$proto" ;;
        deny) fw_deny_port "$port" "$proto" ;;
        delete) fw_delete_port "$port" "$proto" ;;
    esac
}

_firewall_manage_service() {
    log_section "Available Services"
    printf "Predefined: "
    printf "%s " "${!FW_SERVICES[@]}"
    printf "\n\n"

    printf "Enter service name: "
    read -r service

    if [[ -z "$service" ]]; then
        return
    fi

    simple_menu "Action" "Allow" "Deny"

    case "$MENU_CHOICE" in
        1) fw_allow_service "$service" ;;
        2) fw_deny_service "$service" ;;
    esac
}

_firewall_manage_ip() {
    local ip port

    printf "Enter IP address (e.g., 192.168.1.100 or 10.0.0.0/8): "
    read -r ip

    if ! _fw_validate_ip "$ip"; then
        log_error "Invalid IP address"
        return 1
    fi

    simple_menu "Action" "Allow from IP" "Allow from IP to port" "Block IP"

    case "$MENU_CHOICE" in
        1) fw_allow_from "$ip" ;;
        2)
            printf "Enter port number: "
            read -r port
            fw_allow_from "$ip" "$port"
            ;;
        3) fw_deny_from "$ip" ;;
    esac
}

_firewall_apply_preset() {
    simple_menu "Select Preset" \
        "Minimal (SSH only)" \
        "Web Server (SSH, HTTP, HTTPS)" \
        "Database (SSH, MySQL, PostgreSQL)" \
        "Development (common dev ports)"

    case "$MENU_CHOICE" in
        1) fw_apply_preset minimal ;;
        2) fw_apply_preset web-server ;;
        3) fw_apply_preset database ;;
        4) fw_apply_preset development ;;
    esac
}

# ============================================================================
# Module Entry Points
# ============================================================================

firewall_init() {
    local backend
    backend=$(_fw_detect_backend)
    log_debug "Firewall module initialized (backend: $backend)"
}

firewall_main() {
    while true; do
        log_section "Firewall Management"
        _firewall_show_status
        printf "\n"

        simple_menu "Firewall Options" \
            "View Status" \
            "Enable Firewall" \
            "Disable Firewall" \
            "Allow Port" \
            "Deny Port" \
            "Delete Port Rule" \
            "Manage Service" \
            "Manage IP Address" \
            "Apply Preset" \
            "List All Rules" \
            "Reset Firewall"

        case "$MENU_CHOICE" in
            1)
                fw_status
                pause
                ;;
            2) fw_enable ;;
            3) fw_disable ;;
            4) _firewall_manage_port allow ;;
            5) _firewall_manage_port deny ;;
            6) _firewall_manage_port delete ;;
            7) _firewall_manage_service ;;
            8) _firewall_manage_ip ;;
            9) _firewall_apply_preset ;;
            10)
                fw_list_rules
                pause
                ;;
            11) fw_reset ;;
            0) return 0 ;;
        esac
    done
}
