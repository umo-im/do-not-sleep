#!/usr/bin/env bash

set -euo pipefail

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

verify_only=false
if [[ "${1:-}" == --verify-only ]]; then
    verify_only=true
    shift
fi
if [[ $# != 1 || ! "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    fail "Usage: $0 [--verify-only] X.Y.Z"
fi

version="$1"
tag="v$version"
release_title="Do Not Sleep $tag"
commit_message="Release $release_title"
repository=umo-im/do-not-sleep
root_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root_dir"

for tool in xcodebuild xcodegen gh jq; do
    command -v "$tool" > /dev/null || fail "Missing required tool: $tool"
done
[[ "$(git branch --show-current)" == main && -z "$(git status --porcelain)" ]] || fail "Run from a clean main checkout."

case "$(git remote get-url --push origin)" in
    "https://github.com/$repository"|"https://github.com/$repository.git"|"git@github.com:$repository.git") ;;
    *) fail "The origin push URL must point to $repository." ;;
esac

project_setting() {
    awk -v key="$1:" '$1 == key { print $2; exit }' project.yml
}

current_version="$(project_setting MARKETING_VERSION)"
build_number="$(project_setting CURRENT_PROJECT_VERSION)"
team_id="$(project_setting DEVELOPMENT_TEAM)"
[[ "$current_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ && "$build_number" =~ ^[1-9][0-9]*$ && -n "$team_id" ]] \
    || fail "Check the version, build number, and team in project.yml."

latest_tag="$(gh api "repos/$repository/releases/latest" --jq '.tag_name')"
latest_version="${latest_tag#v}"
[[ "$version" != "$latest_version" && "$(printf '%s\n' "$latest_version" "$version" | sort -V | tail -n 1)" == "$version" ]] \
    || fail "$tag must be newer than the latest release, $latest_tag."
[[ "$(printf '%s\n' "$current_version" "$version" | sort -V | tail -n 1)" == "$version" ]] \
    || fail "$tag is older than project version $current_version."
remote_tag="$(git ls-remote origin "refs/tags/$tag")"
[[ -z "$remote_tag" ]] || fail "Tag $tag already exists on GitHub."

if [[ "$current_version" != "$version" ]]; then
    build_number=$((build_number + 1))
fi

output_root="$root_dir/dist/releases"
mkdir -p "$output_root"
source_commit="$(git rev-parse HEAD)"
if "$verify_only"; then
    release_dir="$(mktemp -d "$output_root/$tag-verify.XXXXXX")"
else
    [[ "$(gh api "repos/$repository" --jq '.permissions.push')" == true ]] || fail "GitHub CLI requires write access to $repository."
    remote_main="$(git ls-remote origin refs/heads/main | awk '{print $1}')"
    if [[ "$source_commit" != "$remote_main" ]]; then
        [[ "$current_version" == "$version" && "$(git log -1 --format=%s)" == "$commit_message" && "$(git rev-parse HEAD^)" == "$remote_main" ]] \
            || fail "Sync main with origin/main before releasing."
    fi

    lock_dir="$output_root/.publish-lock"
    mkdir "$lock_dir" || fail "Another release is already running in this checkout."
    trap 'rmdir "$lock_dir"' EXIT

    if [[ "$current_version" != "$version" ]]; then
        awk -v version="$version" -v build="$build_number" '
            $1 == "MARKETING_VERSION:" { sub(/[^[:space:]]+$/, version) }
            $1 == "CURRENT_PROJECT_VERSION:" { sub(/[^[:space:]]+$/, build) }
            { print }
        ' project.yml > "$lock_dir/project.yml"
        mv "$lock_dir/project.yml" project.yml
        git commit -m "$commit_message" -- project.yml
        source_commit="$(git rev-parse HEAD)"
    fi
    release_dir="$output_root/$tag/$source_commit"
fi

mkdir -p "$release_dir"
zip_name="Do-Not-Sleep-$tag-macos.zip"
zip_path="$release_dir/$zip_name"
checksum_path="$zip_path.sha256.txt"

if [[ ! -f "$zip_path" || ! -f "$checksum_path" ]]; then
    build_dir="$(mktemp -d "$release_dir/build.XXXXXX")"
    git archive "$source_commit" | tar -x -C "$build_dir"
    TEAM_ID="$team_id" CONFIGURATION=Release MARKETING_VERSION="$version" BUILD_NUMBER="$build_number" \
        ALLOW_PROVISIONING_UPDATES=1 NOTARIZE_WITH_XCODE=1 NOTARY_PROFILE= DEVELOPER_ID_SIGNING_CERTIFICATE= \
        DERIVED_DATA_PATH="$build_dir/dist/derived" ARCHIVE_PATH="$build_dir/dist/DoNotSleep.xcarchive" \
        EXPORT_DIR="$build_dir/dist/export" ZIP_PATH="$zip_path" SHA_PATH="$checksum_path" \
        "$build_dir/scripts/release-developer-id.sh"
fi

(cd "$release_dir" && shasum -a 256 -c "$(basename "$checksum_path")")
verification_dir="$(mktemp -d "$release_dir/verify.XXXXXX")"
ditto -x -k "$zip_path" "$verification_dir"
app="$verification_dir/Do Not Sleep.app"
bundle_plist="$app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle_plist")" == "$version" ]] || fail "App version does not match $tag."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$bundle_plist")" == "$build_number" ]] || fail "App build number does not match $build_number."
architectures=" $(lipo -archs "$app/Contents/MacOS/Do Not Sleep") "
[[ "$architectures" == *' arm64 '* && "$architectures" == *' x86_64 '* ]] || fail "Expected both arm64 and x86_64 binaries."
codesign --verify --deep --strict "$app"
signature="$(codesign -dvv "$app" 2>&1)"
grep -q '^Authority=Developer ID Application:' <<< "$signature" || fail "Expected a Developer ID Application signature."
grep -Fxq "TeamIdentifier=$team_id" <<< "$signature" || fail "App was signed by a different Apple Developer team."
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=3 "$app"
printf 'Verified release ZIP: %s\n' "$zip_path"

if "$verify_only"; then
    echo "Verification complete. No Git commit, tag, push, or GitHub release was created."
    exit 0
fi

git push origin "$source_commit:refs/heads/main"
if ! draft="$(gh release view "$tag" --repo "$repository" --json isDraft,targetCommitish,assets)"; then
    gh release create "$tag" --repo "$repository" --draft --target "$source_commit" --title "$release_title" --generate-notes
    draft="$(gh release view "$tag" --repo "$repository" --json isDraft,targetCommitish,assets)"
fi
jq -e --arg commit "$source_commit" '.isDraft and .targetCommitish == $commit' <<< "$draft" > /dev/null \
    || fail "GitHub release $tag is not a draft for $source_commit."

for asset in "$zip_path" "$checksum_path"; do
    asset_name="$(basename "$asset")"
    if ! jq -e --arg name "$asset_name" '.assets | any(.name == $name)' <<< "$draft" > /dev/null; then
        gh release upload "$tag" "$asset" --repo "$repository"
    fi
done

draft="$(gh release view "$tag" --repo "$repository" --json isDraft,targetCommitish,assets)"
zip_digest="sha256:$(shasum -a 256 "$zip_path" | awk '{print $1}')"
checksum_digest="sha256:$(shasum -a 256 "$checksum_path" | awk '{print $1}')"
jq -e --arg commit "$source_commit" --arg name "$zip_name" --arg zip "$zip_digest" --arg checksums "$checksum_digest" '
    .isDraft and .targetCommitish == $commit and
    (.assets | any(.name == $name and .state == "uploaded" and .digest == $zip)) and
    (.assets | any(.name == ($name + ".sha256.txt") and .state == "uploaded" and .digest == $checksums))
' <<< "$draft" > /dev/null || fail "GitHub draft assets for $tag differ from the verified files."

gh release edit "$tag" --repo "$repository" --draft=false --latest
