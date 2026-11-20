#!/bin/bash
# Đóng gói bản phát hành: dist/VietKey-<version>.dmg (VietKey.app universal + hướng dẫn).
# Người dùng mở DMG, bấm đúp VietKey => app tự cài vào ~/Library/Input Methods.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
scripts/build.sh --universal
NAME="VietKey-$VERSION"
STAGE="dist/$NAME"
rm -rf "$STAGE" "dist/$NAME.dmg"
mkdir -p "$STAGE"
cp -R build/VietKey.app "$STAGE/"
cp packaging/HUONG-DAN.txt "$STAGE/Hướng dẫn.txt"
cp LICENSE "$STAGE/LICENSE.txt"
hdiutil create -quiet -volname "VietKey $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO "dist/$NAME.dmg"
rm -rf "$STAGE"
shasum -a 256 "dist/$NAME.dmg"
echo "Đã đóng gói: dist/$NAME.dmg"
