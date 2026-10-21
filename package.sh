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
hdiutil create -ov -srcfolder "$STAGE" -volname IdleSentry -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG_NAME"
hdiutil verify "$DMG_NAME"
ZIP_NAME="IdleSentry-${VERSION}-macOS.zip"
ditto -c -k --sequesterRsrc "$STAGE" "$ZIP_NAME"
shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > SHA256SUMS.txt
printf 'Created %s and %s\n' "$DMG_NAME" "$ZIP_NAME"
