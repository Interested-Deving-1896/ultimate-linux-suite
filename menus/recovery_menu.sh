#!/usr/bin/env bash
#
# recovery_menu.sh - Recovery Menu (wrapper)
#
# Note: set options inherited from suite.sh - do not set here

[[ -n "${_RECOVERY_MENU_LOADED:-}" ]] && return 0
readonly _RECOVERY_MENU_LOADED=1

run_recovery_menu() {
    recovery_main
}
