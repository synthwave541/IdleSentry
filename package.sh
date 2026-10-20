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
cat > "$STAGE/Read Me.txt" <<'GUIDE'
IdleSentry for macOS
===================
Drag IdleSentry.app to Applications, then open it from Applications.
Quit any older running copy before upgrading. Your existing preferences are retained.

This open-source build is signed locally (ad-hoc), not Apple notarized.
macOS may require approval in System Settings > Privacy & Security after
an attempted first launch. Review the source and release information before
approving an app from outside the App Store.

IdleSentry can close selected apps, including apps with unsaved work.
Save your work before testing. Close the settings window to keep monitoring
in the menu bar; choose Quit IdleSentry to stop it completely.
GUIDE
hdiutil create -ov -srcfolder "$STAGE" -volname IdleSentry -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG_NAME"
hdiutil verify "$DMG_NAME"
printf 'Created %s\n' "$DMG_NAME"
