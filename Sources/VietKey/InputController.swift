import Cocoa
import InputMethodKit
import VietEngine

private enum Pref {
    static let modernTone = "modernTone"
    static let standaloneW = "standaloneW"
    static let autoRestore = "autoRestore"
    /// Bundle ID các app luôn dùng chế độ marked text (có gạch chân).
    static let markedApps = "markedApps"
}

/// Bọc IMKTextInput theo protocol TextClient.
private final class IMKClient: TextClient {
    let c: IMKTextInput
    init(_ c: IMKTextInput) { self.c = c }
    func selectedRange() -> NSRange { c.selectedRange() }
    func insertText(_ string: String, replacementRange: NSRange) { c.insertText(string, replacementRange: replacementRange) }
    func setMarkedText(_ string: String, selectionRange: NSRange, replacementRange: NSRange) {
        c.setMarkedText(string, selectionRange: selectionRange, replacementRange: replacementRange)
    }
    func text(in range: NSRange) -> String? {
        c.attributedSubstring(from: range)?.string
    }
    var bundleID: String? { c.bundleIdentifier() }
}

/// Ghi log debug ra ~/Library/Logs/VietKey.log khi bật: defaults write com.vietkey.inputmethod.VietKey debug -bool true
func debugLog(_ msg: @autoclosure () -> String) {
    guard UserDefaults.standard.bool(forKey: "debug") else { return }
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/VietKey.log")
    let line = "\(Date()) \(msg())\n"
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

@objc(VietInputController)
final class VietInputController: IMKInputController {
    private let session = InputSession()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        UserDefaults.standard.register(defaults: [
            Pref.modernTone: true, Pref.standaloneW: true, Pref.autoRestore: true,
            Pref.markedApps: [String](),
        ])
        loadPrefs()
        session.log = { debugLog("  " + $0) }
        // App báo vị trí con trỏ trễ => nhớ lại, lần sau dùng marked text ngay từ đầu
        session.onAutoMarked = { id in
            let d = UserDefaults.standard
            var apps = d.stringArray(forKey: Pref.markedApps) ?? []
            if !apps.contains(id) { apps.append(id); d.set(apps, forKey: Pref.markedApps) }
            NSLog("VietKey: %@ báo vị trí con trỏ trễ, chuyển sang chế độ gạch chân", id)
        }
    }

    private func loadPrefs() {
        let d = UserDefaults.standard
        session.composer.modernTone = d.bool(forKey: Pref.modernTone)
        session.composer.standaloneW = d.bool(forKey: Pref.standaloneW)
        session.composer.autoRestore = d.bool(forKey: Pref.autoRestore)
        session.markedApps = Set(d.stringArray(forKey: Pref.markedApps) ?? [])
    }

    private func wrap(_ sender: Any?) -> TextClient? {
        (sender as? IMKTextInput).map(IMKClient.init)
    }

    // MARK: - Lifecycle

    override func activateServer(_ sender: Any!) {
        debugLog("activate \((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")
        super.activateServer(sender)
        loadPrefs()
        session.reset()
    }

    override func deactivateServer(_ sender: Any!) {
        debugLog("deactivate \((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")
        session.commit(wrap(sender))
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        session.commit(wrap(sender))
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]).rawValue)
    }

    // MARK: - Key handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = wrap(sender) else { return false }
        let key = Self.keyInput(event)
        let handled = session.handle(key, client: client)
        debugLog("[\(client.bundleID ?? "?")] key=\(key) handled=\(handled) sel=\(client.selectedRange().location) word=\(session.composer.text) marked=\(session.useMarked)")
        return handled
    }

    static func keyInput(_ event: NSEvent) -> KeyInput {
        guard event.type == .keyDown else { return .interrupt }
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        if !mods.isEmpty { return .interrupt }
        if event.keyCode == 51 { return .backspace }
        guard let chars = event.characters, chars.count == 1, let ch = chars.first,
              let scalar = ch.unicodeScalars.first else { return .control }
        if TelexComposer.accepts(ch) { return .letter(ch) }
        // Phím điều hướng nằm trong vùng Private Use (F700–F8FF); ký tự điều khiển < 0x20
        if (0xF700...0xF8FF).contains(scalar.value) || scalar.value < 0x20 || scalar.value == 0x7F {
            return .control
        }
        return .boundary(chars)
    }

    // MARK: - Menu

    override func menu() -> NSMenu! {
        let m = NSMenu()
        func item(_ title: String, _ key: String, _ action: Selector) {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
            i.target = self
            i.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            m.addItem(i)
        }
        item("Đặt dấu kiểu mới (hoà, thuý)", Pref.modernTone, #selector(toggleModern(_:)))
        item("Gõ w thành ư", Pref.standaloneW, #selector(toggleW(_:)))
        item("Tự khôi phục từ tiếng Anh", Pref.autoRestore, #selector(toggleRestore(_:)))
        m.addItem(.separator())
        let app = NSMenuItem(title: "Dùng chế độ gạch chân cho app hiện tại", action: #selector(toggleMarkedApp(_:)), keyEquivalent: "")
        app.target = self
        if let id = (client() as? IMKTextInput)?.bundleIdentifier() {
            app.state = session.markedApps.contains(id) ? .on : .off
        }
        m.addItem(app)
        return m
    }

    private func toggle(_ key: String) {
        let d = UserDefaults.standard
        d.set(!d.bool(forKey: key), forKey: key)
        loadPrefs()
    }

    @objc func toggleModern(_ sender: Any?) { toggle(Pref.modernTone) }
    @objc func toggleW(_ sender: Any?) { toggle(Pref.standaloneW) }
    @objc func toggleRestore(_ sender: Any?) { toggle(Pref.autoRestore) }

    @objc func toggleMarkedApp(_ sender: Any?) {
        guard let id = (client() as? IMKTextInput)?.bundleIdentifier() else { return }
        let d = UserDefaults.standard
        var apps = d.stringArray(forKey: Pref.markedApps) ?? []
        if let i = apps.firstIndex(of: id) { apps.remove(at: i) } else { apps.append(id) }
        d.set(apps, forKey: Pref.markedApps)
        loadPrefs()
    }
}
