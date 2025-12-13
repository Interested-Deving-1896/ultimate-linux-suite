#!/bin/bash
#
# Build .rpm package for Fedora/RHEL/CentOS
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/rpm"
PKG_NAME="ultimate-linux-suite"
VERSION="1.0.0"

echo "==> Building .rpm package for $PKG_NAME $VERSION"

# Check dependencies
if ! command -v rpmbuild &>/dev/null; then
    echo "Error: rpmbuild required"
    echo "Install with: sudo dnf install rpm-build rpmdevtools"
    exit 1
fi

# Clean and create build directory structure
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create source tarball
echo "==> Creating source tarball..."
TARBALL_DIR="$BUILD_DIR/SOURCES/${PKG_NAME}-${VERSION}"
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

cd "$BUILD_DIR/SOURCES"
tar czf "${PKG_NAME}-${VERSION}.tar.gz" "${PKG_NAME}-${VERSION}"
rm -rf "${PKG_NAME}-${VERSION}"

# Copy spec file
cp "$PROJECT_ROOT/packaging/rpm/ultimate-linux-suite.spec" "$BUILD_DIR/SPECS/"

# Build package
echo "==> Building package..."
rpmbuild --define "_topdir $BUILD_DIR" -bb "$BUILD_DIR/SPECS/ultimate-linux-suite.spec"

# Move built packages to output
echo "==> Moving built packages..."
mkdir -p "$PROJECT_ROOT/dist"
find "$BUILD_DIR/RPMS" -name "*.rpm" -exec mv {} "$PROJECT_ROOT/dist/" \;

echo ""
echo "==> Build complete!"
echo "    Packages available in: $PROJECT_ROOT/dist/"
ls -la "$PROJECT_ROOT/dist/"*.rpm 2>/dev/null || echo "    (no packages found)"
