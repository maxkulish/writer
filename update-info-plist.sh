#!/bin/bash

# Create Info.plist in the Writer directory
INFO_PLIST_PATH="./Writer/Info.plist"

# Create initial Info.plist if it doesn't exist
cat > "$INFO_PLIST_PATH" << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
</dict>
</plist>
EOL

echo "Created base Info.plist at ${INFO_PLIST_PATH}"

# Update Info.plist with required keys
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$INFO_PLIST_PATH" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$INFO_PLIST_PATH"

/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string 'public.app-category.productivity'" "$INFO_PLIST_PATH" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :LSApplicationCategoryType 'public.app-category.productivity'" "$INFO_PLIST_PATH"

/usr/libexec/PlistBuddy -c "Add :NSHumanReadableCopyright string '© 2024 Your Company Name'" "$INFO_PLIST_PATH" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSHumanReadableCopyright '© 2024 Your Company Name'" "$INFO_PLIST_PATH"

# Add required privacy descriptions
/usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string 'Writer needs to simulate keyboard events to process your text.'" "$INFO_PLIST_PATH" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSAppleEventsUsageDescription 'Writer needs to simulate keyboard events to process your text.'" "$INFO_PLIST_PATH"

/usr/libexec/PlistBuddy -c "Add :NSAccessibilityUsageDescription string 'Writer needs accessibility access to detect hotkeys and process text.'" "$INFO_PLIST_PATH" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSAccessibilityUsageDescription 'Writer needs accessibility access to detect hotkeys and process text.'" "$INFO_PLIST_PATH"

echo "Info.plist updated successfully at ${INFO_PLIST_PATH}"

# Now, update the Xcode project to use this Info.plist
PBXPROJ_PATH="./Writer.xcodeproj/project.pbxproj"

if [ -f "$PBXPROJ_PATH" ]; then
    # Create a backup
    cp "$PBXPROJ_PATH" "${PBXPROJ_PATH}.backup"

    # Update the project.pbxproj to reference the Info.plist
    sed -i '' 's/INFOPLIST_FILE = "";/INFOPLIST_FILE = "Writer\/Info.plist";/g' "$PBXPROJ_PATH"

    echo "Updated Xcode project to use Info.plist"
else
    echo "Warning: Could not find project.pbxproj"
fi
