#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# OpenNotch Install Script
# Builds, signs, installs, and sets up auto-start
# ─────────────────────────────────────────────

APP_NAME="OpenNotch"
BUNDLE_ID="com.opennotch.app"
PLIST_LABEL="com.opennotch.app"
INSTALL_DIR="/Applications"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

echo "══════════════════════════════════════════"
echo "  🔧 OpenNotch Installer"
echo "══════════════════════════════════════════"
echo ""

# ── Step 1: Check prerequisites ──────────────

echo "▶ Checking prerequisites..."
if ! command -v xcodebuild &>/dev/null; then
    echo "✗ xcodebuild not found. Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${SCRIPT_DIR}/${APP_NAME}.xcodeproj"

if [ ! -d "$PROJECT" ]; then
    echo "✗ ${APP_NAME}.xcodeproj not found in ${SCRIPT_DIR}"
    exit 1
fi
echo "✓ Prerequisites OK"
echo ""

# ── Step 2: Build ────────────────────────────

echo "▶ Building ${APP_NAME} (Release)..."
BUILD_DIR="${SCRIPT_DIR}/build"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -quiet \
    build

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "✗ Build failed — ${APP_NAME}.app not found"
    exit 1
fi
echo "✓ Build succeeded"
echo ""

# ── Step 3: Code sign (ad-hoc / local) ──────

echo "▶ Signing ${APP_NAME}.app (ad-hoc)..."
codesign --deep --force --options runtime --entitlements "${SCRIPT_DIR}/${APP_NAME}/${APP_NAME}.entitlements" --sign - "$APP_PATH"
echo "✓ Signed"
echo ""

# ── Step 4: Install to /Applications ─────────

echo "▶ Installing to ${INSTALL_DIR}..."

# Kill running instance if any
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Remove old installation
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

cp -R "$APP_PATH" "${INSTALL_DIR}/"
echo "✓ Installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo ""

# ── Step 5: Create launchd plist ─────────────

echo "▶ Setting up auto-start on login..."

# Unload existing plist if present
if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

mkdir -p "$(dirname "$PLIST_PATH")"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/${APP_NAME}.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/${APP_NAME}.stderr.log</string>
</dict>
</plist>
EOF

launchctl load "$PLIST_PATH"
echo "✓ Launch agent created and loaded"
echo ""

# ── Step 6: Launch ───────────────────────────

echo "▶ Launching ${APP_NAME}..."
open "${INSTALL_DIR}/${APP_NAME}.app"
echo ""

echo "══════════════════════════════════════════"
echo "  ✅ ${APP_NAME} installed successfully!"
echo ""
echo "  • App:      ${INSTALL_DIR}/${APP_NAME}.app"
echo "  • Settings: http://localhost:7331"
echo "  • Config:   ~/Library/Application Support/OpenNotch/config.json"
echo "  • Auto-start is enabled (login item)"
echo ""
echo "  To uninstall:"
echo "    pkill -x \"${APP_NAME}\""
echo "    launchctl unload \"${PLIST_PATH}\""
echo "    rm -rf \"${INSTALL_DIR}/${APP_NAME}.app\""
echo "    rm \"${PLIST_PATH}\""
echo "══════════════════════════════════════════"
