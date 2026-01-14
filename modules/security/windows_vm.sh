#!/usr/bin/env bash
# OffTrack Suite - Windows VM Lab Setup
# Creates hardened Windows VM for malware analysis
# License: GPL-3.0-or-later

[[ -n "${_WINDOWS_VM_LOADED:-}" ]] && return 0
readonly _WINDOWS_VM_LOADED=1

WINDOWS_VM_NAME="windows-lab"
WINDOWS_VM_DISK_SIZE="60G"
WINDOWS_VM_RAM="4096"
WINDOWS_VM_CPUS="2"
WINDOWS_VM_DIR="${HOME}/.unified-suite/vms"

# Setup Windows VM for malware analysis
windows_vm_setup() {
    log_section "Windows VM Lab Setup"

    require_root

    # Check prerequisites
    if ! command_exists virsh; then
        log_error "libvirt not installed. Run KVM setup first."
        return 1
    fi

    if ! virsh list --all &>/dev/null; then
        log_error "Cannot connect to libvirt. Ensure libvirtd is running."
        return 1
    fi

    # Create VM directory
    mkdir -p "$WINDOWS_VM_DIR"

    # Check if VM already exists
    if virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        log_info "VM '$WINDOWS_VM_NAME' already exists"
        windows_vm_status
        return 0
    fi

    # Get Windows ISO
    local iso_path
    if tui_available; then
        iso_path=$(tui_inputbox "Windows ISO" "Enter path to Windows ISO file:" "$HOME/Downloads/Win11.iso")
    else
        read -rp "Enter path to Windows ISO file: " iso_path
    fi

    if [[ ! -f "$iso_path" ]]; then
        log_error "ISO file not found: $iso_path"
        echo ""
        echo "Download Windows 11 evaluation ISO from:"
        echo "  https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise"
        return 1
    fi

    # Get virtio drivers ISO (optional)
    local virtio_iso=""
    if [[ -f "/usr/share/virtio-win/virtio-win.iso" ]]; then
        virtio_iso="/usr/share/virtio-win/virtio-win.iso"
        log_info "Found virtio drivers ISO"
    elif [[ -f "$HOME/Downloads/virtio-win.iso" ]]; then
        virtio_iso="$HOME/Downloads/virtio-win.iso"
    fi

    # Create disk
    local disk_path="$WINDOWS_VM_DIR/${WINDOWS_VM_NAME}.qcow2"
    log_info "Creating virtual disk: $disk_path ($WINDOWS_VM_DISK_SIZE)"

    if [[ $DRY_RUN -eq 0 ]]; then
        qemu-img create -f qcow2 "$disk_path" "$WINDOWS_VM_DISK_SIZE"
    else
        log_info "[DRY-RUN] Would create disk: $disk_path"
    fi

    # Build virt-install command
    local install_cmd=(
        virt-install
        --name "$WINDOWS_VM_NAME"
        --ram "$WINDOWS_VM_RAM"
        --vcpus "$WINDOWS_VM_CPUS"
        --disk "path=$disk_path,format=qcow2,bus=virtio"
        --cdrom "$iso_path"
        --os-variant "win11"
        --network "network=${LAB_NETWORK_NAME:-malware-lab},model=virtio"
        --graphics "spice,listen=127.0.0.1"
        --video "qxl"
        --boot "uefi"
        --features "kvm_hidden=on"
        --cpu "host-passthrough"
        --noautoconsole
    )

    # Add virtio drivers if available
    if [[ -n "$virtio_iso" ]]; then
        install_cmd+=(--disk "path=$virtio_iso,device=cdrom")
    fi

    # Create the VM
    log_info "Creating Windows VM..."
    log_info "This will start the installation process."

    if [[ $DRY_RUN -eq 0 ]]; then
        "${install_cmd[@]}"
    else
        log_info "[DRY-RUN] Would run: ${install_cmd[*]}"
    fi

    log_success "Windows VM created"
    echo ""
    echo "VM Details:"
    echo "  Name: $WINDOWS_VM_NAME"
    echo "  Disk: $disk_path"
    echo "  RAM: ${WINDOWS_VM_RAM}MB"
    echo "  CPUs: $WINDOWS_VM_CPUS"
    echo "  Network: ${LAB_NETWORK_NAME:-malware-lab} (isolated)"
    echo ""
    echo "To connect to the VM:"
    echo "  virt-manager (graphical)"
    echo "  virt-viewer $WINDOWS_VM_NAME"
    echo ""
    echo "Security Notes:"
    echo "  - VM is on isolated network (no internet)"
    echo "  - Take snapshots before analysis"
    echo "  - Do not enable shared folders for malware"
}

# Start Windows VM
windows_vm_start() {
    if ! virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        log_error "VM '$WINDOWS_VM_NAME' does not exist"
        return 1
    fi

    log_info "Starting Windows VM..."
    safe_exec virsh start "$WINDOWS_VM_NAME"
    log_success "VM started"
}

# Stop Windows VM
windows_vm_stop() {
    if ! virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        log_error "VM '$WINDOWS_VM_NAME' does not exist"
        return 1
    fi

    log_info "Stopping Windows VM..."
    safe_exec virsh shutdown "$WINDOWS_VM_NAME"
    log_success "VM shutdown initiated"
}

# Force stop Windows VM
windows_vm_destroy() {
    if ! virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        log_error "VM '$WINDOWS_VM_NAME' does not exist"
        return 1
    fi

    log_warn "Force stopping Windows VM..."
    safe_exec virsh destroy "$WINDOWS_VM_NAME"
    log_success "VM force stopped"
}

# Create VM snapshot
windows_vm_snapshot() {
    local snap_name="${1:-analysis-$(date +%Y%m%d-%H%M%S)}"

    if ! virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        log_error "VM '$WINDOWS_VM_NAME' does not exist"
        return 1
    fi

    log_info "Creating snapshot: $snap_name"
    safe_exec virsh snapshot-create-as "$WINDOWS_VM_NAME" "$snap_name" \
        --description "OffTrack analysis snapshot"
    log_success "Snapshot created: $snap_name"
}

# Revert to snapshot
windows_vm_revert() {
    local snap_name="$1"

    if [[ -z "$snap_name" ]]; then
        log_error "Snapshot name required"
        echo "Available snapshots:"
        virsh snapshot-list "$WINDOWS_VM_NAME" 2>/dev/null
        return 1
    fi

    log_info "Reverting to snapshot: $snap_name"
    safe_exec virsh snapshot-revert "$WINDOWS_VM_NAME" "$snap_name"
    log_success "Reverted to snapshot: $snap_name"
}

# Check VM status
windows_vm_status() {
    echo "Windows VM Status:"
    echo ""

    if virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        echo "  VM exists: Yes"
        local state=$(virsh domstate "$WINDOWS_VM_NAME" 2>/dev/null)
        echo "  State: $state"

        echo ""
        echo "  Snapshots:"
        virsh snapshot-list "$WINDOWS_VM_NAME" 2>/dev/null | head -10 || echo "    (none)"

        echo ""
        echo "  Network:"
        virsh domifaddr "$WINDOWS_VM_NAME" 2>/dev/null || echo "    (not available)"
    else
        echo "  VM exists: No"
        echo "  Run 'offtrack security windows-vm' to create"
    fi
}

# Delete Windows VM
windows_vm_delete() {
    if ! virsh dominfo "$WINDOWS_VM_NAME" &>/dev/null; then
        log_info "VM '$WINDOWS_VM_NAME' does not exist"
        return 0
    fi

    log_warn "This will permanently delete the Windows VM!"

    if ! confirm "Are you sure you want to delete the VM and all snapshots?"; then
        log_info "Deletion cancelled"
        return 0
    fi

    # Stop if running
    virsh destroy "$WINDOWS_VM_NAME" 2>/dev/null || true

    # Delete snapshots
    for snap in $(virsh snapshot-list "$WINDOWS_VM_NAME" --name 2>/dev/null); do
        virsh snapshot-delete "$WINDOWS_VM_NAME" "$snap" 2>/dev/null || true
    done

    # Undefine VM
    virsh undefine "$WINDOWS_VM_NAME" --remove-all-storage --nvram 2>/dev/null || \
        virsh undefine "$WINDOWS_VM_NAME" --remove-all-storage 2>/dev/null || \
        virsh undefine "$WINDOWS_VM_NAME" 2>/dev/null

    log_success "Windows VM deleted"
}

# Windows VM menu
windows_vm_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Windows VM Lab" \
                "status" "VM Status" \
                "setup" "Create VM" \
                "start" "Start VM" \
                "stop" "Stop VM" \
                "snapshot" "Create Snapshot" \
                "revert" "Revert Snapshot" \
                "console" "Open Console" \
                "delete" "Delete VM" \
                "back" "Back")
        else
            echo ""
            echo "Windows VM Menu"
            echo "==============="
            echo ""
            echo "  1) VM Status"
            echo "  2) Create VM"
            echo "  3) Start VM"
            echo "  4) Stop VM"
            echo "  5) Create Snapshot"
            echo "  6) Revert Snapshot"
            echo "  7) Open Console"
            echo "  8) Delete VM"
            echo "  b) Back"
            echo ""
            read -rp "Select: " num
            case "$num" in
                1) choice="status" ;;
                2) choice="setup" ;;
                3) choice="start" ;;
                4) choice="stop" ;;
                5) choice="snapshot" ;;
                6) choice="revert" ;;
                7) choice="console" ;;
                8) choice="delete" ;;
                b|B) choice="back" ;;
            esac
        fi

        case "$choice" in
            status)
                windows_vm_status
                read -rp "Press Enter to continue..."
                ;;
            setup)
                windows_vm_setup
                read -rp "Press Enter to continue..."
                ;;
            start)
                windows_vm_start
                read -rp "Press Enter to continue..."
                ;;
            stop)
                windows_vm_stop
                read -rp "Press Enter to continue..."
                ;;
            snapshot)
                read -rp "Snapshot name (optional): " snap_name
                windows_vm_snapshot "$snap_name"
                read -rp "Press Enter to continue..."
                ;;
            revert)
                echo "Available snapshots:"
                virsh snapshot-list "$WINDOWS_VM_NAME" 2>/dev/null || echo "  (none)"
                read -rp "Snapshot to revert to: " snap_name
                [[ -n "$snap_name" ]] && windows_vm_revert "$snap_name"
                read -rp "Press Enter to continue..."
                ;;
            console)
                if command_exists virt-viewer; then
                    virt-viewer "$WINDOWS_VM_NAME" &
                    log_info "Opening virt-viewer..."
                else
                    log_error "virt-viewer not installed"
                fi
                read -rp "Press Enter to continue..."
                ;;
            delete)
                windows_vm_delete
                read -rp "Press Enter to continue..."
                ;;
            back|"")
                return
                ;;
        esac
    done
}
