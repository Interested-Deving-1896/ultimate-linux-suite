#!/usr/bin/env bash
# OffTrack Suite - Encrypted Vault
# LUKS-encrypted container for sensitive data
# License: GPL-3.0-or-later

[[ -n "${_VAULT_LOADED:-}" ]] && return 0
readonly _VAULT_LOADED=1

VAULT_DIR="${VAULT_DIR:-${HOME}/.unified-suite/vault}"
VAULT_FILE="${VAULT_DIR}/vault.img"
VAULT_SIZE="${VAULT_SIZE:-1G}"
VAULT_MOUNT="${VAULT_DIR}/mount"
VAULT_MAPPER="offtrack-vault"

# Setup encrypted vault
vault_setup() {
    log_section "Encrypted Vault Setup"

    # Check for cryptsetup
    if ! command_exists cryptsetup; then
        log_info "Installing cryptsetup..."
        pkg_install cryptsetup
    fi

    # Create vault directory
    mkdir -p "$VAULT_DIR"
    mkdir -p "$VAULT_MOUNT"

    # Check if vault already exists
    if [[ -f "$VAULT_FILE" ]]; then
        log_info "Vault already exists at: $VAULT_FILE"
        vault_status
        return 0
    fi

    # Get vault size
    local size
    if tui_available; then
        size=$(tui_inputbox "Vault Size" "Enter vault size (e.g., 1G, 500M):" "$VAULT_SIZE")
    else
        read -rp "Enter vault size (default: $VAULT_SIZE): " size
        size="${size:-$VAULT_SIZE}"
    fi

    log_info "Creating vault container: $VAULT_FILE ($size)"

    # Create sparse file
    if [[ $DRY_RUN -eq 0 ]]; then
        truncate -s "$size" "$VAULT_FILE"

        # Setup LUKS
        log_info "Setting up LUKS encryption..."
        echo "You will be prompted to create a password for the vault."
        sudo cryptsetup luksFormat "$VAULT_FILE"

        # Open vault to format filesystem
        log_info "Opening vault to create filesystem..."
        sudo cryptsetup open "$VAULT_FILE" "$VAULT_MAPPER"

        # Create filesystem
        sudo mkfs.ext4 -L "OffTrack-Vault" "/dev/mapper/$VAULT_MAPPER"

        # Close vault
        sudo cryptsetup close "$VAULT_MAPPER"

        # Set permissions
        chmod 600 "$VAULT_FILE"
    else
        log_info "[DRY-RUN] Would create encrypted vault"
    fi

    log_success "Encrypted vault created"
    echo ""
    echo "Vault Details:"
    echo "  Location: $VAULT_FILE"
    echo "  Size: $size"
    echo "  Mount Point: $VAULT_MOUNT"
    echo ""
    echo "Commands:"
    echo "  Mount:   offtrack vault mount"
    echo "  Unmount: offtrack vault unmount"
}

# Mount vault
vault_mount() {
    log_info "Mounting encrypted vault..."

    [[ -f "$VAULT_FILE" ]] || {
        log_error "Vault not found: $VAULT_FILE"
        log_info "Run 'offtrack security vault' to create a vault"
        return 1
    }

    # Check if already mounted
    if [[ -e "/dev/mapper/$VAULT_MAPPER" ]]; then
        log_info "Vault is already open"
        if mountpoint -q "$VAULT_MOUNT"; then
            log_info "Vault is mounted at: $VAULT_MOUNT"
            return 0
        fi
    fi

    # Open LUKS container
    sudo cryptsetup open "$VAULT_FILE" "$VAULT_MAPPER"

    # Mount
    mkdir -p "$VAULT_MOUNT"
    sudo mount "/dev/mapper/$VAULT_MAPPER" "$VAULT_MOUNT"

    # Fix ownership
    local user="${SUDO_USER:-$USER}"
    sudo chown -R "$user:$user" "$VAULT_MOUNT"

    log_success "Vault mounted at: $VAULT_MOUNT"
}

# Unmount vault
vault_unmount() {
    log_info "Unmounting encrypted vault..."

    # Unmount filesystem
    if mountpoint -q "$VAULT_MOUNT" 2>/dev/null; then
        sudo umount "$VAULT_MOUNT"
    fi

    # Close LUKS container
    if [[ -e "/dev/mapper/$VAULT_MAPPER" ]]; then
        sudo cryptsetup close "$VAULT_MAPPER"
    fi

    log_success "Vault unmounted and secured"
}

# Vault status
vault_status() {
    echo "Vault Status:"
    echo ""
    echo "  File: $VAULT_FILE"

    if [[ -f "$VAULT_FILE" ]]; then
        echo "  Size: $(du -h "$VAULT_FILE" | cut -f1)"
        echo "  Exists: Yes"

        if [[ -e "/dev/mapper/$VAULT_MAPPER" ]]; then
            echo "  LUKS: Open"
            if mountpoint -q "$VAULT_MOUNT" 2>/dev/null; then
                echo "  Mounted: Yes ($VAULT_MOUNT)"
                echo "  Usage: $(df -h "$VAULT_MOUNT" | awk 'NR==2{print $3 " / " $2 " (" $5 " used)"}')"
            else
                echo "  Mounted: No"
            fi
        else
            echo "  LUKS: Closed"
            echo "  Mounted: No"
        fi
    else
        echo "  Exists: No (run 'offtrack security vault' to create)"
    fi
}

# Delete vault (with confirmation)
vault_delete() {
    log_warn "This will permanently delete the encrypted vault!"

    if ! confirm "Are you sure you want to delete the vault?"; then
        log_info "Vault deletion cancelled"
        return 0
    fi

    # Unmount first
    vault_unmount 2>/dev/null || true

    # Delete file
    if [[ -f "$VAULT_FILE" ]]; then
        rm -f "$VAULT_FILE"
        log_success "Vault deleted"
    else
        log_info "Vault file not found"
    fi
}

# Vault menu
vault_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Encrypted Vault" \
                "status" "Vault Status" \
                "create" "Create Vault" \
                "mount" "Mount Vault" \
                "unmount" "Unmount Vault" \
                "delete" "Delete Vault" \
                "back" "Back")
        else
            echo ""
            echo "Encrypted Vault Menu"
            echo "===================="
            echo ""
            echo "  1) Vault Status"
            echo "  2) Create Vault"
            echo "  3) Mount Vault"
            echo "  4) Unmount Vault"
            echo "  5) Delete Vault"
            echo "  b) Back"
            echo ""
            read -rp "Select: " num
            case "$num" in
                1) choice="status" ;;
                2) choice="create" ;;
                3) choice="mount" ;;
                4) choice="unmount" ;;
                5) choice="delete" ;;
                b|B) choice="back" ;;
            esac
        fi

        case "$choice" in
            status)
                vault_status
                read -rp "Press Enter to continue..."
                ;;
            create)
                vault_setup
                read -rp "Press Enter to continue..."
                ;;
            mount)
                vault_mount
                read -rp "Press Enter to continue..."
                ;;
            unmount)
                vault_unmount
                read -rp "Press Enter to continue..."
                ;;
            delete)
                vault_delete
                read -rp "Press Enter to continue..."
                ;;
            back|"")
                return
                ;;
        esac
    done
}
