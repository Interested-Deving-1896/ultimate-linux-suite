#!/usr/bin/env bash
#
# test_tui_advanced.sh - Test script for advanced TUI components
#

set -euo pipefail

# Source the libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/tui.sh"
source "${SCRIPT_DIR}/lib/tui_advanced.sh"

# Initialize logging
logging_init

# ============================================================================
# Test 1: Helper functions
# ============================================================================

test_helpers() {
    log_section "Testing Helper Functions"

    echo "Truncate test:"
    tui_truncate "This is a very long string that needs to be truncated" 30

    echo -e "\nFormat bytes test:"
    tui_format_bytes 1024
    tui_format_bytes 1048576
    tui_format_bytes 1073741824

    echo -e "\nPadding test:"
    tui_pad "Left" 20 "left"
    tui_pad "Right" 20 "right"
    tui_pad "Center" 20 "center"

    pause
}

# ============================================================================
# Test 2: Box and display
# ============================================================================

test_box() {
    clear
    log_section "Testing Box Display"

    tui_box "Welcome" 60 "This is a test box
with multiple lines
of content to display"

    pause
}

# ============================================================================
# Test 3: Key-value display
# ============================================================================

test_keyvalue() {
    clear
    log_section "Testing Key-Value Display"

    tui_keyvalue \
        "Hostname" "$(hostname)" \
        "OS" "$(uname -o)" \
        "Kernel" "$(uname -r)" \
        "Architecture" "$(uname -m)" \
        "User" "$(whoami)"

    pause
}

# ============================================================================
# Test 4: Table display
# ============================================================================

test_table() {
    clear
    log_section "Testing Table Display"

    tui_table "Name" "Status" "Size" -- \
        "Package A" "Installed" "1.2 MB" \
        "Package B" "Available" "3.4 MB" \
        "Package C" "Installed" "512 KB"

    pause
}

# ============================================================================
# Test 5: Task list
# ============================================================================

test_task_list() {
    clear
    log_section "Testing Task List"

    tui_task_list "Installation Tasks" \
        "complete|Install dependencies" \
        "running|Configure system" \
        "pending|Run tests" \
        "failed|Deploy application"

    pause
}

# ============================================================================
# Test 6: Step indicator
# ============================================================================

test_steps() {
    clear
    log_section "Testing Step Indicator"

    tui_step_indicator 2 4 "Welcome" "Configure" "Install" "Complete"

    pause
}

# ============================================================================
# Test 7: App card
# ============================================================================

test_app_card() {
    clear
    log_section "Testing App Card"

    declare -A test_app=(
        [name]="Firefox"
        [category]="Web Browsers"
        [description]="Fast, privacy-focused web browser from Mozilla. Features include tracking protection, password manager, and extensive customization."
        [installed]=0
        [size]="85 MB"
        [methods]="native, flatpak, snap"
    )

    tui_app_card "firefox" test_app

    pause
}

# ============================================================================
# Test 8: Batch install display
# ============================================================================

test_batch() {
    clear
    log_section "Testing Batch Install"

    declare -A batch_apps=(
        [0]="Firefox|complete|flatpak"
        [1]="VLC|running|native"
        [2]="GIMP|pending|native"
        [3]="Blender|failed|flatpak"
    )

    tui_batch_install batch_apps
}

# ============================================================================
# Test 9: List columns
# ============================================================================

test_columns() {
    clear
    log_section "Testing Multi-Column List"

    tui_list_columns \
        "vim" "nano" "emacs" "gedit" \
        "firefox" "chrome" "brave" "edge" \
        "gimp" "inkscape" "blender" "krita" \
        "vlc" "mpv" "rhythmbox" "audacity"

    pause
}

# ============================================================================
# Main menu
# ============================================================================

main_menu() {
    while true; do
        clear
        log_section "TUI Advanced Component Test Suite"

        cat << EOF
Select a test to run:

  1) Helper functions (truncate, format, pad)
  2) Box display
  3) Key-value pairs
  4) Table display
  5) Task list
  6) Step indicator
  7) App card
  8) Batch installation
  9) Multi-column list
  0) Exit

EOF

        read -p "Enter choice [0-9]: " choice

        case "$choice" in
            1) test_helpers ;;
            2) test_box ;;
            3) test_keyvalue ;;
            4) test_table ;;
            5) test_task_list ;;
            6) test_steps ;;
            7) test_app_card ;;
            8) test_batch ;;
            9) test_columns ;;
            0) exit 0 ;;
            *) log_warn "Invalid choice" ; sleep 1 ;;
        esac
    done
}

# Run main menu
main_menu
