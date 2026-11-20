#!/bin/bash
# Test trình cài đặt có giao diện: mở VietKey.app (từ DMG trong dist/ nếu có, không thì build/),
# bấm nút trong hộp thoại qua Accessibility và kiểm tra kết quả: cài lại, gỡ cài đặt, cài mới.
# Kết thúc ở trạng thái đã cài. Cần quyền Accessibility cho app chạy script.
set -uo pipefail
cd "$(dirname "$0")/.."
AX="swift scripts/axtool.swift"
DEST="$HOME/Library/Input Methods/VietKey.app"
PASS=0; FAIL=0
check() { # check <mô tả> <lệnh kiểm tra...>
    local desc=$1; shift
    if "$@"; then echo "  ✔ $desc"; PASS=$((PASS+1)); else echo "  ✘ $desc"; FAIL=$((FAIL+1)); fi
}
ime_running() { pgrep -f "Input Methods/VietKey.app/Contents/MacOS/VietKey$" >/dev/null; }
installer_running() { pgrep -f "$PATTERN" >/dev/null; }
wait_gone() { for _ in $(seq 1 30); do installer_running || return 0; sleep 0.2; done; return 1; }

DMG=$(ls dist/VietKey-*.dmg 2>/dev/null | tail -1)
if [ -n "$DMG" ]; then
    MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" 2>/dev/null | tail -1 | cut -f3)
    APP="$MOUNT/VietKey.app"; PATTERN="^/Volumes/VietKey.*/MacOS/VietKey$"
    trap 'hdiutil detach -quiet "$MOUNT" 2>/dev/null || hdiutil detach -force -quiet "$MOUNT"' EXIT
    echo "Nguồn: $DMG"
else
    [ -d build/VietKey.app ] || scripts/build.sh >/dev/null
    APP="build/VietKey.app"; PATTERN="build/VietKey.app/Contents/MacOS/VietKey$"
    echo "Nguồn: $APP"
fi

# Mở trình cài đặt, in hộp thoại, bấm nút $1, in hộp thoại kết quả, bấm OK
run_installer() {
    open "$APP"
    local pid=""
    for _ in $(seq 1 50); do pid=$(pgrep -f "$PATTERN" | head -1); [ -n "$pid" ] && break; sleep 0.2; done
    [ -n "$pid" ] || { echo "  ✘ trình cài đặt không mở được"; FAIL=$((FAIL+1)); return 1; }
    $AX dump "$pid" | sed 's/^/    /'
    echo "    → bấm \"$1\""
    $AX press "$pid" "$1" || { FAIL=$((FAIL+1)); return 1; }
    $AX dump "$pid" | sed 's/^/    /'
    $AX press "$pid" "OK"
    check "trình cài đặt tự thoát" wait_gone
    sleep 1
}

if [ -d "$DEST" ]; then
    echo; echo "▸ Cài lại (đã cài sẵn)"
    run_installer "Cài lại bản $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
    check "app có trong Input Methods" test -d "$DEST"
    check "bộ gõ đang chạy" ime_running
    check "bộ gõ được bật" test "$($AX sources)" -ge 1
fi

echo; echo "▸ Gỡ cài đặt"
run_installer "Gỡ cài đặt"
check "app đã bị xoá khỏi Input Methods" test ! -d "$DEST"
check "bộ gõ đã tắt tiến trình" bash -c '! pgrep -f "Input Methods/VietKey.app/Contents/MacOS/VietKey$" >/dev/null'
check "bộ gõ không còn được bật" test "$($AX sources)" -eq 0

echo; echo "▸ Cài mới"
run_installer "Cài đặt"
check "app có trong Input Methods" test -d "$DEST"
check "không còn cờ quarantine" bash -c "! xattr '$DEST' | grep -q quarantine"
check "bộ gõ đang chạy" ime_running
check "bộ gõ được bật" test "$($AX sources)" -ge 1
check "binary universal (arm64 + x86_64)" bash -c "lipo -archs '$DEST/Contents/MacOS/VietKey' | grep -q x86_64 && lipo -archs '$DEST/Contents/MacOS/VietKey' | grep -q arm64"

echo; echo "$([ $FAIL -eq 0 ] && echo ✔ || echo ✘) $PASS/$((PASS+FAIL)) đúng"
[ $FAIL -eq 0 ]
