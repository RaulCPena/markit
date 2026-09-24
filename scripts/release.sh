#!/usr/bin/env bash
set -euo pipefail

# Archive + Developer ID export + notarize.
# One-time: xcrun notarytool store-credentials "MarkItNotary" \
#   --apple-id "you@example.com" --team-id "D9M7YX54A8" --password "app-specific-password"
#
# Prefer Xcode: open MarkIt.xcodeproj → Product → Archive → Distribute App →
# Direct Distribution (Developer ID) → Notarize. This script is the CLI equivalent.

VERSION="${1:?Usage: scripts/release.sh <version, e.g. 1.0.0>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="MarkItNotary"
ARCHIVE_PATH="build/MarkIt.xcarchive"
EXPORT_DIR="build/export"
APP_PATH="$EXPORT_DIR/MarkIt.app"
ZIP_PATH="build/MarkIt-$VERSION.zip"
DMG_STAGING_DIR="build/dmg"
DMG_PATH="build/MarkIt-$VERSION.dmg"

xcodegen generate

# Prefer Xcode tests; fall back to SPM if the test host path is awkward in CI.
xcodebuild \
  -project MarkIt.xcodeproj \
  -scheme MarkIt \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  test \
  || swift test

rm -rf build
mkdir -p build

xcodebuild \
  -project MarkIt.xcodeproj \
  -scheme MarkIt \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist ExportOptions.plist

test -d "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_PATH"

mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/MarkIt.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create -volname "MarkIt" -srcfolder "$DMG_STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"

echo "Done: $DMG_PATH"
echo "Or use Xcode Organizer → Distribute App → Direct Distribution."
