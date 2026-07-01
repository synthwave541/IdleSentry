#!/bin/bash
set -e

APP_NAME="IdleSentry"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

echo "Rebuilding app..."
./build.sh

echo "Stopping existing instance of ${APP_NAME} if running..."
killall "${APP_NAME}" 2>/dev/null || true

echo "Opening ${APP_NAME}..."
open "${APP_PATH}"
echo "Running!"
