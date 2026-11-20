// Tạo icon 16x16@2x cho input source: chữ "Vi" trên nền bo góc.
import AppKit
let out = CommandLine.arguments[1]
let size = NSSize(width: 32, height: 32)
let img = NSImage(size: size, flipped: false) { r in
    NSColor.black.setFill()
    NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 3), xRadius: 5, yRadius: 5).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 17, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    let s = NSAttributedString(string: "Vi", attributes: attrs)
    let sz = s.size()
    s.draw(at: NSPoint(x: (r.width - sz.width) / 2, y: (r.height - sz.height) / 2))
    return true
}
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
rep.size = NSSize(width: 16, height: 16)
try! rep.tiffRepresentation!.write(to: URL(fileURLWithPath: out))
