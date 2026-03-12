#!/bin/bash
set -e

# DriveMosaic Build & Package Script
# Produces a distributable DMG installer

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="/tmp/DriveMosaicBuild"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="DriveMosaic"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "═══════════════════════════════════════════"
echo "  DriveMosaic Build & Package"
echo "  Version: $VERSION"
echo "═══════════════════════════════════════════"
echo ""

# Step 1: Quit any running instance
echo "→ Quitting any running instance..."
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
sleep 0.3

# Step 2: Clean build
echo "→ Cleaning build directory..."
rm -rf "$BUILD_DIR"

echo "→ Building $APP_NAME (Release)..."
cd "$PROJECT_DIR"
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    ENABLE_HARDENED_RUNTIME=YES \
    clean build 2>&1 | grep -E "error:|BUILD|warning:" || true

# Verify build succeeded
APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "✗ BUILD FAILED — no .app bundle found"
    exit 1
fi

echo "✓ Build succeeded: $APP_PATH"
echo ""

# Step 3: Create DMG
echo "→ Creating DMG installer..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$DMG_NAME"

# Stage DMG contents
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create compressed DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME" 2>&1 | grep -v "^$"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✓ DMG created successfully!"
echo "  $DIST_DIR/$DMG_NAME"
echo ""
ls -lh "$DIST_DIR/$DMG_NAME" | awk '{print "  Size: " $5}'
echo "═══════════════════════════════════════════"

# Step 4: Also install locally
echo ""
echo "→ Installing to /Applications..."
rm -rf "/Applications/${APP_NAME}.app"
cp -R "$APP_PATH" "/Applications/${APP_NAME}.app"
echo "✓ Installed to /Applications/${APP_NAME}.app"
echo ""
echo "Done! To launch: open /Applications/${APP_NAME}.app"
