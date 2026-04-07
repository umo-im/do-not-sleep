#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CASK_PATH="${CASK_PATH:-$ROOT_DIR/Casks/umo-do-not-sleep.rb}"
REPOSITORY="${REPOSITORY:-umo-im/do-not-sleep}"
TOKEN="${TOKEN:-umo-do-not-sleep}"

project_setting() {
    sed -n "s/^[[:space:]]*$1: //p" "$ROOT_DIR/project.yml" | head -n 1
}

VERSION="${VERSION:-$(project_setting MARKETING_VERSION)}"
ZIP_PATH="${ZIP_PATH:-$ROOT_DIR/dist/Do-Not-Sleep-v${VERSION}-macos.zip}"

if [[ -z "$VERSION" ]]; then
    echo "VERSION is required. Set it in project.yml or export VERSION before running this script." >&2
    exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Release zip not found: $ZIP_PATH" >&2
    exit 1
fi

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

mkdir -p "$(dirname "$CASK_PATH")"

cat > "$CASK_PATH" <<EOF
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$REPOSITORY/releases/download/v#{version}/Do-Not-Sleep-v#{version}-macos.zip",
      verified: "github.com/$REPOSITORY/"
  name "Do Not Sleep"
  desc "Menu bar app that prevents idle sleep and screen saver"
  homepage "https://github.com/$REPOSITORY"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Do Not Sleep.app"

  zap trash: [
    "~/Library/Containers/im.umo.dns",
    "~/Library/Saved Application State/im.umo.dns.savedState",
  ]
end
EOF

echo "Updated $CASK_PATH"
echo "Version: $VERSION"
echo "SHA-256: $SHA256"
