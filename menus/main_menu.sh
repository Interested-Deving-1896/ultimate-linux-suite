#!/usr/bin/env bash
# Unified Suite - Main Menu
# License: GPL-3.0-or-later

[[ -n "${_MENU_MAIN_LOADED:-}" ]] && return 0
readonly _MENU_MAIN_LOADED=1

# Main menu function
main_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Unified Suite - Main Menu" \
                "optimize" "System Optimization" \
                "profile" "Apply Optimization Profile" \
                "apps" "Application Installer" \
                "hardware" "Hardware Information" \
                "macbook" "MacBook Support" \
                "security" "Security Lab" \
                "pentest" "Pentest Tools" \
                "bootstrap" "System Bootstrap" \
                "update" "System Update" \
                "snapshot" "Snapshot Management" \
                "status" "System Status" \
                "health" "Health Check" \
                "quit" "Exit")
        else
            echo ""
            echo "Unified Suite - Main Menu"
            echo "========================="
            echo ""
            echo "  1) System Optimization"
            echo "  2) Apply Optimization Profile"
            echo "  3) Application Installer"
            echo "  4) Hardware Information"
            echo "  5) MacBook Support"
            echo "  6) Security Lab"
            echo "  7) Pentest Tools"
            echo "  8) System Bootstrap"
            echo "  9) System Update"
            echo " 10) Snapshot Management"
            echo " 11) System Status"
            echo " 12) Health Check"
            echo "  q) Exit"
            echo ""
            read -rp "Select: " num

            case "$num" in
                1)  choice="optimize" ;;
                2)  choice="profile" ;;
                3)  choice="apps" ;;
                4)  choice="hardware" ;;
                5)  choice="macbook" ;;
                6)  choice="security" ;;
                7)  choice="pentest" ;;
                8)  choice="bootstrap" ;;
                9)  choice="update" ;;
                10) choice="snapshot" ;;
                11) choice="status" ;;
                12) choice="health" ;;
                q|Q|quit|exit) choice="quit" ;;
            esac
        fi

        case "$choice" in
            optimize)
                source "$SUITE_ROOT/modules/optimization/ram_optimizer.sh"
                ram_optimize_interactive
                ;;
            profile)
                source "$SUITE_ROOT/modules/optimization/profiles.sh"
                select_profile_interactive
                ;;
            apps)
                source "$SUITE_ROOT/modules/apps/app_installer.sh"
                app_installer_menu
                ;;
            hardware)
                print_hardware_info
                read -rp "Press Enter to continue..."
                ;;
            macbook)
                if is_macbook; then
                    print_macbook_info
                else
                    log_warn "This system is not a MacBook"
                fi
                read -rp "Press Enter to continue..."
                ;;
            security)
                source "$SUITE_ROOT/modules/security/lab_setup.sh" 2>/dev/null || true
                if declare -F security_lab_menu &>/dev/null; then
                    security_lab_menu
                else
                    log_info "Security lab features require root privileges"
                fi
                ;;
            pentest)
                source "$SUITE_ROOT/modules/pentest/tools_installer.sh" 2>/dev/null || true
                if declare -F pentest_tools_menu &>/dev/null; then
                    pentest_tools_menu
                else
                    log_info "Pentest tools installer"
                fi
                ;;
            bootstrap)
                source "$SUITE_ROOT/modules/bootstrap/bootstrap.sh" 2>/dev/null || true
                if declare -F bootstrap_menu &>/dev/null; then
                    bootstrap_menu
                else
                    log_info "Bootstrap wizard"
                fi
                ;;
            update)
                log_info "Running system update..."
                pkg_update
                pkg_upgrade
                log_success "Update complete"
                read -rp "Press Enter to continue..."
                ;;
            snapshot)
                snapshot_menu
                ;;
            status)
                cmd_status
                read -rp "Press Enter to continue..."
                ;;
            health)
                system_health
                read -rp "Press Enter to continue..."
                ;;
            quit|"")
                log_info "Goodbye!"
                exit 0
                ;;
        esac
    done
}

# Snapshot submenu
snapshot_menu() {
    while true; do
        local choice=""

        if tui_available; then
            choice=$(tui_menu "Snapshot Management" \
                "list" "List Snapshots" \
                "create" "Create Snapshot" \
                "delete" "Delete Snapshot" \
                "restore" "Restore Snapshot" \
                "back" "Back to Main Menu")
        else
            echo ""
            echo "Snapshot Management"
            echo "==================="
            echo ""
            echo "  1) List Snapshots"
            echo "  2) Create Snapshot"
            echo "  3) Delete Snapshot"
            echo "  4) Restore Snapshot"
            echo "  b) Back"
            echo ""
            read -rp "Select: " num

            case "$num" in
                1) choice="list" ;;
                2) choice="create" ;;
                3) choice="delete" ;;
                4) choice="restore" ;;
                b|B|back) choice="back" ;;
            esac
        fi

        case "$choice" in
            list)
                safety_list_snapshots
                read -rp "Press Enter to continue..."
                ;;
            create)
                read -rp "Snapshot name: " name
                safety_checkpoint "${name:-manual}"
                read -rp "Press Enter to continue..."
                ;;
            delete)
                safety_list_snapshots
                read -rp "Snapshot to delete: " name
                [[ -n "$name" ]] && safety_delete_snapshot "$name"
                read -rp "Press Enter to continue..."
                ;;
            restore)
                safety_list_snapshots
                read -rp "Snapshot to restore: " name
                [[ -n "$name" ]] && safety_restore "$name"
                read -rp "Press Enter to continue..."
                ;;
            back|"")
                return
                ;;
        esac
    done
}

# Stub for cmd_status (used by main_menu)
cmd_status() {
    log_section "System Information"
    echo "OS: $OS_PRETTY_NAME"
    echo "Kernel: $(uname -r)"
    echo "RAM: $(get_total_ram_mb) MB ($(detect_ram_profile))"
    echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
    echo ""
    safety_list_snapshots
}
