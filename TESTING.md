# Kiểm thử VietKey

Kết quả lần chạy gần nhất: [test-results/SUMMARY.md](test-results/SUMMARY.md)

| Bộ test | Kiểm tra gì | Chạy |
|---|---|---|
| Unit test | Engine Telex và cách đưa chữ vào app, với app giả lập nhiều kiểu: app Cocoa chuẩn, app không báo vị trí con trỏ, app báo vị trí trễ, app báo nội dung trễ (kiểu Electron) | `swift run VietTests` |
| Trình cài đặt | Mở VietKey trong file DMG, bấm nút trong hộp thoại qua Accessibility, kiểm tra cài lại, gỡ cài đặt và cài mới (file, tiến trình, bộ gõ được bật, cờ quarantine, binary universal) | `scripts/installertest.sh` |
| Lệnh cài bằng curl | Chạy `install.sh` qua pipe giống `curl … \| bash`: gỡ, gỡ khi chưa cài, cài bản mới nhất từ GitHub, cài phiên bản cụ thể, phiên bản không tồn tại (báo lỗi, không đụng bản đã cài), cài từ DMG có sẵn | `scripts/curlinstalltest.sh` |
| Gõ phím thật | Gửi phím thật qua macOS (đi qua bộ gõ) vào TextEdit, Safari, Chrome (ô nhập liệu và thanh địa chỉ), VS Code rồi đọc lại chữ | `swift scripts/realtest.swift [app...]` |

Chạy tất cả và lưu kết quả vào `test-results/`:

```bash
scripts/test-all.sh              # cả 4 bộ test
scripts/test-all.sh --unit-only  # chỉ unit test, không cần quyền gì
```

## Yêu cầu

- Unit test: chỉ cần Command Line Tools. Test viết thành chương trình chạy được (`Sources/VietTests`) vì Command Line Tools không có XCTest.
- Trình cài đặt, lệnh cài curl và gõ thật: cần quyền **Accessibility** cho app chạy script (Terminal, iTerm...) trong System Settings → Privacy & Security → Accessibility.
- Gõ thật: cần cài VietKey trước, có sẵn Safari, Chrome, VS Code. Trong lúc chạy (vài phút) không dùng bàn phím, chuột. Script tự dừng nếu cửa sổ đang focus bị đổi sang app khác, và trả lại bộ gõ ban đầu khi xong.
- Tắt **Secure Keyboard Entry** của Terminal: khi bật, macOS tắt mọi bộ gõ.

## Các bài gõ thật

| Phím gõ | Mong đợi | Kiểm tra |
|---|---|---|
| `tooi ddi hocj ` | `tôi đi học ` | câu thường |
| `Vieejt Nam laf nuwowcs ` | `Việt Nam là nước ` | chữ hoa, ươ |
| `nguowif dduowcj truwowngf ` | `người được trường ` | ươ + dấu, đ |
| `quys khachs giuwax ` | `quý khách giữa ` | qu, gi |
| `toans` Delete | `toá` | Delete giữa từ, dấu dời chỗ |
| `tieengs` Delete `g` | `tiếng` | xoá rồi gõ tiếp |
| `vieejt ` Delete Delete `t` | `việt` | xoá qua dấu cách về từ trước |
| `hoaf` Delete×3 `xin chaof` | `xin chào` | xoá hết từ rồi gõ từ mới |
| `hoa` ← `f` | `hofa` | di chuyển con trỏ thì bắt đầu từ mới |
| `case tests, windows.` | `case tests, windows.` | tự khôi phục từ tiếng Anh |

## Ghi chú

- Ngay sau khi bộ gõ được cài lại hoặc khởi động lại, vài phím đầu trong app đang mở có thể chưa đi qua bộ gõ. Vì vậy test gõ thật có bước "khởi động": gõ `aa` tới khi ra `â` rồi mới tính điểm, và ghi lại số lần thử vào kết quả.
- Khi thử bỏ `LSBackgroundOnly` khỏi Info.plist, đôi khi cả lượt test trong một app không nhận bộ gõ (thấy ở Chrome, Safari). Vì vậy tiến trình bộ gõ giữ `LSBackgroundOnly`. Hộp thoại cài đặt vẫn hiện bình thường.
- Chưa test trên máy Intel thật.
- Mở DMG tải bằng trình duyệt: macOS 15 trở lên hiện *"VietKey" Not Opened* chỉ với nút Done, phải vào Privacy & Security → Open Anyway (đã thấy khi thử thật). Lệnh cài bằng curl không gặp bước này.
