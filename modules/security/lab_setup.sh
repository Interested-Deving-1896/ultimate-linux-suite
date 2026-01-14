#!/usr/bin/env bash
# OffTrack Suite - Security Lab Setup
# Complete security testing environment
# License: GPL-3.0-or-later

[[ -n "${_SECURITY_LAB_LOADED:-}" ]] && return 0
readonly _SECURITY_LAB_LOADED=1

# Security lab configuration
LAB_NETWORK_NAME="malware-lab"
LAB_NETWORK_SUBNET="192.168.200.0/24"
LAB_VAULT_DIR="${HOME}/.unified-suite/vault"

# Complete lab setup
security_lab_setup() {
    log_section "Security Lab Setup"

    require_root

    # Create snapshot
    safety_checkpoint "security-lab"

    # Step 1: KVM/Libvirt
    log_info "Step 1: Setting up KVM/libvirt..."
    source "$SUITE_ROOT/modules/security/kvm_setup.sh"
    kvm_setup

    # Step 2: Isolated network
    log_info "Step 2: Creating isolated network..."
    source "$SUITE_ROOT/modules/security/malware_lab.sh"
    malware_lab_setup

    # Step 3: Encrypted vault
    log_info "Step 3: Setting up encrypted vault..."
    source "$SUITE_ROOT/modules/security/vault.sh"
    vault_setup

    # Step 4: Firewall rules
    log_info "Step 4: Configuring firewall..."
    source "$SUITE_ROOT/modules/security/firewall.sh"
    firewall_setup

    log_success "Security lab setup complete"
    echo ""
    echo "Lab Components:"
    echo "  - KVM/libvirt: Ready for virtual machines"
    echo "  - Isolated Network: $LAB_NETWORK_NAME ($LAB_NETWORK_SUBNET)"
    echo "  - Encrypted Vault: $LAB_VAULT_DIR"
    echo "  - Firewall: Configured"
    echo ""
    echo "Next steps:"
    echo "  1. Download analysis VMs (e.g., REMnux, FlareVM)"
    echo "  2. Connect VMs to '$LAB_NETWORK_NAME' network"
    echo "  3. Mount vault: offtrack vault mount"
}

# Security lab menu
security_lab_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Security Lab" \
                "setup" "Full Lab Setup" \
                "kvm" "KVM/Libvirt Setup" \
                "network" "Isolated Network" \
                "vault" "Encrypted Vault" \
                "firewall" "Firewall Config" \
                "windows" "Windows VM Setup" \
                "status" "Lab Status" \
                "back" "Back")
        else
            echo ""
            echo "Security Lab Menu"
            echo "================="
            echo ""
            echo "  1) Full Lab Setup"
            echo "  2) KVM/Libvirt Setup"
            echo "  3) Isolated Network"
            echo "  4) Encrypted Vault"
            echo "  5) Firewall Config"
            echo "  6) Windows VM Setup"
            echo "  7) Lab Status"
            echo "  b) Back"
            echo ""
            read -rp "Select: " num
            case "$num" in
                1) choice="setup" ;;
                2) choice="kvm" ;;
                3) choice="network" ;;
                4) choice="vault" ;;
                5) choice="firewall" ;;
                6) choice="windows" ;;
                7) choice="status" ;;
                b|B) choice="back" ;;
            esac
        fi

        case "$choice" in
            setup)
                security_lab_setup
                read -rp "Press Enter to continue..."
                ;;
            kvm)
                source "$SUITE_ROOT/modules/security/kvm_setup.sh"
                kvm_setup
                read -rp "Press Enter to continue..."
                ;;
            network)
                source "$SUITE_ROOT/modules/security/malware_lab.sh"
                malware_lab_setup
                read -rp "Press Enter to continue..."
                ;;
            vault)
                source "$SUITE_ROOT/modules/security/vault.sh"
                vault_menu
                ;;
            firewall)
                source "$SUITE_ROOT/modules/security/firewall.sh"
                firewall_menu
                ;;
            windows)
                source "$SUITE_ROOT/modules/security/windows_vm.sh"
                windows_vm_menu
                ;;
            status)
                security_lab_status
                read -rp "Press Enter to continue..."
                ;;
            back|"")
                return
                ;;
        esac
    done
}

# Lab status check
security_lab_status() {
    log_section "Security Lab Status"

    echo "KVM/Libvirt:"
    if command_exists virsh; then
        echo "  Status: Installed"
        virsh list --all 2>/dev/null | head -10 || echo "  (not running or no VMs)"
    else
        echo "  Status: Not installed"
    fi
    echo ""

    echo "Isolated Network ($LAB_NETWORK_NAME):"
    if virsh net-info "$LAB_NETWORK_NAME" &>/dev/null; then
        echo "  Status: Active"
    else
        echo "  Status: Not configured"
    fi
    echo ""

    echo "Encrypted Vault:"
    if [[ -d "$LAB_VAULT_DIR" ]]; then
        echo "  Location: $LAB_VAULT_DIR"
        echo "  Status: Configured"
    else
        echo "  Status: Not configured"
    fi
    echo ""

    echo "Firewall:"
    if command_exists ufw; then
        ufw status 2>/dev/null | head -5
    elif command_exists firewall-cmd; then
        firewall-cmd --state 2>/dev/null || echo "  Status: Unknown"
    else
        echo "  Status: No firewall detected"
    fi
}
