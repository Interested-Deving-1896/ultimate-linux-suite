#!/usr/bin/env bash
# OffTrack Suite - MacBook Cirrus Audio Driver
# Installs snd_hda_macbookpro for Cirrus CS8409 audio
# License: GPL-3.0-or-later

[[ -n "${_MACBOOK_AUDIO_LOADED:-}" ]] && return 0
readonly _MACBOOK_AUDIO_LOADED=1

# Configuration
MACBOOK_AUDIO_REPO="https://github.com/davidjo/snd_hda_macbookpro.git"
MACBOOK_AUDIO_DIR="/usr/src/snd_hda_macbookpro"

# Install Cirrus audio driver
macbook_audio_install() {
    log_section "Installing Cirrus CS8409 Audio Driver"

    require_root

    # Create safety snapshot
    safety_checkpoint "macbook-audio"

    # Install build dependencies
    log_info "Installing build dependencies..."
    pkg_install_build_deps

    case "$OS_FAMILY" in
        fedora)
            pkg_install kernel-devel kernel-headers wget patch
            ;;
        debian)
            pkg_install "linux-headers-$(uname -r)" wget patch
            ;;
        arch)
            pkg_install linux-headers wget patch
            ;;
    esac

    # Clone or update repository
    log_info "Fetching driver source..."
    if [[ -d "$MACBOOK_AUDIO_DIR" ]]; then
        cd "$MACBOOK_AUDIO_DIR"
        safe_exec git pull origin
    else
        safe_exec git clone "$MACBOOK_AUDIO_REPO" "$MACBOOK_AUDIO_DIR"
    fi

    cd "$MACBOOK_AUDIO_DIR"

    # Check kernel version and select appropriate installer
    # Using sort -V for proper version comparison
    local current_kernel=$(uname -r | cut -d- -f1)
    local installer="install.cirrus.driver.sh"

    # Check if current kernel is older than 6.17
    if printf '%s\n' "6.17" "$current_kernel" | sort -V | head -n1 | grep -q "^${current_kernel}$"; then
        # Current kernel sorts before 6.17, so it's older
        if [[ "$current_kernel" != "6.17" ]]; then
            installer="install.cirrus.driver.pre617.sh"
            log_info "Using pre-6.17 installer for kernel $current_kernel"
        fi
    fi

    # Run installer
    log_info "Running audio driver installer..."
    if [[ -f "$installer" ]]; then
        safe_exec bash "$installer"
    elif [[ -f "dkms.sh" ]]; then
        # Alternative: DKMS installation
        log_info "Using DKMS installation method..."
        safe_exec bash dkms.sh
    else
        log_error "No installer script found"
        return 1
    fi

    # Verify installation
    log_info "Verifying installation..."
    if lsmod | grep -q "snd_hda_codec_cs8409\|snd_hda_macbookpro"; then
        log_success "Audio driver module loaded"
    else
        log_warn "Audio driver module not yet loaded - reboot may be required"
    fi

    log_success "Cirrus audio driver installed"
    log_warn "A reboot is required for full functionality"
    log_info "After reboot, test with: speaker-test -c 2"
}

# Remove audio driver
macbook_audio_remove() {
    log_section "Removing Cirrus Audio Driver"

    require_root

    # Remove DKMS module
    safe_exec dkms remove -m snd_hda_macbookpro --all 2>/dev/null || true

    # Remove source
    [[ -d "$MACBOOK_AUDIO_DIR" ]] && safe_exec rm -rf "$MACBOOK_AUDIO_DIR"

    log_success "Audio driver removed"
}

# Check audio status
macbook_audio_status() {
    echo "Audio Driver Status:"
    echo ""

    # Check if module is loaded
    if lsmod | grep -q "snd_hda"; then
        echo "HDA Module: loaded"
        lsmod | grep snd_hda | head -5
    else
        echo "HDA Module: not loaded"
    fi

    echo ""

    # Check audio devices
    echo "Audio Devices:"
    aplay -l 2>/dev/null || echo "  No playback devices found"

    echo ""

    # Check ALSA info
    if [[ -f /proc/asound/card0/codec* ]]; then
        echo "Codec Info:"
        head -10 /proc/asound/card0/codec* 2>/dev/null || true
    fi
}

# Test audio
macbook_audio_test() {
    log_info "Testing audio output..."

    if ! command_exists speaker-test; then
        pkg_install alsa-utils
    fi

    echo "Playing test tone (press Ctrl+C to stop)..."
    speaker-test -c 2 -t sine -f 440 -l 1
}
