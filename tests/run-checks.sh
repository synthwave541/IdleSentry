#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/idlesentry-checks.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos13.0" \
    -o "$CHECK_DIR/PresentationChecks" tests/PresentationChecks.swift \
    AppState.swift MonitoringPresentation.swift ContentView.swift SettingsViews.swift AppPickerView.swift
"$CHECK_DIR/PresentationChecks"
