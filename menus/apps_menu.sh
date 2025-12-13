#!/usr/bin/env bash
#
# apps_menu.sh - Applications Menu (wrapper)
#
# The main menu logic is in modules/apps.sh (apps_main function)
# This file exists for organizational clarity and potential future expansion
#
# Note: set options inherited from suite.sh - do not set here

[[ -n "${_APPS_MENU_LOADED:-}" ]] && return 0
readonly _APPS_MENU_LOADED=1

# Apps menu entry point - delegates to module
run_apps_menu() {
    apps_main
}
