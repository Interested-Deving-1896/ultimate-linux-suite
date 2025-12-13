#!/usr/bin/env bash
#
# setup_profiles.sh - Profile Setup Module for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# Prevent multiple sourcing
[[ -n "${_PROFILES_MODULE_LOADED:-}" ]] && return 0
readonly _PROFILES_MODULE_LOADED=1

# Profile definitions
declare -A PROFILES=(
    [workstation]="General desktop workstation with productivity apps"
    [gaming]="Gaming-optimized setup with Steam, Lutris, drivers"
    [developer]="Development environment with common tools"
    [pentest]="Security/penetration testing tools"
    [minimal]="Minimal essential utilities only"
    [server]="Server-oriented packages and settings"
)

# Get recommended profile based on hardware
get_recommended_profile() {
    local form_factor
    form_factor=$(get_form_factor)

    case "$form_factor" in
        laptop)
            echo "workstation"
            ;;
        server)
            echo "server"
            ;;
        *)
            # Check GPU for gaming potential
            if [[ "$GPU_VENDOR" == "nvidia" ]] || [[ "$GPU_VENDOR" == "amd" ]]; then
                if [[ "$RAM_TOTAL_GB" -ge 16 ]]; then
                    echo "gaming"
                    return
                fi
            fi
            echo "workstation"
            ;;
    esac
}

# Show profile info
show_profile_info() {
    local profile="$1"
    local preset_file="$SUITE_ROOT/configs/app_presets/${profile}.conf"

    log_section "Profile: $profile"

    printf "%s\n\n" "${PROFILES[$profile]:-No description}"

    if [[ -f "$preset_file" ]]; then
        printf "Packages included:\n"
        grep -v "^#" "$preset_file" | grep -v "^$" | while read -r pkg; do
            printf "  - %s\n" "$pkg"
        done
    else
        printf "No package preset file found.\n"
    fi
}

# Apply complete profile
apply_profile() {
    local profile="$1"

    log_section "Applying Profile: $profile"

    # Install apps from preset
    local preset_file="$SUITE_ROOT/configs/app_presets/${profile}.conf"
    if [[ -f "$preset_file" ]]; then
        log_info "Installing profile packages..."

        local packages=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            local mapped
            mapped=$(pkg_name "$line")
            packages="$packages $mapped"
        done < "$preset_file"

        if [[ -n "$packages" ]]; then
            # shellcheck disable=SC2086
            pkg_install $packages
        fi
    fi

    # Apply profile-specific optimizations
    case "$profile" in
        gaming)
            log_info "Applying gaming optimizations..."
            apply_sysctl "vm.swappiness" "10" 2>/dev/null || true
            apply_sysctl "vm.vfs_cache_pressure" "50" 2>/dev/null || true
            ;;
        server)
            log_info "Applying server optimizations..."
            apply_sysctl "vm.swappiness" "30" 2>/dev/null || true
            apply_sysctl "fs.file-max" "2097152" 2>/dev/null || true
            ;;
        workstation)
            log_info "Applying workstation optimizations..."
            apply_sysctl "vm.swappiness" "20" 2>/dev/null || true
            ;;
    esac

    log_success "Profile $profile applied"
}

# Interactive profile wizard
profile_wizard() {
    log_section "Profile Setup Wizard"

    printf "This wizard will help set up your system.\n\n"

    # Show detected hardware
    printf "Detected System:\n"
    printf "  CPU: %s\n" "$CPU_MODEL"
    printf "  GPU: %s (%s)\n" "$GPU_MODEL" "$GPU_VENDOR"
    printf "  RAM: %sGB\n" "$RAM_TOTAL_GB"
    printf "  Form: %s\n\n" "$(get_form_factor)"

    # Get recommendation
    local recommended
    recommended=$(get_recommended_profile)
    printf "Recommended profile: %s\n\n" "$recommended"

    # Let user choose
    simple_menu "Select Profile" \
        "Workstation (general desktop)" \
        "Gaming (optimized for games)" \
        "Developer (dev tools)" \
        "Pentest (security tools)" \
        "Server (server setup)" \
        "Minimal (essentials only)" \
        "Show profile details first"

    local selected_profile=""
    case "$MENU_CHOICE" in
        1) selected_profile="workstation" ;;
        2) selected_profile="gaming" ;;
        3) selected_profile="developer" ;;
        4) selected_profile="pentest" ;;
        5) selected_profile="server" ;;
        6) selected_profile="minimal" ;;
        7)
            # Show details for each
            for profile in workstation gaming developer pentest server minimal; do
                show_profile_info "$profile"
                pause
            done
            profile_wizard  # Recurse
            return
            ;;
        0) return 0 ;;
    esac

    if [[ -n "$selected_profile" ]]; then
        show_profile_info "$selected_profile"

        if confirm "Apply this profile?"; then
            apply_profile "$selected_profile"
            log_success "Profile setup complete!"
        fi
    fi

    pause
}

# Module initialization
profiles_init() {
    log_debug "Profiles module initialized"
}

# Module main entry point
profiles_main() {
    while true; do
        simple_menu "Profile Setup" \
            "Run Setup Wizard" \
            "Apply Workstation Profile" \
            "Apply Gaming Profile" \
            "Apply Developer Profile" \
            "Apply Server Profile" \
            "View Profile Details"

        case "$MENU_CHOICE" in
            1) profile_wizard ;;
            2)
                if confirm "Apply workstation profile?"; then
                    apply_profile "workstation"
                    pause
                fi
                ;;
            3)
                if confirm "Apply gaming profile?"; then
                    apply_profile "gaming"
                    pause
                fi
                ;;
            4)
                if confirm "Apply developer profile?"; then
                    apply_profile "developer"
                    pause
                fi
                ;;
            5)
                if confirm "Apply server profile?"; then
                    apply_profile "server"
                    pause
                fi
                ;;
            6)
                simple_menu "Select Profile to View" \
                    "Workstation" "Gaming" "Developer" "Pentest" "Server" "Minimal"
                case "$MENU_CHOICE" in
                    1) show_profile_info "workstation"; pause ;;
                    2) show_profile_info "gaming"; pause ;;
                    3) show_profile_info "developer"; pause ;;
                    4) show_profile_info "pentest"; pause ;;
                    5) show_profile_info "server"; pause ;;
                    6) show_profile_info "minimal"; pause ;;
                esac
                ;;
            0) return 0 ;;
        esac
    done
}
