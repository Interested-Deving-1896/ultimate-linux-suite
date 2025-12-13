#!/usr/bin/env bash
#
# drivers.sh - Driver Management Module for Ultimate Linux Suite
#
# Note: set options inherited from suite.sh - do not set here

# Prevent multiple sourcing
[[ -n "${_DRIVERS_MODULE_LOADED:-}" ]] && return 0
readonly _DRIVERS_MODULE_LOADED=1

# Detect GPU and suggest drivers
detect_gpu_drivers() {
    log_section "GPU Driver Detection"

    detect_gpu  # From hardware_detect.sh

    printf "\nDetected GPU: %s\n" "$GPU_MODEL"
    printf "Vendor: %s\n\n" "$GPU_VENDOR"

    case "$GPU_VENDOR" in
        nvidia)
            suggest_nvidia_driver
            ;;
        amd)
            suggest_amd_driver
            ;;
        intel)
            suggest_intel_driver
            ;;
        *)
            log_warn "Unknown GPU vendor. Cannot suggest drivers."
            ;;
    esac
}

# NVIDIA driver suggestions
suggest_nvidia_driver() {
    log_info "NVIDIA GPU detected"

    case "$OS_FAMILY" in
        debian)
            printf "\nRecommended packages:\n"
            printf "  - nvidia-driver (proprietary)\n"
            printf "  - nvidia-driver-XXX (specific version)\n"
            printf "\nInstall with:\n"
            printf "  sudo apt install nvidia-driver\n"
            printf "\nFor newer cards, you may need:\n"
            printf "  sudo apt install nvidia-driver-535\n"
            ;;
        fedora)
            printf "\nRecommended:\n"
            printf "  1. Enable RPM Fusion: https://rpmfusion.org\n"
            printf "  2. Install: sudo dnf install akmod-nvidia\n"
            ;;
        arch)
            printf "\nRecommended packages:\n"
            printf "  - nvidia (latest)\n"
            printf "  - nvidia-lts (for LTS kernel)\n"
            printf "  - nvidia-dkms (DKMS version)\n"
            printf "\nInstall with:\n"
            printf "  sudo pacman -S nvidia nvidia-utils\n"
            ;;
        suse)
            printf "\nRecommended:\n"
            printf "  Add NVIDIA repo and install via YaST\n"
            printf "  Or: zypper install nvidia-driver\n"
            ;;
    esac

    printf "\n"
    if confirm "Attempt automatic NVIDIA driver installation?"; then
        install_nvidia_driver
    fi
}

# Install NVIDIA driver
install_nvidia_driver() {
    log_info "Installing NVIDIA driver..."

    case "$OS_FAMILY" in
        debian)
            # Ensure contrib/non-free is enabled (Debian)
            if is_debian; then
                log_info "Checking repositories..."
            fi
            pkg_update
            pkg_install nvidia-driver
            ;;
        fedora)
            log_warn "For Fedora, please enable RPM Fusion first."
            log_info "Visit: https://rpmfusion.org/Configuration"
            if confirm "Attempt installation anyway?"; then
                pkg_install akmod-nvidia xorg-x11-drv-nvidia
            fi
            ;;
        arch)
            pkg_install nvidia nvidia-utils nvidia-settings
            ;;
        suse)
            log_warn "Please use YaST or add NVIDIA repo first."
            ;;
    esac

    log_success "NVIDIA driver installation attempted"
    log_warn "A reboot is required for changes to take effect"
}

# AMD driver suggestions
suggest_amd_driver() {
    log_info "AMD GPU detected"

    printf "\nAMD GPUs typically work out-of-the-box with the open-source\n"
    printf "amdgpu/radeon kernel driver.\n\n"

    case "$OS_FAMILY" in
        debian)
            printf "For enhanced features, install:\n"
            printf "  sudo apt install firmware-amd-graphics mesa-vulkan-drivers\n"
            ;;
        fedora)
            printf "Install mesa drivers:\n"
            printf "  sudo dnf install mesa-vulkan-drivers mesa-va-drivers\n"
            ;;
        arch)
            printf "Install:\n"
            printf "  sudo pacman -S mesa vulkan-radeon lib32-vulkan-radeon\n"
            ;;
        suse)
            printf "Install:\n"
            printf "  sudo zypper install Mesa-dri-nouveau libvulkan_radeon\n"
            ;;
    esac

    printf "\n"
    if confirm "Install AMD mesa/vulkan packages?"; then
        install_amd_driver
    fi
}

# Install AMD driver packages
install_amd_driver() {
    log_info "Installing AMD graphics packages..."

    case "$OS_FAMILY" in
        debian)
            pkg_install firmware-amd-graphics mesa-vulkan-drivers libvulkan1
            ;;
        fedora)
            pkg_install mesa-vulkan-drivers mesa-va-drivers
            ;;
        arch)
            pkg_install mesa vulkan-radeon lib32-vulkan-radeon
            ;;
        suse)
            pkg_install Mesa-dri-nouveau libvulkan_radeon
            ;;
    esac

    log_success "AMD packages installed"
}

# Intel driver suggestions
suggest_intel_driver() {
    log_info "Intel GPU detected"

    printf "\nIntel GPUs work with the built-in i915 kernel driver.\n\n"

    case "$OS_FAMILY" in
        debian)
            printf "For hardware acceleration:\n"
            printf "  sudo apt install intel-media-va-driver vainfo\n"
            ;;
        fedora)
            printf "Install:\n"
            printf "  sudo dnf install intel-media-driver libva-intel-driver\n"
            ;;
        arch)
            printf "Install:\n"
            printf "  sudo pacman -S intel-media-driver vulkan-intel\n"
            ;;
        suse)
            printf "Install:\n"
            printf "  sudo zypper install intel-media-driver\n"
            ;;
    esac

    printf "\n"
    if confirm "Install Intel graphics packages?"; then
        install_intel_driver
    fi
}

# Install Intel driver packages
install_intel_driver() {
    log_info "Installing Intel graphics packages..."

    case "$OS_FAMILY" in
        debian)
            pkg_install intel-media-va-driver vainfo
            ;;
        fedora)
            pkg_install intel-media-driver libva-intel-driver
            ;;
        arch)
            pkg_install intel-media-driver vulkan-intel
            ;;
        suse)
            pkg_install intel-media-driver
            ;;
    esac

    log_success "Intel packages installed"
}

# WiFi driver detection
detect_wifi_drivers() {
    log_section "WiFi Driver Detection"

    if ! cmd_exists lspci; then
        log_warn "lspci not found. Install pciutils."
        return 1
    fi

    local wifi_devices
    wifi_devices=$(lspci 2>/dev/null | grep -iE "network|wireless|wifi" || true)

    if [[ -z "$wifi_devices" ]]; then
        log_info "No WiFi hardware detected via PCI"
        return 0
    fi

    printf "\nDetected wireless devices:\n%s\n\n" "$wifi_devices"

    # Check for common problematic chipsets
    if echo "$wifi_devices" | grep -qi "broadcom"; then
        suggest_broadcom_wifi
    elif echo "$wifi_devices" | grep -qi "realtek"; then
        suggest_realtek_wifi
    elif echo "$wifi_devices" | grep -qi "intel"; then
        log_info "Intel WiFi - should work out-of-box with iwlwifi"
    elif echo "$wifi_devices" | grep -qi "atheros\|qualcomm"; then
        log_info "Atheros/Qualcomm WiFi - usually works out-of-box"
    fi
}

# Broadcom WiFi suggestions
suggest_broadcom_wifi() {
    log_warn "Broadcom WiFi detected - may need proprietary driver"

    case "$OS_FAMILY" in
        debian)
            printf "\nFor Broadcom WiFi on Debian/Ubuntu:\n"
            printf "  sudo apt install broadcom-sta-dkms\n"
            printf "  # Or for some chips:\n"
            printf "  sudo apt install firmware-b43-installer\n"
            ;;
        fedora)
            printf "\nFor Broadcom on Fedora (enable RPM Fusion first):\n"
            printf "  sudo dnf install broadcom-wl\n"
            ;;
        arch)
            printf "\nFor Broadcom on Arch:\n"
            printf "  sudo pacman -S broadcom-wl-dkms\n"
            ;;
    esac

    printf "\n"
    if confirm "Attempt Broadcom driver installation?"; then
        case "$OS_FAMILY" in
            debian) pkg_install broadcom-sta-dkms ;;
            fedora) pkg_install broadcom-wl ;;
            arch) pkg_install broadcom-wl-dkms ;;
        esac
    fi
}

# Realtek WiFi suggestions
suggest_realtek_wifi() {
    log_warn "Realtek WiFi detected"

    printf "\nRealtek WiFi often requires DKMS drivers.\n"
    printf "Check: https://github.com/lwfinger for community drivers\n"

    case "$OS_FAMILY" in
        debian)
            printf "\nTry:\n"
            printf "  sudo apt install realtek-rtl88xxau-dkms\n"
            ;;
    esac
}

# Show driver summary
show_driver_summary() {
    log_section "Driver Summary"

    printf "\nGPU:\n"
    detect_gpu
    printf "  Model: %s\n" "$GPU_MODEL"
    printf "  Vendor: %s\n" "$GPU_VENDOR"

    # Check loaded modules
    printf "\nLoaded graphics modules:\n"
    lsmod | grep -iE "nvidia|amdgpu|radeon|i915|nouveau" || printf "  (none detected)\n"

    printf "\nWiFi:\n"
    lsmod | grep -iE "iwlwifi|ath|brcm|rtl|r8" | head -5 || printf "  (no wireless modules found)\n"

    pause
}

# ============================================================================
# VirtualBox Guest Additions
# ============================================================================

detect_virtualbox() {
    # Check if running in VirtualBox
    if cmd_exists dmidecode; then
        dmidecode -s system-product-name 2>/dev/null | grep -qi "virtualbox"
        return $?
    elif [[ -d /sys/class/dmi/id ]]; then
        grep -qi "virtualbox" /sys/class/dmi/id/product_name 2>/dev/null
        return $?
    fi
    return 1
}

install_virtualbox_guest() {
    log_section "VirtualBox Guest Additions"

    if ! detect_virtualbox; then
        log_warn "This system does not appear to be a VirtualBox VM"
        if ! confirm "Install anyway?"; then
            return
        fi
    fi

    printf "VirtualBox Guest Additions provide:\n"
    printf "  - Shared folders\n"
    printf "  - Seamless mouse integration\n"
    printf "  - Better display support\n"
    printf "  - Shared clipboard\n\n"

    case "$OS_FAMILY" in
        debian)
            queue_pkg_install "virtualbox-guest-utils" "VirtualBox guest utilities"
            queue_pkg_install "virtualbox-guest-x11" "VirtualBox X11 integration"
            ;;
        fedora)
            queue_pkg_install "virtualbox-guest-additions" "VirtualBox guest additions"
            ;;
        arch)
            queue_pkg_install "virtualbox-guest-utils" "VirtualBox guest utilities"
            ;;
        suse)
            queue_pkg_install "virtualbox-guest-tools" "VirtualBox guest tools"
            ;;
    esac

    log_success "VirtualBox Guest Additions queued for installation"
}

# ============================================================================
# VMware Tools
# ============================================================================

detect_vmware() {
    if cmd_exists dmidecode; then
        dmidecode -s system-product-name 2>/dev/null | grep -qi "vmware"
        return $?
    elif [[ -d /sys/class/dmi/id ]]; then
        grep -qi "vmware" /sys/class/dmi/id/product_name 2>/dev/null
        return $?
    fi
    return 1
}

install_vmware_tools() {
    log_section "VMware Tools"

    if ! detect_vmware; then
        log_warn "This system does not appear to be a VMware VM"
        if ! confirm "Install anyway?"; then
            return
        fi
    fi

    printf "Open-VM-Tools provide:\n"
    printf "  - Shared folders\n"
    printf "  - Time synchronization\n"
    printf "  - Better display support\n"
    printf "  - Seamless mouse\n\n"

    case "$OS_FAMILY" in
        debian)
            queue_pkg_install "open-vm-tools" "VMware open tools"
            if [[ "$DESKTOP_ENV" != "none" ]]; then
                queue_pkg_install "open-vm-tools-desktop" "VMware desktop integration"
            fi
            ;;
        fedora)
            queue_pkg_install "open-vm-tools" "VMware open tools"
            if [[ "$DESKTOP_ENV" != "none" ]]; then
                queue_pkg_install "open-vm-tools-desktop" "VMware desktop integration"
            fi
            ;;
        arch)
            queue_pkg_install "open-vm-tools" "VMware open tools"
            ;;
        suse)
            queue_pkg_install "open-vm-tools" "VMware open tools"
            ;;
    esac

    log_success "VMware Tools queued for installation"
}

# ============================================================================
# VM Driver Menu
# ============================================================================

vm_drivers_menu() {
    log_section "Virtual Machine Drivers"

    # Auto-detect VM environment
    local vm_type="none"
    if detect_virtualbox; then
        vm_type="virtualbox"
        log_info "VirtualBox VM detected"
    elif detect_vmware; then
        vm_type="vmware"
        log_info "VMware VM detected"
    elif [[ -d /sys/class/dmi/id ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        if [[ "$product" == *"KVM"* ]] || [[ "$product" == *"QEMU"* ]]; then
            vm_type="qemu"
            log_info "QEMU/KVM VM detected"
        fi
    fi

    if [[ "$vm_type" == "none" ]]; then
        log_info "No virtual machine environment detected"
    fi

    printf "\n"

    simple_menu "VM Driver Options" \
        "Install VirtualBox Guest Additions" \
        "Install VMware Tools (open-vm-tools)" \
        "Install QEMU Guest Agent"

    case "$MENU_CHOICE" in
        1) install_virtualbox_guest; pause ;;
        2) install_vmware_tools; pause ;;
        3)
            queue_pkg_install "qemu-guest-agent" "QEMU guest agent"
            log_success "QEMU guest agent queued"
            pause
            ;;
    esac
}

# Module initialization
drivers_init() {
    log_debug "Drivers module initialized"
}

# Module main entry point
drivers_main() {
    while true; do
        local queue_count
        queue_count=$(queue_count)

        simple_menu "Driver Management" \
            "Detect & Install GPU Drivers" \
            "Detect WiFi Hardware" \
            "Virtual Machine Drivers" \
            "Show Driver Summary" \
            "Install DKMS Support" \
            "Rebuild DKMS Modules" \
            "View Queue ($queue_count pending)"

        case "$MENU_CHOICE" in
            1)
                detect_gpu_drivers
                pause
                ;;
            2)
                detect_wifi_drivers
                pause
                ;;
            3)
                vm_drivers_menu
                ;;
            4)
                show_driver_summary
                ;;
            5)
                queue_pkg_install "dkms" "DKMS"
                queue_pkg_install "$(pkg_name kernel-headers)" "Kernel headers"
                log_success "DKMS packages queued"
                pause
                ;;
            6)
                log_info "Rebuilding DKMS modules..."
                if cmd_exists dkms; then
                    dkms autoinstall
                    log_success "DKMS modules rebuilt"
                else
                    log_error "DKMS not installed"
                fi
                pause
                ;;
            7)
                queue_menu
                ;;
            0)
                return 0
                ;;
        esac
    done
}
