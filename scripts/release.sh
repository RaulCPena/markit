#!/usr/bin/env bash
set -euo pipefail

# Required environment variables (set these in your shell — never commit them):
#   MARKIT_SIGNING_IDENTITY — e.g. "Developer ID Application: Raul Pena (TEAMID)"
#
# One-time setup for notarization (run once, stores credentials in your keychain):
#   xcrun notarytool store-credentials "MarkItNotary" \
#     --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-password"

: "${MARKIT_SIGNING_IDENTITY:?set MARKIT_SIGNING_IDENTITY before running this script}"

VERSION="${1:?Usage: scripts/release.sh <version, e.g. 1.0.0>}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/MarkIt.app"
ZIP_PATH="$BUILD_DIR/MarkIt-$VERSION.zip"
DMG_STAGING_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/MarkIt-$VERSION.dmg"
NOTARY_PROFILE="MarkItNotary"

# A broken test suite must block cutting a release.
swift test

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift build -c release

cp .build/release/MarkIt "$APP_DIR/Contents/MacOS/MarkIt"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
cp Resources/MenuBarIcon.png "$APP_DIR/Contents/Resources/MenuBarIcon.png"
cp Resources/MenuBarIcon@2x.png "$APP_DIR/Contents/Resources/MenuBarIcon@2x.png"
cp Resources/MenuBarIcon.pdf "$APP_DIR/Contents/Resources/MenuBarIcon.pdf"

# Single-binary bundle with no embedded frameworks, so --deep is unnecessary
# (and deprecated by Apple).
codesign --force --options runtime \
  --sign "$MARKIT_SIGNING_IDENTITY" \
  "$APP_DIR"

# Notarize the .app itself and staple the ticket to it, so a copy dragged out of
# the dmg to /Applications still passes Gatekeeper offline.
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_DIR"

# Build the dmg from the now-stapled .app, with a drag-to-Applications layout.
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/MarkIt.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create -volname "MarkIt" -srcfolder "$DMG_STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"

echo "Done: $DMG_PATH"
