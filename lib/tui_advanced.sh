#!/usr/bin/env bash
#
# tui_advanced.sh - Advanced TUI components for Ultimate Linux Suite
#
# This library provides sophisticated UI components for application
# installation, system scanning, and complex menu navigation.
#

# Prevent multiple sourcing
[[ -n "${_TUI_ADVANCED_LOADED:-}" ]] && return 0
readonly _TUI_ADVANCED_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# Source tui.sh with fallback
source "${SCRIPT_DIR}/tui.sh" 2>/dev/null || {
    log_debug "tui.sh not available, using basic fallbacks"
    TUI_BACKEND="basic"
}

# ============================================================================
# State management for complex dialogs
# ============================================================================

declare -gA TUI_STATE=(
    [current_page]=0
    [selected_items]=""
    [scroll_offset]=0
    [search_term]=""
    [category]="all"
)

# Save state to temp file
tui_state_save() {
    local name="$1"
    local state_file="/tmp/uls_tui_state_${name}.tmp"

    declare -p TUI_STATE > "$state_file" 2>/dev/null
}

# Restore state from temp file
tui_state_restore() {
    local name="$1"
    local state_file="/tmp/uls_tui_state_${name}.tmp"

    if [[ -f "$state_file" ]]; then
        source "$state_file"
        rm -f "$state_file"
    fi
}

# ============================================================================
# Helper functions
# ============================================================================

# Truncate text to width with ellipsis
tui_truncate() {
    local text="$1"
    local max_width="$2"

    if [[ ${#text} -gt $max_width ]]; then
        echo "${text:0:$((max_width-3))}..."
    else
        echo "$text"
    fi
}

# Wrap text to width
tui_wrap() {
    local text="$1"
    local width="$2"

    echo "$text" | fold -s -w "$width"
}

# Format bytes to human readable
tui_format_bytes() {
    local bytes="$1"

    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt $((1024 * 1024)) ]]; then
        echo "$((bytes / 1024)) KB"
    elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
        echo "$((bytes / 1024 / 1024)) MB"
    else
        echo "$((bytes / 1024 / 1024 / 1024)) GB"
    fi
}

# Pad string to width
tui_pad() {
    local text="$1"
    local width="$2"
    local align="${3:-left}"

    local len=${#text}
    local padding=$((width - len))

    if [[ $padding -le 0 ]]; then
        echo "$text"
        return
    fi

    case "$align" in
        right)
            printf "%*s%s" "$padding" "" "$text"
            ;;
        center)
            local left_pad=$((padding / 2))
            local right_pad=$((padding - left_pad))
            printf "%*s%s%*s" "$left_pad" "" "$text" "$right_pad" ""
            ;;
        *)
            printf "%s%*s" "$text" "$padding" ""
            ;;
    esac
}

# Draw a box with title
tui_box() {
    local title="$1"
    local width="${2:-60}"
    local content="${3:-}"

    # Top border
    printf "%b┌" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┐%b\n" "${RESET}"

    # Title
    if [[ -n "$title" ]]; then
        local title_text=" $title "
        local title_len=${#title_text}
        local title_padding=$(( (width - title_len - 2) / 2 ))

        printf "%b│%b%*s%b%s%b%*s%b│%b\n" \
            "${BOLD}" "${CYAN}" "$title_padding" "" "${BOLD}" "$title_text" \
            "${CYAN}" "$title_padding" "" "${BOLD}" "${RESET}"

        # Separator
        printf "%b├" "${BOLD}"
        printf "─%.0s" $(seq 1 $((width - 2)))
        printf "┤%b\n" "${RESET}"
    fi

    # Content
    if [[ -n "$content" ]]; then
        while IFS= read -r line; do
            local trimmed
            trimmed=$(tui_truncate "$line" $((width - 4)))
            printf "│ %-$((width - 4))s │\n" "$trimmed"
        done <<< "$content"
    fi

    # Bottom border
    printf "%b└" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┘%b\n" "${RESET}"
}

# ============================================================================
# Hierarchical menus
# ============================================================================

# Category menu with breadcrumbs
tui_category_menu() {
    local title="$1"
    shift
    local -n categories_ref="$1"

    local current_category="root"
    local breadcrumb=("Home")

    while true; do
        clear

        # Display breadcrumb
        printf "\n%b%s%b\n" "${CYAN}" "${breadcrumb[*]} > " "${RESET}"
        log_divider
        printf "\n"

        # Get items for current category
        local items=()
        for key in "${!categories_ref[@]}"; do
            if [[ "$key" == "${current_category}:"* ]]; then
                local item="${key#*:}"
                items+=("$item")
            fi
        done

        # Display menu
        if [[ ${#items[@]} -eq 0 ]]; then
            printf "No items in this category.\n\n"
            pause
            return 1
        fi

        local choice
        if [[ $TUI_HAS_FZF -eq 1 ]]; then
            choice=$(printf "%s\n.. (Back)\n" "${items[@]}" | fzf --prompt="Select > ")
        else
            printf "%s\n" "${items[@]}"
            printf ".. (Back)\n"
            printf "\nChoice: "
            read -r choice
        fi

        [[ -z "$choice" || "$choice" == ".. (Back)" ]] && return 0

        # Check if it's a subcategory or item
        if [[ -v "categories_ref[${current_category}:${choice}]" ]]; then
            current_category="${current_category}:${choice}"
            breadcrumb+=("$choice")
        else
            echo "$choice"
            return 0
        fi
    done
}

# Breadcrumb navigation menu
tui_breadcrumb_menu() {
    local -n path_array="$1"
    shift
    local items=("$@")

    clear
    printf "\n%bPath:%b " "${BOLD}" "${RESET}"

    for i in "${!path_array[@]}"; do
        if [[ $i -eq $((${#path_array[@]} - 1)) ]]; then
            printf "%b%s%b" "${CYAN}" "${path_array[$i]}" "${RESET}"
        else
            printf "%s > " "${path_array[$i]}"
        fi
    done
    printf "\n\n"

    tui_select "Choose an item" "${items[@]}"
}

# Tree-style selection
tui_tree_select() {
    local title="$1"
    shift
    local -n tree_data="$1"

    # Simple tree display (can be enhanced)
    local items=()
    for key in "${!tree_data[@]}"; do
        local depth="${key//[^:]}"
        local indent="$(printf '  %.0s' $(seq 1 ${#depth}))"
        items+=("${indent}${tree_data[$key]}")
    done

    tui_select "$title" "${items[@]}"
}

# ============================================================================
# Enhanced multi-select
# ============================================================================

# Multi-select with search overlay
tui_multiselect_search() {
    local title="$1"
    shift
    local items=("$@")

    if [[ $TUI_HAS_FZF -eq 1 ]]; then
        printf "%s\n" "${items[@]}" | fzf --multi --prompt="$title (Tab to select) > " \
            --bind 'ctrl-a:select-all,ctrl-d:deselect-all' --height=60%
    else
        tui_multiselect "$title" "${items[@]}"
    fi
}

# Multi-select with select/deselect all
tui_select_all() {
    local title="$1"
    shift
    local items=("$@")

    if [[ $TUI_HAS_GUM -eq 1 ]]; then
        # gum supports --select-if-one and --limit flags
        printf "%s\n" "${items[@]}" | gum choose --no-limit --header="$title (Space: toggle, Ctrl+A: all)"
    elif [[ $TUI_HAS_FZF -eq 1 ]]; then
        printf "%s\n" "${items[@]}" | fzf --multi --prompt="$title > " \
            --bind 'ctrl-a:select-all,ctrl-d:deselect-all'
    else
        # Fallback implementation
        local -a selected=()
        local -a display_items=("Select All" "Deselect All" "---" "${items[@]}")

        while true; do
            clear
            printf "\n%b=== %s ===%b\n\n" "${BOLD}" "$title" "${RESET}"

            for i in "${!display_items[@]}"; do
                local item="${display_items[$i]}"
                if [[ "$item" == "---" ]]; then
                    printf "\n"
                elif [[ "$item" == "Select All" ]] || [[ "$item" == "Deselect All" ]]; then
                    printf "  %b%s%b\n" "${YELLOW}" "$item" "${RESET}"
                elif printf "%s\n" "${selected[@]}" | grep -qx "$item" 2>/dev/null; then
                    printf "  %b[x]%b %s\n" "${GREEN}" "${RESET}" "$item"
                else
                    printf "  [ ] %s\n" "$item"
                fi
            done

            printf "\n%bEnter item name, 'done' to finish:%b " "${CYAN}" "${RESET}"
            read -r choice

            case "$choice" in
                done|"")
                    break
                    ;;
                "Select All")
                    selected=("${items[@]}")
                    ;;
                "Deselect All")
                    selected=()
                    ;;
                *)
                    if printf "%s\n" "${items[@]}" | grep -qx "$choice"; then
                        if printf "%s\n" "${selected[@]}" | grep -qx "$choice" 2>/dev/null; then
                            # Remove from selected
                            local -a new_selected=()
                            for item in "${selected[@]}"; do
                                [[ "$item" != "$choice" ]] && new_selected+=("$item")
                            done
                            selected=("${new_selected[@]}")
                        else
                            # Add to selected
                            selected+=("$choice")
                        fi
                    fi
                    ;;
            esac
        done

        printf "%s\n" "${selected[@]}"
    fi
}

# Grouped multi-select
tui_grouped_select() {
    local title="$1"
    shift

    local -a all_items=()
    local -a group_headers=()

    # Parse groups (format: GROUP_NAME item1 item2 ... next_GROUP_NAME ...)
    local current_group=""
    while [[ $# -gt 0 ]]; do
        if [[ "$1" =~ ^[A-Z_]+$ ]]; then
            current_group="$1"
            group_headers+=("--- $current_group ---")
            all_items+=("--- $current_group ---")
        else
            all_items+=("  $1")
        fi
        shift
    done

    # Use multiselect but filter out headers from results
    local selected
    selected=$(tui_multiselect_search "$title" "${all_items[@]}")

    # Filter out group headers and trim spaces
    echo "$selected" | grep -v "^---" | sed 's/^  //'
}

# ============================================================================
# Progress tracking
# ============================================================================

# Multiple progress bars
tui_progress_multi() {
    local -n tasks_ref="$1"

    clear
    printf "\n%b=== Task Progress ===%b\n\n" "${BOLD}" "${RESET}"

    for task_id in "${!tasks_ref[@]}"; do
        local task_data="${tasks_ref[$task_id]}"
        IFS='|' read -r name current total status <<< "$task_data"

        local percent=0
        [[ $total -gt 0 ]] && percent=$((current * 100 / total))

        # Status icon
        local icon="⏳"
        case "$status" in
            complete) icon="${GREEN}✓${RESET}" ;;
            failed) icon="${RED}✗${RESET}" ;;
            running) icon="${YELLOW}⟳${RESET}" ;;
        esac

        printf "%b %s%-30s%b [" "$icon" "${BOLD}" "$name" "${RESET}"

        # Progress bar
        local bar_width=30
        local filled=$((percent * bar_width / 100))
        printf "%b" "${GREEN}"
        printf "%*s" "$filled" "" | tr ' ' '█'
        printf "%b" "${RESET}"
        printf "%*s" "$((bar_width - filled))" "" | tr ' ' '░'

        printf "] %3d%%\n" "$percent"
    done

    printf "\n"
}

# Task list with checkmarks
tui_task_list() {
    local title="$1"
    shift
    local -a tasks=("$@")

    printf "\n%b=== %s ===%b\n\n" "${BOLD}" "$title" "${RESET}"

    for task in "${tasks[@]}"; do
        IFS='|' read -r status name <<< "$task"

        case "$status" in
            pending)
                printf "  %b⏳%b %s\n" "${YELLOW}" "${RESET}" "$name"
                ;;
            running)
                printf "  %b⟳%b %s\n" "${CYAN}" "${RESET}" "$name"
                ;;
            complete)
                printf "  %b✓%b %s\n" "${GREEN}" "${RESET}" "$name"
                ;;
            failed)
                printf "  %b✗%b %s\n" "${RED}" "${RESET}" "$name"
                ;;
        esac
    done

    printf "\n"
}

# Scrollable log viewer
tui_log_viewer() {
    local log_file="$1"
    local title="${2:-Log Viewer}"

    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi

    if [[ $TUI_HAS_GUM -eq 1 ]]; then
        gum pager --show-line-numbers < "$log_file"
    elif cmd_exists less; then
        less +F "$log_file"
    else
        tail -f "$log_file"
    fi
}

# ============================================================================
# Tables and lists
# ============================================================================

# Formatted table display
tui_table() {
    local -a headers=()
    local -a data=()
    local separator_found=0

    # Parse arguments (headers before --, data after)
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then
            separator_found=1
            shift
            continue
        fi

        if [[ $separator_found -eq 0 ]]; then
            headers+=("$1")
        else
            data+=("$1")
        fi
        shift
    done

    local num_cols=${#headers[@]}
    [[ $num_cols -eq 0 ]] && return 1

    local -a col_widths=()

    # Calculate column widths
    for i in "${!headers[@]}"; do
        col_widths[$i]=${#headers[$i]}
    done

    # Check data widths
    for ((i=0; i<${#data[@]}; i++)); do
        local col=$((i % num_cols))
        local len=${#data[$i]}
        [[ $len -gt ${col_widths[$col]} ]] && col_widths[$col]=$len
    done

    # Print header
    printf "\n%b" "${BOLD}"
    for i in "${!headers[@]}"; do
        printf "%-$((col_widths[$i] + 2))s" "${headers[$i]}"
    done
    printf "%b\n" "${RESET}"

    # Print separator
    for width in "${col_widths[@]}"; do
        printf "%*s" "$((width + 2))" "" | tr ' ' '─'
    done
    printf "\n"

    # Print data rows
    for ((i=0; i<${#data[@]}; i++)); do
        local col=$((i % num_cols))
        printf "%-$((col_widths[$col] + 2))s" "${data[$i]}"

        if [[ $(((i + 1) % num_cols)) -eq 0 ]]; then
            printf "\n"
        fi
    done

    printf "\n"
}

# Key-value pair display
tui_keyvalue() {
    local max_key_len=0
    local -a pairs=("$@")

    # Find longest key
    for ((i=0; i<${#pairs[@]}; i+=2)); do
        local len=${#pairs[$i]}
        [[ $len -gt $max_key_len ]] && max_key_len=$len
    done

    # Display pairs
    printf "\n"
    for ((i=0; i<${#pairs[@]}; i+=2)); do
        local key="${pairs[$i]}"
        local value="${pairs[$i+1]}"
        printf "  %b%-${max_key_len}s:%b %s\n" "${CYAN}" "$key" "${RESET}" "$value"
    done
    printf "\n"
}

# Multi-column list
tui_list_columns() {
    local items=("$@")
    local term_cols
    term_cols=$(term_width)

    # Find longest item
    local max_len=0
    for item in "${items[@]}"; do
        [[ ${#item} -gt $max_len ]] && max_len=${#item}
    done

    # Calculate columns
    local col_width=$((max_len + 4))
    local num_cols=$((term_cols / col_width))
    [[ $num_cols -lt 1 ]] && num_cols=1

    # Display in columns
    printf "\n"
    for ((i=0; i<${#items[@]}; i++)); do
        printf "%-${col_width}s" "${items[$i]}"

        if [[ $(((i + 1) % num_cols)) -eq 0 ]]; then
            printf "\n"
        fi
    done
    [[ $(( ${#items[@]} % num_cols )) -ne 0 ]] && printf "\n"
    printf "\n"
}

# ============================================================================
# Installation wizard
# ============================================================================

# Step indicator
tui_step_indicator() {
    local current="$1"
    local total="$2"
    shift 2
    local labels=("$@")

    printf "\n"
    for ((i=1; i<=total; i++)); do
        if [[ $i -lt $current ]]; then
            printf "%b✓%b " "${GREEN}" "${RESET}"
        elif [[ $i -eq $current ]]; then
            printf "%b●%b " "${CYAN}" "${RESET}"
        else
            printf "○ "
        fi

        if [[ $i -le ${#labels[@]} ]]; then
            if [[ $i -eq $current ]]; then
                printf "%b%s%b" "${BOLD}" "${labels[$((i-1))]}" "${RESET}"
            else
                printf "%s" "${labels[$((i-1))]}"
            fi
        fi

        [[ $i -lt $total ]] && printf " → "
    done
    printf "\n\n"
}

# Multi-step wizard
tui_wizard() {
    local -n steps_ref="$1"
    local current_step=1
    local total_steps=${#steps_ref[@]}

    while [[ $current_step -le $total_steps ]]; do
        clear

        # Show step indicator
        local -a labels=()
        for step_name in "${steps_ref[@]}"; do
            labels+=("${step_name%%:*}")
        done
        tui_step_indicator "$current_step" "$total_steps" "${labels[@]}"

        # Execute step
        local step_data="${steps_ref[$((current_step-1))]}"
        local step_name="${step_data%%:*}"
        local step_func="${step_data##*:}"

        printf "%b=== %s ===%b\n\n" "${BOLD}" "$step_name" "${RESET}"

        # Call step function
        if type "$step_func" &>/dev/null; then
            "$step_func"
            local result=$?

            if [[ $result -ne 0 ]]; then
                log_error "Step failed: $step_name"
                if ! tui_confirm "Continue anyway?"; then
                    return 1
                fi
            fi
        fi

        # Navigation
        printf "\n"
        local choice
        if [[ $current_step -eq 1 ]]; then
            choice=$(tui_select "Navigation" "Next" "Cancel")
        elif [[ $current_step -eq $total_steps ]]; then
            choice=$(tui_select "Navigation" "Finish" "Back" "Cancel")
        else
            choice=$(tui_select "Navigation" "Next" "Back" "Cancel")
        fi

        case "$choice" in
            Next|Finish)
                ((current_step++))
                ;;
            Back)
                ((current_step--))
                ;;
            Cancel)
                tui_confirm "Really cancel?" && return 1
                ;;
        esac
    done

    return 0
}

# ============================================================================
# Application browser and selection
# ============================================================================

# Structure for app entry
declare -gA APP_ENTRY=(
    [name]=""
    [category]=""
    [description]=""
    [installed]=0
    [size]=""
    [methods]=""
)

# Application card display
tui_app_card() {
    local app_name="$1"
    local -n app_data="$2"

    local width=70

    # Top border
    printf "\n%b┌" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┐%b\n" "${RESET}"

    # App name
    printf "%b│ %b%-$((width - 4))s%b │%b\n" \
        "${BOLD}" "${CYAN}${BOLD}" "${app_data[name]}" "${RESET}${BOLD}" "${RESET}"

    # Category
    printf "%b│ %b%s%b%-$((width - 14))s │%b\n" \
        "${BOLD}" "${YELLOW}" "Category: " "${RESET}" "${app_data[category]}" "${BOLD}${RESET}"

    # Status
    local status_text="Not installed"
    local status_color="${RED}"
    if [[ ${app_data[installed]} -eq 1 ]]; then
        status_text="Installed"
        status_color="${GREEN}"
    fi
    printf "%b│ %b%s: %b%s%-$((width - 22))s%b │%b\n" \
        "${BOLD}" "${RESET}" "Status" "$status_color" "$status_text" "" "${BOLD}" "${RESET}"

    # Separator
    printf "%b├" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┤%b\n" "${RESET}"

    # Description (wrapped)
    printf "│ %-$((width - 4))s │\n" "Description:"
    local wrapped
    wrapped=$(tui_wrap "${app_data[description]}" $((width - 6)))
    while IFS= read -r line; do
        printf "│   %-$((width - 6))s   │\n" "$line"
    done <<< "$wrapped"

    # Separator
    printf "%b├" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┤%b\n" "${RESET}"

    # Methods available
    printf "│ %-$((width - 4))s │\n" "Install methods: ${app_data[methods]}"

    # Size (if available)
    if [[ -n "${app_data[size]}" ]]; then
        printf "│ %-$((width - 4))s │\n" "Size: ${app_data[size]}"
    fi

    # Bottom border
    printf "%b└" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┘%b\n" "${RESET}"
}

# Application browser with categories
tui_app_browser() {
    local -n apps_ref="$1"
    local -a selected_apps=()

    while true; do
        clear
        printf "\n%b=== Application Browser ===%b\n\n" "${BOLD}${CYAN}" "${RESET}"

        # Get unique categories
        local -a categories=("All")
        for app_key in "${!apps_ref[@]}"; do
            local category="${apps_ref[$app_key]%%|*}"
            if ! printf "%s\n" "${categories[@]}" | grep -qx "$category"; then
                categories+=("$category")
            fi
        done

        # Category selection
        printf "%bFilter by category:%b\n" "${BOLD}" "${RESET}"
        local selected_cat
        selected_cat=$(tui_select "Select category" "${categories[@]}" "Search all" "View selected (${#selected_apps[@]})" "Done")

        case "$selected_cat" in
            "Done")
                break
                ;;
            "View selected"*)
                if [[ ${#selected_apps[@]} -eq 0 ]]; then
                    printf "\nNo apps selected yet.\n"
                    pause
                else
                    printf "\n%bSelected applications:%b\n" "${BOLD}" "${RESET}"
                    printf "%s\n" "${selected_apps[@]}"
                    printf "\n"
                    if tui_confirm "Clear selection?"; then
                        selected_apps=()
                    fi
                    pause
                fi
                continue
                ;;
            "Search all")
                selected_cat="All"
                ;;
        esac

        # Build app list for category
        local -a app_list=()
        for app_key in "${!apps_ref[@]}"; do
            IFS='|' read -r cat name desc installed <<< "${apps_ref[$app_key]}"

            if [[ "$selected_cat" == "All" ]] || [[ "$cat" == "$selected_cat" ]]; then
                local status_icon="  "
                [[ "$installed" == "1" ]] && status_icon="${GREEN}✓${RESET}"

                # Check if already in selected list
                local selected_mark=""
                if printf "%s\n" "${selected_apps[@]}" | grep -qx "$name" 2>/dev/null; then
                    selected_mark="${CYAN}[+]${RESET} "
                fi

                app_list+=("${selected_mark}${status_icon} ${name} - ${desc}")
            fi
        done

        if [[ ${#app_list[@]} -eq 0 ]]; then
            printf "\nNo applications in category: %s\n" "$selected_cat"
            pause
            continue
        fi

        # App selection
        local selected
        if [[ $TUI_HAS_FZF -eq 1 ]]; then
            selected=$(printf "%s\n" "${app_list[@]}" | \
                fzf --prompt="Select app (Tab for multi) > " \
                    --preview='echo {}' \
                    --preview-window=up:3:wrap \
                    --multi)
        else
            selected=$(tui_select "Select application" "${app_list[@]}")
        fi

        [[ -z "$selected" ]] && continue

        # Extract app names from selection
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            # Extract name (remove status icons and description)
            local clean_line="${line#\[+\] }"
            clean_line="${clean_line#✓ }"
            clean_line="${clean_line%% - *}"
            clean_line="${clean_line## }"

            # Toggle selection
            if printf "%s\n" "${selected_apps[@]}" | grep -qx "$clean_line" 2>/dev/null; then
                # Remove from selection
                local -a new_selection=()
                for app in "${selected_apps[@]}"; do
                    [[ "$app" != "$clean_line" ]] && new_selection+=("$app")
                done
                selected_apps=("${new_selection[@]}")
            else
                # Add to selection
                selected_apps+=("$clean_line")
            fi
        done <<< "$selected"
    done

    # Return selected apps
    printf "%s\n" "${selected_apps[@]}"
}

# ============================================================================
# Installation progress
# ============================================================================

# Installation progress for single app
tui_install_progress() {
    local app_name="$1"
    local method="$2"
    local log_file="${3:-/tmp/install_${app_name}.log}"

    local width=70

    clear
    printf "\n"

    # Header
    printf "%b┌" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┐%b\n" "${RESET}"

    printf "%b│ %bInstalling:%b %-$((width - 16))s │%b\n" \
        "${BOLD}" "${CYAN}" "${RESET}" "$app_name" "${BOLD}${RESET}"

    printf "%b│ %bMethod:%b %-$((width - 12))s │%b\n" \
        "${BOLD}" "${YELLOW}" "${RESET}" "$method" "${BOLD}${RESET}"

    printf "%b├" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┤%b\n" "${RESET}"

    # Log output area
    printf "%b│ %bProgress:%b%-$((width - 14))s │%b\n" \
        "${BOLD}" "${RESET}" "${BOLD}" "" "${RESET}"

    # Show last few lines of log
    if [[ -f "$log_file" ]]; then
        local log_lines
        log_lines=$(tail -n 5 "$log_file" 2>/dev/null || echo "Initializing...")

        while IFS= read -r line; do
            line=$(tui_truncate "$line" $((width - 6)))
            printf "│   %-$((width - 6))s   │\n" "$line"
        done <<< "$log_lines"
    else
        printf "│   %-$((width - 6))s   │\n" "Initializing..."
    fi

    printf "%b└" "${BOLD}"
    printf "─%.0s" $(seq 1 $((width - 2)))
    printf "┘%b\n" "${RESET}"
}

# Batch installation progress
tui_batch_install() {
    local -n batch_apps="$1"

    while true; do
        clear
        printf "\n%b=== Batch Installation Progress ===%b\n\n" "${BOLD}${CYAN}" "${RESET}"

        local all_complete=1

        for app_key in "${!batch_apps[@]}"; do
            IFS='|' read -r name status method <<< "${batch_apps[$app_key]}"

            local icon=""
            local color=""

            case "$status" in
                pending)
                    icon="⏳"
                    color="${RESET}"
                    all_complete=0
                    ;;
                running)
                    icon="${YELLOW}⟳${RESET}"
                    color="${YELLOW}"
                    all_complete=0
                    ;;
                complete)
                    icon="${GREEN}✓${RESET}"
                    color="${GREEN}"
                    ;;
                failed)
                    icon="${RED}✗${RESET}"
                    color="${RED}"
                    ;;
            esac

            printf "  %b %b%-30s%b [%s]\n" "$icon" "$color" "$name" "${RESET}" "$method"
        done

        printf "\n"

        [[ $all_complete -eq 1 ]] && break
        sleep 1
    done

    printf "%bInstallation complete!%b\n" "${GREEN}${BOLD}" "${RESET}"
    pause
}

# ============================================================================
# System scan display
# ============================================================================

# Hardware detection display
tui_scan_display() {
    local -n scan_data="$1"

    clear
    printf "\n%b=== Hardware Detection Results ===%b\n\n" "${BOLD}${CYAN}" "${RESET}"

    for section in "${!scan_data[@]}"; do
        printf "%b%s:%b\n" "${BOLD}" "$section" "${RESET}"

        local data="${scan_data[$section]}"
        while IFS= read -r line; do
            printf "  %s\n" "$line"
        done <<< "$data"

        printf "\n"
    done

    pause
}

# Optimization preview with toggles
tui_optimization_preview() {
    local -n opt_items="$1"
    local -a enabled=()

    # Initialize all as enabled
    for item in "${!opt_items[@]}"; do
        enabled+=("$item")
    done

    while true; do
        clear
        printf "\n%b=== Optimization Preview ===%b\n" "${BOLD}${CYAN}" "${RESET}"
        printf "%bToggle items to enable/disable%b\n\n" "${YELLOW}" "${RESET}"

        for item in "${!opt_items[@]}"; do
            local is_enabled=0
            printf "%s\n" "${enabled[@]}" | grep -qx "$item" && is_enabled=1

            if [[ $is_enabled -eq 1 ]]; then
                printf "  %b[x]%b %s\n" "${GREEN}" "${RESET}" "$item"
            else
                printf "  [ ] %s\n" "$item"
            fi

            printf "      %b→%b %s\n" "${CYAN}" "${RESET}" "${opt_items[$item]}"
        done

        printf "\n"
        local choice
        choice=$(tui_select "Action" "Toggle item" "Apply changes" "Cancel")

        case "$choice" in
            "Toggle item")
                local toggle_item
                toggle_item=$(tui_select "Select item to toggle" "${!opt_items[@]}")

                if printf "%s\n" "${enabled[@]}" | grep -qx "$toggle_item" 2>/dev/null; then
                    # Disable
                    local -a new_enabled=()
                    for e in "${enabled[@]}"; do
                        [[ "$e" != "$toggle_item" ]] && new_enabled+=("$e")
                    done
                    enabled=("${new_enabled[@]}")
                else
                    # Enable
                    enabled+=("$toggle_item")
                fi
                ;;
            "Apply changes")
                printf "%s\n" "${enabled[@]}"
                return 0
                ;;
            "Cancel")
                return 1
                ;;
        esac
    done
}

# ============================================================================
# Queue management
# ============================================================================

# Queue viewer and manager
tui_queue_view() {
    local -n queue_items="$1"

    while true; do
        clear
        printf "\n%b=== Queue Management ===%b\n\n" "${BOLD}${CYAN}" "${RESET}"

        if [[ ${#queue_items[@]} -eq 0 ]]; then
            printf "Queue is empty.\n\n"
            pause
            return 0
        fi

        printf "%bCurrent queue:%b\n\n" "${BOLD}" "${RESET}"
        for i in "${!queue_items[@]}"; do
            printf "  %b%d.%b %s\n" "${CYAN}" "$((i+1))" "${RESET}" "${queue_items[$i]}"
        done

        printf "\n"
        local choice
        choice=$(tui_select "Action" "Move item up" "Move item down" "Remove item" "Execute queue" "Back")

        case "$choice" in
            "Move item up"|"Move item down")
                local idx
                read -p "Enter item number: " idx
                idx=$((idx - 1))

                if [[ $idx -ge 0 ]] && [[ $idx -lt ${#queue_items[@]} ]]; then
                    if [[ "$choice" == "Move item up" ]] && [[ $idx -gt 0 ]]; then
                        local temp="${queue_items[$idx]}"
                        queue_items[$idx]="${queue_items[$((idx-1))]}"
                        queue_items[$((idx-1))]="$temp"
                    elif [[ "$choice" == "Move item down" ]] && [[ $idx -lt $((${#queue_items[@]} - 1)) ]]; then
                        local temp="${queue_items[$idx]}"
                        queue_items[$idx]="${queue_items[$((idx+1))]}"
                        queue_items[$((idx+1))]="$temp"
                    fi
                fi
                ;;
            "Remove item")
                local idx
                read -p "Enter item number: " idx
                idx=$((idx - 1))

                if [[ $idx -ge 0 ]] && [[ $idx -lt ${#queue_items[@]} ]]; then
                    unset 'queue_items[$idx]'
                    queue_items=("${queue_items[@]}")  # Re-index
                fi
                ;;
            "Execute queue")
                if tui_confirm "Execute all items in queue?"; then
                    return 0
                fi
                ;;
            "Back")
                return 1
                ;;
        esac
    done
}

# ============================================================================
# File and directory pickers
# ============================================================================

# File picker dialog
tui_file_picker() {
    local title="$1"
    local start_dir="${2:-.}"

    if [[ $TUI_HAS_FZF -eq 1 ]]; then
        find "$start_dir" -type f 2>/dev/null | fzf --prompt="$title > " --preview='cat {}'
    else
        printf "%b%s%b\n" "${BOLD}" "$title" "${RESET}"
        read -e -p "Enter file path: " -i "$start_dir" filepath
        echo "$filepath"
    fi
}

# Directory picker
tui_dir_picker() {
    local title="$1"
    local start_dir="${2:-.}"

    if [[ $TUI_HAS_FZF -eq 1 ]]; then
        find "$start_dir" -type d 2>/dev/null | fzf --prompt="$title > " --preview='ls -la {}'
    else
        printf "%b%s%b\n" "${BOLD}" "$title" "${RESET}"
        read -e -p "Enter directory path: " -i "$start_dir" dirpath
        echo "$dirpath"
    fi
}

# Simple text editor for configs
tui_editor() {
    local title="$1"
    local content="$2"
    local tmpfile
    tmpfile=$(mktemp)

    echo "$content" > "$tmpfile"

    printf "%b%s%b\n" "${BOLD}" "$title" "${RESET}"
    printf "Opening editor...\n"

    ${EDITOR:-nano} "$tmpfile"

    cat "$tmpfile"
    rm -f "$tmpfile"
}

# ============================================================================
# USAGE EXAMPLES AND DOCUMENTATION
# ============================================================================
#
# This library provides advanced TUI components for building sophisticated
# terminal user interfaces. Below are usage examples for each component.
#
# ============================================================================
# APPLICATION BROWSER EXAMPLE
# ============================================================================
#
# declare -A available_apps=(
#     [firefox]="Web Browsers|Firefox|Fast web browser|0|85 MB|native,flatpak"
#     [chrome]="Web Browsers|Chrome|Google browser|1|120 MB|native"
#     [gimp]="Graphics|GIMP|Image editor|0|200 MB|native,flatpak"
#     [blender]="Graphics|Blender|3D creation suite|0|350 MB|native,flatpak"
#     [vscode]="Development|VS Code|Code editor|1|250 MB|native,snap"
# )
#
# # Browse and select applications
# selected=$(tui_app_browser available_apps)
# echo "Selected apps: $selected"
#
# ============================================================================
# INSTALLATION PROGRESS EXAMPLE
# ============================================================================
#
# # Single app installation
# tui_install_progress "Firefox" "flatpak" "/tmp/firefox_install.log"
#
# # Batch installation
# declare -A batch=(
#     [0]="Firefox|pending|flatpak"
#     [1]="GIMP|pending|native"
#     [2]="VLC|pending|native"
# )
#
# # In background, update status as installations proceed
# batch[0]="Firefox|running|flatpak"
# # ... after completion
# batch[0]="Firefox|complete|flatpak"
#
# tui_batch_install batch
#
# ============================================================================
# WIZARD EXAMPLE
# ============================================================================
#
# step1() {
#     echo "Welcome to the installer!"
#     tui_keyvalue "OS" "$(uname -o)" "Kernel" "$(uname -r)"
# }
#
# step2() {
#     choice=$(tui_select "Select installation type" "Minimal" "Full" "Custom")
#     echo "Selected: $choice"
# }
#
# step3() {
#     apps=$(tui_multiselect_search "Select applications" "vim" "nano" "emacs")
#     echo "Selected: $apps"
# }
#
# declare -a wizard_steps=(
#     "Welcome:step1"
#     "Configuration:step2"
#     "Applications:step3"
# )
#
# tui_wizard wizard_steps
#
# ============================================================================
# TABLE AND DISPLAY EXAMPLES
# ============================================================================
#
# # Table
# tui_table "Package" "Version" "Status" -- \
#     "nginx" "1.18.0" "Installed" \
#     "apache2" "2.4.46" "Available" \
#     "mysql" "8.0.23" "Installed"
#
# # Key-value pairs
# tui_keyvalue \
#     "Hostname" "server01" \
#     "IP Address" "192.168.1.100" \
#     "Uptime" "15 days"
#
# # Multi-column list
# tui_list_columns vim nano emacs gedit kate sublime-text vscode atom
#
# # Task list with status
# tui_task_list "Build Process" \
#     "complete|Download sources" \
#     "running|Compile code" \
#     "pending|Run tests" \
#     "pending|Package release"
#
# ============================================================================
# PROGRESS AND STATUS EXAMPLES
# ============================================================================
#
# # Multiple progress bars
# declare -A tasks=(
#     [download]="Downloading|450|1000|running"
#     [extract]="Extracting|100|100|complete"
#     [install]="Installing|0|50|pending"
# )
# tui_progress_multi tasks
#
# # Step indicator
# tui_step_indicator 3 5 "Prepare" "Download" "Install" "Configure" "Complete"
#
# # Log viewer
# tui_log_viewer "/var/log/installation.log" "Installation Log"
#
# ============================================================================
# SELECTION EXAMPLES
# ============================================================================
#
# # Multi-select with search
# selected=$(tui_multiselect_search "Choose packages" \
#     "vim" "nano" "emacs" "gedit" "kate")
#
# # Select all / Deselect all
# selected=$(tui_select_all "Choose all you need" \
#     "Install updates" "Clean cache" "Optimize database" "Backup configs")
#
# # Grouped selection
# selected=$(tui_grouped_select "Select components" \
#     BROWSERS firefox chrome brave edge \
#     EDITORS vim nano emacs vscode \
#     MEDIA vlc mpv spotify)
#
# ============================================================================
# MENU NAVIGATION EXAMPLES
# ============================================================================
#
# # Category menu
# declare -A categories=(
#     [root:Web]="Web Browsers"
#     [root:Web:Firefox]="Firefox"
#     [root:Web:Chrome]="Chrome"
#     [root:Graphics]="Graphics Apps"
#     [root:Graphics:GIMP]="GIMP"
# )
# choice=$(tui_category_menu "Applications" categories)
#
# # Breadcrumb menu
# declare -a path=("Home" "Settings" "Network")
# choice=$(tui_breadcrumb_menu path "WiFi" "Ethernet" "VPN" "Proxy")
#
# ============================================================================
# SYSTEM SCAN AND OPTIMIZATION EXAMPLES
# ============================================================================
#
# # Hardware scan display
# declare -A scan_results=(
#     [CPU]="Intel Core i7-9700K @ 3.60GHz\\n8 cores, 8 threads"
#     [GPU]="NVIDIA GeForce RTX 2070\\nDriver: 470.129.06"
#     [Memory]="32 GB DDR4 @ 3200 MHz"
# )
# tui_scan_display scan_results
#
# # Optimization preview
# declare -A optimizations=(
#     ["CPU Governor"]="performance -> powersave"
#     ["I/O Scheduler"]="mq-deadline -> bfq"
#     ["Swappiness"]="60 -> 10"
#     ["Zram"]="disabled -> enabled (8GB)"
# )
# enabled=$(tui_optimization_preview optimizations)
#
# ============================================================================
# QUEUE MANAGEMENT EXAMPLE
# ============================================================================
#
# declare -a queue=(
#     "Update system packages"
#     "Install Firefox"
#     "Configure firewall"
#     "Enable automatic updates"
# )
#
# tui_queue_view queue
# # User can reorder, remove items, or execute
#
# ============================================================================
# FILE PICKER EXAMPLES
# ============================================================================
#
# # Pick a file
# config_file=$(tui_file_picker "Select configuration file" "/etc")
#
# # Pick a directory
# backup_dir=$(tui_dir_picker "Select backup directory" "/home")
#
# # Edit text
# new_content=$(tui_editor "Edit Configuration" "$(cat /etc/myapp.conf)")
#
# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
#
# # Truncate long text
# short=$(tui_truncate "This is a very long string" 20)
#
# # Format file sizes
# size=$(tui_format_bytes 1073741824)  # Returns "1 GB"
#
# # Wrap text to width
# wrapped=$(tui_wrap "Long paragraph text here..." 60)
#
# # Pad strings
# left=$(tui_pad "Text" 20 "left")
# right=$(tui_pad "Text" 20 "right")
# center=$(tui_pad "Text" 20 "center")
#
# # Draw boxes
# tui_box "Title" 60 "Line 1\\nLine 2\\nLine 3"
#
# ============================================================================
# STATE MANAGEMENT
# ============================================================================
#
# # Save UI state
# TUI_STATE[current_page]=2
# TUI_STATE[search_term]="firefox"
# tui_state_save "app_browser"
#
# # Restore UI state
# tui_state_restore "app_browser"
# echo "Current page: ${TUI_STATE[current_page]}"
#
# ============================================================================
# GRACEFUL FALLBACKS
# ============================================================================
#
# All functions automatically detect available tools (gum, fzf, dialog, whiptail)
# and fall back to basic bash implementations when tools are unavailable.
#
# Tool detection:
#   - TUI_HAS_GUM=1 if 'gum' is available
#   - TUI_HAS_FZF=1 if 'fzf' is available
#   - TUI_HAS_DIALOG=1 if 'dialog' is available
#   - TUI_HAS_WHIPTAIL=1 if 'whiptail' is available
#
# Functions automatically use the best available tool or provide fallback.
#
# ============================================================================
# INTEGRATION WITH APP INSTALLER
# ============================================================================
#
# The application browser and installation progress components are designed
# specifically for the app installer module. Key features:
#
# 1. Category-based browsing with search
# 2. Installation status tracking (installed/available)
# 3. Multiple installation method support (native/flatpak/snap/appimage)
# 4. Batch installation with individual progress tracking
# 5. Real-time log viewing during installation
# 6. Graceful error handling and retry options
#
# ============================================================================
