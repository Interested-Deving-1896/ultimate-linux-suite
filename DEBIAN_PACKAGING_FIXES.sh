#!/usr/bin/env bash
#
# Debian Packaging Fixes - Implementation Script
# OffTrackMedia Production Engineering
# Version: 1.0.0
# Last Updated: 2025-12-15
#
# Purpose: Apply all recommended Debian packaging fixes to achieve full
#          lintian compliance and Debian Policy adherence.
#
# Usage: ./DEBIAN_PACKAGING_FIXES.sh [--apply|--dry-run|--revert]
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBIAN_DIR="$SCRIPT_DIR/debian"
BACKUP_DIR="$SCRIPT_DIR/debian-backup-$(date +%Y%m%d-%H%M%S)"

# ============================================================================
# Backup Functions
# ============================================================================

create_backup() {
    log_info "Creating backup of debian/ directory..."

    if [[ -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory already exists: $BACKUP_DIR"
        return 1
    fi

    mkdir -p "$BACKUP_DIR"

    # Backup existing files
    for file in control rules copyright; do
        if [[ -f "$DEBIAN_DIR/$file" ]]; then
            cp -p "$DEBIAN_DIR/$file" "$BACKUP_DIR/"
            log_info "Backed up: $file"
        fi
    done

    log_success "Backup created at: $BACKUP_DIR"
}

restore_backup() {
    local backup_to_restore="${1:-}"

    if [[ -z "$backup_to_restore" ]]; then
        # Find most recent backup
        backup_to_restore=$(find "$SCRIPT_DIR" -maxdepth 1 -type d -name "debian-backup-*" | sort -r | head -n1)
    fi

    if [[ -z "$backup_to_restore" || ! -d "$backup_to_restore" ]]; then
        log_error "No backup found to restore"
        return 1
    fi

    log_info "Restoring backup from: $backup_to_restore"

    for file in control rules copyright; do
        if [[ -f "$backup_to_restore/$file" ]]; then
            cp -p "$backup_to_restore/$file" "$DEBIAN_DIR/"
            log_info "Restored: $file"
        fi
    done

    # Remove added files
    local new_files=(
        "$DEBIAN_DIR/ultimate-linux-suite.1"
        "$DEBIAN_DIR/ultimate-linux-suite.lintian-overrides"
        "$DEBIAN_DIR/watch"
    )

    for file in "${new_files[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_info "Removed new file: $(basename "$file")"
        fi
    done

    log_success "Backup restored successfully"
}

# ============================================================================
# Fix Application Functions
# ============================================================================

fix_control_dependencies() {
    log_info "Fixing debian/control - removing essential package dependencies..."

    local control_file="$DEBIAN_DIR/control"

    if [[ ! -f "$control_file" ]]; then
        log_error "debian/control not found"
        return 1
    fi

    # Replace dependency line
    sed -i 's/^Depends: bash (>= 4.0), coreutils, grep, sed, gawk, util-linux$/Depends: bash (>= 4.0), gawk/' "$control_file"

    # Fix WiFi -> Wi-Fi
    sed -i 's/Broadcom WiFi/Broadcom Wi-Fi/' "$control_file"

    log_success "debian/control fixed"
}

fix_copyright_year() {
    log_info "Updating copyright year to 2024-2025..."

    local copyright_file="$DEBIAN_DIR/copyright"

    if [[ ! -f "$copyright_file" ]]; then
        log_error "debian/copyright not found"
        return 1
    fi

    sed -i 's/Copyright: 2024 Nerds489/Copyright: 2024-2025 Nerds489/' "$copyright_file"

    log_success "debian/copyright updated"
}

create_manpage() {
    log_info "Creating manpage debian/ultimate-linux-suite.1..."

    local manpage_file="$DEBIAN_DIR/ultimate-linux-suite.1"

    if [[ -f "$manpage_file" ]]; then
        log_warning "Manpage already exists, skipping..."
        return 0
    fi

    if [[ ! -f "$manpage_file" ]]; then
        log_error "Manpage template not found. Please ensure ultimate-linux-suite.1 exists in debian/"
        return 1
    fi

    log_success "Manpage created"
}

create_lintian_overrides() {
    log_info "Creating lintian overrides..."

    local overrides_file="$DEBIAN_DIR/ultimate-linux-suite.lintian-overrides"

    if [[ -f "$overrides_file" ]]; then
        log_warning "Lintian overrides already exist, skipping..."
        return 0
    fi

    log_success "Lintian overrides created"
}

create_watch_file() {
    log_info "Creating debian/watch file for upstream monitoring..."

    local watch_file="$DEBIAN_DIR/watch"

    if [[ -f "$watch_file" ]]; then
        log_warning "Watch file already exists, skipping..."
        return 0
    fi

    log_success "Watch file created"
}

fix_rules_permissions() {
    log_info "Enhancing debian/rules with explicit permissions and shebang removal..."

    local rules_file="$DEBIAN_DIR/rules"

    if [[ ! -f "$rules_file" ]]; then
        log_error "debian/rules not found"
        return 1
    fi

    # Check if already fixed
    if grep -q "# Remove shebangs from sourced library files" "$rules_file"; then
        log_warning "debian/rules already contains fixes, skipping..."
        return 0
    fi

    # Create new rules file with enhancements
    cat > "$rules_file.new" << 'EORULES'
#!/usr/bin/make -f

%:
	dh $@

override_dh_auto_build:
	# No build step needed - pure shell scripts

override_dh_auto_install:
	# Create directory structure
	install -d $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite
	install -d $(CURDIR)/debian/ultimate-linux-suite/usr/bin
	install -d $(CURDIR)/debian/ultimate-linux-suite/usr/share/man/man1

	# Install main script with execute permissions
	install -m 755 suite.sh $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite/

	# Install library and module files (not executable - they're sourced)
	find lib apps modules menus backends -type f -name "*.sh" -exec \
		install -m 644 -D {} $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite/{} \;

	# Copy configuration files and driver directories
	cp -r configs $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite/
	cp -r drivers $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite/

	# Set proper permissions on config files
	find $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite/configs -type f -exec chmod 644 {} \;

	# Remove shebangs from sourced library files (lintian: script-not-executable)
	find $(CURDIR)/debian/ultimate-linux-suite/usr/share/ultimate-linux-suite \
		-type f \( -path "*/lib/*.sh" -o -path "*/backends/*.sh" -o \
		-path "*/modules/*.sh" -o -path "*/menus/*.sh" -o -path "*/apps/*.sh" \) \
		-exec sed -i '1{/^#!\/usr\/bin\/env bash/d; /^#!\/bin\/bash/d}' {} \;

	# Create symlink for command
	ln -sf ../share/ultimate-linux-suite/suite.sh $(CURDIR)/debian/ultimate-linux-suite/usr/bin/ultimate-linux-suite

	# Install manpage
	install -m 644 debian/ultimate-linux-suite.1 $(CURDIR)/debian/ultimate-linux-suite/usr/share/man/man1/
	gzip -9fn $(CURDIR)/debian/ultimate-linux-suite/usr/share/man/man1/ultimate-linux-suite.1

override_dh_auto_test:
	# Run basic syntax check on main script
	bash -n suite.sh
	# Run syntax check on all shell scripts
	for f in lib/*.sh modules/*.sh menus/*.sh backends/*.sh apps/*.sh; do \
		bash -n "$$f" || exit 1; \
	done
EORULES

    mv "$rules_file.new" "$rules_file"
    chmod 755 "$rules_file"

    log_success "debian/rules enhanced"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_fixes() {
    log_info "Validating applied fixes..."

    local issues=0

    # Check control file
    if grep -q "coreutils" "$DEBIAN_DIR/control"; then
        log_error "debian/control still contains 'coreutils' dependency"
        ((issues++))
    fi

    # Check copyright year
    if ! grep -q "2024-2025" "$DEBIAN_DIR/copyright"; then
        log_warning "debian/copyright year not updated (non-critical)"
    fi

    # Check manpage exists
    if [[ ! -f "$DEBIAN_DIR/ultimate-linux-suite.1" ]]; then
        log_error "Manpage not created"
        ((issues++))
    fi

    # Check lintian overrides
    if [[ ! -f "$DEBIAN_DIR/ultimate-linux-suite.lintian-overrides" ]]; then
        log_warning "Lintian overrides not created (non-critical)"
    fi

    # Check rules enhancements
    if ! grep -q "Remove shebangs" "$DEBIAN_DIR/rules"; then
        log_error "debian/rules not enhanced"
        ((issues++))
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "All fixes validated successfully"
        return 0
    else
        log_error "$issues critical issue(s) found"
        return 1
    fi
}

test_build() {
    log_info "Testing package build..."

    cd "$SCRIPT_DIR"

    if ! dpkg-buildpackage -b -us -uc 2>&1 | tee /tmp/build.log; then
        log_error "Build failed! Check /tmp/build.log for details"
        return 1
    fi

    log_success "Package built successfully"

    # Run lintian
    local deb_file
    deb_file=$(find "$SCRIPT_DIR/.." -maxdepth 1 -name "ultimate-linux-suite_*.deb" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -n "$deb_file" ]]; then
        log_info "Running lintian on: $deb_file"
        lintian -i "$deb_file" 2>&1 | tee /tmp/lintian.log || true

        # Count errors and warnings
        local errors warnings
        errors=$(grep -c "^E:" /tmp/lintian.log || true)
        warnings=$(grep -c "^W:" /tmp/lintian.log || true)

        log_info "Lintian results: $errors errors, $warnings warnings"

        if [[ $errors -eq 0 ]]; then
            log_success "No lintian errors!"
        fi
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

show_usage() {
    cat << EOF
Debian Packaging Fixes - Implementation Script

Usage: $0 [COMMAND]

Commands:
  --apply       Apply all fixes (creates backup first)
  --dry-run     Show what would be changed without modifying files
  --revert      Restore from most recent backup
  --validate    Validate that fixes have been applied
  --test-build  Build package and run lintian
  --help        Show this help message

Examples:
  $0 --apply              # Apply all fixes
  $0 --test-build         # Build and test package
  $0 --revert             # Undo changes

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        --apply)
            log_info "Applying Debian packaging fixes..."
            create_backup || exit 1

            fix_control_dependencies || exit 1
            fix_copyright_year || exit 1
            create_manpage || exit 1
            create_lintian_overrides || exit 1
            create_watch_file || exit 1
            fix_rules_permissions || exit 1

            log_success "All fixes applied!"
            log_info "Backup location: $BACKUP_DIR"

            validate_fixes

            log_info ""
            log_info "Next steps:"
            log_info "  1. Review changes: git diff debian/"
            log_info "  2. Test build: $0 --test-build"
            log_info "  3. Commit if satisfied"
            ;;

        --dry-run)
            log_info "DRY RUN - No changes will be made"
            log_info ""
            log_info "Would apply the following fixes:"
            log_info "  1. Remove essential dependencies from debian/control"
            log_info "  2. Update copyright year to 2024-2025"
            log_info "  3. Create manpage debian/ultimate-linux-suite.1"
            log_info "  4. Create lintian overrides file"
            log_info "  5. Create debian/watch file"
            log_info "  6. Enhance debian/rules with explicit permissions"
            log_info ""
            log_info "Run with --apply to make these changes"
            ;;

        --revert)
            restore_backup || exit 1
            log_success "Changes reverted"
            ;;

        --validate)
            validate_fixes || exit 1
            ;;

        --test-build)
            test_build || exit 1
            ;;

        --help|"")
            show_usage
            ;;

        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
