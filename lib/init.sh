#!/usr/bin/env bash
# Unified Suite - Master Library Loader
# License: GPL-3.0-or-later
#
# This file loads all libraries in the correct dependency order.
# Source this file to load the complete library stack.

[[ -n "${_UNIFIED_INIT_LOADED:-}" ]] && return 0
readonly _UNIFIED_INIT_LOADED=1

# Determine library directory
readonly LIB_DIR="${BASH_SOURCE%/*}"

# ============================================================
# LIBRARY LOAD ORDER
# ============================================================
# Libraries are loaded in dependency order:
#   Level 0: colors.sh (no dependencies)
#   Level 1: core.sh, logging.sh (depend on colors)
#   Level 2: os_detect.sh, tui.sh (depend on Level 1)
#   Level 3: pkg.sh, safety.sh, deps.sh (depend on Level 2)
#   Level 4: config.sh, optimization.sh, macbook_detect.sh
#   Level 5: hardware.sh, monitor.sh

# Level 0
source "$LIB_DIR/colors.sh"

# Level 1
source "$LIB_DIR/core.sh"
source "$LIB_DIR/logging.sh"

# Level 2
source "$LIB_DIR/os_detect.sh"
source "$LIB_DIR/tui.sh"

# Level 3
source "$LIB_DIR/pkg.sh"
source "$LIB_DIR/safety.sh"
source "$LIB_DIR/deps.sh"

# Level 4
source "$LIB_DIR/config.sh"
source "$LIB_DIR/optimization.sh"
source "$LIB_DIR/macbook_detect.sh"

# Level 5
source "$LIB_DIR/hardware.sh"
source "$LIB_DIR/monitor.sh"

# ============================================================
# LIBRARY VERIFICATION
# ============================================================

verify_libraries() {
    local -a required_libs=(
        "_UNIFIED_COLORS_LOADED"
        "_UNIFIED_CORE_LOADED"
        "_UNIFIED_LOGGING_LOADED"
        "_UNIFIED_OS_DETECT_LOADED"
        "_UNIFIED_TUI_LOADED"
        "_UNIFIED_PKG_LOADED"
        "_UNIFIED_SAFETY_LOADED"
        "_UNIFIED_DEPS_LOADED"
        "_UNIFIED_CONFIG_LOADED"
        "_UNIFIED_OPTIMIZATION_LOADED"
        "_UNIFIED_MACBOOK_DETECT_LOADED"
        "_UNIFIED_HARDWARE_LOADED"
        "_UNIFIED_MONITOR_LOADED"
    )

    local missing=0
    for lib in "${required_libs[@]}"; do
        if [[ -z "${!lib:-}" ]]; then
            echo "Library not loaded: $lib" >&2
            ((missing++))
        fi
    done

    return $missing
}

# Log successful initialization
log_debug "Unified Suite libraries initialized (13 libraries loaded)"
