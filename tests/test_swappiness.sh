#!/bin/bash
# Unified Suite - Swappiness Compliance Test
# License: GPL-3.0-or-later
#
# This test verifies that ALL swappiness values in the suite
# are >= 85 as per the project specification.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="${SCRIPT_DIR}/.."

source "$SUITE_ROOT/lib/init.sh"

echo "Swappiness Compliance Test"
echo "=========================="
echo ""
echo "REQUIREMENT: All swappiness values must be >= 85"
echo ""

PASS=0
FAIL=0

# Test all RAM profiles
echo "RAM Profiles:"
for profile in MINIMAL LOW MEDIUM HIGH VERY_HIGH; do
    swappiness=$(get_profile_value "$profile" "SWAPPINESS")
    if [[ $swappiness -ge 85 ]]; then
        echo "  [PASS] $profile: $swappiness (>= 85)"
        ((PASS++))
    else
        echo "  [FAIL] $profile: $swappiness (< 85) - VIOLATION!"
        ((FAIL++))
    fi
done

echo ""

# Verify no hardcoded low swappiness values in code
echo "Code Scan for Low Swappiness Values:"
violations=$(grep -rn "swappiness.*[0-7][0-9]\|swappiness.*[1-9]$\|swappiness = [0-7]" \
    "$SUITE_ROOT/lib" "$SUITE_ROOT/modules" 2>/dev/null | \
    grep -v "# " | grep -v "85" || true)

if [[ -z "$violations" ]]; then
    echo "  [PASS] No hardcoded low swappiness values found"
    ((PASS++))
else
    echo "  [WARN] Potential low swappiness values found:"
    echo "$violations"
fi

echo ""
echo "============================================"
echo "Passed: $PASS | Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo "SWAPPINESS COMPLIANCE: VERIFIED"
    exit 0
else
    echo "SWAPPINESS COMPLIANCE: FAILED"
    exit 1
fi
