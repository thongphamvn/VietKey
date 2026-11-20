#!/bin/bash
# Cài VietKey vào ~/Library/Input Methods và bật bộ gõ.
# Dùng: bấm đúp file này, hoặc chạy: ./install.command [thư mục chứa VietKey.app]
set -euo pipefail
SRC="${1:-$(dirname "$0")}"
APP="$SRC/VietKey.app"
DEST="$HOME/Library/Input Methods"
if [ ! -d "$APP" ]; then
    echo "Không tìm thấy VietKey.app trong $SRC"; exit 1
fi
mkdir -p "$DEST"
pkill -x VietKey 2>/dev/null || true
rm -rf "$DEST/VietKey.app"
cp -R "$APP" "$DEST/"
# App chưa được Apple công chứng (notarize): bỏ cờ "tải từ internet" để macOS cho chạy
xattr -dr com.apple.quarantine "$DEST/VietKey.app" 2>/dev/null || true
echo "Đã cài vào: $DEST/VietKey.app"
"$DEST/VietKey.app/Contents/MacOS/VietKey" --register
open "$DEST/VietKey.app"
