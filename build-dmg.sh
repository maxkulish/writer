#!/bin/bash

# Configuration
APP_NAME="Writer"
PROJECT_DIR=$(pwd)
BUILD_DIR="${PROJECT_DIR}/build"
DERIVED_DATA_DIR="${HOME}/Library/Developer/Xcode/DerivedData"
DMG_NAME="${APP_NAME}_Installer"
DMG_FINAL="${DMG_NAME}.dmg"
TMP_DMG="tmp.dmg"
VOLUME_NAME="${APP_NAME} Installer"

echo "=== Building Writer.app ==="

# Create build directory
mkdir -p "${BUILD_DIR}"

# First, clean any existing builds
echo "Cleaning previous builds..."
xcodebuild clean -project Writer.xcodeproj -scheme Writer -configuration Release

# Build the project
echo "Building project..."
xcodebuild -project Writer.xcodeproj -scheme Writer -configuration Release build

# Find the app in DerivedData
APP_PATH=$(find "${DERIVED_DATA_DIR}" -name "Writer.app" -path "*/Release/*" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find Writer.app in DerivedData"
    exit 1
fi

echo "Found app at: ${APP_PATH}"

# Create a temporary directory for the DMG contents
DMG_TEMP="${BUILD_DIR}/dmg_temp"
mkdir -p "${DMG_TEMP}"

# Copy the app to our temporary directory
cp -R "${APP_PATH}" "${DMG_TEMP}/"

echo "=== Creating DMG ==="

# Clean up any previous files
rm -f "${DMG_FINAL}" "${TMP_DMG}"

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create -size 100m -volname "${VOLUME_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDRW "${TMP_DMG}"

# Mount the temporary DMG
echo "Mounting DMG..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${TMP_DMG}"

# Wait for mount
sleep 2

# Create /Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "${MOUNT_DIR}/Applications"

# Set volume icon position
echo "Configuring DMG appearance..."
osascript << EOT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 400}
        set theFiles to every item of container window
        repeat with i in theFiles
            if name of i is "${APP_NAME}.app" then
                set position of i to {120, 150}
            else if name of i is "Applications" then
                set position of i to {380, 150}
            end if
        end repeat
        close
    end tell
end tell
EOT

# Finalize DMG
echo "Finalizing DMG..."
sync
sync
hdiutil detach "${MOUNT_DIR}"
hdiutil convert "${TMP_DMG}" -format UDZO -o "${DMG_FINAL}"
rm -f "${TMP_DMG}"

echo "=== Cleaning up ==="
rm -rf "${DMG_TEMP}"
rm -rf "${BUILD_DIR}"

echo "DMG created successfully: ${DMG_FINAL}"
