#!/usr/bin/env bash
set -euo pipefail

# Required environment variables (set these in your shell — never commit them):
#   MARKIT_SIGNING_IDENTITY — e.g. "Developer ID Application: Raul Pena (TEAMID)"
#
# One-time setup for notarization (run once, stores credentials in your keychain):
#   xcrun notarytool store-credentials "MarkItNotary" \
#     --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-password"

VERSION="${1:?Usage: scripts/release.sh <version, e.g. 1.0.0>}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/MarkIt.app"
DMG_PATH="$BUILD_DIR/MarkIt-$VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

swift build -c release

cp .build/release/MarkIt "$APP_DIR/Contents/MacOS/MarkIt"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --deep --options runtime \
  --sign "$MARKIT_SIGNING_IDENTITY" \
  "$APP_DIR"

hdiutil create -volname "MarkIt" -srcfolder "$APP_DIR" \
  -ov -format UDZO "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "MarkItNotary" \
  --wait

xcrun stapler staple "$DMG_PATH"

echo "Done: $DMG_PATH"
