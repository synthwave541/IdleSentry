#!/bin/bash
# Run on the release Mac after package.sh. Private key stays in the login Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/fetch-sparkle.sh
VERSION=$(tr -d '\r\n' < VERSION)
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp "IdleSentry-$VERSION-macOS.zip" "$STAGE/"
build/dependencies/Sparkle-2.10.0/bin/generate_appcast \
    --account com.zennoris.IdleSentry --maximum-deltas 0 \
    --download-url-prefix "https://github.com/synthwave541/IdleSentry/releases/download/$VERSION/" \
    --link https://apps.zennoris.com/com.zennoris.idlesentry "$STAGE"
cp "$STAGE/appcast.xml" appcast.xml
