#!/usr/bin/env bash
#
# optimize_menu.sh - Optimization Menu (wrapper)
#
# Note: set options inherited from suite.sh - do not set here

[[ -n "${_OPTIMIZE_MENU_LOADED:-}" ]] && return 0
readonly _OPTIMIZE_MENU_LOADED=1

run_optimize_menu() {
    optimize_main
}
