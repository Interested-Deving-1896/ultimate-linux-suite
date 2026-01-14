#!/usr/bin/env bash
# Unified Suite - Dependency Resolution
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_DEPS_LOADED:-}" ]] && return 0
readonly _UNIFIED_DEPS_LOADED=1

# Source dependencies
[[ -z "${_UNIFIED_CORE_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/core.sh"
[[ -z "${_UNIFIED_LOGGING_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/logging.sh"
[[ -z "${_UNIFIED_PKG_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/pkg.sh"

# ============================================================
# DEPENDENCY GROUPS
# ============================================================

declare -a CORE_DEPS=(
    "bash"
    "coreutils"
    "util-linux"
    "procps"
    "grep"
    "sed"
    "gawk"
    "curl"
    "wget"
)

declare -a TUI_DEPS=(
    "whiptail"
    "dialog"
)

declare -a OPTIMIZATION_DEPS=(
    "earlyoom"
    "cpupower"
)

declare -a MONITORING_DEPS=(
    "htop"
    "iotop"
    "sysstat"
)

declare -a SECURITY_DEPS=(
    "cryptsetup"
    "ufw"
)

declare -a MACBOOK_DEPS=(
    "dkms"
    "build-essential"
    "git"
)

# ============================================================
# DEPENDENCY STATUS TRACKING
# ============================================================

declare -A DEPENDENCY_STATUS

# Check single dependency
check_dependency() {
    local dep="$1"
    local type="${2:-command}"

    case "$type" in
        command)
            command -v "$dep" &>/dev/null
            ;;
        package)
            pkg_is_installed "$dep"
            ;;
        file)
            [[ -f "$dep" ]]
            ;;
        directory)
            [[ -d "$dep" ]]
            ;;
    esac

    local status=$?
    DEPENDENCY_STATUS["$dep"]=$status
    return $status
}

# Check multiple dependencies
check_dependencies() {
    local -a deps=("$@")
    local -a missing=()

    for dep in "${deps[@]}"; do
        if ! check_dependency "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[@]}"
        return 1
    fi

    return 0
}

# Resolve (install) missing dependencies
resolve_dependencies() {
    local -a deps=("$@")
    local -a missing=()

    for dep in "${deps[@]}"; do
        if ! check_dependency "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        pkg_install "${missing[@]}"
    else
        log_debug "All dependencies satisfied"
    fi
}

# Print dependency report
print_dependency_report() {
    log_section "Dependency Status Report"

    for dep in "${!DEPENDENCY_STATUS[@]}"; do
        local status="${DEPENDENCY_STATUS[$dep]}"
        if [[ $status -eq 0 ]]; then
            echo -e "  ${C_GREEN}[OK]${C_RESET} $dep"
        else
            echo -e "  ${C_RED}[MISSING]${C_RESET} $dep"
        fi
    done
}

# Check core dependencies
check_core_deps() {
    log_info "Checking core dependencies..."
    check_dependencies "${CORE_DEPS[@]}"
}

# Check optimization dependencies
check_optimization_deps() {
    log_info "Checking optimization dependencies..."
    check_dependencies "${OPTIMIZATION_DEPS[@]}"
}

# Check TUI dependencies
check_tui_deps() {
    log_info "Checking TUI dependencies..."
    local missing=$(check_dependencies "${TUI_DEPS[@]}")
    if [[ -n "$missing" ]]; then
        log_warn "TUI may be limited. Missing: $missing"
        return 1
    fi
    return 0
}

# Install build dependencies for compiling drivers/modules
pkg_install_build_deps() {
    log_info "Installing build dependencies..."

    case "$OS_FAMILY" in
        debian)
            pkg_install build-essential dkms git linux-headers-$(uname -r) 2>/dev/null || \
            pkg_install build-essential dkms git linux-headers-generic
            ;;
        fedora)
            pkg_install @development-tools kernel-devel kernel-headers dkms git
            ;;
        arch)
            pkg_install base-devel linux-headers dkms git
            ;;
        opensuse)
            pkg_install -t pattern devel_basis
            pkg_install kernel-devel dkms git
            ;;
        *)
            log_warn "Unknown OS family: $OS_FAMILY - attempting generic build deps"
            pkg_install gcc make git dkms
            ;;
    esac
}
