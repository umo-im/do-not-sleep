#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
repository="${GITHUB_REPOSITORY:-umo-im/do-not-sleep}"
release="$(gh api "repos/$repository/releases/latest")"
tag="$(jq -er '.tag_name' <<< "$release")"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Unexpected release tag: $tag" >&2
    exit 1
fi

version="${tag#v}"
asset_name="Do-Not-Sleep-${tag}-macos.zip"
release_url="https://github.com/$repository/releases"
if ! expected_digest="$(jq -er --arg name "$asset_name" '
    .assets[]
    | select(.name == $name and .state == "uploaded")
    | .digest | strings | select(test("^sha256:[a-f0-9]{64}$"))
' <<< "$release")"; then
    echo "Release $tag is missing an uploaded $asset_name with a SHA-256 digest." >&2
    exit 1
fi

temp_dir="$(mktemp -d)"
zip_path="$temp_dir/$asset_name"
temp_readme="$temp_dir/README.md"
temp_cask="$temp_dir/cask.rb"
trap 'rm -f "$zip_path" "$temp_readme" "$temp_cask"; rmdir "$temp_dir"' EXIT

gh release download "$tag" --repo "$repository" --pattern "$asset_name" --dir "$temp_dir"
actual_sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
if [[ "sha256:$actual_sha256" != "$expected_digest" ]]; then
    echo "SHA-256 mismatch for $asset_name on release $tag." >&2
    exit 1
fi

download_link="**[Do Not Sleep $tag ZIP 다운로드]($release_url/download/$tag/$asset_name)** · [최신 릴리스]($release_url/latest)"
if ! awk -v link="$download_link" '
    $0 == "<!-- release-download -->" {
        print
        if (getline != 1 || $0 !~ /^\*\*\[Do Not Sleep v/) exit 1
        print link
        replaced++
        next
    }
    { print }
    END { if (replaced != 1) exit 1 }
' "$root_dir/README.md" > "$temp_readme"; then
    echo "Expected exactly one marked release download link in README.md." >&2
    exit 1
fi

VERSION="$version" ZIP_PATH="$zip_path" REPOSITORY="$repository" CASK_PATH="$temp_cask" \
    "$root_dir/scripts/update-homebrew-cask.sh"

cp "$temp_readme" "$root_dir/README.md"
cp "$temp_cask" "$root_dir/Casks/umo-do-not-sleep.rb"
