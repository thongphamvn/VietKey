import Foundation

/// Phần tối thiểu của app (client) mà bộ gõ cần. IMKTextInput được bọc lại theo protocol này,
/// nhờ vậy có thể test bằng app giả lập.
public protocol TextClient: AnyObject {
    func selectedRange() -> NSRange
    func insertText(_ string: String, replacementRange: NSRange)
    func setMarkedText(_ string: String, selectionRange: NSRange, replacementRange: NSRange)
    /// Đọc text trong khoảng range; nil nếu app không hỗ trợ.
    func text(in range: NSRange) -> String?
    var bundleID: String? { get }
}

public enum KeyInput: Equatable {
    /// Chữ cái a-z / A-Z
    case letter(Character)
    case backspace
    /// Ký tự kết thúc từ: dấu cách, dấu câu, số...
    case boundary(String)
    /// Phím điều khiển: mũi tên, Enter, Tab, Esc...
    case control
    /// Tổ hợp có Cmd/Ctrl/Option, hoặc click chuột
    case interrupt
}

public let kNotFound = NSRange(location: NSNotFound, length: NSNotFound)

/// Logic xử lý phím của bộ gõ. Trả về true nếu bộ gõ đã tự xử lý, false để app xử lý phím như bình thường.
///
/// Hai cách đưa chữ vào app:
/// - direct: để app tự chèn phím; khi cần sửa chữ trước đó thì dùng insertText(_:replacementRange:). Không gạch chân.
/// - marked: giữ từ đang gõ ở dạng marked text (giống bộ gõ Apple). Dùng cho app không báo được vị trí con trỏ.
public final class InputSession {
    public var composer = TelexComposer()
    public var markedApps: Set<String> = []
    /// Gọi khi phát hiện app báo vị trí con trỏ trễ và tự chuyển app đó sang marked text.
    public var onAutoMarked: ((String) -> Void)?
    /// Log debug (nil = tắt)
    public var log: ((String) -> Void)?
    public private(set) var useMarked = false
    /// Vị trí con trỏ mà bộ gõ dự đoán sau phím vừa rồi
    private var expectedLocation = NSNotFound
    /// Vị trí con trỏ trước phím vừa rồi (để nhận ra app báo trễ)
    private var previousLocation = NSNotFound
    private var lagHits = 0
    /// Lần sửa gần nhất của bộ gõ (để nhận ra app báo nội dung trễ ngay sau khi bộ gõ sửa)
    private struct Edit { let location: Int; let removed: String; let inserted: String }
    private var lastEdit: Edit?
    private var autoMarkedClients = Set<ObjectIdentifier>()

    public init() {}

    public func reset() {
        composer.reset()
        expectedLocation = NSNotFound
        previousLocation = NSNotFound
        lastEdit = nil
    }

    public func handle(_ key: KeyInput, client: TextClient) -> Bool {
        switch key {
        case .interrupt:
            commit(client)
            return false
        case .backspace:
            return handleBackspace(client)
        case .control:
            return endWord(client, boundary: nil)
        case .boundary(let s):
            return endWord(client, boundary: s)
        case .letter(let ch):
            if composer.isEmpty { useMarked = shouldUseMarked(client) }
            return useMarked ? typeMarked(ch, client) : typeDirect(ch, client)
        }
    }

    /// Kết thúc từ đang gõ (khi đổi bộ gõ, mất focus...).
    public func commit(_ client: TextClient?) {
        if useMarked, !composer.isEmpty, let client {
            client.insertText(composer.restoredText() ?? composer.text, replacementRange: kNotFound)
        }
        reset()
    }

    // MARK: Direct mode

    private func typeDirect(_ ch: Character, _ client: TextClient) -> Bool {
        let sel = client.selectedRange()
        if !composer.isEmpty && !positionMatches(sel, client) {
            // Con trỏ đã bị di chuyển (hoặc app báo trễ) => bắt đầu từ mới
            composer.reset()
        }
        let before = composer.word
        composer.type(ch)
        let after = composer.word

        if after == before + [ch] && sel.location != NSNotFound {
            // Không biến đổi gì: để app tự chèn phím, tương thích tốt nhất
            advance(from: sel.location, to: sel.location + String(ch).utf16.count)
            return false
        }
        guard replace(client, from: before, to: after, cursor: sel.location) else {
            // Không chắc chắn vị trí => không sửa gì, để app tự chèn phím
            composer.reset()
            advance(from: sel.location, to: sel.location + String(ch).utf16.count)
            return false
        }
        return true
    }

    private func advance(from: Int, to: Int) {
        previousLocation = from
        expectedLocation = to
    }

    /// Con trỏ có đúng chỗ bộ gõ dự đoán không. Nếu app báo đúng vị trí *trước* phím vừa gõ
    /// thì nhiều khả năng app báo trễ (vd app đa tiến trình) => sau 2 lần thì tự chuyển sang marked text.
    private func positionMatches(_ sel: NSRange, _ client: TextClient) -> Bool {
        if sel.location == expectedLocation && sel.length == 0 { return true }
        log?("position mismatch sel=\(sel.location),\(sel.length) expected=\(expectedLocation) prev=\(previousLocation)")
        if previousLocation != NSNotFound && sel.location == previousLocation {
            registerLag(client)
        }
        return false
    }

    /// App báo vị trí/nội dung không khớp thực tế. Sau 2 lần => chuyển app sang marked text.
    private func registerLag(_ client: TextClient) {
        lagHits += 1
        log?("lag hit #\(lagHits)")
        guard lagHits >= 2, !useMarked, !autoMarkedClients.contains(ObjectIdentifier(client)) else { return }
        autoMarkedClients.insert(ObjectIdentifier(client))
        if let id = client.bundleID {
            markedApps.insert(id)
            onAutoMarked?(id)
        }
    }

    private func handleBackspace(_ client: TextClient) -> Bool {
        guard !composer.isEmpty else { return false }
        if useMarked {
            composer.backspace()
            let t = composer.text
            client.setMarkedText(t, selectionRange: NSRange(location: t.utf16.count, length: 0), replacementRange: kNotFound)
            return true
        }
        let sel = client.selectedRange()
        guard positionMatches(sel, client) else {
            reset()
            return false
        }
        let before = composer.word
        composer.backspace()
        let after = composer.word
        if Array(before.dropLast()) == after {
            // Xoá đúng ký tự cuối: để app tự xử lý Delete
            advance(from: sel.location, to: sel.location - String(before.last!).utf16.count)
            return false
        }
        guard replace(client, from: before, to: after, cursor: sel.location) else {
            reset()
            return false
        }
        return true
    }

    /// Thay phần khác nhau giữa từ cũ và từ mới, bắt đầu từ ký tự đầu tiên khác nhau.
    /// Trước khi thay, đọc lại text trong app để chắc chắn đang thay đúng chữ; trả về false nếu không khớp.
    @discardableResult
    private func replace(_ client: TextClient, from before: [Character], to after: [Character], cursor: Int) -> Bool {
        var p = 0
        while p < before.count && p < after.count && before[p] == after[p] { p += 1 }
        let old = String(before[p...])
        let delLen = old.utf16.count
        let ins = String(after[p...])
        guard cursor != NSNotFound else {
            guard delLen == 0 else { return false }
            client.insertText(ins, replacementRange: kNotFound)
            expectedLocation = NSNotFound
            return true
        }
        if delLen > 0 {
            guard cursor >= delLen else { return false }
            let range = NSRange(location: cursor - delLen, length: delLen)
            if let actual = client.text(in: range), actual != old, !isStaleOwnEdit(actual, expected: old, range: range) {
                log?("verify FAIL range=\(range.location),\(range.length) app=\"\(actual)\" mong đợi=\"\(old)\" sel=\(client.selectedRange().location)")
                registerLag(client)
                return false
            }
            client.insertText(ins, replacementRange: range)
            lastEdit = Edit(location: range.location, removed: old, inserted: ins)
        } else {
            client.insertText(ins, replacementRange: kNotFound)
            lastEdit = nil
        }
        advance(from: cursor, to: cursor - delLen + ins.utf16.count)
        return true
    }

    /// App (vd Electron/VS Code) báo vị trí con trỏ đúng nhưng nội dung còn là bản *trước* lần sửa gần nhất
    /// của bộ gõ. Nếu nội dung app trả về đúng bằng chữ mong đợi với lần sửa đó được hoàn tác, thì đó là
    /// app chưa cập nhật kịp — sửa tiếp vẫn an toàn vì app xử lý các lệnh sửa theo thứ tự.
    private func isStaleOwnEdit(_ actual: String, expected: String, range: NSRange) -> Bool {
        guard let e = lastEdit else { return false }
        let len = (e.inserted as NSString).length
        guard len == (e.removed as NSString).length,
              e.location >= range.location, e.location + len <= NSMaxRange(range) else { return false }
        let ns = expected as NSString
        let span = NSRange(location: e.location - range.location, length: len)
        guard ns.substring(with: span) == e.inserted else { return false }
        let stale = ns.replacingCharacters(in: span, with: e.removed)
        if actual == stale {
            log?("app báo nội dung trễ sau lần sửa của bộ gõ (app=\"\(actual)\"), vẫn sửa tiếp")
            return true
        }
        return false
    }

    // MARK: Marked mode

    private func typeMarked(_ ch: Character, _ client: TextClient) -> Bool {
        composer.type(ch)
        let t = composer.text
        client.setMarkedText(t, selectionRange: NSRange(location: t.utf16.count, length: 0), replacementRange: kNotFound)
        return true
    }

    // MARK: Word boundary

    private func endWord(_ client: TextClient, boundary: String?) -> Bool {
        if composer.isEmpty { reset(); return false }
        if useMarked {
            commit(client)
            return false
        }
        defer { reset() }
        // Khôi phục từ tiếng Anh (vd "cáe" => "case") khi gõ dấu cách/dấu câu
        guard let boundary, let restored = composer.restoredText() else { return false }
        let sel = client.selectedRange()
        guard sel.location == expectedLocation, sel.length == 0 else { return false }
        return replace(client, from: composer.word, to: Array(restored + boundary), cursor: sel.location)
    }

    private func shouldUseMarked(_ client: TextClient) -> Bool {
        if autoMarkedClients.contains(ObjectIdentifier(client)) { return true }
        if let id = client.bundleID, markedApps.contains(id) { return true }
        return client.selectedRange().location == NSNotFound
    }
}
