#!/usr/bin/env bash
#
# tui.sh - Terminal User Interface Abstraction Layer
#
# Provides a modern, unified TUI interface using gum (Charm.sh) as primary backend
# with graceful fallback to fzf, whiptail, and dialog for maximum compatibility.
#
# Features:
#   - Modern TUI using gum (Charm.sh) as primary with fzf as fallback
#   - Fall back to whiptail/dialog for maximum compatibility
#   - Support: menu rendering, checklists, radiolists, input prompts, confirmations
#   - Fuzzy search capability via fzf integration
#   - Terminal size awareness and responsive layouts
#   - Customizable color theming
#

# Prevent multiple sourcing
[[ -n "${_TUI_LOADED:-}" ]] && return 0
readonly _TUI_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging with fallback
if ! declare -f log_info &>/dev/null; then
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $*"; }
        log_success() { echo "[OK] $*"; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }
    }
fi

# ============================================================================
# Global TUI Configuration
# ============================================================================

# Backend selection (auto-detected or manually set)
declare -g TUI_BACKEND=""
declare -g TUI_AUTO_DETECT=1

# Terminal dimensions cache
declare -g TUI_TERM_ROWS=24
declare -g TUI_TERM_COLS=80

# Color theme configuration
declare -gA TUI_COLORS=(
    [primary]="#7C3AED"
    [secondary]="#06B6D4"
    [success]="#22C55E"
    [warning]="#F59E0B"
    [error]="#EF4444"
    [info]="#3B82F6"
    [accent]="#8B5CF6"
    [muted]="#6B7280"
)

# Current theme (dark/light)
declare -g TUI_THEME="dark"

# Spinner styles (used when gum is not available)
declare -gA TUI_SPINNERS=(
    [dots]='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    [line]='-\|/'
    [arrow]='←↖↑↗→↘↓↙'
    [circle]='◐◓◑◒'
    [bounce]='⠁⠂⠄⠂'
)

# Default spinner
declare -g TUI_SPINNER_STYLE="dots"

# ============================================================================
# Backend Detection Functions
# ============================================================================

# Check if gum is available
# Returns: 0 if available, 1 otherwise
tui_has_gum() {
    command -v gum &>/dev/null
}

# Check if fzf is available
# Returns: 0 if available, 1 otherwise
tui_has_fzf() {
    command -v fzf &>/dev/null
}

# Check if whiptail is available
# Returns: 0 if available, 1 otherwise
tui_has_whiptail() {
    command -v whiptail &>/dev/null
}

# Check if dialog is available
# Returns: 0 if available, 1 otherwise
tui_has_dialog() {
    command -v dialog &>/dev/null
}

# Detect the best available TUI backend
# Sets TUI_BACKEND to the detected backend
# Priority: gum > fzf > whiptail > dialog > basic
tui_detect_backend() {
    if [[ "$TUI_AUTO_DETECT" -eq 0 ]]; then
        log_debug "Auto-detection disabled, using manual backend: $TUI_BACKEND"
        return 0
    fi

    if tui_has_gum; then
        TUI_BACKEND="gum"
        log_debug "TUI backend detected: gum (Charm.sh)"
    elif tui_has_fzf; then
        TUI_BACKEND="fzf"
        log_debug "TUI backend detected: fzf"
    elif tui_has_whiptail; then
        TUI_BACKEND="whiptail"
        log_debug "TUI backend detected: whiptail"
    elif tui_has_dialog; then
        TUI_BACKEND="dialog"
        log_debug "TUI backend detected: dialog"
    else
        TUI_BACKEND="basic"
        log_warn "No TUI backend found, using basic fallback"
    fi

    # Update terminal dimensions
    tui_update_dimensions

    return 0
}

# Get current backend name
# Returns: The name of the current backend
tui_get_backend() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend
    echo "$TUI_BACKEND"
}

# Manually set the TUI backend
# Args:
#   $1 - backend: Backend name (gum, fzf, whiptail, dialog, basic)
# Returns: 0 on success, 1 if backend is not available
tui_set_backend() {
    local backend="$1"

    case "$backend" in
        gum)
            if ! tui_has_gum; then
                log_error "gum is not installed"
                return 1
            fi
            ;;
        fzf)
            if ! tui_has_fzf; then
                log_error "fzf is not installed"
                return 1
            fi
            ;;
        whiptail)
            if ! tui_has_whiptail; then
                log_error "whiptail is not installed"
                return 1
            fi
            ;;
        dialog)
            if ! tui_has_dialog; then
                log_error "dialog is not installed"
                return 1
            fi
            ;;
        basic)
            # Basic fallback always available
            ;;
        *)
            log_error "Unknown backend: $backend"
            return 1
            ;;
    esac

    TUI_BACKEND="$backend"
    TUI_AUTO_DETECT=0
    log_info "TUI backend manually set to: $backend"
    return 0
}

# ============================================================================
# Terminal Dimension Functions
# ============================================================================

# Get current terminal dimensions
# Returns: "ROWS COLS" as space-separated string
tui_get_dimensions() {
    local rows cols
    rows=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)
    echo "$rows $cols"
}

# Update cached terminal dimensions
tui_update_dimensions() {
    local dims
    dims=$(tui_get_dimensions)
    read -r TUI_TERM_ROWS TUI_TERM_COLS <<< "$dims"
    log_debug "Terminal dimensions: ${TUI_TERM_ROWS}x${TUI_TERM_COLS}"
}

# Check if terminal can fit a dialog of specified size
# Args:
#   $1 - min_rows: Minimum required rows (default: 20)
#   $2 - min_cols: Minimum required columns (default: 60)
# Returns: 0 if fits, 1 otherwise
tui_fits_dialog() {
    local min_rows="${1:-20}"
    local min_cols="${2:-60}"

    tui_update_dimensions

    [[ $TUI_TERM_ROWS -ge $min_rows && $TUI_TERM_COLS -ge $min_cols ]]
}

# Calculate optimal dialog size for current terminal
# Args:
#   $1 - percentage: Percentage of screen to use (default: 80)
# Returns: "rows cols" as space-separated string
tui_calc_dialog_size() {
    local percentage="${1:-80}"

    tui_update_dimensions

    local rows=$((TUI_TERM_ROWS * percentage / 100))
    local cols=$((TUI_TERM_COLS * percentage / 100))

    # Enforce minimums
    [[ $rows -lt 10 ]] && rows=10
    [[ $cols -lt 40 ]] && cols=40

    echo "$rows $cols"
}

# ============================================================================
# Theme Management
# ============================================================================

# Set color theme
# Args:
#   $1 - theme: Theme name (dark, light, custom)
tui_set_theme() {
    local theme="$1"

    case "$theme" in
        dark)
            TUI_COLORS[primary]="#7C3AED"
            TUI_COLORS[secondary]="#06B6D4"
            TUI_COLORS[success]="#22C55E"
            TUI_COLORS[warning]="#F59E0B"
            TUI_COLORS[error]="#EF4444"
            TUI_COLORS[info]="#3B82F6"
            TUI_COLORS[accent]="#8B5CF6"
            TUI_COLORS[muted]="#6B7280"
            TUI_THEME="dark"
            ;;
        light)
            TUI_COLORS[primary]="#6D28D9"
            TUI_COLORS[secondary]="#0891B2"
            TUI_COLORS[success]="#16A34A"
            TUI_COLORS[warning]="#D97706"
            TUI_COLORS[error]="#DC2626"
            TUI_COLORS[info]="#2563EB"
            TUI_COLORS[accent]="#7C3AED"
            TUI_COLORS[muted]="#9CA3AF"
            TUI_THEME="light"
            ;;
        *)
            log_warn "Unknown theme: $theme, keeping current theme"
            return 1
            ;;
    esac

    log_debug "Theme set to: $theme"
    return 0
}

# Get color from theme
# Args:
#   $1 - color_name: Color name (primary, secondary, success, etc.)
# Returns: Hex color code
tui_get_color() {
    local color_name="$1"
    echo "${TUI_COLORS[$color_name]:-${TUI_COLORS[primary]}}"
}

# ============================================================================
# Backend Implementation: Gum
# ============================================================================

# Gum: Show menu
_tui_gum_menu() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No menu items provided"
        return 1
    fi

    gum choose --header="$title" --header.foreground="$(tui_get_color primary)" "$@"
}

# Gum: Confirmation prompt
_tui_gum_confirm() {
    local question="$1"
    local default="${2:-no}"

    if [[ "${default,,}" == "yes" ]]; then
        gum confirm "$question" --default=true --affirmative="Yes" --negative="No"
    else
        gum confirm "$question" --default=false --affirmative="Yes" --negative="No"
    fi
}

# Gum: Text input
_tui_gum_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    local args=(--prompt="$prompt ")
    [[ -n "$default" ]] && args+=(--value="$default")
    [[ -n "$placeholder" ]] && args+=(--placeholder="$placeholder")

    gum input "${args[@]}"
}

# Gum: Password input
_tui_gum_password() {
    local prompt="$1"

    gum input --password --prompt="$prompt "
}

# Gum: Checklist (multi-select)
_tui_gum_checklist() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No checklist items provided"
        return 1
    fi

    gum choose --no-limit --header="$title" --header.foreground="$(tui_get_color primary)" "$@"
}

# Gum: Filter/search
_tui_gum_filter() {
    local prompt="$1"

    gum filter --placeholder="$prompt" --indicator="→" --prompt="🔍 "
}

# Gum: Spinner
_tui_gum_spinner() {
    local pid="$1"
    local message="$2"

    gum spin --spinner dot --title "$message" -- bash -c "while kill -0 $pid 2>/dev/null; do sleep 0.1; done"
}

# Gum: Progress bar
_tui_gum_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"

    local percent=$((current * 100 / total))
    echo "$percent" | gum progress --title="$message"
}

# ============================================================================
# Backend Implementation: fzf
# ============================================================================

# fzf: Show menu
_tui_fzf_menu() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No menu items provided"
        return 1
    fi

    printf '%s\n' "$@" | fzf --prompt="$title: " --height=40% --reverse --border --info=inline
}

# fzf: Confirmation (simulated)
_tui_fzf_confirm() {
    local question="$1"
    local default="${2:-no}"

    local choice
    if [[ "${default,,}" == "yes" ]]; then
        choice=$(printf 'Yes\nNo' | fzf --prompt="$question " --height=3 --reverse --border)
    else
        choice=$(printf 'No\nYes' | fzf --prompt="$question " --height=3 --reverse --border)
    fi

    [[ "${choice,,}" == "yes" ]]
}

# fzf: Text input (uses read with prompt)
_tui_fzf_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    local display_prompt="$prompt"
    [[ -n "$placeholder" ]] && display_prompt="$prompt ($placeholder)"
    [[ -n "$default" ]] && display_prompt="$display_prompt [$default]"

    printf "%s: " "$display_prompt" >&2
    local input
    read -r input
    echo "${input:-$default}"
}

# fzf: Password input
_tui_fzf_password() {
    local prompt="$1"

    printf "%s: " "$prompt" >&2
    local password
    read -r -s password
    echo "" >&2
    echo "$password"
}

# fzf: Checklist (multi-select)
_tui_fzf_checklist() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No checklist items provided"
        return 1
    fi

    printf '%s\n' "$@" | fzf --multi --prompt="$title (TAB to select): " --height=40% --reverse --border --info=inline
}

# fzf: Filter/search
_tui_fzf_filter() {
    local prompt="$1"

    fzf --prompt="$prompt: " --height=40% --reverse --border --info=inline
}

# fzf: Spinner (fallback to basic)
_tui_fzf_spinner() {
    _tui_basic_spinner "$@"
}

# fzf: Progress (fallback to basic)
_tui_fzf_progress() {
    _tui_basic_progress "$@"
}

# ============================================================================
# Backend Implementation: Whiptail
# ============================================================================

# whiptail: Show menu
_tui_whiptail_menu() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No menu items provided"
        return 1
    fi

    local items=()
    local i=1
    for item in "$@"; do
        items+=("$i" "$item")
        ((i++))
    done

    local size
    size=$(tui_calc_dialog_size 80)
    local rows cols
    read -r rows cols <<< "$size"

    local menu_height=$((rows - 8))
    [[ $menu_height -lt 5 ]] && menu_height=5

    local choice
    choice=$(whiptail --title "$title" --menu "Select an option:" "$rows" "$cols" "$menu_height" "${items[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$choice" ]]; then
        # Return the actual item text, not the number
        local idx=$((choice - 1))
        shift "$idx"
        echo "$1"
        return 0
    else
        return 1
    fi
}

# whiptail: Confirmation
_tui_whiptail_confirm() {
    local question="$1"
    local default="${2:-no}"

    local size
    size=$(tui_calc_dialog_size 50)
    local rows cols
    read -r rows cols <<< "$size"
    rows=$((rows / 2))

    if [[ "${default,,}" == "yes" ]]; then
        whiptail --title "Confirm" --yesno "$question" "$rows" "$cols" --defaultno
    else
        whiptail --title "Confirm" --yesno "$question" "$rows" "$cols"
    fi
}

# whiptail: Text input
_tui_whiptail_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    local size
    size=$(tui_calc_dialog_size 50)
    local rows cols
    read -r rows cols <<< "$size"
    rows=$((rows / 2))

    local display_prompt="$prompt"
    [[ -n "$placeholder" ]] && display_prompt="$display_prompt\n($placeholder)"

    whiptail --title "Input" --inputbox "$display_prompt" "$rows" "$cols" "$default" 3>&1 1>&2 2>&3
}

# whiptail: Password input
_tui_whiptail_password() {
    local prompt="$1"

    local size
    size=$(tui_calc_dialog_size 50)
    local rows cols
    read -r rows cols <<< "$size"
    rows=$((rows / 2))

    whiptail --title "Password" --passwordbox "$prompt" "$rows" "$cols" 3>&1 1>&2 2>&3
}

# whiptail: Checklist
_tui_whiptail_checklist() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No checklist items provided"
        return 1
    fi

    local items=()
    local i=1
    for item in "$@"; do
        items+=("$i" "$item" "OFF")
        ((i++))
    done

    local size
    size=$(tui_calc_dialog_size 80)
    local rows cols
    read -r rows cols <<< "$size"

    local menu_height=$((rows - 8))
    [[ $menu_height -lt 5 ]] && menu_height=5

    local choices
    choices=$(whiptail --title "$title" --checklist "Select items (SPACE to toggle):" "$rows" "$cols" "$menu_height" "${items[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$choices" ]]; then
        # Convert indices back to item text
        local selected=()
        for idx in $choices; do
            # Remove quotes
            idx="${idx//\"/}"
            local item_idx=$((idx - 1))
            local args=("$@")
            selected+=("${args[$item_idx]}")
        done
        printf '%s\n' "${selected[@]}"
        return 0
    else
        return 1
    fi
}

# whiptail: Filter (fallback to menu)
_tui_whiptail_filter() {
    local prompt="$1"

    local input
    mapfile -t input

    _tui_whiptail_menu "$prompt" "${input[@]}"
}

# whiptail: Spinner (fallback to basic)
_tui_whiptail_spinner() {
    _tui_basic_spinner "$@"
}

# whiptail: Progress
_tui_whiptail_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"

    local percent=$((current * 100 / total))

    echo "$percent" | whiptail --title "$message" --gauge "" 6 60 0
}

# ============================================================================
# Backend Implementation: Dialog
# ============================================================================

# dialog: Show menu
_tui_dialog_menu() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No menu items provided"
        return 1
    fi

    local items=()
    local i=1
    for item in "$@"; do
        items+=("$i" "$item")
        ((i++))
    done

    local size
    size=$(tui_calc_dialog_size 80)
    local rows cols
    read -r rows cols <<< "$size"

    local menu_height=$((rows - 8))
    [[ $menu_height -lt 5 ]] && menu_height=5

    local choice
    choice=$(dialog --stdout --title "$title" --menu "Select an option:" "$rows" "$cols" "$menu_height" "${items[@]}")

    if [[ -n "$choice" ]]; then
        # Return the actual item text, not the number
        local idx=$((choice - 1))
        shift "$idx"
        echo "$1"
        return 0
    else
        return 1
    fi
}

# dialog: Confirmation
_tui_dialog_confirm() {
    local question="$1"
    local default="${2:-no}"

    local size
    size=$(tui_calc_dialog_size 50)
    local rows cols
    read -r rows cols <<< "$size"
    rows=$((rows / 2))

    if [[ "${default,,}" == "yes" ]]; then
        dialog --stdout --title "Confirm" --defaultno --yesno "$question" "$rows" "$cols"
    else
        dialog --stdout --title "Confirm" --yesno "$question" "$rows" "$cols"
    fi
}

# dialog: Text input
_tui_dialog_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    local size
    size=$(tui_calc_dialog_size 50)
    local rows cols
    read -r rows cols <<< "$size"
    rows=$((rows / 2))

    local display_prompt="$prompt"
    [[ -n "$placeholder" ]] && display_prompt="$display_prompt\n($placeholder)"

    dialog --stdout --title "Input" --inputbox "$display_prompt" "$rows" "$cols" "$default"
}

# dialog: Password input
_tui_dialog_password() {
    local prompt="$1"

    local size
    size=$(tui_calc_dialog_size 50)
    local rows cols
    read -r rows cols <<< "$size"
    rows=$((rows / 2))

    dialog --stdout --title "Password" --passwordbox "$prompt" "$rows" "$cols"
}

# dialog: Checklist
_tui_dialog_checklist() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No checklist items provided"
        return 1
    fi

    local items=()
    local i=1
    for item in "$@"; do
        items+=("$i" "$item" "off")
        ((i++))
    done

    local size
    size=$(tui_calc_dialog_size 80)
    local rows cols
    read -r rows cols <<< "$size"

    local menu_height=$((rows - 8))
    [[ $menu_height -lt 5 ]] && menu_height=5

    local choices
    choices=$(dialog --stdout --title "$title" --checklist "Select items (SPACE to toggle):" "$rows" "$cols" "$menu_height" "${items[@]}")

    if [[ -n "$choices" ]]; then
        # Convert indices back to item text
        local selected=()
        for idx in $choices; do
            # Remove quotes
            idx="${idx//\"/}"
            local item_idx=$((idx - 1))
            local args=("$@")
            selected+=("${args[$item_idx]}")
        done
        printf '%s\n' "${selected[@]}"
        return 0
    else
        return 1
    fi
}

# dialog: Filter (fallback to menu)
_tui_dialog_filter() {
    local prompt="$1"

    local input
    mapfile -t input

    _tui_dialog_menu "$prompt" "${input[@]}"
}

# dialog: Spinner (fallback to basic)
_tui_dialog_spinner() {
    _tui_basic_spinner "$@"
}

# dialog: Progress
_tui_dialog_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"

    local percent=$((current * 100 / total))

    echo "$percent" | dialog --title "$message" --gauge "" 6 60 0
}

# ============================================================================
# Backend Implementation: Basic (fallback)
# ============================================================================

# Basic: Show menu
_tui_basic_menu() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No menu items provided"
        return 1
    fi

    echo ""
    echo "=== $title ==="
    echo ""

    local items=("$@")
    local i=1
    for item in "${items[@]}"; do
        printf "  %d) %s\n" "$i" "$item"
        ((i++))
    done

    echo ""
    printf "Select [1-%d]: " "${#items[@]}"

    local choice
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#items[@]} ]]; then
        echo "${items[$((choice - 1))]}"
        return 0
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Basic: Confirmation
_tui_basic_confirm() {
    local question="$1"
    local default="${2:-no}"

    local prompt
    if [[ "${default,,}" == "yes" ]]; then
        prompt="$question [Y/n]: "
    else
        prompt="$question [y/N]: "
    fi

    printf "%s" "$prompt"
    local response
    read -r response
    response="${response:-$default}"

    [[ "${response,,}" =~ ^y(es)?$ ]]
}

# Basic: Text input
_tui_basic_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    local display_prompt="$prompt"
    [[ -n "$placeholder" ]] && display_prompt="$display_prompt ($placeholder)"
    [[ -n "$default" ]] && display_prompt="$display_prompt [$default]"

    printf "%s: " "$display_prompt"
    local input
    read -r input
    echo "${input:-$default}"
}

# Basic: Password input
_tui_basic_password() {
    local prompt="$1"

    printf "%s: " "$prompt"
    local password
    read -r -s password
    echo "" >&2
    echo "$password"
}

# Basic: Checklist
_tui_basic_checklist() {
    local title="$1"
    shift

    if [[ $# -eq 0 ]]; then
        log_error "No checklist items provided"
        return 1
    fi

    echo ""
    echo "=== $title ==="
    echo ""

    local items=("$@")
    local i=1
    for item in "${items[@]}"; do
        printf "  %d) %s\n" "$i" "$item"
        ((i++))
    done

    echo ""
    echo "Enter numbers separated by spaces (e.g., '1 3 5'), or 'all' for all items:"
    printf "Selection: "

    local choice
    read -r choice

    if [[ "${choice,,}" == "all" ]]; then
        printf '%s\n' "${items[@]}"
        return 0
    fi

    local selected=()
    for idx in $choice; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && [[ $idx -ge 1 ]] && [[ $idx -le ${#items[@]} ]]; then
            selected+=("${items[$((idx - 1))]}")
        fi
    done

    if [[ ${#selected[@]} -gt 0 ]]; then
        printf '%s\n' "${selected[@]}"
        return 0
    else
        log_error "No valid selections"
        return 1
    fi
}

# Basic: Filter (simple grep)
_tui_basic_filter() {
    local prompt="$1"

    printf "%s: " "$prompt" >&2
    local pattern
    read -r pattern

    if [[ -n "$pattern" ]]; then
        grep -i "$pattern"
    else
        cat
    fi
}

# Basic: Spinner
_tui_basic_spinner() {
    local pid="$1"
    local message="$2"
    local spin="${TUI_SPINNERS[$TUI_SPINNER_STYLE]}"
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s " "${spin:i++%${#spin}:1}" "$message"
        sleep 0.1
    done
    printf "\r\033[K"
}

# Basic: Progress bar
_tui_basic_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r%s: [" "$message"
    printf "%*s" "$filled" "" | tr ' ' '#'
    printf "%*s" "$empty" "" | tr ' ' '-'
    printf "] %3d%%" "$percent"

    # Newline when complete
    [[ "$current" -eq "$total" ]] && printf "\n"
}

# ============================================================================
# Unified TUI Functions (Auto-dispatch to backend)
# ============================================================================

# Show a menu and return the selected item
# Args:
#   $1 - title: Menu title
#   $@ - items: Menu items
# Returns: Selected item (stdout), exit code 0 on success
tui_menu() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local title="$1"
    shift

    case "$TUI_BACKEND" in
        gum)      _tui_gum_menu "$title" "$@" ;;
        fzf)      _tui_fzf_menu "$title" "$@" ;;
        whiptail) _tui_whiptail_menu "$title" "$@" ;;
        dialog)   _tui_dialog_menu "$title" "$@" ;;
        *)        _tui_basic_menu "$title" "$@" ;;
    esac
}

# Alias for menu with different name
tui_choose() {
    tui_menu "$@"
}

# Show a confirmation dialog
# Args:
#   $1 - question: Question to ask
#   $2 - default: Default answer (yes/no, optional)
# Returns: 0 for yes, 1 for no
tui_confirm() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local question="$1"
    local default="${2:-no}"

    case "$TUI_BACKEND" in
        gum)      _tui_gum_confirm "$question" "$default" ;;
        fzf)      _tui_fzf_confirm "$question" "$default" ;;
        whiptail) _tui_whiptail_confirm "$question" "$default" ;;
        dialog)   _tui_dialog_confirm "$question" "$default" ;;
        *)        _tui_basic_confirm "$question" "$default" ;;
    esac
}

# Show an input prompt
# Args:
#   $1 - prompt: Input prompt
#   $2 - default: Default value (optional)
#   $3 - placeholder: Placeholder text (optional)
# Returns: User input (stdout)
tui_input() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    case "$TUI_BACKEND" in
        gum)      _tui_gum_input "$prompt" "$default" "$placeholder" ;;
        fzf)      _tui_fzf_input "$prompt" "$default" "$placeholder" ;;
        whiptail) _tui_whiptail_input "$prompt" "$default" "$placeholder" ;;
        dialog)   _tui_dialog_input "$prompt" "$default" "$placeholder" ;;
        *)        _tui_basic_input "$prompt" "$default" "$placeholder" ;;
    esac
}

# Show a password input prompt
# Args:
#   $1 - prompt: Password prompt
# Returns: Password (stdout)
tui_password() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local prompt="$1"

    case "$TUI_BACKEND" in
        gum)      _tui_gum_password "$prompt" ;;
        fzf)      _tui_fzf_password "$prompt" ;;
        whiptail) _tui_whiptail_password "$prompt" ;;
        dialog)   _tui_dialog_password "$prompt" ;;
        *)        _tui_basic_password "$prompt" ;;
    esac
}

# Show a checklist (multi-select)
# Args:
#   $1 - title: Checklist title
#   $@ - items: Checklist items
# Returns: Selected items (newline-separated, stdout)
tui_checklist() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local title="$1"
    shift

    case "$TUI_BACKEND" in
        gum)      _tui_gum_checklist "$title" "$@" ;;
        fzf)      _tui_fzf_checklist "$title" "$@" ;;
        whiptail) _tui_whiptail_checklist "$title" "$@" ;;
        dialog)   _tui_dialog_checklist "$title" "$@" ;;
        *)        _tui_basic_checklist "$title" "$@" ;;
    esac
}

# Show a radio list (single select, alias for menu)
# Args:
#   $1 - title: Radio list title
#   $@ - items: Radio list items
# Returns: Selected item (stdout)
tui_radiolist() {
    tui_menu "$@"
}

# Filter items using fuzzy search
# Args:
#   $1 - prompt: Search prompt
#   stdin - items: Items to filter (newline-separated)
# Returns: Selected item (stdout)
tui_filter() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local prompt="$1"

    case "$TUI_BACKEND" in
        gum)      _tui_gum_filter "$prompt" ;;
        fzf)      _tui_fzf_filter "$prompt" ;;
        whiptail) _tui_whiptail_filter "$prompt" ;;
        dialog)   _tui_dialog_filter "$prompt" ;;
        *)        _tui_basic_filter "$prompt" ;;
    esac
}

# Search through items
# Args:
#   $1 - prompt: Search prompt
#   $@ - items: Items to search through
# Returns: Selected item (stdout)
tui_search() {
    local prompt="$1"
    shift

    printf '%s\n' "$@" | tui_filter "$prompt"
}

# Show a spinner while a process runs
# Args:
#   $1 - pid: Process ID to monitor
#   $2 - message: Spinner message
tui_spinner() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local pid="$1"
    local message="$2"

    case "$TUI_BACKEND" in
        gum)      _tui_gum_spinner "$pid" "$message" ;;
        fzf)      _tui_fzf_spinner "$pid" "$message" ;;
        whiptail) _tui_whiptail_spinner "$pid" "$message" ;;
        dialog)   _tui_dialog_spinner "$pid" "$message" ;;
        *)        _tui_basic_spinner "$pid" "$message" ;;
    esac
}

# Show a progress bar
# Args:
#   $1 - current: Current progress value
#   $2 - total: Total progress value
#   $3 - message: Progress message (optional)
tui_progress() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local current="$1"
    local total="$2"
    local message="${3:-Progress}"

    case "$TUI_BACKEND" in
        gum)      _tui_gum_progress "$current" "$total" "$message" ;;
        fzf)      _tui_fzf_progress "$current" "$total" "$message" ;;
        whiptail) _tui_whiptail_progress "$current" "$total" "$message" ;;
        dialog)   _tui_dialog_progress "$current" "$total" "$message" ;;
        *)        _tui_basic_progress "$current" "$total" "$message" ;;
    esac
}

# ============================================================================
# Visual Feedback Functions
# ============================================================================

# Show a message box
# Args:
#   $1 - type: Message type (info, warn, error, success)
#   $2 - title: Message title
#   $3 - message: Message text
tui_message() {
    [[ -z "$TUI_BACKEND" ]] && tui_detect_backend

    local type="$1"
    local title="$2"
    local message="$3"

    case "$TUI_BACKEND" in
        gum)
            local color
            case "$type" in
                info)    color="$(tui_get_color info)" ;;
                warn)    color="$(tui_get_color warning)" ;;
                error)   color="$(tui_get_color error)" ;;
                success) color="$(tui_get_color success)" ;;
                *)       color="$(tui_get_color primary)" ;;
            esac
            gum style --border double --border-foreground="$color" --padding="1 2" --margin="1 2" "$(gum style --bold "$title")

$message"
            ;;
        whiptail)
            local size
            size=$(tui_calc_dialog_size 60)
            local rows cols
            read -r rows cols <<< "$size"
            whiptail --title "$title" --msgbox "$message" "$rows" "$cols"
            ;;
        dialog)
            local size
            size=$(tui_calc_dialog_size 60)
            local rows cols
            read -r rows cols <<< "$size"
            dialog --title "$title" --msgbox "$message" "$rows" "$cols"
            ;;
        *)
            echo ""
            echo "=== $title ==="
            echo "$message"
            echo ""
            ;;
    esac
}

# Show a notification
# Args:
#   $1 - title: Notification title
#   $2 - message: Notification message
tui_notify() {
    local title="$1"
    local message="$2"

    if tui_has_gum; then
        gum style --border rounded --border-foreground="$(tui_get_color accent)" --padding="0 1" "$title: $message"
    else
        echo "[$title] $message"
    fi
}

# ============================================================================
# Demonstration Function
# ============================================================================

# Demonstrate all TUI capabilities
tui_demo() {
    log_section "TUI Abstraction Layer Demo"

    # Detect backend
    tui_detect_backend
    echo "Current backend: $(tui_get_backend)"
    echo ""

    # Test terminal dimensions
    echo "Terminal dimensions: ${TUI_TERM_ROWS}x${TUI_TERM_COLS}"
    tui_fits_dialog && echo "Terminal can fit standard dialogs" || echo "Terminal is too small for some dialogs"
    echo ""

    # Test menu
    echo "Testing menu..."
    local choice
    choice=$(tui_menu "Select a color" "Red" "Green" "Blue" "Yellow")
    echo "You selected: $choice"
    echo ""

    # Test confirmation
    echo "Testing confirmation..."
    if tui_confirm "Do you like this demo?"; then
        echo "Great!"
    else
        echo "We'll improve it!"
    fi
    echo ""

    # Test input
    echo "Testing input..."
    local name
    name=$(tui_input "What's your name?" "User" "Enter your name")
    echo "Hello, $name!"
    echo ""

    # Test checklist
    echo "Testing checklist..."
    local selected
    selected=$(tui_checklist "Select features" "Fast" "Reliable" "User-friendly" "Powerful")
    echo "Selected features:"
    echo "$selected"
    echo ""

    # Test search
    echo "Testing search..."
    local result
    result=$(tui_search "Search for a programming language" "Bash" "Python" "JavaScript" "Rust" "Go" "Ruby" "PHP")
    echo "You selected: $result"
    echo ""

    # Test progress
    echo "Testing progress bar..."
    for i in {1..10}; do
        tui_progress "$i" 10 "Processing"
        sleep 0.2
    done
    echo ""

    # Test spinner
    echo "Testing spinner..."
    sleep 3 &
    local pid=$!
    tui_spinner "$pid" "Working on something"
    echo "Done!"
    echo ""

    # Test message box
    echo "Testing message box..."
    tui_message "success" "Demo Complete" "All TUI components have been demonstrated successfully!"

    log_success "TUI demo completed!"
}

# ============================================================================
# Initialization
# ============================================================================

# Auto-detect backend on load
tui_detect_backend

# ============================================================================
# TUI ABSTRACTION LAYER DOCUMENTATION
# ============================================================================
#
# This library provides a comprehensive TUI abstraction layer with automatic
# backend detection and graceful fallback support.
#
# SUPPORTED BACKENDS (in priority order):
#   1. gum (Charm.sh) - Modern, beautiful TUI with rich features
#   2. fzf - Fast fuzzy finder with good interactivity
#   3. whiptail - Classic dialog tool, widely available
#   4. dialog - Enhanced version of whiptail
#   5. basic - Pure bash fallback, always available
#
# CORE FUNCTIONS:
#
#   Backend Management:
#     tui_detect_backend()           - Auto-detect best backend
#     tui_get_backend()              - Get current backend name
#     tui_set_backend(name)          - Manually set backend
#     tui_has_gum/fzf/whiptail/dialog() - Check if tool is available
#
#   Menu & Selection:
#     tui_menu(title, items...)      - Show menu, return selection
#     tui_choose(title, items...)    - Alias for menu
#     tui_radiolist(title, items...) - Single select (alias for menu)
#     tui_checklist(title, items...) - Multi-select, return list
#
#   User Input:
#     tui_confirm(question, default) - Yes/no prompt
#     tui_input(prompt, default, ph) - Text input
#     tui_password(prompt)           - Hidden password input
#
#   Search & Filter:
#     tui_filter(prompt) < items     - Fuzzy filter from stdin
#     tui_search(prompt, items...)   - Search through items
#
#   Visual Feedback:
#     tui_spinner(pid, message)      - Show spinner while PID runs
#     tui_progress(cur, tot, msg)    - Progress bar
#     tui_message(type, title, msg)  - Message box
#     tui_notify(title, message)     - Toast notification
#
#   Terminal Info:
#     tui_get_dimensions()           - Get terminal size
#     tui_fits_dialog(rows, cols)    - Check if dialog fits
#     tui_calc_dialog_size(percent)  - Calculate optimal size
#
#   Theming:
#     tui_set_theme(name)            - Set color theme
#     tui_get_color(name)            - Get theme color
#
#   Demo:
#     tui_demo()                     - Interactive demonstration
#
# USAGE EXAMPLES:
#
#   # Simple menu
#   choice=$(tui_menu "Main Menu" "Install" "Update" "Remove")
#   echo "You selected: $choice"
#
#   # Confirmation
#   if tui_confirm "Continue with installation?"; then
#       echo "Installing..."
#   fi
#
#   # Multi-select
#   packages=$(tui_checklist "Select packages" "vim" "git" "curl")
#   echo "$packages" | while read -r pkg; do
#       echo "Installing $pkg"
#   done
#
#   # Fuzzy search
#   file=$(find . -type f | tui_filter "Select file")
#
#   # Progress bar
#   for i in {1..100}; do
#       tui_progress "$i" 100 "Processing files"
#       sleep 0.1
#   done
#
#   # Spinner
#   long_command &
#   tui_spinner $! "Running long command"
#
# BACKEND-SPECIFIC FEATURES:
#
#   gum:
#     - Rich colors and borders
#     - Smooth animations
#     - Best visual experience
#
#   fzf:
#     - Fast fuzzy matching
#     - Good keyboard navigation
#     - Preview support (not yet implemented)
#
#   whiptail/dialog:
#     - Classic TUI appearance
#     - Good for scripts
#     - Wide compatibility
#
#   basic:
#     - Works everywhere
#     - No external dependencies
#     - Simple but functional
#
# INSTALLATION RECOMMENDATIONS:
#
#   For best experience, install gum:
#     # On Debian/Ubuntu
#     sudo apt install gum
#
#     # On Fedora
#     sudo dnf install gum
#
#     # Using go
#     go install github.com/charmbracelet/gum@latest
#
#   Alternative: Install fzf
#     # On Debian/Ubuntu
#     sudo apt install fzf
#
#     # On Fedora
#     sudo dnf install fzf
#
# ============================================================================
