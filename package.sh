#!/bin/bash
set -e

APP_NAME="IdleSentry"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
TEMP_DMG="temp.dmg"
VOLUME_NAME="IdleSentry"

# Read version info if present
if [ -f "version.info" ]; then
    source version.info
else
    VERSION="1.0.0"
    BUILD_NUMBER="custom"
    BUILD_TYPE="custom"
fi

if [ "${BUILD_NUMBER}" = "custom" ]; then
    DMG_NAME="${APP_NAME}-custom.dmg"
    DISPLAY_BUILD="${VERSION}-custom"
else
    DMG_NAME="${APP_NAME}-${VERSION}-${BUILD_NUMBER}.dmg"
    DISPLAY_BUILD="${VERSION} (${BUILD_NUMBER})"
fi

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       IdleSentry Build System        ║"
echo "║       Build ${DISPLAY_BUILD}         ║"
echo "╚══════════════════════════════════════╝"
echo ""

echo "→ Building release type: ${BUILD_TYPE}"

echo ""
echo "Rebuilding app for packaging..."
./build.sh

echo "Preparing DMG staging area..."
# Detach any previously mounted volume with the same name
hdiutil detach "/Volumes/${VOLUME_NAME}" 2>/dev/null || true
rm -f "${DMG_NAME}" "${TEMP_DMG}"
rm -rf dmg_staging
mkdir -p dmg_staging

echo "Assembling files..."
cp -R "${APP_PATH}" dmg_staging/
ln -s /Applications dmg_staging/Applications

# Create Installation Guide to help users bypass Gatekeeper "damaged" error
cat << 'EOF' > "dmg_staging/How to Install (Fix Error).txt"
IdleSentry — Installation Guide
==============================

Because IdleSentry is an open-source project, it is signed locally (ad-hoc) and not notarized through Apple's developer program. 

When you first open the app, macOS Gatekeeper might show an error saying:
"IdleSentry is damaged and can't be opened." or "Apple cannot check it for malicious software."

To fix this and run the app:
1. Drag IdleSentry.app into your Applications folder.
2. Open your Terminal app (Applications > Utilities > Terminal).
3. Paste the following command and press Enter:

   xattr -cr /Applications/IdleSentry.app

This clears the macOS quarantine flag, and the app will open and run perfectly.
EOF

# Assemble files (No custom background, standard system theme)

echo "Creating temporary read-write DMG..."
hdiutil create \
    -srcfolder dmg_staging \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -format UDRW \
    -size 20m \
    "${TEMP_DMG}"
rm -rf dmg_staging

echo "Mounting temporary DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
echo "  Mounted at device: ${DEVICE}"
sleep 3

echo "Applying Finder styling via AppleScript..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        
        delay 2
        
        set theWindow to container window
        
        set current view of theWindow to icon view
        set toolbar visible of theWindow to false
        set statusbar visible of theWindow to false
        set the bounds of theWindow to {200, 120, 800, 480}
        
        set theViewOpts to the icon view options of theWindow
        set icon size of theViewOpts to 96
        set text size of theViewOpts to 12
        set arrangement of theViewOpts to not arranged
        
        delay 1
        
        -- Position the three items in a clean row
        set position of item "${APP_NAME}.app" to {120, 160}
        set position of item "Applications" to {300, 160}
        set position of item "How to Install (Fix Error).txt" to {480, 160}
        
        delay 1
        
        -- Force refresh
        close
        open
        
        delay 2
        
        -- Set again after refresh to ensure it sticks
        set theWindow to container window
        set current view of theWindow to icon view
        set toolbar visible of theWindow to false
        set statusbar visible of theWindow to false
        set the bounds of theWindow to {200, 120, 800, 480}
        
        set theViewOpts to the icon view options of theWindow
        set icon size of theViewOpts to 96
        
        set position of item "${APP_NAME}.app" to {120, 160}
        set position of item "Applications" to {300, 160}
        set position of item "How to Install (Fix Error).txt" to {480, 160}
        
        delay 1
        close
        
        update without registering applications
    end tell
end tell
APPLESCRIPT

echo "  AppleScript completed."
sleep 2

# Sync filesystem to ensure DS_Store is written
sync

echo "Detaching temporary DMG..."
hdiutil detach "${DEVICE}"
sleep 1

echo "Converting to compressed final DMG..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
rm -f "${TEMP_DMG}"

echo ""
echo "════════════════════════════════════════"
echo "  DMG created: ${DMG_NAME}"
echo "  Build: ${DISPLAY_BUILD} (${BUILD_TYPE})"
echo "════════════════════════════════════════"
echo ""
