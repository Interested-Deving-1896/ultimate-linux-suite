#!/bin/bash
#
# Master build script - builds all package formats
#
# Usage:
#   ./build-all.sh          # Build all formats
#   ./build-all.sh deb      # Build only .deb
#   ./build-all.sh rpm      # Build only .rpm (Fedora)
#   ./build-all.sh arch     # Build only Arch package
#   ./build-all.sh opensuse # Build only openSUSE .rpm
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Ultimate Linux Suite - Package Builder${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

build_deb() {
    print_info "Building .deb package..."
    if bash "$SCRIPT_DIR/build-deb.sh"; then
        print_success "DEB package built"
        return 0
    else
        print_error "DEB build failed"
        return 1
    fi
}

build_rpm() {
    print_info "Building Fedora/RHEL .rpm package..."
    if bash "$SCRIPT_DIR/build-rpm.sh"; then
        print_success "RPM package built"
        return 0
    else
        print_error "RPM build failed"
        return 1
    fi
}

build_arch() {
    print_info "Building Arch Linux package..."
    if bash "$SCRIPT_DIR/build-arch.sh"; then
        print_success "Arch package built"
        return 0
    else
        print_error "Arch build failed"
        return 1
    fi
}

build_opensuse() {
    print_info "Building openSUSE .rpm package..."
    if bash "$SCRIPT_DIR/build-opensuse.sh"; then
        print_success "openSUSE RPM package built"
        return 0
    else
        print_error "openSUSE build failed"
        return 1
    fi
}

detect_and_build() {
    # Detect current distro and build appropriate package
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|kali|parrot|pop)
                build_deb
                ;;
            fedora|rhel|centos|rocky|alma)
                build_rpm
                ;;
            arch|manjaro|endeavouros|artix)
                build_arch
                ;;
            opensuse*|suse)
                build_opensuse
                ;;
            *)
                print_error "Unknown distribution: $ID"
                print_info "Use: $0 [deb|rpm|arch|opensuse]"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect distribution"
        exit 1
    fi
}

print_header

# Clean dist directory
mkdir -p "$PROJECT_ROOT/dist"

case "${1:-}" in
    deb)
        build_deb
        ;;
    rpm)
        build_rpm
        ;;
    arch)
        build_arch
        ;;
    opensuse)
        build_opensuse
        ;;
    all)
        print_info "Building all package formats..."
        echo ""

        # Try each build, continue on failure
        build_deb || true
        echo ""
        build_rpm || true
        echo ""
        build_arch || true
        echo ""
        build_opensuse || true
        ;;
    "")
        detect_and_build
        ;;
    *)
        echo "Usage: $0 [deb|rpm|arch|opensuse|all]"
        echo ""
        echo "  deb      - Build .deb for Debian/Ubuntu/Mint/Kali/Parrot"
        echo "  rpm      - Build .rpm for Fedora/RHEL/CentOS"
        echo "  arch     - Build .pkg.tar.zst for Arch Linux"
        echo "  opensuse - Build .rpm for openSUSE"
        echo "  all      - Build all formats"
        echo "  (none)   - Auto-detect and build for current distro"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Build Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Packages in: $PROJECT_ROOT/dist/"
ls -la "$PROJECT_ROOT/dist/" 2>/dev/null || echo "(empty)"
