#!/bin/bash
# Test install.sh (lệnh cài bằng curl): gỡ, cài bản mới nhất từ GitHub, cài phiên bản cụ thể,
# phiên bản không tồn tại, cài từ DMG có sẵn. Chạy script qua pipe giống `curl ... | bash`.
# Kết thúc ở trạng thái đã cài.
set -uo pipefail
cd "$(dirname "$0")/.."
DEST="$HOME/Library/Input Methods/VietKey.app"
PASS=0; FAIL=0
check() { local d=$1; shift; if "$@"; then echo "  ✔ $d"; PASS=$((PASS+1)); else echo "  ✘ $d"; FAIL=$((FAIL+1)); fi; }
ime_running() { pgrep -f "Input Methods/VietKey.app/Contents/MacOS/VietKey$" >/dev/null; }
# Đúng một tiến trình bộ gõ (chờ chút để tiến trình trùng, nếu có, kịp tự thoát)
ime_single() { sleep 2; [ "$(pgrep -f "Input Methods/VietKey.app/Contents/MacOS/VietKey$" | wc -l | tr -d ' ')" -eq 1 ]; }
enabled() { swift scripts/axtool.swift sources; }
installed_ok() {
    check "app có trong Input Methods" test -d "$DEST"
    check "không có cờ quarantine" bash -c "! xattr '$DEST' | grep -q quarantine"
    check "bộ gõ đang chạy" ime_running
    check "chỉ có một tiến trình bộ gõ" ime_single
    check "bộ gõ được bật" test "$(enabled)" -ge 1
}
# Chạy install.sh qua pipe, in output (bỏ thanh tiến trình của curl)
pipe() { cat install.sh | env "$@" bash 2>&1 | tr '\r' '\n' | grep -v -E '^[#=O -]*([0-9.]+%)?$' | sed 's/^/    /'; return "${PIPESTATUS[2]}"; }

echo "▸ Gỡ cài đặt"
cat install.sh | bash -s -- --uninstall 2>&1 | sed 's/^/    /'
check "app đã bị xoá" test ! -d "$DEST"
check "bộ gõ không còn được bật" test "$(enabled)" -eq 0

echo; echo "▸ Gỡ khi chưa cài"
out=$(cat install.sh | bash -s -- --uninstall 2>&1); echo "    $out"
check "báo chưa cài" grep -q "chưa được cài" <<<"$out"

echo; echo "▸ Cài bản mới nhất từ GitHub"
pipe X=1; installed_ok

echo; echo "▸ Cài phiên bản cụ thể (VIETKEY_VERSION)"
V=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
pipe VIETKEY_VERSION="$V"; installed_ok

echo; echo "▸ Phiên bản không tồn tại"
out=$(cat install.sh | VIETKEY_VERSION=9.9.9 bash 2>&1); code=$?
grep "Lỗi" <<<"$out" | sed 's/^/    /'
check "thoát với mã lỗi" test "$code" -ne 0
check "báo không có file" grep -q "Không có file" <<<"$out"
check "bản đã cài vẫn còn nguyên" test -d "$DEST"

DMG=$(ls dist/VietKey-*.dmg 2>/dev/null | tail -1)
if [ -n "$DMG" ]; then
    echo; echo "▸ Cài từ DMG có sẵn (VIETKEY_DMG=$DMG)"
    VIETKEY_DMG="$DMG" bash install.sh 2>&1 | sed 's/^/    /'; installed_ok
fi

check "không còn DMG nào bị mount sót" bash -c "! mount | grep -q '/T/tmp\.'"
echo; echo "$([ $FAIL -eq 0 ] && echo ✔ || echo ✘) $PASS/$((PASS+FAIL)) đúng"
[ $FAIL -eq 0 ]
