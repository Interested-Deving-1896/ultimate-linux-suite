#!/usr/bin/env bash
#
# main_menu.sh - Main Menu for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# Prevent multiple sourcing
[[ -n "${_MAIN_MENU_LOADED:-}" ]] && return 0
readonly _MAIN_MENU_LOADED=1

# Show system information
show_system_info() {
    log_section "System Information"

    printf "Operating System:\n"
    print_os_info
    printf "\n"

    printf "Hardware:\n"
    print_hardware_summary
    printf "\n"

    printf "Form Factor: %s\n" "$(get_form_factor)"

    pause
}

# Show welcome screen
show_welcome() {
    clear_screen
    printf "\n"
    center_text "╔══════════════════════════════════════════╗"
    center_text "║     ULTIMATE LINUX SUITE v$SUITE_VERSION       ║"
    center_text "╚══════════════════════════════════════════╝"
    printf "\n"

    center_text "System: ${OS_PRETTY:-$OS_ID}"
    center_text "CPU: $CPU_MODEL"
    center_text "RAM: ${RAM_TOTAL_GB}GB | GPU: $GPU_VENDOR"
    printf "\n"
    log_divider
    printf "\n"
}

# Main menu loop
run_main_menu() {
    while true; do
        show_welcome

        # Show queue count if not empty
        local queue_count
        queue_count=$(queue_count)
        local queue_label=""
        [[ "$queue_count" -gt 0 ]] && queue_label=" ($queue_count pending)"

        printf "  1) Applications      - Install software packages\n"
        printf "  2) Drivers           - GPU, WiFi, and hardware drivers\n"
        printf "  3) Optimization      - System performance tuning\n"
        printf "  4) Recovery          - Repair and maintenance tools\n"
        printf "  5) Services          - Manage system services\n"
        printf "  6) Profiles          - Quick setup profiles\n"
        printf "  7) Queue%s   - View/execute pending actions\n" "$queue_label"
        printf "  8) System Info       - View hardware details\n"
        printf "  0) Exit\n"
        printf "\n"
        printf "Enter choice: "
        read -r choice

        case "$choice" in
            1)
                apps_main
                ;;
            2)
                drivers_main
                ;;
            3)
                optimize_main
                ;;
            4)
                recovery_main
                ;;
            5)
                services_main
                ;;
            6)
                profiles_main
                ;;
            7)
                queue_menu
                ;;
            8)
                show_system_info
                ;;
            0|q|Q|exit)
                # Check for pending queue items
                if ! queue_is_empty; then
                    log_warn "You have $(queue_count) pending actions in the queue"
                    if confirm "Execute queue before exit?"; then
                        queue_execute
                    elif ! confirm "Discard queued actions and exit?"; then
                        continue
                    fi
                fi
                log_info "Thank you for using $SUITE_NAME"
                exit 0
                ;;
            *)
                log_warn "Invalid choice: $choice"
                sleep 1
                ;;
        esac
    done
}
