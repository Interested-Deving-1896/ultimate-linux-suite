#!/usr/bin/env bash
#
# drivers_menu.sh - Drivers Menu (wrapper)
#
# Note: set options inherited from suite.sh - do not set here

[[ -n "${_DRIVERS_MENU_LOADED:-}" ]] && return 0
readonly _DRIVERS_MENU_LOADED=1

run_drivers_menu() {
    drivers_main
}
