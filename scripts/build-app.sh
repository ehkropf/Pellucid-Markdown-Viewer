#!/bin/bash
set -euo pipefail

# Build md_viewr.app bundle from SPM executable

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="md_viewr"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
CONFIG="${1:-release}"

echo "Building ${APP_NAME} (${CONFIG})..."
cd "$PROJECT_DIR"

if [ "$CONFIG" = "release" ]; then
    swift build -c release 2>&1
    BINARY="${PROJECT_DIR}/.build/release/${APP_NAME}"
else
    swift build 2>&1
    BINARY="${PROJECT_DIR}/.build/debug/${APP_NAME}"
fi

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

# Copy binary
cp "$BINARY" "${CONTENTS}/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS}/Info.plist"

# Copy app icon
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${CONTENTS}/Resources/"
    echo "  Copied app icon"
fi

# Copy SwiftMath font resources (required for math rendering)
SWIFTMATH_BUNDLE=$(find "${PROJECT_DIR}/.build" -name "SwiftMath_SwiftMath.bundle" -type d 2>/dev/null | head -1)
if [ -n "$SWIFTMATH_BUNDLE" ]; then
    cp -R "$SWIFTMATH_BUNDLE" "${CONTENTS}/Resources/"
    echo "  Copied SwiftMath resources"
fi

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Run:   open ${APP_BUNDLE}"
echo "  or:  ${APP_BUNDLE}/Contents/MacOS/${APP_NAME} /path/to/file.md"
