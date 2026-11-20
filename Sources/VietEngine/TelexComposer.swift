// Bộ soạn Telex: giữ từ đang gõ (đã dựng sẵn dạng Unicode) và biến đổi theo từng phím.
//
// Nguyên tắc:
// - Engine làm việc trên chữ đã dựng, không replay lại chuỗi phím => Delete luôn xoá đúng 1 ký tự nhìn thấy.
// - Dấu thanh được tách riêng và đặt lại sau mỗi phím => gõ dấu ở đâu cũng ra đúng vị trí.
// - Chỉ biến đổi khi kết quả vẫn là âm tiết tiếng Việt hợp lệ => hạn chế phá chữ tiếng Anh.

public struct TelexComposer: Sendable {
    /// true: hoà, thuý, khoẻ — false: hòa, thúy, khỏe
    public var modernTone: Bool
    /// Gõ "w" đứng riêng ra "ư"
    public var standaloneW: Bool
    /// Khi kết thúc từ không hợp lệ (vd "cáe"), trả lại phím gốc ("case")
    public var autoRestore: Bool

    public private(set) var word: [Character] = []
    private var raw: String? = ""
    private var lastStandaloneW = false
    private var noRestore = false

    public init(modernTone: Bool = true, standaloneW: Bool = true, autoRestore: Bool = true) {
        self.modernTone = modernTone
        self.standaloneW = standaloneW
        self.autoRestore = autoRestore
    }

    public var text: String { String(word) }
    public var isEmpty: Bool { word.isEmpty }

    public mutating func reset() {
        word = []
        raw = ""
        lastStandaloneW = false
        noRestore = false
    }

    /// Phím có được engine xử lý không (chữ cái ASCII). Phím khác là ranh giới từ.
    public static func accepts(_ key: Character) -> Bool {
        key.isASCII && key.isLetter
    }

    public mutating func type(_ key: Character) {
        let prevKey = raw?.last.map(VN.lower)
        raw?.append(key)
        let wasStandaloneW = lastStandaloneW
        lastStandaloneW = false
        let (next, undone) = transform(word, key, wasStandaloneW)
        if undone && prevKey == VN.lower(key) { noRestore = true }
        word = next
    }

    /// Xoá đúng 1 ký tự cuối. Nếu ký tự đó mang dấu thanh thì bỏ dấu, ngược lại dấu được đặt lại cho đúng.
    public mutating func backspace() {
        guard !word.isEmpty else { return }
        raw = nil
        lastStandaloneW = false
        let (bases, tone, pos) = decompose(word)
        var b = bases
        b.removeLast()
        word = compose(b, pos == bases.count - 1 ? .none : tone)
    }

    /// Gọi ở ranh giới từ. Trả về chuỗi phím gốc nếu cần khôi phục (từ tiếng Anh bị biến đổi).
    public func restoredText() -> String? {
        guard autoRestore, !noRestore, let raw, raw != text else { return nil }
        let bases = decompose(word).bases.map(VN.lower)
        return VN.parse(bases) == nil ? raw : nil
    }

    // MARK: - Internals

    private func decompose(_ w: [Character]) -> (bases: [Character], tone: Tone, pos: Int?) {
        var tone = Tone.none
        var pos: Int?
        var bases: [Character] = []
        for (i, c) in w.enumerated() {
            let (b, t) = VN.strip(c)
            if t != .none && pos == nil { tone = t; pos = i }
            bases.append(b)
        }
        return (bases, tone, pos)
    }

    private func compose(_ b: [Character], _ t: Tone) -> [Character] {
        guard t != .none, let p = VN.tonePosition(b.map(VN.lower), modern: modernTone) else { return b }
        var out = b
        out[p] = VN.apply(t, to: b[p])
        return out
    }

    private func isValid(_ b: [Character]) -> Bool {
        VN.parse(b.map(VN.lower)) != nil
    }

    /// Thêm phím như chữ thường, đặt lại dấu thanh nếu âm tiết vẫn hợp lệ (vd hòa + n => hoàn).
    private func append(_ w: [Character], _ key: Character) -> [Character] {
        let appended = w + [key]
        let (b, t, _) = decompose(appended)
        guard t != .none, VN.tonePosition(b.map(VN.lower), modern: modernTone) != nil else { return appended }
        return compose(b, t)
    }

    /// Trả về (từ mới, có phải thao tác hoàn tác không)
    private mutating func transform(_ w: [Character], _ key: Character, _ wasStandaloneW: Bool) -> ([Character], Bool) {
        guard Self.accepts(key) else { return (w + [key], false) }
        let k = VN.lower(key)
        var (bases, tone, _) = decompose(w)
        let low = bases.map(VN.lower)
        let syl = VN.parse(low)

        // Dấu thanh
        if let t = Tone(telexKey: k) {
            guard let syl, syl.hasVowel else { return (append(w, key), false) }
            if t == tone { return (compose(bases, .none) + [key], true) }
            return (compose(bases, t), false)
        }

        switch k {
        case "z":
            if tone != .none && syl != nil { return (compose(bases, .none), false) }
            return (append(w, key), false)

        case "d":
            if low.first == "d" && syl != nil {
                bases[0] = VN.withCase("đ", like: bases[0])
                return (compose(bases, tone), false)
            }
            if low.first == "đ" {
                bases[0] = VN.withCase("d", like: bases[0])
                return (compose(bases, tone) + [key], true)
            }
            return (append(w, key), false)

        case "a", "e", "o":
            guard let syl, syl.hasVowel else { return (append(w, key), false) }
            let circ: Character = k == "a" ? "â" : k == "e" ? "ê" : "ô"
            let range = syl.vStart..<syl.vEnd
            if let i = range.last(where: { low[$0] == circ }) {
                bases[i] = VN.withCase(k, like: bases[i])
                return (compose(bases, tone) + [key], true)
            }
            let sources: Set<Character> = k == "a" ? ["a", "ă"] : k == "e" ? ["e"] : ["o", "ơ"]
            for i in range.reversed() where sources.contains(low[i]) {
                var nb = bases
                nb[i] = VN.withCase(circ, like: bases[i])
                if isValid(nb) { return (compose(nb, tone), false) }
            }
            return (append(w, key), false)

        case "w":
            if let syl, syl.hasVowel {
                let range = syl.vStart..<syl.vEnd
                // "ưo" + w => "ươ" (vd: tr + w + o + w)
                for i in range.dropLast() where low[i] == "ư" && (low[i + 1] == "o" || low[i + 1] == "ô") {
                    var nb = bases
                    nb[i + 1] = VN.withCase("ơ", like: bases[i + 1])
                    if isValid(nb) { return (compose(nb, tone), false) }
                }
                if range.contains(where: { "ăơư".contains(low[$0]) }) {
                    if wasStandaloneW && low.last == "ư" {
                        bases.removeLast()
                        return (compose(bases, tone) + [key], true)
                    }
                    for i in range where "ăơư".contains(low[i]) {
                        let plain: Character = low[i] == "ă" ? "a" : low[i] == "ơ" ? "o" : "u"
                        bases[i] = VN.withCase(plain, like: bases[i])
                    }
                    return (compose(bases, tone) + [key], true)
                }
                for i in range.dropLast() where low[i] == "u" && (low[i + 1] == "o" || low[i + 1] == "ô") {
                    var nb = bases
                    nb[i] = VN.withCase("ư", like: bases[i])
                    nb[i + 1] = VN.withCase("ơ", like: bases[i + 1])
                    if isValid(nb) { return (compose(nb, tone), false) }
                }
                for i in range.reversed() {
                    let target: Character?
                    switch low[i] {
                    case "a", "â": target = "ă"
                    case "o", "ô": target = "ơ"
                    case "u": target = "ư"
                    default: target = nil
                    }
                    guard let target else { continue }
                    var nb = bases
                    nb[i] = VN.withCase(target, like: bases[i])
                    if isValid(nb) { return (compose(nb, tone), false) }
                }
            } else if standaloneW && syl != nil {
                let nb = w + [key.isUppercase ? "Ư" : "ư"]
                if isValid(nb) {
                    lastStandaloneW = true
                    return (nb, false)
                }
            }
            return (append(w, key), false)

        default:
            return (append(w, key), false)
        }
    }
}
