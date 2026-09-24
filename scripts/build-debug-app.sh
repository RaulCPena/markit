#!/usr/bin/env bash
set -euo pipefail

# Debug build via Xcode, install a stable path for Accessibility TCC.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate
xcodebuild \
  -project MarkIt.xcodeproj \
  -scheme MarkIt \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  build

APP_SRC=".build/DerivedData/Build/Products/Debug/MarkIt.app"
APP_DIR=".build/debug-app/MarkIt.app"
INSTALL_DIR="/Applications/MarkIt.app"

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
ditto "$APP_SRC" "$APP_DIR"

rm -rf "$INSTALL_DIR"
ditto "$APP_SRC" "$INSTALL_DIR"

echo "Built: $APP_DIR"
echo "Installed: $INSTALL_DIR (run: open $INSTALL_DIR)"
echo "Or open in Xcode: open MarkIt.xcodeproj"
