#!/bin/bash
# Đóng gói bản phát hành: dist/VietKey-<version>.zip
# (VietKey.app universal + install.command + uninstall.command + hướng dẫn)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
scripts/build.sh --universal
NAME="VietKey-$VERSION"
STAGE="dist/$NAME"
rm -rf "$STAGE" "dist/$NAME.zip"
mkdir -p "$STAGE"
cp -R build/VietKey.app "$STAGE/"
cp packaging/install.command "$STAGE/Cài đặt VietKey.command"
cp packaging/uninstall.command "$STAGE/Gỡ VietKey.command"
cp packaging/HUONG-DAN.txt "$STAGE/"
chmod +x "$STAGE"/*.command
(cd dist && ditto -c -k --keepParent "$NAME" "$NAME.zip")
shasum -a 256 "dist/$NAME.zip"
echo "Đã đóng gói: dist/$NAME.zip"
