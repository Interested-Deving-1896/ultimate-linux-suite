#!/usr/bin/env bash
# ============================================================
# UNIFIED LINUX SUITE
# "Sovereign Optimization Protocol"
# ============================================================
# A comprehensive Linux system management platform combining
# OffTrack Suite and Ultimate Linux Suite functionality.
#
# License: MIT
# ============================================================

set -euo pipefail

# ============================================================
# INITIALIZATION
# ============================================================

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
export SUITE_ROOT="$(dirname "$SCRIPT_PATH")"

# Source all libraries
source "$SUITE_ROOT/lib/init.sh"

# ============================================================
# USAGE
# ============================================================

usage() {
    cat << EOF
${SUITE_NAME} v${SUITE_VERSION}
${SUITE_CODENAME}

Usage: $(basename "$0") [OPTIONS] COMMAND [ARGS]

Options:
  -h, --help        Show this help
  -v, --version     Show version
  -n, --dry-run     Simulate actions without making changes
  -y, --yes         Auto-confirm all prompts
  -d, --debug       Enable debug mode
  -q, --quiet       Suppress non-essential output

Commands:
  menu              Launch interactive TUI menu
  status            Show system status
  health            Full system health report

  Optimization:
    optimize        Run full system optimization (wizard)
    profile NAME    Apply optimization profile (gaming, server, laptop, etc.)
    ram             RAM optimization wizard
    cpu             CPU optimization wizard

  Applications:
    apps            Launch app installer menu
    install APP     Install specific application

  Hardware:
    hardware        Show hardware information
    macbook         MacBook-specific commands
    macbook fix-all Fix all MacBook hardware issues
    macbook status  Show MacBook driver status

  Security:
    security        Security lab menu
    vault           Encrypted vault commands
    firewall        Firewall configuration

  Pentest:
    pentest         Pentest tools installer

  System:
    update          Update system packages
    snapshot        Snapshot management
    bootstrap       System bootstrap wizard

Examples:
  $(basename "$0") menu                    # Launch TUI
  $(basename "$0") optimize                # Run optimization wizard
  $(basename "$0") profile gaming          # Apply gaming profile
  $(basename "$0") --dry-run optimize      # Preview optimization
  $(basename "$0") macbook fix-all         # Fix MacBook hardware

EOF
}

# ============================================================
# ARGUMENT PARSING
# ============================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "${SUITE_NAME} v${SUITE_VERSION}"
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -y|--yes)
                FORCE_YES=1
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=1
                set_log_level "debug"
                shift
                ;;
            -q|--quiet)
                LOG_LEVEL=$LOG_LEVEL_WARN
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit $EXIT_INVALID_ARGS
                ;;
            *)
                break
                ;;
        esac
    done

    COMMAND="${1:-menu}"
    shift || true
    ARGS=("$@")
}

# ============================================================
# COMMAND HANDLERS
# ============================================================

cmd_menu() {
    source "$SUITE_ROOT/menus/main_menu.sh"
    main_menu
}

cmd_status() {
    log_section "System Information"

    echo "OS: $OS_PRETTY_NAME"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo ""

    echo "RAM:"
    echo "  Total: $(get_total_ram_mb) MB"
    echo "  Available: $(get_available_ram_mb) MB"
    echo "  Profile: $(detect_ram_profile)"
    echo ""

    echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
    echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")"
    echo ""

    if is_macbook; then
        echo "MacBook: Yes ($MACBOOK_GENERATION)"
    else
        echo "MacBook: No"
    fi
    echo ""

    echo "TUI Backend: ${TUI_BACKEND:-none}"
    echo ""

    safety_list_snapshots
}

cmd_health() {
    system_health
}

cmd_optimize() {
    source "$SUITE_ROOT/modules/optimization/ram_optimizer.sh"
    source "$SUITE_ROOT/modules/optimization/cpu_optimizer.sh"
    source "$SUITE_ROOT/modules/optimization/profiles.sh"

    if [[ ${#ARGS[@]} -gt 0 ]]; then
        run_optimization "${ARGS[0]}"
    else
        ram_optimize_interactive
    fi
}

cmd_profile() {
    source "$SUITE_ROOT/modules/optimization/profiles.sh"

    if [[ ${#ARGS[@]} -gt 0 ]]; then
        apply_profile "${ARGS[0]}"
    else
        select_profile_interactive
    fi
}

cmd_ram() {
    source "$SUITE_ROOT/modules/optimization/ram_optimizer.sh"
    ram_optimize_interactive
}

cmd_cpu() {
    source "$SUITE_ROOT/modules/optimization/cpu_optimizer.sh"
    cpu_optimize_interactive
}

cmd_apps() {
    source "$SUITE_ROOT/modules/apps/app_installer.sh"
    app_installer_menu
}

cmd_hardware() {
    print_hardware_info
}

cmd_macbook() {
    if ! is_macbook; then
        log_warn "This system is not a MacBook"
        return 0
    fi

    local subcmd="${ARGS[0]:-status}"
    case "$subcmd" in
        fix-all|fixall)
            source "$SUITE_ROOT/drivers/macbook/fix_all.sh"
            require_root
            macbook_fix_all
            ;;
        status)
            print_macbook_info
            ;;
        *)
            log_error "Unknown macbook command: $subcmd"
            ;;
    esac
}

cmd_security() {
    source "$SUITE_ROOT/modules/security/lab_setup.sh"
    security_lab_menu 2>/dev/null || security_lab_setup
}

cmd_vault() {
    source "$SUITE_ROOT/modules/security/vault.sh"
    local subcmd="${ARGS[0]:-}"
    case "$subcmd" in
        create) vault_create ;;
        open)   vault_open ;;
        close)  vault_close ;;
        status) vault_status ;;
        *)      vault_status ;;
    esac
}

cmd_pentest() {
    source "$SUITE_ROOT/modules/pentest/tools_installer.sh"
    pentest_tools_menu 2>/dev/null || pentest_install_all
}

cmd_update() {
    source "$SUITE_ROOT/scripts/update-all.sh" 2>/dev/null || {
        log_info "Running system update..."
        pkg_update
        pkg_upgrade
        log_success "System updated"
    }
}

cmd_snapshot() {
    local subcmd="${ARGS[0]:-list}"
    case "$subcmd" in
        create)
            safety_checkpoint "${ARGS[1]:-manual}"
            ;;
        list)
            safety_list_snapshots
            ;;
        delete)
            if [[ ${#ARGS[@]} -gt 1 ]]; then
                safety_delete_snapshot "${ARGS[1]}"
            else
                log_error "Snapshot name required"
            fi
            ;;
        restore)
            if [[ ${#ARGS[@]} -gt 1 ]]; then
                safety_restore "${ARGS[1]}"
            else
                log_error "Snapshot name required"
            fi
            ;;
        *)
            log_error "Unknown snapshot command: $subcmd"
            ;;
    esac
}

cmd_bootstrap() {
    source "$SUITE_ROOT/modules/bootstrap/bootstrap.sh"
    bootstrap_wizard 2>/dev/null || bootstrap_menu
}

# ============================================================
# MAIN
# ============================================================

main() {
    parse_args "$@"

    # Initialize logging
    log_init

    case "$COMMAND" in
        menu)
            print_banner
            cmd_menu
            ;;
        status)
            print_banner
            cmd_status
            ;;
        health)
            cmd_health
            ;;
        optimize)
            cmd_optimize
            ;;
        profile)
            cmd_profile
            ;;
        ram)
            cmd_ram
            ;;
        cpu)
            cmd_cpu
            ;;
        apps|install)
            cmd_apps
            ;;
        hardware)
            cmd_hardware
            ;;
        macbook)
            cmd_macbook
            ;;
        security)
            cmd_security
            ;;
        vault)
            cmd_vault
            ;;
        firewall)
            source "$SUITE_ROOT/modules/security/firewall.sh"
            firewall_menu 2>/dev/null || firewall_status
            ;;
        pentest)
            cmd_pentest
            ;;
        update)
            cmd_update
            ;;
        snapshot)
            cmd_snapshot
            ;;
        bootstrap)
            cmd_bootstrap
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit $EXIT_INVALID_ARGS
            ;;
    esac
}

main "$@"
