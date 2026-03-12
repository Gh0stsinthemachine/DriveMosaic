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

# Step 3: Create styled DMG with background and icon layout
echo "→ Creating DMG installer..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$DMG_NAME"

BG_IMG="$PROJECT_DIR/resources/dmg-background.tiff"
DMG_SIZE="5m"
DMG_TEMP="$BUILD_DIR/${APP_NAME}-temp.dmg"

# Stage DMG contents
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create a writable DMG first so we can style it
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -size "$DMG_SIZE" \
    "$DMG_TEMP" 2>&1 | grep -v "^$"

# Ensure no stale mounts
hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null || true

# Mount the writable DMG
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | awk -F'\t' '{print $NF}')
VOLUME_NAME=$(basename "$MOUNT_DIR")
echo "  Mounted at: $MOUNT_DIR (volume: $VOLUME_NAME)"

# Copy background image into the DMG (hidden)
mkdir -p "$MOUNT_DIR/.background"
cp "$BG_IMG" "$MOUNT_DIR/.background/background.tiff"

# Use AppleScript to style the DMG window
echo "→ Styling DMG window..."
sleep 1
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 760, 500}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set background picture of theViewOptions to file ".background:background.tiff"
        delay 1
        -- Position app icon on left, Applications on right (matching arrow)
        set position of item "${APP_NAME}.app" to {165, 220}
        set position of item "Applications" to {495, 220}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Make sure writes sync
sync
sleep 1

# Detach the DMG
hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force

# Convert to compressed read-only DMG
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DIST_DIR/$DMG_NAME" 2>&1 | grep -v "^$"

rm -f "$DMG_TEMP"

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
