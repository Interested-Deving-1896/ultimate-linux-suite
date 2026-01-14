#!/usr/bin/env bash
# Unified Suite - Terminal Colors
# Source: OffTrack Suite (updated include guards)
# License: GPL-3.0-or-later

[[ -n "${_UNIFIED_COLORS_LOADED:-}" ]] && return 0
readonly _UNIFIED_COLORS_LOADED=1

# Detect color support
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    readonly COLOR_ENABLED=1
else
    readonly COLOR_ENABLED=0
fi

# Color definitions
if [[ $COLOR_ENABLED -eq 1 ]]; then
    readonly C_RESET='\033[0m'
    readonly C_BOLD='\033[1m'
    readonly C_DIM='\033[2m'
    readonly C_UNDERLINE='\033[4m'

    # Standard colors
    readonly C_BLACK='\033[0;30m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[1;33m'
    readonly C_BLUE='\033[0;34m'
    readonly C_MAGENTA='\033[0;35m'
    readonly C_CYAN='\033[0;36m'
    readonly C_WHITE='\033[0;37m'

    # Bold colors
    readonly C_BRED='\033[1;31m'
    readonly C_BGREEN='\033[1;32m'
    readonly C_BYELLOW='\033[1;33m'
    readonly C_BBLUE='\033[1;34m'
    readonly C_BMAGENTA='\033[1;35m'
    readonly C_BCYAN='\033[1;36m'
    readonly C_BWHITE='\033[1;37m'

    # Background colors
    readonly C_BG_RED='\033[41m'
    readonly C_BG_GREEN='\033[42m'
    readonly C_BG_YELLOW='\033[43m'
    readonly C_BG_BLUE='\033[44m'
else
    readonly C_RESET=''
    readonly C_BOLD=''
    readonly C_DIM=''
    readonly C_UNDERLINE=''
    readonly C_BLACK=''
    readonly C_RED=''
    readonly C_GREEN=''
    readonly C_YELLOW=''
    readonly C_BLUE=''
    readonly C_MAGENTA=''
    readonly C_CYAN=''
    readonly C_WHITE=''
    readonly C_BRED=''
    readonly C_BGREEN=''
    readonly C_BYELLOW=''
    readonly C_BBLUE=''
    readonly C_BMAGENTA=''
    readonly C_BCYAN=''
    readonly C_BWHITE=''
    readonly C_BG_RED=''
    readonly C_BG_GREEN=''
    readonly C_BG_YELLOW=''
    readonly C_BG_BLUE=''
fi

# Semantic aliases
readonly C_SUCCESS="$C_GREEN"
readonly C_ERROR="$C_RED"
readonly C_WARN="$C_YELLOW"
readonly C_INFO="$C_BLUE"
readonly C_DEBUG="$C_CYAN"
readonly C_HEADER="$C_BCYAN"
readonly C_PROMPT="$C_BWHITE"
