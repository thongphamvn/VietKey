# VietKey

Bộ gõ tiếng Việt (Telex) cho macOS, viết bằng Swift trên InputMethodKit.

Sinh ra để sửa hai lỗi khó chịu nhất của bộ gõ có sẵn trên macOS:

- **Xoá không nhảy chữ.** Bộ gõ làm việc trên chữ đã ghép, không phát lại chuỗi phím gốc, nên Delete xoá đúng một ký tự đang nhìn thấy.
- **Đặt dấu đúng chỗ.** Dấu được tách ra và đặt lại sau mỗi phím theo quy tắc chính tả (`hoà` → `hoàn`, `thuý`, `người`, `khuya`), chỉ biến đổi khi kết quả là âm tiết tiếng Việt hợp lệ.

Ngoài ra:

- Không gạch chân: chữ được gõ thẳng vào app. App nào báo vị trí con trỏ không chính xác thì tự chuyển sang chế độ gạch chân, và luôn kiểm tra lại chữ trong app trước khi sửa để không bao giờ làm hỏng văn bản.
- Tự trả lại từ tiếng Anh khi gõ dấu cách (`case`, `windows`, `tests`).
- Đặt dấu kiểu mới (`hoà`) hoặc kiểu cũ (`hòa`); gõ `w` thành `ư`.

Đã kiểm tra bằng phím thật trong TextEdit, Safari, Chrome (ô nhập liệu và thanh địa chỉ) và VS Code.

## Cài đặt

1. Tải **`VietKey-<phiên bản>.dmg`** ở mục [Releases](../../releases) rồi mở ra.
2. Bấm đúp **VietKey** và chọn **Cài đặt**. App tự cài vào `~/Library/Input Methods` và bật bộ gõ, không cần mật khẩu quản trị và không cần kéo vào Applications.
   App chưa được Apple công chứng, nên lần đầu macOS có thể chặn. Khi đó vào **System Settings → Privacy & Security → Open Anyway** rồi bấm đúp lại.
3. Chọn **VietKey** ở biểu tượng bàn phím trên thanh menu (hoặc Ctrl+Space / phím 🌐). Nếu chưa thấy, đăng xuất rồi đăng nhập lại.

Cập nhật hoặc gỡ cài đặt: mở DMG, bấm đúp **VietKey**, chọn **Cài lại** hoặc **Gỡ cài đặt**.

Yêu cầu macOS 13 trở lên, Apple Silicon hoặc Intel.

## Cách gõ (Telex)

| Phím | Kết quả | Phím | Kết quả |
|---|---|---|---|
| `s` `f` `r` `x` `j` | sắc huyền hỏi ngã nặng | `z` | xoá dấu |
| `aa` `ee` `oo` | â ê ô | `aw` `ow` `uw` | ă ơ ư |
| `w` | ư | `dd` | đ |
| `uow` | ươ | gõ phím dấu 2 lần | bỏ dấu, giữ chữ gốc |

Các tuỳ chọn nằm trong menu của bộ gõ trên thanh menu.

## Build từ mã nguồn

Chỉ cần Command Line Tools (`xcode-select --install`), không cần Xcode.

```bash
scripts/install.sh      # build và cài cho máy này
swift run VietTests     # chạy unit test của engine
scripts/package.sh      # đóng gói bản phát hành universal: dist/VietKey-<phiên bản>.dmg
scripts/uninstall.sh    # gỡ cài đặt
```

Cách kiểm thử và kết quả gần nhất: [TESTING.md](TESTING.md), [test-results/SUMMARY.md](test-results/SUMMARY.md). Chạy toàn bộ: `scripts/test-all.sh`.

## Cấu trúc

```
Sources/VietEngine/   engine gõ, không phụ thuộc giao diện
  Vietnamese.swift      bảng chữ, phân tích âm tiết, vị trí dấu
  TelexComposer.swift   biến đổi Telex trên chữ đã ghép
  InputSession.swift    đưa chữ vào app: gõ thẳng hoặc gạch chân, kiểm tra trước khi sửa
Sources/VietKey/      app InputMethodKit; mở từ ngoài Input Methods thì chạy như trình cài đặt
Sources/VietTests/    test engine và app giả lập (app báo trễ, không báo con trỏ...)
packaging/            hướng dẫn đi kèm file DMG
scripts/              build, cài, đóng gói, test trong app thật
```

## Hạn chế

- Từ tiếng Anh tình cờ là âm tiết tiếng Việt hợp lệ vẫn bị đổi (`test` → `tét`).
- Chưa hỗ trợ kiểu gõ VNI.
- Terminal bật Secure Keyboard Entry thì macOS tắt mọi bộ gõ.
