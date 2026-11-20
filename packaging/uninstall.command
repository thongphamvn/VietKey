#!/bin/bash
# Gỡ VietKey khỏi máy.
set -uo pipefail
APP="$HOME/Library/Input Methods/VietKey.app"
[ -d "$APP" ] && "$APP/Contents/MacOS/VietKey" --unregister
pkill -x VietKey 2>/dev/null
rm -rf "$APP"
echo "Đã gỡ VietKey."
