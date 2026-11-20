#!/bin/bash
# Build VietKey.app vào thư mục build/
#   scripts/build.sh              build cho máy hiện tại
#   scripts/build.sh --universal  build universal (Apple Silicon + Intel), dùng khi đóng gói
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/VietKey.app
mkdir -p build
if [ "${1:-}" = "--universal" ]; then
    swift build -c release --triple arm64-apple-macosx13.0 --scratch-path .build/arm64
    swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/x86_64
    lipo -create -output build/VietKey-bin .build/arm64/release/VietKey .build/x86_64/release/VietKey
else
    swift build -c release
    cp .build/release/VietKey build/VietKey-bin
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv build/VietKey-bin "$APP/Contents/MacOS/VietKey"
cp Resources/Info.plist "$APP/Contents/"
[ -f build/icon.tiff ] || swift scripts/make-icon.swift menu build/icon.tiff
[ -f build/AppIcon.icns ] || swift scripts/make-icon.swift app build/AppIcon.icns
cp build/icon.tiff build/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Đã build: $APP ($(lipo -archs "$APP/Contents/MacOS/VietKey"))"
