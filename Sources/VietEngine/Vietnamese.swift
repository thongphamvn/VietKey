// Bảng chữ, quy tắc âm tiết và quy tắc đặt dấu tiếng Việt.
// Không phụ thuộc AppKit để có thể unit test.

public enum Tone: Int, Sendable {
    case none = 0, sac, huyen, hoi, nga, nang

    init?(telexKey k: Character) {
        switch k {
        case "s": self = .sac
        case "f": self = .huyen
        case "r": self = .hoi
        case "x": self = .nga
        case "j": self = .nang
        default: return nil
        }
    }
}

struct Syllable {
    let initial: String
    let vStart: Int
    let vEnd: Int
    let final: String
    var hasVowel: Bool { vEnd > vStart }
}

enum VN {
    // Mỗi dòng: không dấu, sắc, huyền, hỏi, ngã, nặng
    private static let rows = [
        "aáàảãạ", "ăắằẳẵặ", "âấầẩẫậ", "eéèẻẽẹ", "êếềểễệ", "iíìỉĩị",
        "oóòỏõọ", "ôốồổỗộ", "ơớờởỡợ", "uúùủũụ", "ưứừửữự", "yýỳỷỹỵ",
    ]

    private struct Stripped: Sendable { let base: Character; let tone: Tone }

    private static let forms: [Character: [Character]] = {
        var d: [Character: [Character]] = [:]
        for r in rows {
            for row in [r, r.uppercased()] {
                let cs = Array(row)
                d[cs[0]] = cs
            }
        }
        return d
    }()

    private static let stripTable: [Character: Stripped] = {
        var d: [Character: Stripped] = [:]
        for r in rows {
            for row in [r, r.uppercased()] {
                let cs = Array(row)
                for (i, c) in cs.enumerated() {
                    d[c] = Stripped(base: cs[0], tone: Tone(rawValue: i)!)
                }
            }
        }
        return d
    }()

    static let vowels: Set<Character> = Set("aăâeêioôơuưy")

    static let initials: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n",
        "ng", "ngh", "nh", "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ]

    static let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]

    /// Cụm nguyên âm hợp lệ, gồm cả dạng hoàn chỉnh và dạng đang gõ dở (chưa thêm mũ/móc).
    static let clusters: Set<String> = [
        // đơn
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
        // đôi hoàn chỉnh
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe",
        "oi", "ôi", "ơi", "oo", "ôô", "ua", "uâ", "uê", "ui", "uô", "uơ", "uy", "ưa", "ưi",
        "ươ", "ưu", "yê",
        // ba hoàn chỉnh
        "iêu", "oai", "oao", "oay", "oeo", "uây", "uôi", "uya", "uyê", "uyu", "ươi", "ươu", "yêu",
        // dạng gõ dở
        "eu", "ie", "ue", "uo", "ưo", "ye", "ieu", "yeu", "uoi", "uou", "ưou", "uơu", "uay", "uye",
        "ưoi", "uơi",
    ]

    static func lower(_ c: Character) -> Character { Character(c.lowercased()) }

    static func withCase(_ c: Character, like ref: Character) -> Character {
        ref.isUppercase ? Character(c.uppercased()) : c
    }

    static func strip(_ c: Character) -> (Character, Tone) {
        if let s = stripTable[c] { return (s.base, s.tone) }
        return (c, .none)
    }

    static func apply(_ t: Tone, to c: Character) -> Character {
        forms[c]?[t.rawValue] ?? c
    }

    /// Phân tích âm tiết (chữ thường, không dấu thanh). nil nếu không phải âm tiết tiếng Việt.
    static func parse(_ s: [Character]) -> Syllable? {
        var i = 0
        while i < s.count && !vowels.contains(s[i]) { i += 1 }
        var initial = String(s[0..<i])
        if i + 1 < s.count && vowels.contains(s[i + 1]) {
            if initial == "g" && s[i] == "i" { i += 1; initial = "gi" }
            else if initial == "q" && s[i] == "u" { i += 1; initial = "qu" }
        }
        guard initials.contains(initial) else { return nil }
        var j = i
        while j < s.count && vowels.contains(s[j]) { j += 1 }
        let final = String(s[j...])
        guard finals.contains(final) else { return nil }
        if j > i {
            guard clusters.contains(String(s[i..<j])) else { return nil }
        } else if !final.isEmpty {
            return nil
        }
        return Syllable(initial: initial, vStart: i, vEnd: j, final: final)
    }

    /// Vị trí đặt dấu thanh trong âm tiết (chữ thường, không dấu thanh).
    static func tonePosition(_ s: [Character], modern: Bool) -> Int? {
        guard let syl = parse(s), syl.hasVowel else { return nil }
        let v = Array(s[syl.vStart..<syl.vEnd])
        // Ưu tiên nguyên âm có mũ/móc/trăng (với "ươ" thì là ơ)
        if let k = v.lastIndex(where: { "ăâêôơư".contains($0) }) { return syl.vStart + k }
        switch v.count {
        case 1: return syl.vStart
        case 3: return syl.vStart + 1
        default:
            if !syl.final.isEmpty { return syl.vStart + 1 }
            if ["oa", "oe", "uy"].contains(String(v)) {
                return modern ? syl.vStart + 1 : syl.vStart
            }
            return syl.vStart
        }
    }
}
