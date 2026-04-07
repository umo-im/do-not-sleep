#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/DoNotSleep.xcodeproj"
SCHEME="DoNotSleep"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="Do Not Sleep"
APP_BUNDLE_NAME="$APP_NAME.app"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build-xcode-release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/dist/DoNotSleep.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$ROOT_DIR/dist/export}"
EXPORTED_APP_PATH="$EXPORT_DIR/$APP_BUNDLE_NAME"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DEVELOPER_ID_SIGNING_CERTIFICATE="${DEVELOPER_ID_SIGNING_CERTIFICATE:-}"

project_setting() {
    sed -n "s/^[[:space:]]*$1: //p" "$ROOT_DIR/project.yml" | head -n 1
}

required_value() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        echo "$name is required. Set it in project.yml or export $name before running this script." >&2
        exit 1
    fi
}

TEAM_ID="${TEAM_ID:-$(project_setting DEVELOPMENT_TEAM)}"
MARKETING_VERSION="${MARKETING_VERSION:-$(project_setting MARKETING_VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(project_setting CURRENT_PROJECT_VERSION)}"
ZIP_PATH="${ZIP_PATH:-$ROOT_DIR/dist/Do-Not-Sleep-v${MARKETING_VERSION}-macos.zip}"
SHA_PATH="${SHA_PATH:-$ZIP_PATH.sha256.txt}"
NOTARY_SUBMISSION_ZIP="${NOTARY_SUBMISSION_ZIP:-$ROOT_DIR/dist/Do-Not-Sleep-v${MARKETING_VERSION}-macos-notary.zip}"

required_value TEAM_ID "$TEAM_ID"
required_value MARKETING_VERSION "$MARKETING_VERSION"
required_value BUILD_NUMBER "$BUILD_NUMBER"

mkdir -p "$ROOT_DIR/dist"

export_options_plist="$(mktemp "${TMPDIR:-/tmp}/donotsleep-export-options.XXXXXX.plist")"
cleanup() {
    rm -f "$export_options_plist"
}
trap cleanup EXIT

{
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
EOF
    if [[ -n "$DEVELOPER_ID_SIGNING_CERTIFICATE" ]]; then
        cat <<EOF
    <key>signingCertificate</key>
    <string>$DEVELOPER_ID_SIGNING_CERTIFICATE</string>
EOF
    fi
    cat <<'EOF'
</dict>
</plist>
EOF
} > "$export_options_plist"

(cd "$ROOT_DIR" && swift scripts/generate-icon.swift)
(cd "$ROOT_DIR" && xcodegen generate)

rm -rf "$DERIVED_DATA_PATH" "$ARCHIVE_PATH" "$EXPORT_DIR"

archive_cmd=(
    xcodebuild
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "generic/platform=macOS"
    -archivePath "$ARCHIVE_PATH"
    -derivedDataPath "$DERIVED_DATA_PATH"
    DEVELOPMENT_TEAM="$TEAM_ID"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    archive_cmd+=(-allowProvisioningUpdates)
fi

archive_cmd+=(archive)

"${archive_cmd[@]}"

export_cmd=(
    xcodebuild
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_DIR"
    -exportOptionsPlist "$export_options_plist"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    export_cmd+=(-allowProvisioningUpdates)
fi

"${export_cmd[@]}"

"$ROOT_DIR/scripts/check-signing.sh" --require-developer-id "$EXPORTED_APP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
    rm -f "$NOTARY_SUBMISSION_ZIP"
    ditto -c -k --keepParent "$EXPORTED_APP_PATH" "$NOTARY_SUBMISSION_ZIP"
    xcrun notarytool submit "$NOTARY_SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$EXPORTED_APP_PATH"
    xcrun stapler validate "$EXPORTED_APP_PATH"
    rm -f "$NOTARY_SUBMISSION_ZIP"
fi

rm -f "$ZIP_PATH" "$SHA_PATH"
ditto -c -k --keepParent "$EXPORTED_APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | tee "$SHA_PATH"

echo
echo "Release build ready:"
echo "Version: $MARKETING_VERSION ($BUILD_NUMBER)"
echo "App: $EXPORTED_APP_PATH"
echo "Zip: $ZIP_PATH"
echo "SHA-256: $SHA_PATH"
if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "Notarization: completed with profile $NOTARY_PROFILE"
else
    echo "Notarization: skipped (set NOTARY_PROFILE to notarize and staple the app)"
fi
