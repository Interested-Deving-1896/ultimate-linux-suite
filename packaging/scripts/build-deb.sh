#!/bin/bash
#
# Build .deb package for Debian/Ubuntu/Mint/Kali/Parrot
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/deb"
PKG_NAME="ultimate-linux-suite"
VERSION="$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "2.3.0")"

echo "==> Building .deb package for $PKG_NAME $VERSION"

# Check dependencies
for cmd in dpkg-buildpackage debuild; do
    if command -v "$cmd" &>/dev/null; then
        BUILD_CMD="$cmd"
        break
    fi
done

if [[ -z "$BUILD_CMD" ]]; then
    echo "Error: dpkg-buildpackage or debuild required"
    echo "Install with: sudo apt install build-essential devscripts debhelper"
    exit 1
fi

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create source directory
SRC_DIR="$BUILD_DIR/${PKG_NAME}-${VERSION}"
mkdir -p "$SRC_DIR"

# Copy source files
echo "==> Copying source files..."
cp -r "$PROJECT_ROOT/ultimate.sh" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/lib" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/modules" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/menus" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/backends" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/apps" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/configs" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/drivers" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/README.md" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/CHANGELOG.md" "$SRC_DIR/"
cp -r "$PROJECT_ROOT/LICENSE" "$SRC_DIR/"

# Copy debian directory
cp -r "$PROJECT_ROOT/packaging/debian" "$SRC_DIR/"

# Build package
echo "==> Building package..."
cd "$SRC_DIR"

if [[ "$BUILD_CMD" == "debuild" ]]; then
    debuild -us -uc -b
else
    dpkg-buildpackage -us -uc -b
fi

# Move built packages to output
echo "==> Moving built packages..."
mkdir -p "$PROJECT_ROOT/dist"
mv "$BUILD_DIR"/*.deb "$PROJECT_ROOT/dist/" 2>/dev/null || true

echo ""
echo "==> Build complete!"
echo "    Packages available in: $PROJECT_ROOT/dist/"
ls -la "$PROJECT_ROOT/dist/"*.deb 2>/dev/null || echo "    (no packages found)"
