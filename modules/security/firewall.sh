#!/usr/bin/env bash
# OffTrack Suite - Firewall Configuration
# License: GPL-3.0-or-later

[[ -n "${_FIREWALL_LOADED:-}" ]] && return 0
readonly _FIREWALL_LOADED=1

# Setup firewall for security lab
firewall_setup() {
    log_section "Firewall Configuration"

    require_root

    # Detect firewall tool
    local fw_tool=""
    if command_exists firewall-cmd; then
        fw_tool="firewalld"
    elif command_exists ufw; then
        fw_tool="ufw"
    elif command_exists iptables; then
        fw_tool="iptables"
    fi

    log_info "Detected firewall: ${fw_tool:-none}"

    case "$fw_tool" in
        firewalld)
            firewall_setup_firewalld
            ;;
        ufw)
            firewall_setup_ufw
            ;;
        iptables)
            firewall_setup_iptables
            ;;
        *)
            log_warn "No firewall tool detected"
            log_info "Installing firewalld..."
            pkg_install firewalld
            safe_exec systemctl enable --now firewalld
            firewall_setup_firewalld
            ;;
    esac

    log_success "Firewall configured"
}

# Firewalld configuration
firewall_setup_firewalld() {
    log_info "Configuring firewalld..."

    # Ensure service is running
    safe_exec systemctl enable --now firewalld

    # Create zone for malware lab
    safe_exec firewall-cmd --permanent --new-zone=malware-lab 2>/dev/null || true

    # Configure malware-lab zone (no external access)
    safe_exec firewall-cmd --permanent --zone=malware-lab --set-target=DROP
    safe_exec firewall-cmd --permanent --zone=malware-lab --add-interface=virbr-malware 2>/dev/null || true

    # Block malware lab from reaching internet
    safe_exec firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 \
        -i virbr-malware ! -o virbr-malware -j DROP 2>/dev/null || true

    # Reload
    safe_exec firewall-cmd --reload

    log_info "Firewalld zones:"
    firewall-cmd --get-active-zones
}

# UFW configuration
firewall_setup_ufw() {
    log_info "Configuring UFW..."

    # Enable UFW
    safe_exec ufw --force enable

    # Default policies
    safe_exec ufw default deny incoming
    safe_exec ufw default allow outgoing

    # Allow SSH
    safe_exec ufw allow ssh

    # Block malware lab forwarding
    # Note: UFW uses iptables underneath
    safe_exec iptables -I FORWARD -i virbr-malware ! -o virbr-malware -j DROP 2>/dev/null || true

    log_info "UFW status:"
    ufw status verbose
}

# Raw iptables configuration
firewall_setup_iptables() {
    log_info "Configuring iptables..."

    # Block malware lab from reaching external networks
    safe_exec iptables -I FORWARD -i virbr-malware ! -o virbr-malware -j DROP

    # Save rules
    case "$OS_FAMILY" in
        fedora)
            safe_exec iptables-save > /etc/sysconfig/iptables
            ;;
        debian)
            if command_exists netfilter-persistent; then
                safe_exec netfilter-persistent save
            else
                safe_exec iptables-save > /etc/iptables/rules.v4
            fi
            ;;
    esac
}

# Show firewall status
firewall_status() {
    echo "Firewall Status:"
    echo ""

    if command_exists firewall-cmd; then
        echo "Tool: firewalld"
        firewall-cmd --state
        echo ""
        firewall-cmd --list-all
    elif command_exists ufw; then
        echo "Tool: UFW"
        ufw status verbose
    else
        echo "Tool: iptables"
        iptables -L -n | head -30
    fi
}

# Firewall menu
firewall_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Firewall Configuration" \
                "status" "Firewall Status" \
                "setup" "Setup Firewall" \
                "enable" "Enable Firewall" \
                "disable" "Disable Firewall" \
                "rules" "List Rules" \
                "back" "Back")
        else
            echo ""
            echo "Firewall Menu"
            echo "============="
            echo ""
            echo "  1) Firewall Status"
            echo "  2) Setup Firewall"
            echo "  3) Enable Firewall"
            echo "  4) Disable Firewall"
            echo "  5) List Rules"
            echo "  b) Back"
            echo ""
            read -rp "Select: " num
            case "$num" in
                1) choice="status" ;;
                2) choice="setup" ;;
                3) choice="enable" ;;
                4) choice="disable" ;;
                5) choice="rules" ;;
                b|B) choice="back" ;;
            esac
        fi

        case "$choice" in
            status)
                firewall_status
                read -rp "Press Enter to continue..."
                ;;
            setup)
                firewall_setup
                read -rp "Press Enter to continue..."
                ;;
            enable)
                if command_exists ufw; then
                    sudo ufw enable
                elif command_exists firewall-cmd; then
                    sudo systemctl enable --now firewalld
                fi
                log_success "Firewall enabled"
                read -rp "Press Enter to continue..."
                ;;
            disable)
                if command_exists ufw; then
                    sudo ufw disable
                elif command_exists firewall-cmd; then
                    sudo systemctl disable --now firewalld
                fi
                log_success "Firewall disabled"
                read -rp "Press Enter to continue..."
                ;;
            rules)
                if command_exists ufw; then
                    sudo ufw status numbered
                elif command_exists firewall-cmd; then
                    sudo firewall-cmd --list-all
                else
                    sudo iptables -L -n -v
                fi
                read -rp "Press Enter to continue..."
                ;;
            back|"")
                return
                ;;
        esac
    done
}
