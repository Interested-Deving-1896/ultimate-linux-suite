#!/usr/bin/env bash
#
# database.sh - Application Database for Ultimate Linux Suite
#
# Comprehensive app definitions with cross-distro package mappings
#

# Prevent multiple sourcing
[[ -n "${_APPS_DATABASE_LOADED:-}" ]] && return 0
readonly _APPS_DATABASE_LOADED=1

# ============================================================================
# Application Database Structure
# Format: APP_NAME|CATEGORY|DESCRIPTION|APT_PKG|DNF_PKG|PACMAN_PKG|ZYPPER_PKG|FLATPAK_ID|CHECK_CMD
# ============================================================================

declare -ga APP_DATABASE=(
    # ========== BROWSERS ==========
    "firefox|browsers|Mozilla Firefox web browser|firefox|firefox|firefox|firefox|org.mozilla.firefox|firefox"
    "firefox-esr|browsers|Firefox Extended Support Release|firefox-esr|firefox|firefox|firefox|org.mozilla.firefox|firefox"
    "chromium|browsers|Open-source Chrome browser|chromium-browser|chromium|chromium|chromium|org.chromium.Chromium|chromium"
    "google-chrome|browsers|Google Chrome browser|google-chrome-stable|google-chrome-stable|google-chrome|google-chrome-stable|com.google.Chrome|google-chrome"
    "brave|browsers|Brave privacy browser|brave-browser|brave-browser|brave-bin|brave-browser|com.brave.Browser|brave-browser"
    "vivaldi|browsers|Vivaldi browser|vivaldi-stable|vivaldi-stable|vivaldi|vivaldi|com.vivaldi.Vivaldi|vivaldi"
    "opera|browsers|Opera browser|opera-stable|opera-stable|opera|opera|com.opera.Opera|opera"

    # ========== DEVELOPMENT ==========
    "git|development|Git version control|git|git|git|git||git"
    "github-cli|development|GitHub CLI tool|gh|gh|github-cli|gh||gh"
    "gitlab-cli|development|GitLab CLI tool|glab|glab|glab|glab||glab"
    "neovim|development|Modern Vim fork|neovim|neovim|neovim|neovim|io.neovim.nvim|nvim"
    "vim|development|Vi Improved text editor|vim|vim-enhanced|vim|vim||vim"
    "emacs|development|Extensible text editor|emacs|emacs|emacs|emacs|org.gnu.emacs|emacs"
    "vscode|development|Visual Studio Code|code|code|code|code|com.visualstudio.code|code"
    "vscodium|development|VS Code without telemetry|codium|codium|vscodium|codium|com.vscodium.codium|codium"
    "jetbrains-toolbox|development|JetBrains IDEs manager||||jetbrains-toolbox|com.jetbrains.Toolbox|jetbrains-toolbox"
    "docker|development|Container platform|docker.io|docker|docker|docker||docker"
    "docker-compose|development|Multi-container Docker|docker-compose|docker-compose|docker-compose|docker-compose||docker-compose"
    "podman|development|Daemonless containers|podman|podman|podman|podman||podman"
    "buildah|development|OCI image builder|buildah|buildah|buildah|buildah||buildah"
    "python3|development|Python 3 interpreter|python3|python3|python|python3||python3"
    "pip|development|Python package manager|python3-pip|python3-pip|python-pip|python3-pip||pip3"
    "poetry|development|Python dependency manager|python3-poetry|poetry|python-poetry|python3-poetry||poetry"
    "nodejs|development|Node.js runtime|nodejs|nodejs|nodejs|nodejs||node"
    "npm|development|Node package manager|npm|npm|npm|npm||npm"
    "yarn|development|Fast Node.js package manager|yarn|yarn|yarn|yarn||yarn"
    "go|development|Go programming language|golang|golang|go|go||go"
    "rust|development|Rust programming language|rustc|rust|rust|rust||rustc"
    "cargo|development|Rust package manager|cargo|cargo|rust|cargo||cargo"
    "openjdk|development|OpenJDK Java|default-jdk|java-latest-openjdk|jdk-openjdk|java-11-openjdk||java"
    "maven|development|Java build tool|maven|maven|maven|maven||mvn"
    "gradle|development|Java build automation|gradle|gradle|gradle|gradle||gradle"

    # ========== GAMING ==========
    "steam|gaming|Steam gaming platform|steam|steam|steam|steam|com.valvesoftware.Steam|steam"
    "lutris|gaming|Open gaming platform|lutris|lutris|lutris|lutris|net.lutris.Lutris|lutris"
    "heroic|gaming|Epic/GOG game launcher||||heroic-games-launcher|com.heroicgameslauncher.hgl|heroic"
    "bottles|gaming|Run Windows apps|bottles|bottles|bottles|bottles|com.usebottles.bottles|bottles"
    "wine|gaming|Windows compatibility layer|wine|wine|wine|wine||wine"
    "winetricks|gaming|Wine helper scripts|winetricks|winetricks|winetricks|winetricks||winetricks"
    "protonup-qt|gaming|Proton-GE installer||||protonup-qt|net.davidotek.pupgui2|protonup-qt"
    "mangohud|gaming|Gaming overlay|mangohud|mangohud|mangohud|mangohud|org.freedesktop.Platform.VulkanLayer.MangoHud|mangohud"
    "gamescope|gaming|Micro-compositor for gaming|gamescope|gamescope|gamescope|gamescope||gamescope"

    # ========== MEDIA ==========
    "vlc|media|VLC media player|vlc|vlc|vlc|vlc|org.videolan.VLC|vlc"
    "mpv|media|Minimalist media player|mpv|mpv|mpv|mpv|io.mpv.Mpv|mpv"
    "audacity|media|Audio editor|audacity|audacity|audacity|audacity|org.audacityteam.Audacity|audacity"
    "obs-studio|media|Streaming/recording software|obs-studio|obs-studio|obs-studio|obs-studio|com.obsproject.Studio|obs"
    "kdenlive|media|Video editor|kdenlive|kdenlive|kdenlive|kdenlive|org.kde.kdenlive|kdenlive"
    "handbrake|media|Video transcoder|handbrake|HandBrake|handbrake|handbrake|fr.handbrake.ghb|HandBrakeCLI"
    "ffmpeg|media|Multimedia framework|ffmpeg|ffmpeg|ffmpeg|ffmpeg||ffmpeg"
    "gimp|media|Image editor|gimp|gimp|gimp|gimp|org.gimp.GIMP|gimp"
    "krita|media|Digital painting|krita|krita|krita|krita|org.kde.krita|krita"
    "inkscape|media|Vector graphics editor|inkscape|inkscape|inkscape|inkscape|org.inkscape.Inkscape|inkscape"
    "blender|media|3D creation suite|blender|blender|blender|blender|org.blender.Blender|blender"

    # ========== COMMUNICATION ==========
    "discord|communication|Discord chat|discord|discord|discord|discord|com.discordapp.Discord|discord"
    "discord-canary|communication|Discord Canary build||||discord-canary|com.discordapp.DiscordCanary|discord-canary"
    "signal|communication|Signal messenger|signal-desktop|signal-desktop|signal-desktop|signal-desktop|org.signal.Signal|signal-desktop"
    "telegram|communication|Telegram messenger|telegram-desktop|telegram-desktop|telegram-desktop|telegram|org.telegram.desktop|telegram-desktop"
    "slack|communication|Slack for teams|slack-desktop|slack|slack-desktop|slack|com.slack.Slack|slack"
    "zoom|communication|Zoom video conferencing|zoom|zoom|zoom|zoom|us.zoom.Zoom|zoom"
    "teams|communication|Microsoft Teams|teams|teams|teams|teams|com.microsoft.Teams|teams"

    # ========== PRODUCTIVITY ==========
    "libreoffice|productivity|LibreOffice suite|libreoffice|libreoffice|libreoffice-fresh|libreoffice|org.libreoffice.LibreOffice|libreoffice"
    "onlyoffice|productivity|OnlyOffice suite|onlyoffice-desktopeditors|onlyoffice-desktopeditors|onlyoffice-bin|onlyoffice-desktopeditors|org.onlyoffice.desktopeditors|onlyoffice"
    "obsidian|productivity|Markdown knowledge base||||obsidian|md.obsidian.Obsidian|obsidian"
    "notion|productivity|Notion app||||notion|io.github.nickvision.notion|notion"
    "thunderbird|productivity|Email client|thunderbird|thunderbird|thunderbird|thunderbird|org.mozilla.Thunderbird|thunderbird"
    "evolution|productivity|GNOME email/calendar|evolution|evolution|evolution|evolution|org.gnome.Evolution|evolution"

    # ========== SYSTEM UTILITIES ==========
    "htop|utilities|Interactive process viewer|htop|htop|htop|htop||htop"
    "btop|utilities|Resource monitor|btop|btop|btop|btop||btop"
    "neofetch|utilities|System info display|neofetch|neofetch|neofetch|neofetch||neofetch"
    "fastfetch|utilities|Fast system info|fastfetch|fastfetch|fastfetch|fastfetch||fastfetch"
    "tmux|utilities|Terminal multiplexer|tmux|tmux|tmux|tmux||tmux"
    "screen|utilities|Terminal multiplexer|screen|screen|screen|screen||screen"
    "ncdu|utilities|Disk usage analyzer|ncdu|ncdu|ncdu|ncdu||ncdu"
    "ranger|utilities|File manager|ranger|ranger|ranger|ranger||ranger"
    "zsh|utilities|Z shell|zsh|zsh|zsh|zsh||zsh"
    "starship|utilities|Cross-shell prompt|starship|starship|starship|starship||starship"

    # ========== SECURITY ==========
    "wireshark|security|Network analyzer|wireshark|wireshark|wireshark|wireshark|org.wireshark.Wireshark|wireshark"
    "nmap|security|Network scanner|nmap|nmap|nmap|nmap||nmap"
    "tcpdump|security|Packet analyzer|tcpdump|tcpdump|tcpdump|tcpdump||tcpdump"
    "metasploit|security|Penetration testing|metasploit-framework|metasploit|metasploit|metasploit||msfconsole"
    "burpsuite|security|Web security testing||||burpsuite|com.burpsuite.BurpSuite|burpsuite"
    "openvpn|security|VPN client|openvpn|openvpn|openvpn|openvpn||openvpn"
    "wireguard|security|Modern VPN|wireguard-tools|wireguard-tools|wireguard-tools|wireguard-tools||wg"
)

# ============================================================================
# Application Database Functions
# ============================================================================

# Get all categories
apps_get_categories() {
    local categories=()
    local seen=""

    for entry in "${APP_DATABASE[@]}"; do
        local category
        category=$(echo "$entry" | cut -d'|' -f2)
        # Use simple string matching instead of regex for reliability
        if [[ "$seen" != *"|$category|"* ]]; then
            categories+=("$category")
            seen="${seen}|$category|"
        fi
    done

    printf '%s\n' "${categories[@]}"
}

# Get apps in category
apps_get_by_category() {
    local target_category="$1"

    for entry in "${APP_DATABASE[@]}"; do
        local category
        category=$(echo "$entry" | cut -d'|' -f2)
        if [[ "$category" == "$target_category" ]]; then
            echo "$entry"
        fi
    done
}

# Get app by name
apps_get_by_name() {
    local target_name="$1"

    for entry in "${APP_DATABASE[@]}"; do
        local name
        name=$(echo "$entry" | cut -d'|' -f1)
        if [[ "$name" == "$target_name" ]]; then
            echo "$entry"
            return 0
        fi
    done

    return 1
}

# Parse app entry
apps_parse_entry() {
    local entry="$1"

    APP_NAME=$(echo "$entry" | cut -d'|' -f1)
    APP_CATEGORY=$(echo "$entry" | cut -d'|' -f2)
    APP_DESC=$(echo "$entry" | cut -d'|' -f3)
    APP_PKG_APT=$(echo "$entry" | cut -d'|' -f4)
    APP_PKG_DNF=$(echo "$entry" | cut -d'|' -f5)
    APP_PKG_PACMAN=$(echo "$entry" | cut -d'|' -f6)
    APP_PKG_ZYPPER=$(echo "$entry" | cut -d'|' -f7)
    APP_FLATPAK=$(echo "$entry" | cut -d'|' -f8)
    APP_CHECK_CMD=$(echo "$entry" | cut -d'|' -f9)
}

# Get package name for current distro
apps_get_pkg_name() {
    local entry="$1"
    local pkg=""

    case "$PKG_MANAGER" in
        apt)
            pkg=$(echo "$entry" | cut -d'|' -f4)
            ;;
        dnf|yum)
            pkg=$(echo "$entry" | cut -d'|' -f5)
            ;;
        pacman)
            pkg=$(echo "$entry" | cut -d'|' -f6)
            ;;
        zypper)
            pkg=$(echo "$entry" | cut -d'|' -f7)
            ;;
    esac

    echo "$pkg"
}

# Check if app is installed
apps_is_installed() {
    local entry="$1"
    local check_cmd

    check_cmd=$(echo "$entry" | cut -d'|' -f9)

    if [[ -n "$check_cmd" ]]; then
        cmd_exists "$check_cmd"
        return $?
    fi

    # Fallback to package check
    local pkg
    pkg=$(apps_get_pkg_name "$entry")
    if [[ -n "$pkg" ]]; then
        pkg_is_installed "$pkg"
        return $?
    fi

    return 1
}

# Search apps
apps_search() {
    local query="$1"
    query="${query,,}"  # lowercase

    for entry in "${APP_DATABASE[@]}"; do
        local name desc
        name=$(echo "$entry" | cut -d'|' -f1)
        desc=$(echo "$entry" | cut -d'|' -f3)

        if [[ "${name,,}" == *"$query"* ]] || [[ "${desc,,}" == *"$query"* ]]; then
            echo "$entry"
        fi
    done
}

# Count apps in category
apps_count_category() {
    local category="$1"
    local count=0

    for entry in "${APP_DATABASE[@]}"; do
        local cat
        cat=$(echo "$entry" | cut -d'|' -f2)
        [[ "$cat" == "$category" ]] && ((count++))
    done

    echo "$count"
}

# Total app count
apps_count_total() {
    echo "${#APP_DATABASE[@]}"
}
