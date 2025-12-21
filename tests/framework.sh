#!/usr/bin/env bash
#
# framework.sh - Testing Framework for Ultimate Linux Suite
#
# A lightweight, portable testing framework for bash scripts.
# Provides assertion functions, test isolation, and reporting.
#

# ============================================================================
# Guard Pattern
# ============================================================================

[[ -n "${_TEST_FRAMEWORK_LOADED:-}" ]] && return 0
readonly _TEST_FRAMEWORK_LOADED=1

# ============================================================================
# Configuration
# ============================================================================

# Colors for output
declare -g TEST_COLOR_PASS="\033[32m"
declare -g TEST_COLOR_FAIL="\033[31m"
declare -g TEST_COLOR_SKIP="\033[33m"
declare -g TEST_COLOR_INFO="\033[34m"
declare -g TEST_COLOR_RESET="\033[0m"

# Test state
declare -g TEST_SUITE_NAME=""
declare -g TEST_NAME=""
declare -gi TEST_PASSED=0
declare -gi TEST_FAILED=0
declare -gi TEST_SKIPPED=0
declare -gi TEST_TOTAL=0
declare -ga TEST_FAILURES=()

# Temporary test directory
declare -g TEST_TMP_DIR=""

# Verbosity
declare -g TEST_VERBOSE="${TEST_VERBOSE:-0}"

# ============================================================================
# Output Functions
# ============================================================================

_test_print() {
    local color="$1"
    local prefix="$2"
    local message="$3"
    echo -e "${color}[${prefix}]${TEST_COLOR_RESET} ${message}"
}

test_pass() {
    _test_print "$TEST_COLOR_PASS" "PASS" "$1"
}

test_fail() {
    _test_print "$TEST_COLOR_FAIL" "FAIL" "$1"
}

test_skip() {
    _test_print "$TEST_COLOR_SKIP" "SKIP" "$1"
}

test_info() {
    _test_print "$TEST_COLOR_INFO" "INFO" "$1"
}

test_debug() {
    if [[ "$TEST_VERBOSE" -eq 1 ]]; then
        _test_print "$TEST_COLOR_INFO" "DEBUG" "$1"
    fi
}

# ============================================================================
# Assertion Functions
# ============================================================================

# Assert two values are equal
# Usage: assert_equals "expected" "actual" ["message"]
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"

    ((TEST_TOTAL++))

    if [[ "$expected" == "$actual" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert two values are not equal
# Usage: assert_not_equals "unexpected" "actual" ["message"]
assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Expected value to not equal '$unexpected'}"

    ((TEST_TOTAL++))

    if [[ "$unexpected" != "$actual" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert value is true (non-empty and not "0" or "false")
# Usage: assert_true "$value" ["message"]
assert_true() {
    local value="$1"
    local message="${2:-Expected true but got '$value'}"

    ((TEST_TOTAL++))

    if [[ -n "$value" ]] && [[ "$value" != "0" ]] && [[ "$value" != "false" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert value is false (empty, "0", or "false")
# Usage: assert_false "$value" ["message"]
assert_false() {
    local value="$1"
    local message="${2:-Expected false but got '$value'}"

    ((TEST_TOTAL++))

    if [[ -z "$value" ]] || [[ "$value" == "0" ]] || [[ "$value" == "false" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert string contains substring
# Usage: assert_contains "haystack" "needle" ["message"]
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected '$haystack' to contain '$needle'}"

    ((TEST_TOTAL++))

    if [[ "$haystack" == *"$needle"* ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert string matches regex
# Usage: assert_matches "$value" "pattern" ["message"]
assert_matches() {
    local value="$1"
    local pattern="$2"
    local message="${3:-Expected '$value' to match pattern '$pattern'}"

    ((TEST_TOTAL++))

    if [[ "$value" =~ $pattern ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert command exists
# Usage: assert_command_exists "command" ["message"]
assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command '$cmd' should exist}"

    ((TEST_TOTAL++))

    if command -v "$cmd" &>/dev/null; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert file exists
# Usage: assert_file_exists "path" ["message"]
assert_file_exists() {
    local path="$1"
    local message="${2:-File '$path' should exist}"

    ((TEST_TOTAL++))

    if [[ -f "$path" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert directory exists
# Usage: assert_dir_exists "path" ["message"]
assert_dir_exists() {
    local path="$1"
    local message="${2:-Directory '$path' should exist}"

    ((TEST_TOTAL++))

    if [[ -d "$path" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert file contains string
# Usage: assert_file_contains "path" "string" ["message"]
assert_file_contains() {
    local path="$1"
    local string="$2"
    local message="${3:-File '$path' should contain '$string'}"

    ((TEST_TOTAL++))

    if [[ -f "$path" ]] && grep -q "$string" "$path"; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert exit code
# Usage: assert_exit_code 0 "command args" ["message"]
assert_exit_code() {
    local expected="$1"
    local command="$2"
    local message="${3:-Command '$command' should exit with code $expected}"

    ((TEST_TOTAL++))

    eval "$command" &>/dev/null
    local actual=$?

    if [[ "$actual" -eq "$expected" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message (got exit code $actual)"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert command succeeds (exit code 0)
# Usage: assert_success "command args" ["message"]
assert_success() {
    local command="$1"
    local message="${2:-Command '$command' should succeed}"

    assert_exit_code 0 "$command" "$message"
}

# Assert command fails (non-zero exit code)
# Usage: assert_failure "command args" ["message"]
assert_failure() {
    local command="$1"
    local message="${2:-Command '$command' should fail}"

    ((TEST_TOTAL++))

    eval "$command" &>/dev/null
    local actual=$?

    if [[ "$actual" -ne 0 ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message (command succeeded unexpectedly)"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert variable is set
# Usage: assert_set "VAR_NAME" ["message"]
assert_set() {
    local var_name="$1"
    local message="${2:-Variable '$var_name' should be set}"

    ((TEST_TOTAL++))

    if [[ -n "${!var_name+x}" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert value is numeric
# Usage: assert_numeric "$value" ["message"]
assert_numeric() {
    local value="$1"
    local message="${2:-Expected '$value' to be numeric}"

    ((TEST_TOTAL++))

    if [[ "$value" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert greater than
# Usage: assert_gt "$actual" "$expected" ["message"]
assert_gt() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Expected '$actual' > '$expected'}"

    ((TEST_TOTAL++))

    if [[ "$actual" -gt "$expected" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Assert less than
# Usage: assert_lt "$actual" "$expected" ["message"]
assert_lt() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Expected '$actual' < '$expected'}"

    ((TEST_TOTAL++))

    if [[ "$actual" -lt "$expected" ]]; then
        ((TEST_PASSED++))
        test_debug "PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_fail "$message"
        TEST_FAILURES+=("$TEST_NAME: $message")
        return 1
    fi
}

# Skip test with reason
# Usage: skip_test "reason"
skip_test() {
    local reason="${1:-No reason given}"
    ((TEST_SKIPPED++))
    test_skip "$TEST_NAME: $reason"
    return 0
}

# ============================================================================
# Test Lifecycle Functions
# ============================================================================

# Called before each test (override in test file)
setup() {
    :  # Default no-op
}

# Called after each test (override in test file)
teardown() {
    :  # Default no-op
}

# Called once before all tests (override in test file)
setup_suite() {
    :  # Default no-op
}

# Called once after all tests (override in test file)
teardown_suite() {
    :  # Default no-op
}

# Create temporary test directory
create_test_dir() {
    TEST_TMP_DIR=$(mktemp -d -t "test_$$_XXXXXX")
    test_debug "Created test directory: $TEST_TMP_DIR"
    echo "$TEST_TMP_DIR"
}

# Clean up temporary test directory
cleanup_test_dir() {
    if [[ -n "$TEST_TMP_DIR" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
        test_debug "Cleaned up test directory: $TEST_TMP_DIR"
    fi
}

# ============================================================================
# Mocking Support
# ============================================================================

# Store original commands
declare -gA MOCKED_COMMANDS=()

# Mock a command
# Usage: mock_command "command" "replacement_output"
mock_command() {
    local cmd="$1"
    local output="$2"

    # Save original if exists
    if command -v "$cmd" &>/dev/null; then
        MOCKED_COMMANDS["$cmd"]=$(command -v "$cmd")
    fi

    # Create mock function
    eval "$cmd() { echo '$output'; return 0; }"

    test_debug "Mocked command: $cmd"
}

# Mock command with specific exit code
# Usage: mock_command_with_code "command" "output" exit_code
mock_command_with_code() {
    local cmd="$1"
    local output="$2"
    local code="$3"

    # Save original if exists
    if command -v "$cmd" &>/dev/null; then
        MOCKED_COMMANDS["$cmd"]=$(command -v "$cmd")
    fi

    # Create mock function
    eval "$cmd() { echo '$output'; return $code; }"

    test_debug "Mocked command: $cmd (exit code: $code)"
}

# Restore original command
# Usage: restore_command "command"
restore_command() {
    local cmd="$1"

    if [[ -n "${MOCKED_COMMANDS[$cmd]:-}" ]]; then
        unset -f "$cmd" 2>/dev/null || true
        test_debug "Restored command: $cmd"
    fi
}

# Restore all mocked commands
restore_all_commands() {
    for cmd in "${!MOCKED_COMMANDS[@]}"; do
        restore_command "$cmd"
    done
    MOCKED_COMMANDS=()
}

# ============================================================================
# Test Discovery and Execution
# ============================================================================

# Run a single test function
# Usage: run_test "test_function_name"
run_test() {
    local test_func="$1"
    TEST_NAME="$test_func"

    test_info "Running: $test_func"

    # Run setup
    setup

    # Run test
    local test_result=0
    $test_func || test_result=$?

    # Run teardown
    teardown

    if [[ $test_result -eq 0 ]]; then
        test_pass "$test_func"
    fi
}

# Discover and run all test functions in current file
# Test functions must start with "test_"
run_tests() {
    local test_file="${1:-}"

    # Reset counters
    TEST_PASSED=0
    TEST_FAILED=0
    TEST_SKIPPED=0
    TEST_TOTAL=0
    TEST_FAILURES=()

    # Create temp dir for tests
    create_test_dir

    # Run suite setup
    setup_suite

    # Find all test functions
    local test_functions
    if [[ -n "$test_file" ]] && [[ -f "$test_file" ]]; then
        # Source the test file
        # shellcheck source=/dev/null
        source "$test_file"
        test_functions=$(grep -E "^test_[a-zA-Z_]+\s*\(\)" "$test_file" | sed 's/().*//')
    else
        # Find in current context
        test_functions=$(declare -F | awk '{print $3}' | grep "^test_")
    fi

    # Count tests
    local test_count
    test_count=$(echo "$test_functions" | grep -c . || echo 0)

    echo ""
    echo "========================================"
    echo "  Running $test_count test(s)"
    if [[ -n "$TEST_SUITE_NAME" ]]; then
        echo "  Suite: $TEST_SUITE_NAME"
    fi
    echo "========================================"
    echo ""

    # Run each test
    while IFS= read -r test_func; do
        [[ -z "$test_func" ]] && continue
        run_test "$test_func"
    done <<< "$test_functions"

    # Run suite teardown
    teardown_suite

    # Clean up
    cleanup_test_dir
    restore_all_commands

    # Print summary
    print_summary
}

# Print test summary
print_summary() {
    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo ""
    echo "  Total:   $TEST_TOTAL"
    echo -e "  ${TEST_COLOR_PASS}Passed:  $TEST_PASSED${TEST_COLOR_RESET}"
    echo -e "  ${TEST_COLOR_FAIL}Failed:  $TEST_FAILED${TEST_COLOR_RESET}"
    echo -e "  ${TEST_COLOR_SKIP}Skipped: $TEST_SKIPPED${TEST_COLOR_RESET}"
    echo ""

    if [[ ${#TEST_FAILURES[@]} -gt 0 ]]; then
        echo "Failures:"
        for failure in "${TEST_FAILURES[@]}"; do
            echo -e "  ${TEST_COLOR_FAIL}- $failure${TEST_COLOR_RESET}"
        done
        echo ""
    fi

    if [[ $TEST_FAILED -eq 0 ]]; then
        echo -e "${TEST_COLOR_PASS}All tests passed!${TEST_COLOR_RESET}"
        return 0
    else
        echo -e "${TEST_COLOR_FAIL}Some tests failed.${TEST_COLOR_RESET}"
        return 1
    fi
}

# ============================================================================
# Test Runner
# ============================================================================

# Run all test files in a directory
# Usage: run_test_suite "tests_directory"
run_test_suite() {
    local test_dir="${1:-.}"
    local pattern="${2:-test_*.sh}"

    local total_passed=0
    local total_failed=0
    local total_skipped=0

    echo ""
    echo "========================================"
    echo "  Running Test Suite"
    echo "  Directory: $test_dir"
    echo "========================================"

    # Find test files
    local test_files
    test_files=$(find "$test_dir" -maxdepth 1 -name "$pattern" -type f | sort)

    if [[ -z "$test_files" ]]; then
        echo "No test files found matching '$pattern' in '$test_dir'"
        return 1
    fi

    # Run each test file
    while IFS= read -r test_file; do
        echo ""
        echo "----------------------------------------"
        echo "File: $(basename "$test_file")"
        echo "----------------------------------------"

        # Run tests in subshell to isolate state
        (
            # shellcheck source=/dev/null
            source "$test_file"
            run_tests
        )

        local result=$?
        if [[ $result -ne 0 ]]; then
            ((total_failed++))
        else
            ((total_passed++))
        fi
    done <<< "$test_files"

    # Final summary
    echo ""
    echo "========================================"
    echo "  Suite Summary"
    echo "========================================"
    echo "  Test files passed: $total_passed"
    echo "  Test files failed: $total_failed"
    echo ""

    [[ $total_failed -eq 0 ]]
}

# ============================================================================
# Utility Functions
# ============================================================================

# Capture stdout and stderr of a command
# Usage: output=$(capture "command args")
capture() {
    local command="$1"
    eval "$command" 2>&1
}

# Capture only stdout
# Usage: output=$(capture_stdout "command args")
capture_stdout() {
    local command="$1"
    eval "$command" 2>/dev/null
}

# Capture only stderr
# Usage: output=$(capture_stderr "command args")
capture_stderr() {
    local command="$1"
    eval "$command" 2>&1 >/dev/null
}

# Wait for condition with timeout
# Usage: wait_for "condition" timeout_seconds
wait_for() {
    local condition="$1"
    local timeout="${2:-10}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if eval "$condition"; then
            return 0
        fi
        sleep 1
        ((elapsed++))
    done

    return 1
}

# ============================================================================
# Self-Test
# ============================================================================

# Run framework self-tests
_framework_self_test() {
    TEST_SUITE_NAME="Framework Self-Test"

    echo "Running framework self-tests..."

    # Test assert_equals
    local result=""
    assert_equals "foo" "foo" "assert_equals should pass for equal values" && result="pass"
    [[ "$result" == "pass" ]] || echo "FRAMEWORK ERROR: assert_equals failed"

    # Test assert_true
    assert_true "1" "assert_true should pass for '1'" || echo "FRAMEWORK ERROR: assert_true failed"

    # Test assert_false
    assert_false "" "assert_false should pass for empty string" || echo "FRAMEWORK ERROR: assert_false failed"

    # Test assert_contains
    assert_contains "hello world" "world" "assert_contains should find substring" || echo "FRAMEWORK ERROR: assert_contains failed"

    echo "Self-tests complete."
}

# ============================================================================
# USAGE DOCUMENTATION
# ============================================================================
#
# TESTING FRAMEWORK - Usage Guide
# ================================
#
# BASIC TEST FILE STRUCTURE:
#
#   #!/usr/bin/env bash
#   source "$(dirname "$0")/framework.sh"
#
#   TEST_SUITE_NAME="My Test Suite"
#
#   # Optional: setup/teardown
#   setup() { echo "Before each test"; }
#   teardown() { echo "After each test"; }
#
#   # Test functions must start with "test_"
#   test_example() {
#       assert_equals "expected" "actual"
#   }
#
#   # Run tests
#   run_tests
#
# ASSERTION FUNCTIONS:
#
#   assert_equals "expected" "actual" ["message"]
#   assert_not_equals "unexpected" "actual" ["message"]
#   assert_true "$value" ["message"]
#   assert_false "$value" ["message"]
#   assert_contains "haystack" "needle" ["message"]
#   assert_matches "$value" "regex" ["message"]
#   assert_command_exists "command" ["message"]
#   assert_file_exists "path" ["message"]
#   assert_dir_exists "path" ["message"]
#   assert_file_contains "path" "string" ["message"]
#   assert_exit_code 0 "command" ["message"]
#   assert_success "command" ["message"]
#   assert_failure "command" ["message"]
#   assert_set "VAR_NAME" ["message"]
#   assert_numeric "$value" ["message"]
#   assert_gt "$actual" "$expected" ["message"]
#   assert_lt "$actual" "$expected" ["message"]
#   skip_test "reason"
#
# MOCKING:
#
#   mock_command "git" "mocked output"
#   mock_command_with_code "curl" "error" 1
#   restore_command "git"
#   restore_all_commands
#
# LIFECYCLE:
#
#   setup()          - Before each test
#   teardown()       - After each test
#   setup_suite()    - Before all tests
#   teardown_suite() - After all tests
#
# TEMP DIRECTORY:
#
#   local tmpdir=$(create_test_dir)
#   # ... use tmpdir ...
#   cleanup_test_dir
#
# RUNNING TESTS:
#
#   # Run tests in current file
#   run_tests
#
#   # Run specific test file
#   run_tests "/path/to/test_file.sh"
#
#   # Run all test files in directory
#   run_test_suite "/path/to/tests"
#
# VERBOSE MODE:
#
#   TEST_VERBOSE=1 ./test_file.sh
#
# ============================================================================

# If run directly, do self-test
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _framework_self_test
fi
