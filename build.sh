#!/bin/bash
set -e
umask 022

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

# The tracked product version takes precedence over machine-local build metadata.
if [ -f "VERSION" ]; then
    VERSION=$(tr -d '\r\n' < VERSION)
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: VERSION must contain a semantic version such as 1.0.14." >&2
    exit 1
fi
BUILD_ARCH="${1:-native}"
case "$BUILD_ARCH" in
    native) BUILD_ARCH=$(uname -m) ;;
    arm64|x86_64|universal) ;;
    *) echo "Usage: bash build.sh [native|arm64|x86_64|universal]" >&2; exit 1 ;;
esac

if [ "${BUILD_NUMBER}" = "custom" ]; then
    IS_BUILD_VERSION="${VERSION}-custom"
    BUNDLE_VERSION="${VERSION}"
else
    IS_BUILD_VERSION="${VERSION} (${BUILD_NUMBER})"
    BUNDLE_VERSION="${BUILD_NUMBER}"
fi
# Local rebuilds can advertise a distinct internal version without changing the
# product version. macOS must be able to distinguish an updated app bundle.
BUNDLE_VERSION="${IDLESENTRY_BUILD_NUMBER:-${BUNDLE_VERSION}}"

if [ ! -f "AppIcon.icns" ] || [ ! -f "background.png" ]; then
    echo "Assets missing. Generating AppIcon and DMG background..."
    swift scripts/GenerateAssets.swift
fi

bash scripts/fetch-sparkle.sh
SPARKLE_DIR="$PWD/build/dependencies/Sparkle-2.10.0"

echo "Creating bundle directory structure..."
# Never carry resources from an older notification experiment into a new build.
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Generating Info.plist..."
cat <<EOF > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
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
    <string>${BUNDLE_VERSION}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleSupportedPlatforms</key>
    <array><string>MacOSX</string></array>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>IdleSentry uses Accessibility to recognize edited documents and save warnings for your unsaved-work fallback. It does not record what you type.</string>
    <key>SUFeedURL</key>
    <string>https://github.com/synthwave541/IdleSentry/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>lyM3/KqDg9DZtxl6TruOnN3MrzwCp8JVCd7sx2c9TYM=</string>
    <key>SURequireSignedFeed</key>
    <true/>
    <key>SUVerifyUpdateBeforeExtraction</key>
    <true/>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAutomaticallyUpdate</key>
    <false/>
    <key>SUAllowsAutomaticUpdates</key>
    <false/>
    <key>SUEnableSystemProfiling</key>
    <false/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>ISBuildVersion</key>
    <string>${IS_BUILD_VERSION}</string>
    <key>ISBuildType</key>
    <string>${BUILD_TYPE}</string>
</dict>
</plist>
EOF

echo "Compiling Swift source files..."
SWIFT_FILES=(./*.swift)
if [ ! -f "${SWIFT_FILES[0]}" ]; then
    echo "Error: No Swift files found!"
    exit 1
fi
SDK_PATH=$(xcrun --show-sdk-path)
if [ "$BUILD_ARCH" = "universal" ]; then
    COMPILE_DIR=$(mktemp -d "${BUILD_DIR}/.compile.XXXXXX")
    trap 'rm -rf "$COMPILE_DIR"' EXIT
    for build_arch in arm64 x86_64; do
        swiftc -O -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks -sdk "$SDK_PATH" -target "${build_arch}-apple-macos13.0" \
            -o "${COMPILE_DIR}/${APP_NAME}-${build_arch}" "${SWIFT_FILES[@]}"
    done
    lipo -create "${COMPILE_DIR}/${APP_NAME}-arm64" "${COMPILE_DIR}/${APP_NAME}-x86_64" \
        -output "${MACOS_DIR}/${APP_NAME}"
else
    swiftc -O -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks -sdk "$SDK_PATH" -target "${BUILD_ARCH}-apple-macos13.0" \
        -o "${MACOS_DIR}/${APP_NAME}" "${SWIFT_FILES[@]}"
fi

echo "Copying AppIcon assets to Resources..."
for icon in AppIcon.icns AppIcon-clear.icns AppIcon-tinted.icns; do
    if [ -f "$icon" ]; then
        cp "$icon" "${RESOURCES_DIR}/"
    fi
done

# Compile the adaptive icon. Loose *-tinted.icns files are not appearance registrations.
# Assets.car supplies adaptive appearances. Use the compatible catalog runtime
# for the macOS 13 deployment target and consumers such as Notification Center.
xcrun actool --compile "${RESOURCES_DIR}" AppIcon.icon --platform macosx \
    --target-device mac --lightweight-asset-runtime-mode=disabled \
    --minimum-deployment-target 13.0 --app-icon AppIcon \
    --output-partial-info-plist "${BUILD_DIR}/icon-info.plist" --output-format human-readable-text
# Keep the bundle's icon declaration in sync with the compiler's actual output.
# Notification Center resolves the sender from this metadata, not NSApp's Dock image.
/usr/libexec/PlistBuddy -c "Merge ${BUILD_DIR}/icon-info.plist" "${APP_DIR}/Contents/Info.plist"
# Use a complete filename for clients that resolve the standalone icon directly.
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon.icns' "${APP_DIR}/Contents/Info.plist"
# Keep actool's matching standalone icon instead of overwriting it with an older
# generated ICNS (which may be missing the small representations used by banners).
# Generated ICNS sources can be mode 0600. System icon services must be able to
# read installed app resources, not just the user who generated the artwork.
chmod 644 "${RESOURCES_DIR}"/*.icns "${RESOURCES_DIR}/Assets.car"

rm -f "${RESOURCES_DIR}/NotificationSuccess.png"

mkdir -p "${APP_DIR}/Contents/Frameworks"
ditto "$SPARKLE_DIR/Sparkle.framework" "${APP_DIR}/Contents/Frameworks/Sparkle.framework"

# Reused build directories and copied assets may predate the umask above. Icon
# services run outside this app and need to traverse the entire installed bundle.
chmod -R a+rX "${APP_DIR}"
plutil -lint "${APP_DIR}/Contents/Info.plist"

echo "Signing application bundle..."
codesign --force --sign "${IDLESENTRY_SIGNING_IDENTITY:--}" "${APP_DIR}"

echo "Build successful! Created ${APP_DIR}"
