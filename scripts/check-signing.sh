#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Do Not Sleep.app"
REQUIRE_DEVELOPER_ID=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --require-developer-id)
            REQUIRE_DEVELOPER_ID=1
            shift
            ;;
        *)
            APP_PATH="$1"
            shift
            ;;
    esac
done

echo "Available signing identities:"
security find-identity -v -p codesigning | grep -E "Developer ID Application|Apple Development|Apple Distribution|Mac App Distribution" || true
echo

if [[ ! -e "$APP_PATH" ]]; then
    echo "App not found: $APP_PATH" >&2
    exit 1
fi

codesign_output="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
echo "App signature:"
echo "$codesign_output" | sed -n '/^Identifier=/p;/^Authority=/p;/^TeamIdentifier=/p;/^Runtime Version=/p'
echo

primary_authority="$(echo "$codesign_output" | sed -n 's/^Authority=//p' | head -n 1)"
if [[ "$REQUIRE_DEVELOPER_ID" -eq 1 && "$primary_authority" != Developer\ ID\ Application:* ]]; then
    echo "Expected a Developer ID Application signature, but found: $primary_authority" >&2
    exit 1
fi

echo "Gatekeeper assessment:"
spctl --assess --type execute --verbose=4 "$APP_PATH" || true
