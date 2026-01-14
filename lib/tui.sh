#!/usr/bin/env bash
# Unified Suite - TUI Abstraction
# Source: OffTrack Suite (updated)
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_TUI_LOADED:-}" ]] && return 0
readonly _UNIFIED_TUI_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_COLORS_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/colors.sh"

# ============================================================
# TUI BACKEND DETECTION
# ============================================================

declare -g TUI_BACKEND=""
declare -g TUI_AVAILABLE=0

# Detect available TUI backend
detect_tui_backend() {
    if command -v whiptail &>/dev/null; then
        TUI_BACKEND="whiptail"
        TUI_AVAILABLE=1
    elif command -v dialog &>/dev/null; then
        TUI_BACKEND="dialog"
        TUI_AVAILABLE=1
    else
        TUI_BACKEND="none"
        TUI_AVAILABLE=0
    fi
}

# Check if TUI is available
tui_available() {
    [[ $TUI_AVAILABLE -eq 1 ]]
}

# ============================================================
# TUI DIMENSIONS
# ============================================================

get_term_height() {
    tput lines 2>/dev/null || echo 24
}

get_term_width() {
    tput cols 2>/dev/null || echo 80
}

# ============================================================
# TUI WIDGETS
# ============================================================

# Message box
tui_msgbox() {
    local title="$1"
    local message="$2"
    local height=${3:-10}
    local width=${4:-60}

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        echo ""
        echo "=== $title ==="
        echo "$message"
        echo ""
        read -rp "Press Enter to continue..."
        return 0
    fi

    $TUI_BACKEND --title "$title" --msgbox "$message" $height $width
}

# Yes/No dialog
tui_yesno() {
    local title="$1"
    local message="$2"
    local height=${3:-10}
    local width=${4:-60}

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        read -rp "$message [y/N]: " response
        [[ "${response,,}" == "y" ]] && return 0 || return 1
    fi

    $TUI_BACKEND --title "$title" --yesno "$message" $height $width
}

# Input box
tui_inputbox() {
    local title="$1"
    local message="$2"
    local default="${3:-}"
    local height=${4:-10}
    local width=${5:-60}

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        read -rp "$message [$default]: " input
        echo "${input:-$default}"
        return 0
    fi

    $TUI_BACKEND --title "$title" --inputbox "$message" $height $width "$default" 3>&1 1>&2 2>&3
}

# Password box
tui_passwordbox() {
    local title="$1"
    local message="$2"
    local height=${3:-10}
    local width=${4:-60}

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        read -rsp "$message: " password
        echo ""
        echo "$password"
        return 0
    fi

    $TUI_BACKEND --title "$title" --passwordbox "$message" $height $width 3>&1 1>&2 2>&3
}

# Menu selection
tui_menu() {
    local title="$1"
    shift
    local height=${TUI_HEIGHT:-20}
    local width=${TUI_WIDTH:-70}
    local menu_height=$((height - 8))

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        echo ""
        echo "=== $title ==="
        local i=1
        local -a items=()
        while [[ $# -gt 0 ]]; do
            items+=("$1")
            echo "  $i) $1 - $2"
            shift 2
            ((i++))
        done
        echo ""
        read -rp "Selection: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#items[@]} ]]; then
            echo "${items[$((choice-1))]}"
        fi
        return 0
    fi

    $TUI_BACKEND --title "$title" --menu "Select an option:" \
        $height $width $menu_height "$@" 3>&1 1>&2 2>&3
}

# Checklist
tui_checklist() {
    local title="$1"
    shift
    local height=${TUI_HEIGHT:-20}
    local width=${TUI_WIDTH:-70}
    local list_height=$((height - 8))

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        echo ""
        echo "=== $title ==="
        echo "(Enter numbers separated by spaces)"
        local i=1
        local -a items=()
        while [[ $# -gt 0 ]]; do
            items+=("$1")
            echo "  $i) [$3] $1 - $2"
            shift 3
            ((i++))
        done
        echo ""
        read -rp "Selection: " choices
        for choice in $choices; do
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#items[@]} ]]; then
                echo "${items[$((choice-1))]}"
            fi
        done
        return 0
    fi

    $TUI_BACKEND --title "$title" --checklist "Select options:" \
        $height $width $list_height "$@" 3>&1 1>&2 2>&3
}

# Gauge/Progress
tui_gauge() {
    local title="$1"
    local message="$2"
    local percent="$3"
    local height=${4:-8}
    local width=${5:-60}

    if [[ $TUI_AVAILABLE -eq 0 ]]; then
        log_progress "$percent" 100 "$message"
        return 0
    fi

    echo "$percent" | $TUI_BACKEND --title "$title" --gauge "$message" $height $width 0
}

# Initialize
detect_tui_backend
