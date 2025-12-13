#!/bin/bash
#
# Build .pkg.tar.zst package for Arch Linux
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/arch"
PKG_NAME="ultimate-linux-suite"
VERSION="1.0.0"

echo "==> Building Arch package for $PKG_NAME $VERSION"

# Check dependencies
if ! command -v makepkg &>/dev/null; then
    echo "Error: makepkg required (are you on Arch Linux?)"
    exit 1
fi

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create source tarball matching what PKGBUILD expects
echo "==> Creating source tarball..."
TARBALL_DIR="$BUILD_DIR/${PKG_NAME}-${VERSION}"
mkdir -p "$TARBALL_DIR"

cp -r "$PROJECT_ROOT/ultimate.sh" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/lib" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/modules" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/menus" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/backends" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/apps" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/configs" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/drivers" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/README.md" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/CHANGELOG.md" "$TARBALL_DIR/"
cp -r "$PROJECT_ROOT/LICENSE" "$TARBALL_DIR/"

cd "$BUILD_DIR"
tar czf "${PKG_NAME}-${VERSION}.tar.gz" "${PKG_NAME}-${VERSION}"
rm -rf "${PKG_NAME}-${VERSION}"

# Copy PKGBUILD and install file
cp "$PROJECT_ROOT/packaging/arch/PKGBUILD" "$BUILD_DIR/"
cp "$PROJECT_ROOT/packaging/arch/ultimate-linux-suite.install" "$BUILD_DIR/"

# Update PKGBUILD to use local source
sed -i "s|source=(.*)|source=(\"${PKG_NAME}-${VERSION}.tar.gz\")|" "$BUILD_DIR/PKGBUILD"

# Calculate checksum
SHA256=$(sha256sum "$BUILD_DIR/${PKG_NAME}-${VERSION}.tar.gz" | cut -d' ' -f1)
sed -i "s|sha256sums=.*|sha256sums=('$SHA256')|" "$BUILD_DIR/PKGBUILD"

# Build package
echo "==> Building package..."
cd "$BUILD_DIR"
makepkg -sf --noconfirm

# Move built packages to output
echo "==> Moving built packages..."
mkdir -p "$PROJECT_ROOT/dist"
mv "$BUILD_DIR"/*.pkg.tar.* "$PROJECT_ROOT/dist/" 2>/dev/null || true

echo ""
echo "==> Build complete!"
echo "    Packages available in: $PROJECT_ROOT/dist/"
ls -la "$PROJECT_ROOT/dist/"*.pkg.tar.* 2>/dev/null || echo "    (no packages found)"
