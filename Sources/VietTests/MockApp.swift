import Foundation
import VietEngine

/// App giả lập: một ô text với con trỏ, xử lý phím giống app thật khi bộ gõ trả về false.
final class MockApp: TextClient {
    enum Kind {
        /// App Cocoa chuẩn (TextEdit, Notes...): báo đúng vị trí con trỏ, hỗ trợ replacementRange
        case cocoa
        /// App không báo được vị trí con trỏ => bộ gõ phải dùng marked text
        case noSelection
        /// App báo vị trí con trỏ trễ 1 phím (mô phỏng trường hợp xấu nhất của app đa tiến trình như Chrome)
        case laggy
        /// Báo vị trí con trỏ đúng nhưng nội dung trễ 1 phím (giống VS Code/Electron khi gõ nhanh)
        case staleText
    }

    let kind: Kind
    let bundleID: String? = "test.app"
    private(set) var text = NSMutableString()
    private(set) var cursor = 0
    private(set) var marked: NSRange?
    private var reportedCursor = 0
    private var reportedText = ""

    init(_ kind: Kind = .cocoa, text initial: String = "", cursor: Int? = nil) {
        self.kind = kind
        text.setString(initial)
        self.cursor = cursor ?? text.length
        reportedCursor = self.cursor
        reportedText = initial
    }

    var string: String { text as String }
    var markedString: String? { marked.map { text.substring(with: $0) } }

    // MARK: TextClient

    func selectedRange() -> NSRange {
        switch kind {
        case .cocoa: return NSRange(location: cursor, length: 0)
        case .noSelection: return kNotFound
        case .laggy: return NSRange(location: reportedCursor, length: 0)
        case .staleText: return NSRange(location: cursor, length: 0)
        }
    }

    func text(in range: NSRange) -> String? {
        let src = (kind == .laggy || kind == .staleText ? reportedText : string) as NSString
        guard NSMaxRange(range) <= src.length else { return nil }
        return src.substring(with: range)
    }

    func insertText(_ s: String, replacementRange r: NSRange) {
        let range: NSRange
        if let m = marked { range = m }
        else if r.location != NSNotFound { range = r }
        else { range = NSRange(location: cursor, length: 0) }
        text.replaceCharacters(in: range, with: s)
        cursor = range.location + (s as NSString).length
        marked = nil
    }

    func setMarkedText(_ s: String, selectionRange: NSRange, replacementRange: NSRange) {
        let range = marked ?? NSRange(location: cursor, length: 0)
        text.replaceCharacters(in: range, with: s)
        let len = (s as NSString).length
        marked = len == 0 ? nil : NSRange(location: range.location, length: len)
        cursor = range.location + len
    }

    // MARK: Xử lý phím của chính app (khi bộ gõ không xử lý)

    private func native(_ key: KeyInput, raw: Character) {
        switch key {
        case .letter(let c): insertText(String(c), replacementRange: kNotFound)
        case .boundary(let s): insertText(s, replacementRange: kNotFound)
        case .backspace:
            guard cursor > 0 else { return }
            let r = text.rangeOfComposedCharacterSequence(at: cursor - 1)
            text.deleteCharacters(in: r)
            cursor = r.location
        case .control:
            if raw == "←", cursor > 0 { cursor = text.rangeOfComposedCharacterSequence(at: cursor - 1).location }
            if raw == "→", cursor < text.length { cursor = NSMaxRange(text.rangeOfComposedCharacterSequence(at: cursor)) }
        case .interrupt:
            if raw == "^" { cursor = 0 }
            if raw == "|" { cursor = text.length }
        }
    }

    /// Gõ chuỗi phím. Ký hiệu: "<" Delete, "←"/"→" mũi tên, "^" click đầu dòng, "|" click cuối dòng, "⏎" Enter.
    func type(_ keys: String, with session: InputSession) {
        for k in keys {
            let key: KeyInput
            switch k {
            case "<": key = .backspace
            case "←", "→", "⏎": key = .control
            case "^", "|": key = .interrupt
            default: key = TelexComposer.accepts(k) ? .letter(k) : .boundary(String(k))
            }
            let before = (cursor, string)
            if !session.handle(key, client: self) { native(key, raw: k) }
            // App báo trễ: vị trí và nội dung app báo về là của trước phím vừa gõ
            (reportedCursor, reportedText) = (kind == .laggy || kind == .staleText) ? before : (cursor, string)
        }
    }
}

func run(_ keys: String, app: MockApp = MockApp()) -> MockApp {
    let s = InputSession()
    app.type(keys, with: s)
    s.commit(app)
    return app
}

