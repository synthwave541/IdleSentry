#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/idlesentry-checks.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT
bash scripts/fetch-sparkle.sh
SPARKLE_DIR="$PWD/build/dependencies/Sparkle-2.10.0"
swiftc -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker "$SPARKLE_DIR" -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos13.0" \
    -o "$CHECK_DIR/PresentationChecks" tests/PresentationChecks.swift \
    UpdateService.swift AppState.swift MonitoringPresentation.swift ContentView.swift SettingsViews.swift AppPickerView.swift
"$CHECK_DIR/PresentationChecks"
