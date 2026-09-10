#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_DIR="$SCRIPT_DIR/护眼提醒.app"

if [[ ! -x "$APP_DIR/Contents/MacOS/EyeCareReminder" ]]; then
  "$SCRIPT_DIR/build.sh"
fi

open "$APP_DIR"
