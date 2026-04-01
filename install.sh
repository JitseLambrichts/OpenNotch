#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# OpenNotch Install Script
# Builds, signs, and runs the application
# ─────────────────────────────────────────────

APP_NAME="OpenNotch"

echo "══════════════════════════════════════════"
echo "  🔧 OpenNotch Installer"
echo "══════════════════════════════════════════"
echo ""

echo "▶ Killing existing OpenNotch..."
killall OpenNotch 2>/dev/null || true

echo "▶ Building ${APP_NAME}..."
xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE="Manual"

# Extract the built products directory dynamically to avoid hardcoding the DerivedData path
APP_DIR=$(xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR" | awk -F ' = ' '{print $2}')

if [ -d "${APP_DIR}/${APP_NAME}.app" ]; then
    echo "▶ Launching ${APP_NAME}..."
    open "${APP_DIR}/${APP_NAME}.app"
    echo "✓ App launched successfully."
else
    echo "✗ Failed to find built app at ${APP_DIR}/${APP_NAME}.app"
    exit 1
fi

