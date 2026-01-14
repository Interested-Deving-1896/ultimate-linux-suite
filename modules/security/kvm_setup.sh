#!/usr/bin/env bash
# OffTrack Suite - KVM/Libvirt Setup
# License: GPL-3.0-or-later

[[ -n "${_KVM_SETUP_LOADED:-}" ]] && return 0
readonly _KVM_SETUP_LOADED=1

# Install and configure KVM/libvirt
kvm_setup() {
    log_section "KVM/Libvirt Virtualization Setup"

    require_root

    # Check CPU virtualization support
    if ! grep -qE "vmx|svm" /proc/cpuinfo; then
        log_error "CPU does not support hardware virtualization (VT-x/AMD-V)"
        log_info "Enable virtualization in BIOS/UEFI settings"
        return 1
    fi

    log_info "CPU virtualization support: OK"

    # Install packages
    log_info "Installing virtualization packages..."
    case "$OS_FAMILY" in
        fedora)
            pkg_install @virtualization virt-manager virt-viewer libguestfs-tools
            ;;
        debian)
            pkg_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
                virt-manager virt-viewer virtinst libguestfs-tools
            ;;
        arch)
            pkg_install qemu-full libvirt virt-manager virt-viewer dnsmasq \
                bridge-utils openbsd-netcat libguestfs
            ;;
    esac

    # Enable and start libvirtd
    log_info "Enabling libvirt service..."
    safe_exec systemctl enable --now libvirtd.service

    # Add user to libvirt group
    local user="${SUDO_USER:-$USER}"
    if [[ -n "$user" ]] && [[ "$user" != "root" ]]; then
        safe_exec usermod -aG libvirt "$user"
        safe_exec usermod -aG kvm "$user"
        log_info "Added $user to libvirt and kvm groups"
    fi

    # Enable default network
    log_info "Enabling default network..."
    safe_exec virsh net-autostart default 2>/dev/null || true
    safe_exec virsh net-start default 2>/dev/null || true

    # Verify setup
    log_info "Verifying KVM setup..."
    if virsh list --all &>/dev/null; then
        log_success "KVM/libvirt is working"
    else
        log_warn "KVM setup may require re-login for group changes"
    fi

    log_success "KVM/libvirt setup complete"
    log_info "Log out and back in for group membership changes"
}

# Check KVM status
kvm_status() {
    echo "KVM/Libvirt Status:"
    echo ""

    # Check service
    if systemctl is-active libvirtd &>/dev/null; then
        echo "Service: running"
    else
        echo "Service: not running"
    fi

    # Check networks
    echo ""
    echo "Networks:"
    virsh net-list --all 2>/dev/null || echo "  Unable to list networks"

    # Check VMs
    echo ""
    echo "Virtual Machines:"
    virsh list --all 2>/dev/null || echo "  Unable to list VMs"
}
