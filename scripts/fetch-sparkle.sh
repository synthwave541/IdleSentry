#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SPARKLE_VERSION=2.10.0
SPARKLE_SHA256=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
DEST="build/dependencies/Sparkle-$SPARKLE_VERSION"
if [ ! -f "$DEST/.verified" ]; then
    mkdir -p "$DEST"
    curl --fail --location --silent --show-error --retry 3 \
        "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$DEST/archive.tar.xz"
    echo "$SPARKLE_SHA256  $DEST/archive.tar.xz" | shasum -a 256 -c -
    tar -xf "$DEST/archive.tar.xz" -C "$DEST"
    touch "$DEST/.verified"
fi
