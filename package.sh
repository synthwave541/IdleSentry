#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(tr -d '\r\n' < VERSION)
DMG_NAME="IdleSentry-${VERSION}.dmg"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/idlesentry-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

# Package the real universal app without Finder automation or preview metadata.
bash ./build.sh universal
codesign --verify --deep --strict build/IdleSentry.app
ditto build/IdleSentry.app "$STAGE/IdleSentry.app"
ln -s /Applications "$STAGE/Applications"
cp "docs/FIX LAUNCH ERROR.txt" "$STAGE/FIX LAUNCH ERROR.txt"
cat > "$STAGE/Read Me.txt" <<'GUIDE'
IdleSentry for macOS
===================
Drag IdleSentry.app to Applications, then open it from Applications.
Quit any older running copy before upgrading. Your existing preferences are retained.

This open-source build is signed locally (ad-hoc), not Apple notarized.
macOS may require approval in System Settings > Privacy & Security after
an attempted first launch. Review the source and release information before
approving an app from outside the App Store.

If launch is blocked, see FIX LAUNCH ERROR.txt in this package. It starts
with the targeted quarantine-removal command and explains when to use it.

IdleSentry can close selected apps, including apps with unsaved work.
Save your work before testing. Close the settings window to keep monitoring
in the menu bar; choose Quit IdleSentry to stop it completely.
GUIDE
hdiutil create -ov -srcfolder "$STAGE" -volname IdleSentry -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG_NAME"
hdiutil verify "$DMG_NAME"
ZIP_NAME="IdleSentry-${VERSION}-macOS.zip"
ditto -c -k --sequesterRsrc "$STAGE" "$ZIP_NAME"
shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > SHA256SUMS.txt
printf 'Created %s and %s\n' "$DMG_NAME" "$ZIP_NAME"
