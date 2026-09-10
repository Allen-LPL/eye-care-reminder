#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_DIR="$SCRIPT_DIR/护眼提醒.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

mkdir -p "$MACOS_DIR"
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

clang \
  -O2 \
  -fobjc-arc \
  -fblocks \
  -framework Cocoa \
  "$SCRIPT_DIR/EyeCareReminder.m" \
  -o "$MACOS_DIR/EyeCareReminder"

codesign --force --deep --sign - "$APP_DIR"

echo "已生成：$APP_DIR"
