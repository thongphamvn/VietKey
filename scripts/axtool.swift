// Công cụ nhỏ dùng trong scripts/installertest.sh (cần quyền Accessibility):
//   swift axtool.swift dump <pid>           in chữ và nút trong cửa sổ của tiến trình
//   swift axtool.swift press <pid> <nút>    bấm nút có tiêu đề <nút>
//   swift axtool.swift sources              đếm số bộ gõ VietKey đang bật
import Cocoa
import Carbon

func attr(_ e: AXUIElement, _ a: String) -> AnyObject? {
    var v: AnyObject?
    AXUIElementCopyAttributeValue(e, a as CFString, &v)
    return v
}
func children(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }

/// Chờ tối đa 10 giây cho tới khi `f` trả về giá trị.
func poll<T>(_ f: () -> T?) -> T? {
    for _ in 0..<50 { if let v = f() { return v }; usleep(200_000) }
    return nil
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "sources":
    let filter = [kTISPropertyBundleID as String: "com.vietkey.inputmethod.VietKey"] as CFDictionary
    let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
    print(list.count)
case "dump":
    let app = AXUIElementCreateApplication(pid_t(args[2])!)
    var lines: [String] = []
    func walk(_ e: AXUIElement) {
        let role = attr(e, kAXRoleAttribute) as? String ?? ""
        let text = (attr(e, kAXTitleAttribute) as? String) ?? (attr(e, kAXValueAttribute) as? String) ?? ""
        if (role == "AXButton" || role == "AXStaticText") && !text.isEmpty {
            lines.append("\(role == "AXButton" ? "[nút]" : "[chữ]") \(text.replacingOccurrences(of: "\n", with: " / "))")
        }
        children(e).forEach(walk)
    }
    _ = poll { () -> Bool? in
        lines = []
        children(app).forEach(walk)
        return lines.isEmpty ? nil : true
    }
    if lines.isEmpty { print("(không thấy hộp thoại)"); exit(1) }
    lines.forEach { print($0) }
case "press":
    let app = AXUIElementCreateApplication(pid_t(args[2])!)
    let title = args[3]
    func find(_ e: AXUIElement) -> AXUIElement? {
        if attr(e, kAXRoleAttribute) as? String == "AXButton", attr(e, kAXTitleAttribute) as? String == title { return e }
        for c in children(e) { if let f = find(c) { return f } }
        return nil
    }
    guard let b = poll({ find(app) }) else { print("không thấy nút \"\(title)\""); exit(1) }
    exit(AXUIElementPerformAction(b, kAXPressAction as CFString) == .success ? 0 : 1)
default:
    print("dùng: axtool.swift dump <pid> | press <pid> <nút> | sources"); exit(2)
}
