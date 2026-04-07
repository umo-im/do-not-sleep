#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/.build-xcode"
APP_DIR="$ROOT_DIR/dist/Do Not Sleep.app"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Do Not Sleep.app"

(cd "$ROOT_DIR" && swift scripts/generate-icon.swift)
(cd "$ROOT_DIR" && xcodegen generate)

rm -rf "$DERIVED_DATA_PATH"

xcodebuild \
    -project "$ROOT_DIR/DoNotSleep.xcodeproj" \
    -scheme "DoNotSleep" \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

rm -rf "$APP_DIR"
cp -R "$BUILT_APP_PATH" "$APP_DIR"

echo "Built app bundle at:"
echo "$APP_DIR"
