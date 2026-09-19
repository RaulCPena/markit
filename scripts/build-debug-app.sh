#!/usr/bin/env bash
set -euo pipefail

swift build

APP_DIR=".build/debug-app/MarkIt.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp .build/debug/MarkIt "$APP_DIR/Contents/MacOS/MarkIt"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "Built: $APP_DIR (run: open $APP_DIR)"
