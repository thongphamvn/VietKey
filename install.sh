#!/bin/bash
# Cài VietKey bằng một lệnh, không gặp hộp thoại "Apple could not verify":
#
#   curl -fsSL https://raw.githubusercontent.com/thongphamvn/VietKey/main/install.sh | bash
#
# Gỡ cài đặt:
#   curl -fsSL https://raw.githubusercontent.com/thongphamvn/VietKey/main/install.sh | bash -s -- --uninstall
#
# Cài một phiên bản cụ thể:  ... | VIETKEY_VERSION=0.1.0 bash
# Cài từ file DMG có sẵn:    VIETKEY_DMG=đường/dẫn.dmg bash install.sh
#
# Script tải file DMG ở mục Releases trên GitHub, cài VietKey vào ~/Library/Input Methods
# và bật bộ gõ. Không cần mật khẩu quản trị. File tải bằng curl không bị macOS gắn cờ
# "tải từ internet", nên không cần vào Privacy & Security để cho phép.

# Toàn bộ nằm trong hàm main, gọi ở dòng cuối: nếu tải script bị đứt giữa chừng thì không chạy gì cả.
main() {
    set -euo pipefail
    local repo="thongphamvn/VietKey"
    local dest="$HOME/Library/Input Methods/VietKey.app"

    say() { printf '%s\n' "$*"; }
    die() { printf 'Lỗi: %s\n' "$*" >&2; exit 1; }

    [ "$(uname -s)" = "Darwin" ] || die "VietKey chỉ chạy trên macOS."
    local major
    major=$(sw_vers -productVersion | cut -d. -f1)
    [ "$major" -ge 13 ] || die "VietKey cần macOS 13 trở lên (máy này: $(sw_vers -productVersion))."

    if [ "${1:-}" = "--uninstall" ]; then
        if [ -d "$dest" ]; then
            "$dest/Contents/MacOS/VietKey" --uninstall
        else
            say "VietKey chưa được cài."
        fi
        return
    fi

    local tmp
    tmp=$(mktemp -d)
    local mnt="$tmp/mnt"
    trap 'hdiutil detach -quiet "'"$mnt"'" 2>/dev/null; rm -rf "'"$tmp"'"' EXIT

    local dmg="${VIETKEY_DMG:-}"
    if [ -z "$dmg" ]; then
        local url
        if [ -n "${VIETKEY_VERSION:-}" ]; then
            local v="${VIETKEY_VERSION#v}"
            url="https://github.com/$repo/releases/download/v$v/VietKey-$v.dmg"
        else
            say "Đang tìm phiên bản mới nhất..."
            url=$(curl -fsSL --connect-timeout 15 --max-time 30 --retry 3 "https://api.github.com/repos/$repo/releases/latest" \
                | grep -o '"browser_download_url": *"[^"]*\.dmg"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/') \
                || die "Không lấy được thông tin bản phát hành từ GitHub."
            [ -n "$url" ] || die "Không tìm thấy file DMG trong bản phát hành mới nhất."
        fi
        say "Đang tải $(basename "$url")..."
        dmg="$tmp/VietKey.dmg"
        # Tự thử lại khi mạng lỗi tạm thời hoặc kết nối đứng (dưới 1 KB/s trong 15 giây); 404 thì báo ngay
        local code=0
        curl -fL --progress-bar --connect-timeout 15 --speed-limit 1024 --speed-time 15 \
            --retry 5 --retry-delay 2 "$url" -o "$dmg" || code=$?
        if [ "$code" -eq 22 ] || [ "$code" -eq 56 ] && ! [ -s "$dmg" ]; then
            die "Không có file $(basename "$url") trên GitHub. Xem các phiên bản tại https://github.com/$repo/releases"
        fi
        [ "$code" -eq 0 ] || die "Tải không thành công (curl lỗi $code). Kiểm tra mạng rồi chạy lại lệnh."
    fi

    mkdir -p "$mnt"
    hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg" >/dev/null 2>&1 \
        || die "Không mở được file DMG."
    [ -x "$mnt/VietKey.app/Contents/MacOS/VietKey" ] || die "File DMG không có VietKey.app."

    "$mnt/VietKey.app/Contents/MacOS/VietKey" --install
    say ""
    say "Xong! Chọn VietKey ở biểu tượng bàn phím trên thanh menu, hoặc đổi bộ gõ bằng Ctrl+Space / phím 🌐."
    say "Nếu chưa thấy VietKey trong danh sách: đăng xuất rồi đăng nhập lại."
}

main "$@"
