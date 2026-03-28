#!/bin/bash
# Pellucid — Native macOS markdown viewer
# Copyright (C) 2026 Everett Kropf
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

set -euo pipefail

# Build Pellucid.app bundle from SPM executable

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Pellucid"
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

# Ad-hoc code sign
echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Run:   open ${APP_BUNDLE}"
echo "  or:  ${APP_BUNDLE}/Contents/MacOS/${APP_NAME} /path/to/file.md"
