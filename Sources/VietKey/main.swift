import Cocoa
import InputMethodKit

// Dòng lệnh (dùng cho script cài đặt):
//   VietKey --register     đăng ký và bật bộ gõ tại vị trí của app này, rồi thoát
//   VietKey --unregister   tắt bộ gõ rồi thoát
//   VietKey --install      cài vào ~/Library/Input Methods không cần hỏi (giống bấm "Cài đặt")
//   VietKey --uninstall    gỡ khỏi máy không cần hỏi
let args = CommandLine.arguments
if args.contains("--install") || args.contains("--uninstall") {
    do {
        if args.contains("--install") { try Installer.install() } else { try Installer.uninstall() }
        print(args.contains("--install") ? "Đã cài VietKey vào \(Installer.dest.path)" : "Đã gỡ VietKey")
        exit(0)
    } catch {
        print(error.localizedDescription); exit(1)
    }
}
if args.contains("--register") || args.contains("--unregister") {
    let enable = args.contains("--register")
    if let err = Installer.setEnabled(enable, appAt: Bundle.main.bundleURL) {
        print(err); exit(1)
    }
    print(enable ? "Đã bật VietKey. Chọn VietKey trên thanh menu (biểu tượng bàn phím) để dùng." : "Đã tắt VietKey.")
    exit(0)
}

// Mở từ DMG / Applications => chạy trình cài đặt
if !Installer.isInstalledCopy {
    Installer.runInteractive()
}

let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "VietKey_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
debugLog("VietKey started, connection=\(connectionName) bundle=\(Bundle.main.bundleIdentifier ?? "?")")
NSApplication.shared.run()
