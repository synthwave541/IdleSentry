#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/idlesentry-checks.XXXXXX")
cleanup() {
    pkill -f "$CHECK_DIR/.*[.]app/Contents/MacOS/Helper" 2>/dev/null || true
    rm -rf "$CHECK_DIR"
}
trap cleanup EXIT
bash scripts/fetch-sparkle.sh
SPARKLE_DIR="$PWD/build/dependencies/Sparkle-2.10.0"
swiftc -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker "$SPARKLE_DIR" -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos13.0" \
    -o "$CHECK_DIR/PresentationChecks" tests/PresentationChecks.swift \
    AccessRecovery.swift LaunchContext.swift UnsavedWork.swift IdleAction.swift UpdateService.swift AppState.swift MonitoringPresentation.swift ContentView.swift SettingsViews.swift AppPickerView.swift
# Disposable native apps exercise actual hide/quit semantics without touching user apps.
swiftc -O -o "$CHECK_DIR/Helper" tests/LifecycleHelper.swift
for helper_name in Unsaved First Second; do
    helper_app="$CHECK_DIR/$helper_name.app"
    mkdir -p "$helper_app/Contents/MacOS"
    cp "$CHECK_DIR/Helper" "$helper_app/Contents/MacOS/Helper"
    cat > "$helper_app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.zennoris.IdleSentry.tests.$helper_name</string>
<key>CFBundleExecutable</key><string>Helper</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleName</key><string>$helper_name</string>
</dict></plist>
EOF
    codesign --force --sign - "$helper_app"
done
IDLESENTRY_HELPER_DIR="$CHECK_DIR" "$CHECK_DIR/PresentationChecks"
