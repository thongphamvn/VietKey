import Cocoa
import Carbon
import InputMethodKit

/// `VietKey --register`: đăng ký và bật bộ gõ với macOS rồi thoát (dùng khi cài đặt).
/// `VietKey --unregister`: tắt bộ gõ rồi thoát (dùng khi gỡ cài đặt).
func registerInputSource(enable: Bool) -> Int32 {
    let url = Bundle.main.bundleURL as CFURL
    let status = TISRegisterInputSource(url)
    guard status == noErr else {
        print("Không đăng ký được bộ gõ (lỗi \(status))")
        return 1
    }
    let filter = [kTISPropertyBundleID as String: Bundle.main.bundleIdentifier ?? ""] as CFDictionary
    let sources = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
    guard !sources.isEmpty else {
        print("Đã đăng ký nhưng chưa thấy bộ gõ. Hãy đăng xuất rồi đăng nhập lại.")
        return 1
    }
    for s in sources {
        let err = enable ? TISEnableInputSource(s) : TISDisableInputSource(s)
        if err != noErr { print("Lỗi \(err)") }
    }
    print(enable ? "Đã bật VietKey. Chọn VietKey trên thanh menu (biểu tượng bàn phím) để dùng."
                 : "Đã tắt VietKey.")
    return 0
}

let args = CommandLine.arguments
if args.contains("--register") { exit(registerInputSource(enable: true)) }
if args.contains("--unregister") { exit(registerInputSource(enable: false)) }

let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "VietKey_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
debugLog("VietKey started, connection=\(connectionName) bundle=\(Bundle.main.bundleIdentifier ?? "?")")
NSApplication.shared.run()
