#!/usr/bin/env bash
# OffTrack Suite - Sudo Askpass Configuration
# Configures graphical password prompts for sudo
# License: GPL-3.0-or-later

[[ -n "${_ASKPASS_SETUP_LOADED:-}" ]] && return 0
readonly _ASKPASS_SETUP_LOADED=1

# Setup sudo askpass
askpass_setup() {
    log_section "Configuring Sudo Askpass"

    # Detect desktop environment and choose appropriate askpass
    local askpass_cmd=""

    if command_exists ksshaskpass; then
        askpass_cmd="/usr/bin/ksshaskpass"
    elif command_exists ssh-askpass-gnome; then
        askpass_cmd="/usr/lib/ssh/ssh-askpass-gnome"
    elif command_exists zenity; then
        askpass_cmd="zenity-askpass"
    elif command_exists kdialog; then
        askpass_cmd="kdialog-askpass"
    fi

    if [[ -z "$askpass_cmd" ]]; then
        log_info "Installing askpass utility..."
        case "$OS_FAMILY" in
            fedora)
                if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]]; then
                    pkg_install ksshaskpass
                    askpass_cmd="/usr/bin/ksshaskpass"
                else
                    pkg_install openssh-askpass
                    askpass_cmd="/usr/libexec/openssh/ssh-askpass"
                fi
                ;;
            debian)
                if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]]; then
                    pkg_install ksshaskpass
                    askpass_cmd="/usr/bin/ksshaskpass"
                else
                    pkg_install ssh-askpass-gnome
                    askpass_cmd="/usr/lib/openssh/gnome-ssh-askpass"
                fi
                ;;
            arch)
                if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]]; then
                    pkg_install ksshaskpass
                    askpass_cmd="/usr/bin/ksshaskpass"
                else
                    pkg_install x11-ssh-askpass
                    askpass_cmd="/usr/lib/ssh/x11-ssh-askpass"
                fi
                ;;
        esac
    fi

    # Create zenity/kdialog wrappers if needed
    if [[ "$askpass_cmd" == "zenity-askpass" ]]; then
        cat > /usr/local/bin/zenity-askpass << 'EOF'
#!/usr/bin/env bash
zenity --password --title="sudo password required"
EOF
        chmod +x /usr/local/bin/zenity-askpass
        askpass_cmd="/usr/local/bin/zenity-askpass"
    elif [[ "$askpass_cmd" == "kdialog-askpass" ]]; then
        cat > /usr/local/bin/kdialog-askpass << 'EOF'
#!/usr/bin/env bash
kdialog --password "sudo password required"
EOF
        chmod +x /usr/local/bin/kdialog-askpass
        askpass_cmd="/usr/local/bin/kdialog-askpass"
    fi

    # Configure sudoers
    log_info "Configuring sudoers..."
    local sudoers_file="/etc/sudoers.d/offtrack-askpass"

    safe_exec bash -c "cat > '$sudoers_file' << EOF
# OffTrack Suite - Askpass configuration
Defaults    env_keep += \"SUDO_ASKPASS\"
Defaults    timestamp_timeout=20
EOF"

    safe_exec chmod 440 "$sudoers_file"

    # Add to user's bashrc
    local bashrc="${HOME}/.bashrc"
    local export_line="export SUDO_ASKPASS=\"$askpass_cmd\""

    if ! grep -q "SUDO_ASKPASS" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# OffTrack Suite - Graphical sudo prompt" >> "$bashrc"
        echo "$export_line" >> "$bashrc"
    fi

    # Export for current session
    export SUDO_ASKPASS="$askpass_cmd"

    log_success "Sudo askpass configured"
    echo ""
    echo "Askpass command: $askpass_cmd"
    echo "Timeout: 20 minutes"
    echo ""
    echo "Restart your terminal or run: source ~/.bashrc"
}
