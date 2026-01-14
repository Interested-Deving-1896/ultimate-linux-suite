#!/bin/bash
# Unified Suite - Test Runner
# License: GPL-3.0-or-later

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="${SCRIPT_DIR}/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║          UNIFIED SUITE - TEST RUNNER                      ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

PASS=0
FAIL=0

# Test function
test_result() {
    local name="$1"
    local result="$2"

    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${RESET} $name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${RESET} $name"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
# LIBRARY TESTS
# ============================================================

echo ""
echo "Testing Libraries..."
echo "===================="

# Test library loading
(
    source "$SUITE_ROOT/lib/init.sh"
    verify_libraries
) 2>/dev/null
test_result "Library loading" $?

# Test individual libraries
for lib in colors core logging os_detect tui pkg safety deps config optimization hardware monitor macbook_detect; do
    (
        source "$SUITE_ROOT/lib/${lib}.sh" 2>/dev/null
    )
    test_result "Load lib/${lib}.sh" $?
done

# ============================================================
# SWAPPINESS COMPLIANCE TESTS
# ============================================================

echo ""
echo "Testing Swappiness Compliance (All must be >= 85)..."
echo "===================================================="

source "$SUITE_ROOT/lib/optimization.sh"

for profile in MINIMAL LOW MEDIUM HIGH VERY_HIGH; do
    swappiness=$(get_profile_value "$profile" "SWAPPINESS")
    if [[ $swappiness -ge 85 ]]; then
        test_result "Profile $profile swappiness ($swappiness >= 85)" 0
    else
        test_result "Profile $profile swappiness ($swappiness < 85)" 1
    fi
done

# ============================================================
# MODULE TESTS
# ============================================================

echo ""
echo "Testing Modules..."
echo "=================="

for module in \
    modules/optimization/ram_optimizer.sh \
    modules/optimization/cpu_optimizer.sh \
    modules/optimization/profiles.sh \
    modules/apps/app_installer.sh \
    modules/bootstrap/bootstrap.sh; do

    if [[ -f "$SUITE_ROOT/$module" ]]; then
        (
            source "$SUITE_ROOT/lib/init.sh"
            source "$SUITE_ROOT/$module" 2>/dev/null
        )
        test_result "Load $module" $?
    else
        test_result "Load $module (missing)" 1
    fi
done

# ============================================================
# SYNTAX VALIDATION
# ============================================================

echo ""
echo "Testing Syntax..."
echo "================="

syntax_errors=0
for script in $(find "$SUITE_ROOT" -name "*.sh" -type f); do
    if ! bash -n "$script" 2>/dev/null; then
        echo -e "${RED}[SYNTAX ERROR]${RESET} $script"
        ((syntax_errors++))
    fi
done

if [[ $syntax_errors -eq 0 ]]; then
    test_result "All scripts pass syntax check" 0
else
    test_result "Syntax errors found: $syntax_errors" 1
fi

# ============================================================
# CLI TESTS
# ============================================================

echo ""
echo "Testing CLI..."
echo "=============="

# Test --help
"$SUITE_ROOT/unified.sh" --help &>/dev/null
test_result "unified.sh --help" $?

# Test --version
"$SUITE_ROOT/unified.sh" --version &>/dev/null
test_result "unified.sh --version" $?

# Test --dry-run status
"$SUITE_ROOT/unified.sh" --dry-run status &>/dev/null
test_result "unified.sh --dry-run status" $?

# ============================================================
# SUMMARY
# ============================================================

echo ""
echo "============================================"
echo -e "Tests: $((PASS + FAIL)) | ${GREEN}Passed: $PASS${RESET} | ${RED}Failed: $FAIL${RESET}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}ALL TESTS PASSED${RESET}"
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED${RESET}"
    exit 1
fi
