#!/usr/bin/env bash
#
# dev-check.sh - Development sanity checks for Ultimate Linux Suite
#
# Runs syntax checks and shellcheck on all scripts
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Ultimate Linux Suite - Development Checks"
echo "=========================================="
echo

# Find all .sh files
mapfile -t scripts < <(find "$REPO_ROOT" -name "*.sh" -type f)

echo "Found ${#scripts[@]} shell scripts"
echo

# Syntax check
echo "Running bash syntax check..."
errors=0
for script in "${scripts[@]}"; do
    rel_path="${script#$REPO_ROOT/}"
    if bash -n "$script" 2>/dev/null; then
        printf "  ${GREEN}OK${RESET}  %s\n" "$rel_path"
    else
        printf "  ${RED}FAIL${RESET}  %s\n" "$rel_path"
        bash -n "$script" 2>&1 | sed 's/^/       /'
        ((errors++))
    fi
done

echo
if [[ $errors -gt 0 ]]; then
    echo -e "${RED}Syntax check: $errors errors${RESET}"
else
    echo -e "${GREEN}Syntax check: All passed${RESET}"
fi

echo

# ShellCheck (optional)
if command -v shellcheck &>/dev/null; then
    echo "Running shellcheck..."
    sc_errors=0

    for script in "${scripts[@]}"; do
        rel_path="${script#$REPO_ROOT/}"
        if shellcheck -S warning "$script" &>/dev/null; then
            printf "  ${GREEN}OK${RESET}  %s\n" "$rel_path"
        else
            printf "  ${YELLOW}WARN${RESET}  %s\n" "$rel_path"
            shellcheck -S warning "$script" 2>&1 | head -10 | sed 's/^/       /'
            ((sc_errors++))
        fi
    done

    echo
    if [[ $sc_errors -gt 0 ]]; then
        echo -e "${YELLOW}ShellCheck: $sc_errors scripts with warnings${RESET}"
    else
        echo -e "${GREEN}ShellCheck: All clean${RESET}"
    fi
else
    echo -e "${YELLOW}ShellCheck not installed (optional)${RESET}"
    echo "  Install with: sudo apt install shellcheck"
fi

echo
echo "=========================================="

# Exit with error if syntax failed
if [[ $errors -gt 0 ]]; then
    exit 1
fi

echo -e "${GREEN}All checks passed!${RESET}"
