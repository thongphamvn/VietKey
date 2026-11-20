#!/bin/bash
# Gỡ VietKey khỏi máy
APP="$HOME/Library/Input Methods/VietKey.app"
[ -d "$APP" ] || { echo "VietKey chưa được cài."; exit 0; }
"$APP/Contents/MacOS/VietKey" --uninstall
