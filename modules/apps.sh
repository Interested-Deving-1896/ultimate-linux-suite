#!/usr/bin/env bash
#
# apps.sh - Application Installation Module for Ultimate Linux Suite
#
# Comprehensive application management with queue-based installation
#

# Prevent multiple sourcing
[[ -n "${_APPS_MODULE_LOADED:-}" ]] && return 0
readonly _APPS_MODULE_LOADED=1

# Source app database
source "$SUITE_ROOT/apps/database.sh"

# ============================================================================
# Category Browser
# ============================================================================

# Browse and select apps by category
browse_category() {
    local category="$1"

    while true; do
        clear_screen
        log_section "Category: ${category^}"

        # Get apps in this category
        local apps=()
        local i=1
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            apps+=("$entry")

            local name desc installed=""
            name=$(echo "$entry" | cut -d'|' -f1)
            desc=$(echo "$entry" | cut -d'|' -f3)

            if apps_is_installed "$entry"; then
                installed="${GREEN}[installed]${RESET}"
            fi

            printf "  %2d) %-20s %s %s\n" "$i" "$name" "$desc" "$installed"
            ((i++))
        done < <(apps_get_by_category "$category")

        printf "\n  a) Add all to queue\n"
        printf "  0) Back\n"
        printf "\nSelect app(s) to queue (e.g., 1 3 5 or 1-5): "
        read -r selection

        case "$selection" in
            0) return ;;
            a|A)
                for entry in "${apps[@]}"; do
                    local name pkg
                    name=$(echo "$entry" | cut -d'|' -f1)
                    pkg=$(apps_get_pkg_name "$entry")
                    if [[ -n "$pkg" ]] && ! apps_is_installed "$entry"; then
                        queue_pkg_install "$pkg" "Install $name"
                    fi
                done
                log_success "Added all uninstalled apps to queue"
                pause
                ;;
            *)
                # Parse selection (supports ranges like 1-5 and lists like 1 3 5)
                local nums=()
                for part in $selection; do
                    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                        for ((n=${BASH_REMATCH[1]}; n<=${BASH_REMATCH[2]}; n++)); do
                            nums+=("$n")
                        done
                    elif [[ "$part" =~ ^[0-9]+$ ]]; then
                        nums+=("$part")
                    fi
                done

                for num in "${nums[@]}"; do
                    local idx=$((num - 1))
                    if [[ $idx -ge 0 ]] && [[ $idx -lt ${#apps[@]} ]]; then
                        local entry="${apps[$idx]}"
                        local name pkg
                        name=$(echo "$entry" | cut -d'|' -f1)
                        pkg=$(apps_get_pkg_name "$entry")

                        if [[ -z "$pkg" ]]; then
                            log_warn "$name: No package available for $PKG_MANAGER"
                        elif apps_is_installed "$entry"; then
                            log_info "$name is already installed"
                        else
                            queue_pkg_install "$pkg" "Install $name"
                            log_success "Queued: $name"
                        fi
                    fi
                done
                pause
                ;;
        esac
    done
}

# Show category menu
category_menu() {
    while true; do
        clear_screen
        log_section "Application Categories"

        local categories=()
        local i=1
        while IFS= read -r cat; do
            categories+=("$cat")
            local count
            count=$(apps_count_category "$cat")
            printf "  %2d) %-15s (%d apps)\n" "$i" "${cat^}" "$count"
            ((i++))
        done < <(apps_get_categories)

        printf "\n  0) Back\n"
        printf "\nSelect category: "
        read -r choice

        if [[ "$choice" == "0" ]]; then
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#categories[@]} ]]; then
            browse_category "${categories[$((choice-1))]}"
        fi
    done
}

# ============================================================================
# Search
# ============================================================================

search_apps() {
    printf "Search for: "
    read -r query

    if [[ -z "$query" ]]; then
        return
    fi

    clear_screen
    log_section "Search Results: $query"

    local results=()
    local i=1
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        results+=("$entry")

        local name category desc installed=""
        name=$(echo "$entry" | cut -d'|' -f1)
        category=$(echo "$entry" | cut -d'|' -f2)
        desc=$(echo "$entry" | cut -d'|' -f3)

        if apps_is_installed "$entry"; then
            installed="${GREEN}[installed]${RESET}"
        fi

        printf "  %2d) %-15s [%-12s] %s %s\n" "$i" "$name" "$category" "$desc" "$installed"
        ((i++))
    done < <(apps_search "$query")

    if [[ ${#results[@]} -eq 0 ]]; then
        log_warn "No apps found matching '$query'"
        pause
        return
    fi

    printf "\n  0) Back\n"
    printf "\nSelect to queue: "
    read -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -gt 0 ]] && [[ "$selection" -le ${#results[@]} ]]; then
        local entry="${results[$((selection-1))]}"
        local name pkg
        name=$(echo "$entry" | cut -d'|' -f1)
        pkg=$(apps_get_pkg_name "$entry")

        if [[ -n "$pkg" ]]; then
            queue_pkg_install "$pkg" "Install $name"
            log_success "Queued: $name"
        else
            log_warn "No package available for $PKG_MANAGER"
        fi
        pause
    fi
}

# ============================================================================
# Presets
# ============================================================================

# Install preset profile
install_preset() {
    local preset="$1"
    local preset_file="$SUITE_ROOT/configs/app_presets/${preset}.conf"

    if [[ ! -f "$preset_file" ]]; then
        log_error "Preset not found: $preset"
        return 1
    fi

    log_section "Preset: ${preset^}"

    # Read and display packages
    local packages=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        packages+=("$line")
    done < "$preset_file"

    printf "This preset includes:\n"
    for pkg in "${packages[@]}"; do
        printf "  - %s\n" "$pkg"
    done

    printf "\n"
    if confirm "Add these packages to queue?"; then
        for pkg in "${packages[@]}"; do
            local mapped
            mapped=$(pkg_name "$pkg")
            if ! pkg_is_installed "$mapped"; then
                queue_pkg_install "$mapped" "Install $pkg (preset: $preset)"
            fi
        done
        log_success "Preset packages added to queue"
    fi
}

# Preset menu
preset_menu() {
    while true; do
        simple_menu "Application Presets" \
            "Workstation (productivity, office)" \
            "Gaming (Steam, Lutris, Wine)" \
            "Developer (IDEs, tools, runtimes)" \
            "Pentest (security tools)" \
            "Minimal (essentials only)" \
            "Server (headless utilities)"

        case "$MENU_CHOICE" in
            1) install_preset "workstation"; pause ;;
            2) install_preset "gaming"; pause ;;
            3) install_preset "developer"; pause ;;
            4) install_preset "pentest"; pause ;;
            5) install_preset "minimal"; pause ;;
            6) install_preset "server"; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
# Flatpak Support
# ============================================================================

flatpak_menu() {
    if ! cmd_exists flatpak; then
        log_warn "Flatpak is not installed"
        if confirm "Install Flatpak?"; then
            pkg_install flatpak
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        else
            return
        fi
    fi

    while true; do
        clear_screen
        log_section "Flatpak Apps"

        printf "Apps with Flatpak versions:\n\n"

        local flatpak_apps=()
        local i=1
        for entry in "${APP_DATABASE[@]}"; do
            local flatpak_id
            flatpak_id=$(echo "$entry" | cut -d'|' -f8)
            if [[ -n "$flatpak_id" ]]; then
                flatpak_apps+=("$entry")
                local name desc
                name=$(echo "$entry" | cut -d'|' -f1)
                desc=$(echo "$entry" | cut -d'|' -f3)
                printf "  %2d) %-20s %s\n" "$i" "$name" "$flatpak_id"
                ((i++))
            fi
        done

        printf "\n  s) Search Flathub\n"
        printf "  0) Back\n"
        printf "\nSelect app: "
        read -r choice

        case "$choice" in
            0) return ;;
            s|S)
                printf "Search Flathub: "
                read -r query
                if [[ -n "$query" ]]; then
                    flatpak search "$query" | head -20
                    pause
                fi
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -gt 0 ]] && [[ "$choice" -le ${#flatpak_apps[@]} ]]; then
                    local entry="${flatpak_apps[$((choice-1))]}"
                    local name flatpak_id
                    name=$(echo "$entry" | cut -d'|' -f1)
                    flatpak_id=$(echo "$entry" | cut -d'|' -f8)

                    if confirm "Install $name via Flatpak?"; then
                        queue_command "flatpak install -y flathub $flatpak_id" "Flatpak: Install $name"
                        log_success "Queued Flatpak install: $name"
                    fi
                    pause
                fi
                ;;
        esac
    done
}

# ============================================================================
# Show installed apps
# ============================================================================

show_installed() {
    clear_screen
    log_section "Installed Applications"

    local installed_count=0

    for entry in "${APP_DATABASE[@]}"; do
        if apps_is_installed "$entry"; then
            local name category
            name=$(echo "$entry" | cut -d'|' -f1)
            category=$(echo "$entry" | cut -d'|' -f2)
            printf "  %-20s [%s]\n" "$name" "$category"
            ((installed_count++))
        fi
    done

    printf "\n%d of %d apps installed\n" "$installed_count" "$(apps_count_total)"
    pause
}

# ============================================================================
# Module Initialization
# ============================================================================

apps_init() {
    log_debug "Apps module initialized ($(apps_count_total) apps in database)"
}

# ============================================================================
# Main Entry Point
# ============================================================================

apps_main() {
    while true; do
        local queue_count
        queue_count=$(queue_count)

        simple_menu "Applications ($(apps_count_total) available)" \
            "Browse by Category" \
            "Search Apps" \
            "Quick Presets" \
            "Flatpak Apps" \
            "Show Installed" \
            "View Queue ($queue_count pending)"

        case "$MENU_CHOICE" in
            1) category_menu ;;
            2) search_apps ;;
            3) preset_menu ;;
            4) flatpak_menu ;;
            5) show_installed ;;
            6) queue_menu ;;
            0) return 0 ;;
        esac
    done
}
