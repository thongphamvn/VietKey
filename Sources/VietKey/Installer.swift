import Cocoa
import Carbon

/// Khi mở VietKey.app từ chỗ khác ~/Library/Input Methods (vd từ file DMG hoặc Applications),
/// app chạy như trình cài đặt: tự chép mình vào ~/Library/Input Methods, đăng ký và bật bộ gõ.
enum Installer {
    static let bundleID = Bundle.main.bundleIdentifier ?? "com.vietkey.inputmethod.VietKey"
    static let dest = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Input Methods/VietKey.app")

    /// App đang chạy từ thư mục Input Methods => là bộ gõ, không phải trình cài đặt.
    static var isInstalledCopy: Bool {
        Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Input Methods"
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    // MARK: Đăng ký với macOS

    /// Đăng ký bộ gõ tại `url` rồi bật/tắt nó. Trả về thông báo lỗi, nil nếu thành công.
    static func setEnabled(_ enable: Bool, appAt url: URL) -> String? {
        if enable {
            let status = TISRegisterInputSource(url as CFURL)
            guard status == noErr else { return "Không đăng ký được bộ gõ (lỗi \(status))." }
        }
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        let sources = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
        if sources.isEmpty {
            return enable ? "Đã đăng ký nhưng macOS chưa thấy bộ gõ. Hãy đăng xuất rồi đăng nhập lại." : nil
        }
        for s in sources {
            let err = enable ? TISEnableInputSource(s) : TISDisableInputSource(s)
            if err != noErr { return "Lỗi \(err) khi \(enable ? "bật" : "tắt") bộ gõ." }
        }
        return nil
    }

    // MARK: Cài / gỡ

    /// Tắt các tiến trình VietKey khác đang chạy (bản cũ) để có thể thay file.
    private static func stopOtherCopies() {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != getpid() }
        others.forEach { $0.forceTerminate() }
        let deadline = Date().addingTimeInterval(3)
        while others.contains(where: { !$0.isTerminated }) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    static func install() throws {
        let fm = FileManager.default
        stopOtherCopies()
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: Bundle.main.bundleURL, to: dest)
        // App chưa được Apple công chứng: bỏ cờ "tải từ internet" ở bản đã cài để macOS cho bộ gõ chạy
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", dest.path]
        try? xattr.run()
        xattr.waitUntilExit()
        if let err = setEnabled(true, appAt: dest) {
            throw NSError(domain: "VietKey", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        // Khởi động tiến trình bộ gõ. Nếu VietKey đang là bộ gõ hiện tại, macOS tự mở lại ngay khi bản cũ
        // bị tắt; tự mở thêm lúc đó sẽ thành hai tiến trình. Vì vậy chờ macOS trước, chỉ tự mở nếu sau 3 giây
        // vẫn chưa có tiến trình nào.
        if waitForInstalledProcess(seconds: 3) { return }
        // Dùng /usr/bin/open: -n buộc mở tiến trình mới (trình cài đặt có cùng bundle ID), -g mở ở nền.
        // (NSWorkspace.openApplication in cảnh báo sandbox_extension vô hại ra stderr khi chạy từ DMG.)
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-g", "-n", dest.path]
        try? open.run()
        open.waitUntilExit()
        _ = waitForInstalledProcess(seconds: 5)
    }

    /// Chờ tới khi có tiến trình bộ gõ chạy từ thư mục Input Methods.
    private static func waitForInstalledProcess(seconds: Double) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains {
                $0.processIdentifier != getpid() && $0.bundleURL?.standardizedFileURL == dest.standardizedFileURL
            }
            if running { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    static func uninstall() throws {
        _ = setEnabled(false, appAt: dest)
        stopOtherCopies()
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
    }

    // MARK: Giao diện

    /// Chạy trình cài đặt có giao diện (hộp thoại) rồi thoát.
    static func runInteractive() -> Never {
        let app = NSApplication.shared
        let delegate = InstallerDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        exit(0)
    }

    fileprivate static func showDialogs() -> Never {
        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)

        let installed = FileManager.default.fileExists(atPath: dest.path)
        let ask = NSAlert()
        ask.messageText = installed ? "VietKey đã được cài trên máy" : "Cài bộ gõ VietKey \(version)?"
        ask.informativeText = installed
            ? "Bạn có thể cài lại bản \(version) (cập nhật) hoặc gỡ VietKey khỏi máy."
            : "VietKey sẽ được cài vào thư mục Input Methods của bạn và bật trong danh sách bộ gõ. Không cần mật khẩu quản trị."
        ask.addButton(withTitle: installed ? "Cài lại bản \(version)" : "Cài đặt")
        ask.addButton(withTitle: "Huỷ")
        if installed { ask.addButton(withTitle: "Gỡ cài đặt") }

        let result = NSAlert()
        switch ask.runModal() {
        case .alertFirstButtonReturn:
            do {
                try install()
                result.messageText = "Đã cài VietKey"
                result.informativeText = """
                Chọn VietKey ở biểu tượng bàn phím trên thanh menu, hoặc đổi bộ gõ bằng Ctrl+Space / phím 🌐.

                Nếu chưa thấy VietKey trong danh sách: đăng xuất rồi đăng nhập lại.

                Có thể đẩy (eject) file DMG và xoá nó đi.
                """
            } catch {
                result.alertStyle = .warning
                result.messageText = "Cài đặt không thành công"
                result.informativeText = error.localizedDescription
            }
        case .alertThirdButtonReturn:
            do {
                try uninstall()
                result.messageText = "Đã gỡ VietKey"
                result.informativeText = "Nếu VietKey vẫn còn trong danh sách bộ gõ, hãy đăng xuất rồi đăng nhập lại."
            } catch {
                result.alertStyle = .warning
                result.messageText = "Gỡ cài đặt không thành công"
                result.informativeText = error.localizedDescription
            }
        default:
            exit(0)
        }
        app.activate(ignoringOtherApps: true)
        result.runModal()
        exit(0)
    }
}

private final class InstallerDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Installer.showDialogs()
    }
}
