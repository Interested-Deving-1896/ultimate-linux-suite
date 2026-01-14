#!/usr/bin/env bash
# Unified Suite - Application Installer Module
# Source: Ported from Ultimate Linux Suite v5.0
# License: GPL-3.0-or-later

[[ -n "${_MOD_APP_INSTALLER_LOADED:-}" ]] && return 0
readonly _MOD_APP_INSTALLER_LOADED=1

# Source libraries
[[ -z "${_UNIFIED_PKG_LOADED:-}" ]] && source "${SUITE_ROOT}/lib/pkg.sh"
[[ -z "${_UNIFIED_TUI_LOADED:-}" ]] && source "${SUITE_ROOT}/lib/tui.sh"

# ============================================================
# APPLICATION CATEGORIES
# ============================================================

declare -A APP_BROWSERS=(
    ["firefox"]="firefox:Firefox Web Browser"
    ["chromium"]="chromium-browser chromium:Chromium Browser"
    ["brave"]="brave-browser:Brave Browser"
)

declare -A APP_DEV_TOOLS=(
    ["vscode"]="code:Visual Studio Code"
    ["git"]="git:Git Version Control"
    ["docker"]="docker.io docker:Docker Containers"
    ["nodejs"]="nodejs npm:Node.js Runtime"
    ["python"]="python3 python3-pip:Python 3"
)

declare -A APP_MEDIA=(
    ["vlc"]="vlc:VLC Media Player"
    ["gimp"]="gimp:GIMP Image Editor"
    ["audacity"]="audacity:Audacity Audio Editor"
    ["obs"]="obs-studio:OBS Studio"
)

declare -A APP_UTILITIES=(
    ["htop"]="htop:Htop Process Viewer"
    ["neofetch"]="neofetch:Neofetch System Info"
    ["tmux"]="tmux:Tmux Terminal Multiplexer"
    ["vim"]="vim:Vim Text Editor"
    ["curl"]="curl:cURL HTTP Client"
    ["wget"]="wget:Wget Downloader"
)

declare -A APP_COMMUNICATION=(
    ["discord"]="discord:Discord Chat"
    ["slack"]="slack-desktop:Slack"
    ["zoom"]="zoom:Zoom Video"
)

# ============================================================
# INSTALLER FUNCTIONS
# ============================================================

# Install app by key
install_app() {
    local app_key="$1"
    local packages=""
    local description=""

    # Search all categories
    for category in APP_BROWSERS APP_DEV_TOOLS APP_MEDIA APP_UTILITIES APP_COMMUNICATION; do
        declare -n cat_ref="$category"
        if [[ -n "${cat_ref[$app_key]:-}" ]]; then
            IFS=':' read -r packages description <<< "${cat_ref[$app_key]}"
            break
        fi
    done

    if [[ -z "$packages" ]]; then
        log_error "Unknown application: $app_key"
        return 1
    fi

    log_info "Installing: $description"
    pkg_install $packages
}

# Interactive category installer
install_category_interactive() {
    local category="$1"
    local title="$2"
    declare -n apps="$category"

    log_header "$title"

    local -a menu_items=()
    for key in "${!apps[@]}"; do
        IFS=':' read -r _ desc <<< "${apps[$key]}"
        menu_items+=("$key" "$desc" "off")
    done

    if tui_available; then
        local selected=$(tui_checklist "Select applications to install" "${menu_items[@]}")
        for app in $selected; do
            install_app "$app"
        done
    else
        echo "Available applications:"
        local i=1
        local -a keys=("${!apps[@]}")
        for key in "${keys[@]}"; do
            IFS=':' read -r _ desc <<< "${apps[$key]}"
            echo "  $i) $key - $desc"
            ((i++))
        done
        echo ""
        read -rp "Enter numbers to install (space-separated): " choices
        for choice in $choices; do
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#keys[@]} ]]; then
                install_app "${keys[$((choice-1))]}"
            fi
        done
    fi
}

# Main app installer menu
app_installer_menu() {
    log_header "Application Installer"

    local categories=(
        "browsers" "Web Browsers"
        "devtools" "Development Tools"
        "media" "Media Applications"
        "utilities" "System Utilities"
        "comm" "Communication"
        "all" "Install Essential Apps"
    )

    local choice=""
    if tui_available; then
        choice=$(tui_menu "Select Category" "${categories[@]}")
    else
        echo "Categories:"
        echo "  1) browsers  - Web Browsers"
        echo "  2) devtools  - Development Tools"
        echo "  3) media     - Media Applications"
        echo "  4) utilities - System Utilities"
        echo "  5) comm      - Communication"
        echo "  6) all       - Install Essential Apps"
        echo ""
        read -rp "Select: " num
        case "$num" in
            1) choice="browsers" ;;
            2) choice="devtools" ;;
            3) choice="media" ;;
            4) choice="utilities" ;;
            5) choice="comm" ;;
            6) choice="all" ;;
        esac
    fi

    case "$choice" in
        browsers) install_category_interactive "APP_BROWSERS" "Web Browsers" ;;
        devtools) install_category_interactive "APP_DEV_TOOLS" "Development Tools" ;;
        media)    install_category_interactive "APP_MEDIA" "Media Applications" ;;
        utilities) install_category_interactive "APP_UTILITIES" "System Utilities" ;;
        comm)     install_category_interactive "APP_COMMUNICATION" "Communication" ;;
        all)      install_essential_apps ;;
    esac
}

# Install essential apps
install_essential_apps() {
    log_section "Installing Essential Applications"

    local -a essentials=(
        "git"
        "curl"
        "wget"
        "htop"
        "vim"
        "tmux"
    )

    for app in "${essentials[@]}"; do
        install_app "$app"
    done

    log_success "Essential applications installed"
}
