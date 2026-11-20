// Vẽ icon VietKey.
//   swift make-icon.swift menu <out.tiff>   icon 16pt@2x cho thanh menu (chữ "Vi" trên nền đen)
//   swift make-icon.swift app <out.icns>    icon app cho Finder
import AppKit

func png(_ img: NSImage, px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func centered(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in r: NSRect, dy: CGFloat = 0) {
    let s = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
    ])
    let sz = s.size()
    s.draw(at: NSPoint(x: r.midX - sz.width / 2, y: r.midY - sz.height / 2 + dy))
}

let mode = CommandLine.arguments[1]
let out = URL(fileURLWithPath: CommandLine.arguments[2])

if mode == "menu" {
    let img = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { r in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 3), xRadius: 5, yRadius: 5).fill()
        centered("Vi", size: 17, weight: .bold, color: .white, in: r)
        return true
    }
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    rep.size = NSSize(width: 16, height: 16)
    try! rep.tiffRepresentation!.write(to: out)
} else {
    // Ô vuông bo góc kiểu macOS, nền đỏ, chữ "Vi" trắng và dấu sắc vàng
    let img = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { r in
        let tile = r.insetBy(dx: 100, dy: 100)
        let path = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.shadowBlurRadius = 28
        shadow.set()
        NSColor(red: 0.85, green: 0.15, blue: 0.13, alpha: 1).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(red: 0.93, green: 0.26, blue: 0.20, alpha: 1),
                   ending: NSColor(red: 0.74, green: 0.09, blue: 0.10, alpha: 1))!.draw(in: path, angle: -90)
        centered("Vi", size: 430, weight: .heavy, color: .white, in: tile, dy: -30)
        // dấu sắc phía trên chữ i
        let accent = NSBezierPath()
        accent.move(to: NSPoint(x: 600, y: 720))
        accent.line(to: NSPoint(x: 700, y: 820))
        accent.lineWidth = 46
        accent.lineCapStyle = .round
        NSColor(red: 1, green: 0.83, blue: 0.2, alpha: 1).setStroke()
        accent.stroke()
        return true
    }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("VietKey-\(getpid()).iconset")
    try? FileManager.default.removeItem(at: dir)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for pt in [16, 32, 128, 256, 512] {
        try! png(img, px: pt).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt).png"))
        try! png(img, px: pt * 2).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    p.arguments = ["-c", "icns", dir.path, "-o", out.path]
    try! p.run(); p.waitUntilExit()
    try? FileManager.default.removeItem(at: dir)
    exit(p.terminationStatus)
}
