// Test VietKey trong app thật: gửi phím thật qua macOS (đi qua bộ gõ), đọc lại kết quả.
// Cần quyền Accessibility cho app chạy script (System Settings > Privacy & Security > Accessibility).
//
// Chạy:  swift scripts/realtest.swift [textedit safari chrome omnibox vscode terminal] [--delay ms]
// Ký hiệu trong chuỗi phím: "<" Delete, "←"/"→" mũi tên.
import AppKit
import ApplicationServices
import Carbon

setvbuf(stdout, nil, _IONBF, 0)

// MARK: - Quyền

let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
guard trusted else {
    print("NEED_ACCESSIBILITY: Hãy bật quyền Accessibility cho app đang chạy script này rồi chạy lại.")
    exit(2)
}

// MARK: - Tham số

var args = Array(CommandLine.arguments.dropFirst())
var delayMs: UInt32 = 35
if let i = args.firstIndex(of: "--delay"), i + 1 < args.count {
    delayMs = UInt32(args[i + 1]) ?? 35
    args.removeSubrange(i...(i + 1))
}
let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vietkey-realtest")
try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

// MARK: - Bàn phím

let keyCodes: [Character: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
    "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38,
    "k": 40, "n": 45, "m": 46, " ": 49, ",": 43, ".": 47, "<": 51, "←": 123, "→": 124,
]
let src = CGEventSource(stateID: .hidSystemState)

func press(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
    let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)!
    let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(3000)
    up.post(tap: .cghidEventTap)
    usleep(delayMs * 1000)
}

func typeKeys(_ keys: String) {
    for k in keys {
        let lower = Character(k.lowercased())
        guard let code = keyCodes[lower] else { fatalError("Không có keycode cho \(k)") }
        press(code, k.isUppercase ? .maskShift : [])
    }
}

func cmd(_ k: Character) { press(keyCodes[k]!, .maskCommand) }
func ctrl(_ k: Character) { press(keyCodes[k]!, .maskControl) }

// MARK: - Accessibility

func axValue(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success ? v : nil
}

func focusedElement() -> AXUIElement? {
    axValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute).map { $0 as! AXUIElement }
}

func focusedText() -> String? {
    focusedElement().flatMap { axValue($0, kAXValueAttribute) as? String }
}

func frontBundleID() -> String? {
    // Cho run loop chạy một chút để NSWorkspace cập nhật app phía trước
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier { return id }
    guard let app = axValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute) else { return nil }
    var pid: pid_t = 0
    AXUIElementGetPid(app as! AXUIElement, &pid)
    return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
}

/// Bật cây accessibility cho Chrome/Electron
func enableAX(_ bundleID: String) {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(el, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(el, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }
}

// MARK: - Input source

func inputSource(_ id: String) -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    return (TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource])?.first
}

let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
guard let vietkey = inputSource("com.vietkey.inputmethod.VietKey") else {
    print("Không tìm thấy VietKey. Chạy scripts/install.sh trước."); exit(1)
}
func currentSourceID() -> String {
    let src = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    return Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(src, kTISPropertyInputSourceID)).takeUnretainedValue() as String
}
let abc = inputSource("com.apple.keylayout.ABC") ?? inputSource("com.apple.keylayout.US")
func selectVietKey() {
    // Đổi sang bàn phím Latin trước rồi mới chọn VietKey => app thấy một lần chuyển bộ gõ thật
    if let abc { TISSelectInputSource(abc); RunLoop.current.run(until: Date().addingTimeInterval(0.15)) }
    TISSelectInputSource(vietkey)
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}

// MARK: - Test

struct Case { let keys: String; let expected: String }

let cases: [Case] = [
    Case(keys: "tooi ddi hocj ", expected: "tôi đi học "),
    Case(keys: "Vieejt Nam laf nuwowcs ", expected: "Việt Nam là nước "),
    Case(keys: "nguowif dduowcj truwowngf ", expected: "người được trường "),
    Case(keys: "quys khachs giuwax ", expected: "quý khách giữa "),
    Case(keys: "toans<", expected: "toá"),
    Case(keys: "tieengs<g", expected: "tiếng"),
    Case(keys: "vieejt <<t", expected: "việt"),
    Case(keys: "hoaf<<<xin chaof", expected: "xin chào"),
    Case(keys: "hoa←f", expected: "hofa"),
    Case(keys: "case tests, windows.", expected: "case tests, windows."),
]

struct Target {
    let name: String
    let bundleID: String
    let open: () -> Void
    let clear: () -> Void
    let read: () -> String?
    var compareSuffix = false
    var cleanup: () -> Void = {}
}

func run(_ cmd: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: cmd)
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
}

let html = workDir.appendingPathComponent("test.html")
try! """
<!doctype html><meta charset=utf-8><title>VietKey test</title>
<textarea id=t autofocus style="width:90vw;height:60vh;font-size:20px"></textarea>
""".write(to: html, atomically: true, encoding: .utf8)

func fileTarget(_ name: String, _ bundleID: String, _ appName: String, _ file: String) -> Target {
    // Mỗi lượt chạy dùng file riêng: nếu lượt trước bị dừng giữa chừng và app còn mở file cũ,
    // ghi đè file đó sẽ làm app hiện hộp thoại "file đã bị app khác thay đổi" và chặn phím.
    let stem = (file as NSString).deletingPathExtension, ext = (file as NSString).pathExtension
    let url = workDir.appendingPathComponent("\(stem)-\(getpid()).\(ext)")
    return Target(
        name: name, bundleID: bundleID,
        open: {
            try? "".write(to: url, atomically: true, encoding: .utf8)
            run("/usr/bin/open", ["-a", appName, url.path])
        },
        clear: { cmd("a"); press(51) },
        read: {
            // Lưu file rồi đọc từ đĩa: chắc chắn đúng nội dung trong editor
            cmd("s"); usleep(500_000)
            return try? String(contentsOf: url, encoding: .utf8)
        },
        cleanup: {
            cmd("a"); press(51); cmd("s"); usleep(300_000); cmd("w"); usleep(500_000)
            try? FileManager.default.removeItem(at: url)
        }
    )
}

func browserTarget(_ name: String, _ bundleID: String, _ appName: String) -> Target {
    Target(
        name: name, bundleID: bundleID,
        open: { run("/usr/bin/open", ["-a", appName, html.absoluteString]) },
        clear: { cmd("a"); press(51) },
        read: { focusedText() },
        cleanup: { cmd("w") }
    )
}

let allTargets: [String: Target] = [
    "textedit": fileTarget("TextEdit", "com.apple.TextEdit", "TextEdit", "textedit.txt"),
    "vscode": fileTarget("VS Code", "com.microsoft.VSCode", "Visual Studio Code", "vscode.txt"),
    "safari": browserTarget("Safari (textarea)", "com.apple.Safari", "Safari"),
    "chrome": browserTarget("Chrome (textarea)", "com.google.Chrome", "Google Chrome"),
    "omnibox": Target(
        name: "Chrome (thanh địa chỉ)", bundleID: "com.google.Chrome",
        open: { run("/usr/bin/open", ["-a", "Google Chrome", html.absoluteString]); usleep(800_000); cmd("l") },
        clear: { cmd("l"); press(51) },
        read: { focusedText() },
        compareSuffix: false,
        cleanup: { press(53); press(53); cmd("w") }
    ),
    "terminal": Target(
        name: "Terminal", bundleID: "com.apple.Terminal",
        open: { run("/usr/bin/open", ["-a", "Terminal", workDir.path]) },
        clear: { ctrl("e"); ctrl("u") },
        read: {
            // Dòng cuối có chữ của màn hình terminal (dòng prompt đang gõ)
            focusedText()?.split(separator: "\n")
                .map { String($0).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
                .last(where: { !$0.isEmpty })
        },
        compareSuffix: true,
        cleanup: { ctrl("e"); ctrl("u"); cmd("w") }
    ),
]
// Terminal không nằm trong mặc định: khi bật Secure Keyboard Entry, Terminal giữ Secure Input và chặn mọi bộ gõ ở mọi app
let order = ["textedit", "safari", "chrome", "omnibox", "vscode"]
let selected = args.isEmpty ? order : args.filter { allTargets[$0] != nil }

var total = 0, failedCount = 0
var aborted = false

outer: for key in selected {
    let t = allTargets[key]!
    print("\n▸ \(t.name)")
    // Chọn VietKey trước khi kích hoạt app: lệnh chọn bộ gõ từ tiến trình nền chỉ có hiệu lực với app được kích hoạt sau đó
    selectVietKey()
    t.open()
    sleep(3)
    enableAX(t.bundleID)
    usleep(500_000)
    guard frontBundleID() == t.bundleID else {
        print("  ⚠︎ \(t.name) không ở phía trước (đang là \(frontBundleID() ?? "?")), bỏ qua")
        continue
    }
    selectVietKey()
    // Khởi động: gõ thử "aa" tới khi ra "â" (lần đầu sau khi bộ gõ khởi động lại có thể chưa nhận phím)
    var ready = false
    for attempt in 1...4 {
        t.clear(); usleep(200_000)
        typeKeys("aa"); usleep(500_000)
        let v = t.read() ?? ""
        if t.compareSuffix ? v.hasSuffix("â") : v == "â" { ready = true; break }
        print("  (khởi động lần \(attempt): nhận \"\(v.suffix(10))\", chọn lại VietKey)")
        selectVietKey(); usleep(500_000)
    }
    if !ready { print("  ⚠︎ VietKey không nhận phím trong \(t.name)") }
    print("  (bộ gõ: \(currentSourceID()))")
    for c in cases {
        if key == "omnibox" && c.keys.contains("←") { continue }
        guard frontBundleID() == t.bundleID else {
            print("  ⛔︎ Cửa sổ đang focus đã đổi sang \(frontBundleID() ?? "?") — dừng test để không gõ nhầm app khác.")
            aborted = true
            break outer
        }
        t.clear()
        usleep(200_000)
        if currentSourceID() != "com.vietkey.inputmethod.VietKey" {
            print("  (bộ gõ bị đổi thành \(currentSourceID()), chọn lại VietKey)")
            selectVietKey()
        }
        typeKeys(c.keys)
        usleep(600_000)
        var got = t.read() ?? "<không đọc được>"
        if key == "omnibox" { got = String(got.prefix(c.expected.count)) }
        let trimmedExpected = c.expected.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        let ok = t.compareSuffix ? got.hasSuffix(trimmedExpected) : got == c.expected
        total += 1
        if !ok { failedCount += 1 }
        let shown = t.compareSuffix ? String(got.suffix(c.expected.count + 6)) : got
        print("  \(ok ? "✔" : "✘") \(c.keys.padding(toLength: 34, withPad: " ", startingAt: 0)) → \"\(shown)\"\(ok ? "" : "   (đúng: \"\(c.expected)\")")")
    }
    if frontBundleID() == t.bundleID { t.cleanup() }
    usleep(500_000)
}

TISSelectInputSource(originalSource)
print("\n\(failedCount == 0 && !aborted ? "✔" : "✘") \(total - failedCount)/\(total) đúng\(aborted ? " (đã dừng giữa chừng)" : "")")
exit(failedCount == 0 && !aborted ? 0 : 1)
