#!/bin/bash
set -e

APP_NAME="IdleSentry"
BUNDLE_ID="com.zennoris.IdleSentry"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

# Read version info if present
if [ -f "version.info" ]; then
    echo "Loading official version info from version.info..."
    source version.info
else
    echo "No version.info found. Building as Custom Build."
    VERSION="1.0.0"
    BUILD_NUMBER="custom"
    BUILD_TYPE="custom"
fi

if [ "${BUILD_NUMBER}" = "custom" ]; then
    IS_BUILD_VERSION="${VERSION}-custom"
else
    IS_BUILD_VERSION="${VERSION} (${BUILD_NUMBER})"
fi

if [ ! -f "AppIcon.icns" ] || [ ! -f "background.png" ]; then
    echo "Assets missing. Generating AppIcon and DMG background..."
    swift scripts/GenerateAssets.swift
fi

echo "Creating bundle directory structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Generating Info.plist..."
cat <<EOF > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>IdleSentry uses Accessibility to detect system idle time and pause app timers when you step away from the computer.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>ISBuildVersion</key>
    <string>${IS_BUILD_VERSION}</string>
    <key>ISBuildType</key>
    <string>${BUILD_TYPE}</string>
</dict>
</plist>
EOF

echo "Compiling Swift source files..."
SWIFT_FILES=$(find . -maxdepth 1 -name "*.swift")

if [ -z "${SWIFT_FILES}" ]; then
    echo "Error: No Swift files found!"
    exit 1
fi

SDK_PATH=$(xcrun --show-sdk-path)
ARCH=$(uname -m)

swiftc -O \
    -sdk "${SDK_PATH}" \
    -target "${ARCH}-apple-macos13.0" \
    -o "${MACOS_DIR}/${APP_NAME}" \
    ${SWIFT_FILES}

echo "Copying AppIcon assets to Resources..."
for icon in AppIcon.icns AppIcon-clear.icns AppIcon-tinted.icns; do
    if [ -f "$icon" ]; then
        cp "$icon" "${RESOURCES_DIR}/"
    fi
done

echo "Signing application bundle..."
codesign --force --deep --sign - "${APP_DIR}"

echo "Build successful! Created ${APP_DIR}"
