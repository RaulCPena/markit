#!/usr/bin/env bash
set -euo pipefail

swift build

APP_DIR=".build/debug-app/MarkIt.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp .build/debug/MarkIt "$APP_DIR/Contents/MacOS/MarkIt"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

# Ad-hoc signatures change CDHash on every rebuild, so TCC Accessibility
# (which keys off code identity) looks "on" in Settings for an old MarkIt
# while AXIsProcessTrusted() is still false for this process. Sign with a
# stable Apple Development identity when one is available.
IDENTITY="${MARKIT_DEBUG_SIGNING_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -1 || true)"
fi
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --identifier com.raulpena.markit --timestamp=none "$APP_DIR"
  echo "Signed with: $IDENTITY"
else
  echo "warning: no Apple Development identity found; Accessibility may reset on each rebuild" >&2
fi

# One stable path so System Settings is not left pointing at a .build copy
# while we launch a newly signed binary from the repo.
INSTALL_DIR="/Applications/MarkIt.app"
rm -rf "$INSTALL_DIR"
ditto "$APP_DIR" "$INSTALL_DIR"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --identifier com.raulpena.markit --timestamp=none "$INSTALL_DIR"
fi

echo "Built: $APP_DIR"
echo "Installed: $INSTALL_DIR (run: open $INSTALL_DIR)"
