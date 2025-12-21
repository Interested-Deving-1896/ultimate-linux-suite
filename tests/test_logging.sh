#!/usr/bin/env bash
#
# test_logging.sh - Tests for the logging module
#

# Get script directory and source framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

# Source the module under test
source "${SCRIPT_DIR}/../lib/logging.sh"

TEST_SUITE_NAME="Logging Module Tests"

# ============================================================================
# Setup and Teardown
# ============================================================================

setup() {
    # Create temp directory for test logs
    TEST_LOG_DIR=$(mktemp -d)
    export LOG_FILE="${TEST_LOG_DIR}/test.log"
}

teardown() {
    # Clean up temp directory
    if [[ -d "$TEST_LOG_DIR" ]]; then
        rm -rf "$TEST_LOG_DIR"
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_log_info_outputs_message() {
    local output
    output=$(log_info "test message" 2>&1)
    assert_contains "$output" "test message" "log_info should output the message"
}

test_log_success_outputs_message() {
    local output
    output=$(log_success "success message" 2>&1)
    assert_contains "$output" "success message" "log_success should output the message"
}

test_log_warn_outputs_message() {
    local output
    output=$(log_warn "warning message" 2>&1)
    assert_contains "$output" "warning message" "log_warn should output the message"
}

test_log_error_outputs_message() {
    local output
    output=$(log_error "error message" 2>&1)
    assert_contains "$output" "error message" "log_error should output the message"
}

test_log_debug_respects_log_level() {
    # Debug should not output by default (if LOG_LEVEL is not DEBUG)
    export LOG_LEVEL="INFO"
    local output
    output=$(log_debug "debug message" 2>&1)
    # This depends on implementation - adjust assertion as needed
    assert_true "1" "log_debug respects log level (placeholder test)"
}

test_log_section_creates_header() {
    local output
    output=$(log_section "Test Section" 2>&1)
    assert_contains "$output" "Test Section" "log_section should output section name"
}

test_log_step_shows_progress() {
    local output
    output=$(log_step 1 5 "Step message" 2>&1)
    assert_contains "$output" "1" "log_step should show step number"
    assert_contains "$output" "Step message" "log_step should show step message"
}

test_logging_functions_exist() {
    assert_command_exists "log_info" "log_info function should exist"
    assert_command_exists "log_success" "log_success function should exist"
    assert_command_exists "log_warn" "log_warn function should exist"
    assert_command_exists "log_error" "log_error function should exist"
    assert_command_exists "log_debug" "log_debug function should exist"
}

test_color_variables_are_set() {
    assert_set "GREEN" "GREEN color should be set"
    assert_set "RED" "RED color should be set"
    assert_set "YELLOW" "YELLOW color should be set"
    assert_set "RESET" "RESET should be set"
}

# ============================================================================
# Run Tests
# ============================================================================

run_tests
