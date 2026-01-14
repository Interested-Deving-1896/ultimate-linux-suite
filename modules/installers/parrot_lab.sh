#!/usr/bin/env bash
# OffTrack Suite - Parrot OS Hacking Lab Setup
# License: GPL-3.0-or-later

[[ -n "${_PARROT_LAB_LOADED:-}" ]] && return 0
readonly _PARROT_LAB_LOADED=1

parrot_lab_setup() {
    log_section "Parrot OS Hacking Lab Setup"

    # Check if running on Parrot
    if [[ "$OS_ID" != "parrot" ]]; then
        log_warn "This setup is optimized for Parrot OS"
        if ! tui_yesno "Continue?" "Continue on non-Parrot system?"; then
            return 1
        fi
    fi

    require_root

    # Create snapshot
    safety_checkpoint "parrot-lab"

    # Step 1: Update system
    log_info "Step 1: Updating system..."
    safe_exec apt-get update
    safe_exec apt-get full-upgrade -y

    # Step 2: Install full Parrot tools
    log_info "Step 2: Installing Parrot security tools..."
    safe_exec apt-get install -y parrot-tools-full 2>/dev/null || \
        safe_exec apt-get install -y parrot-tools 2>/dev/null || \
        log_warn "Parrot tools package not found"

    # Step 3: Setup KVM
    log_info "Step 3: Setting up KVM/libvirt..."
    source "$SUITE_ROOT/modules/security/kvm_setup.sh"
    kvm_setup

    # Step 4: Create isolated network
    log_info "Step 4: Creating isolated lab network..."
    source "$SUITE_ROOT/modules/security/malware_lab.sh"
    malware_lab_setup

    # Step 5: Setup encrypted vault
    log_info "Step 5: Setting up encrypted vault..."
    source "$SUITE_ROOT/modules/security/vault.sh"
    vault_setup

    # Step 6: Configure firewall
    log_info "Step 6: Configuring firewall..."
    source "$SUITE_ROOT/modules/security/firewall.sh"
    firewall_setup

    # Step 7: Install additional tools
    log_info "Step 7: Installing additional tools..."
    source "$SUITE_ROOT/modules/pentest/tools_installer.sh"
    pentest_install_all

    log_success "Parrot hacking lab setup complete"
    echo ""
    echo "Lab Components:"
    echo "  - Parrot security tools: Installed"
    echo "  - KVM/libvirt: Ready"
    echo "  - Isolated network: malware-lab"
    echo "  - Encrypted vault: ~/.unified-suite/vault"
    echo "  - Pentest tools: Installed"
}
