#!/usr/bin/env bash
#
# menu.sh - Menu System for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# Prevent multiple sourcing
[[ -n "${_MENU_LOADED:-}" ]] && return 0
readonly _MENU_LOADED=1

# Clear screen
clear_screen() {
    printf "\033c"
}

# Show a menu and get user choice
# Usage: show_menu "Title" "1) Option 1" "2) Option 2" "0) Exit"
# Returns: Sets MENU_CHOICE to the selected number
show_menu() {
    local title="$1"
    shift
    local options=("$@")

    while true; do
        clear_screen
        printf "\n"
        log_section "$title"

        for opt in "${options[@]}"; do
            printf "  %s\n" "$opt"
        done

        printf "\n"
        printf "Enter choice: "
        read -r MENU_CHOICE

        # Validate input - must be a number
        if [[ "$MENU_CHOICE" =~ ^[0-9]+$ ]]; then
            return 0
        fi

        log_warn "Invalid choice. Please enter a number."
        sleep 1
    done
}

# Show a simple menu with automatic numbering
# Usage: simple_menu "Title" "Option A" "Option B" "Option C"
# Returns: MENU_CHOICE (1-based index, 0 for exit)
simple_menu() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}

    while true; do
        clear_screen
        printf "\n"
        log_section "$title"

        local i=1
        for opt in "${options[@]}"; do
            printf "  %d) %s\n" "$i" "$opt"
            ((i++))
        done
        printf "  0) Back/Exit\n"

        printf "\n"
        printf "Enter choice [0-%d]: " "$count"
        read -r MENU_CHOICE

        if [[ "$MENU_CHOICE" =~ ^[0-9]+$ ]] && [[ "$MENU_CHOICE" -ge 0 ]] && [[ "$MENU_CHOICE" -le "$count" ]]; then
            return 0
        fi

        log_warn "Invalid choice. Please enter 0-$count."
        sleep 1
    done
}

# Yes/No menu
# Usage: yesno_menu "Question?"
# Returns: 0 for yes, 1 for no
yesno_menu() {
    local question="$1"

    while true; do
        printf "\n%s [y/n]: " "$question"
        read -r response

        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) log_warn "Please enter y or n" ;;
        esac
    done
}

# Show info box
info_box() {
    local title="$1"
    shift
    local lines=("$@")

    printf "\n"
    log_section "$title"

    for line in "${lines[@]}"; do
        printf "  %s\n" "$line"
    done

    printf "\n"
    pause
}

# Show progress indicator
# Usage: progress_indicator PID "Message"
show_progress() {
    local pid="$1"
    local msg="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s " "${spin:i++%${#spin}:1}" "$msg"
        sleep 0.1
    done
    printf "\r\033[K"
}

# Multi-select menu
# Usage: multiselect_menu "Title" "opt1" "opt2" "opt3"
# Returns: SELECTED_ITEMS array
declare -ga SELECTED_ITEMS=()

multiselect_menu() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    declare -a selected=()

    # Initialize all as unselected
    for ((i=0; i<count; i++)); do
        selected[$i]=0
    done

    while true; do
        clear_screen
        printf "\n"
        log_section "$title"
        printf "  (Space to toggle, Enter to confirm)\n\n"

        for ((i=0; i<count; i++)); do
            if [[ ${selected[$i]} -eq 1 ]]; then
                printf "  [x] %d) %s\n" "$((i+1))" "${options[$i]}"
            else
                printf "  [ ] %d) %s\n" "$((i+1))" "${options[$i]}"
            fi
        done

        printf "\n  0) Done\n"
        printf "\nToggle item [1-%d] or 0 to finish: " "$count"
        read -r choice

        if [[ "$choice" == "0" ]]; then
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$count" ]]; then
            local idx=$((choice - 1))
            if [[ ${selected[$idx]} -eq 1 ]]; then
                selected[$idx]=0
            else
                selected[$idx]=1
            fi
        fi
    done

    # Build result array
    SELECTED_ITEMS=()
    for ((i=0; i<count; i++)); do
        if [[ ${selected[$i]} -eq 1 ]]; then
            SELECTED_ITEMS+=("${options[$i]}")
        fi
    done
}

# Status line
status_line() {
    local left="$1"
    local right="$2"
    local width
    width=$(term_width)
    local padding=$((width - ${#left} - ${#right} - 2))

    printf "%s%*s%s\n" "$left" "$padding" "" "$right"
}

# Header with system info
show_header() {
    clear_screen
    printf "\n"
    center_text "$SUITE_NAME v$SUITE_VERSION"
    printf "\n"
    status_line "OS: ${OS_PRETTY:-$OS_ID}" "Pkg: $PKG_MANAGER"
    log_divider
}
