// Test runner đơn giản: swift run VietTests
import Foundation
import VietEngine

var passed = 0
var failed = 0
var currentSuite = ""

func suite(_ name: String) { currentSuite = name; print("\n▸ \(name)") }

func check(_ actual: String?, _ expected: String?, _ label: String, line: Int = #line) {
    if actual == expected {
        passed += 1
    } else {
        failed += 1
        print("  ✘ [\(label)] got \(actual.map { "\"\($0)\"" } ?? "nil"), expected \(expected.map { "\"\($0)\"" } ?? "nil")  (main.swift:\(line))")
    }
}

func check(_ cond: Bool, _ label: String, line: Int = #line) {
    check(cond ? "true" : "false", "true", label, line: line)
}

/// Gõ chuỗi phím chỉ qua engine; "<" là Delete, ký tự khác chữ cái là ranh giới từ.
func typeKeys(_ keys: String, modern: Bool = true) -> String {
    var c = TelexComposer(modernTone: modern)
    var out = ""
    for k in keys {
        if k == "<" {
            if c.isEmpty { if !out.isEmpty { out.removeLast() } } else { c.backspace() }
        } else if TelexComposer.accepts(k) {
            c.type(k)
        } else {
            out += (c.restoredText() ?? c.text) + String(k)
            c.reset()
        }
    }
    return out + (c.restoredText() ?? c.text)
}

// MARK: - Engine

suite("Engine: Telex")
for (i, e) in [
    ("vieejt", "việt"), ("vieetj", "việt"), ("vietje", "việt"), ("Vieejt", "Việt"), ("VIEEJT", "VIỆT"),
    ("tieengs", "tiếng"), ("tiesnge", "tiếng"), ("nghieeng", "nghiêng"),
    ("quys", "quý"), ("gif", "gì"), ("giuwax", "giữa"), ("gias", "giá"),
    ("nguowif", "người"), ("dduowcj", "được"), ("Dduowngf", "Đường"), ("khuyur", "khuỷu"),
    ("muaw", "mưa"), ("muwa", "mưa"), ("luaatj", "luật"), ("quaanf", "quần"), ("chuyeenr", "chuyển"),
    ("hoaif", "hoài"), ("ngoaif", "ngoài"), ("uoongs", "uống"), ("huowu", "hươu"), ("quowr", "quở"),
    ("w", "ư"), ("ww", "w"), ("tw", "tư"), ("trwowngf", "trường"), ("truwowngf", "trường"),
    ("ass", "as"), ("aaa", "aa"), ("dd", "đ"), ("ddd", "dd"), ("az", "az"), ("asz", "a"),
    ("toans", "toán"), ("hoafn", "hoàn"), ("tooi ddi hocj", "tôi đi học"),
] { check(typeKeys(i), e, i) }

suite("Engine: kiểu đặt dấu mới / cũ")
for (i, m, o) in [
    ("hoaf", "hoà", "hòa"), ("thuyr", "thuỷ", "thủy"), ("khoer", "khoẻ", "khỏe"),
    ("hoafn", "hoàn", "hoàn"), ("quas", "quá", "quá"), ("toans<", "toá", "tóa"),
] {
    check(typeKeys(i, modern: true), m, i + " (mới)")
    check(typeKeys(i, modern: false), o, i + " (cũ)")
}

suite("Engine: Delete")
for (i, e) in [
    ("toans<", "toá"), ("hoaf<", "ho"), ("vieejt<", "việ"), ("vieejt<<<", "v"), ("ab<<<", ""),
    ("tieengs<g", "tiếng"),
] { check(typeKeys(i), e, i) }

suite("Engine: tự khôi phục tiếng Anh")
for (i, e) in [
    ("case ", "case "), ("cases ", "cases "), ("tests ", "tests "), ("windows ", "windows "),
    ("class ", "class "), ("ass ", "as "),
] { check(typeKeys(i), e, i) }

// MARK: - Tích hợp với app giả lập

suite("App Cocoa (TextEdit, Notes...): không gạch chân")
check(run("tooi ddi hocj").string, "tôi đi học", "câu")
check(run("Vieejt Nam laf nuwowcs toi.").string, "Việt Nam là nước toi.", "câu có dấu chấm")
do {
    let app = MockApp(); let s = InputSession()
    app.type("vieej", with: s)
    check(app.string, "việ", "đang gõ")
    check(app.markedString, nil, "không có marked text")
    check(!s.useMarked, "chế độ direct")
}
check(run("chaof", app: MockApp(text: "xin  ban", cursor: 4)).string, "xin chào ban", "gõ giữa đoạn văn")
check(run("tieengs<<").string, "tiế", "Delete 2 lần")
check(run("toans<").string, "toá", "Delete dời dấu")
check(run("hoaf<").string, "ho", "Delete chữ mang dấu")
check(run("tieengs<g").string, "tiếng", "Delete rồi gõ lại")
check(run("vieejt <").string, "việt", "Delete dấu cách")
check(run("vieejt <<").string, "việ", "Delete qua từ trước")
check(run("vieejt <<t").string, "việt", "Delete qua từ trước rồi gõ tiếp")
check(run("ddi hocj <<<<").string, "đi ", "Delete nhiều lần")
check(run("hoa <f").string, "hoaf", "dấu sau khi Delete qua ranh giới từ không sửa từ cũ")
check(run("hoa←f").string, "hofa", "mũi tên trái rồi gõ")
check(run("hoa←→f").string, "hoaf", "mũi tên trái-phải rồi gõ")
check(run("hoa^s").string, "shoa", "click chỗ khác rồi gõ")
check(run("case ").string, "case ", "khôi phục 'case'")
check(run("tests, windows.").string, "tests, windows.", "khôi phục có dấu câu")
check(run("vieejt⏎nam").string, "việtnam", "Enter kết thúc từ")

suite("App không báo vị trí con trỏ: tự chuyển sang marked text")
check(run("tooi ddi hocj", app: MockApp(.noSelection)).string, "tôi đi học", "câu")
do {
    let app = MockApp(.noSelection); let s = InputSession()
    app.type("vieej", with: s)
    check(s.useMarked, "chế độ marked")
    check(app.markedString, "việ", "marked text khi đang gõ")
    app.type("t ", with: s)
    check(app.string, "việt ", "sau dấu cách")
    check(app.markedString, nil, "đã commit")
}
check(run("toans<", app: MockApp(.noSelection)).string, "toá", "Delete")
check(run("ab<<<", app: MockApp(.noSelection)).string, "", "Delete hết")
check(run("case ", app: MockApp(.noSelection)).string, "case ", "khôi phục")

suite("App báo vị trí con trỏ trễ 1 phím (trường hợp xấu)")
do {
    let app = MockApp(.laggy); let s = InputSession()
    var switched: String?
    s.onAutoMarked = { switched = $0 }
    app.type("tooi ddi hocj", with: s)
    s.commit(app)
    print("    (kết quả: \"\(app.string)\")")
    check(switched, "test.app", "tự chuyển sang marked text")
    check(app.string.hasSuffix(" đi học"), "các từ sau khi chuyển đều đúng")
    // Từ đầu tiên có thể mất dấu nhưng không bao giờ bị đảo/xoá chữ
    check(app.string.replacingOccurrences(of: "ô", with: "o").hasPrefix("too") || app.string.hasPrefix("tôi"), "từ đầu không bị đảo chữ")
}
do {
    // Lần sau (app đã nằm trong danh sách) => đúng ngay từ đầu
    let s = InputSession(); s.markedApps = ["test.app"]
    let app = MockApp(.laggy)
    app.type("tooi ddi hocj", with: s); s.commit(app)
    check(app.string, "tôi đi học", "lần sau đúng ngay từ đầu")
    let app2 = MockApp(.laggy); let s2 = InputSession(); s2.markedApps = ["test.app"]
    app2.type("toans<", with: s2); s2.commit(app2)
    check(app2.string, "toá", "Delete")
}
for keys in ["vieejt nam", "nguowif vieejt", "toans hocj", "hoaf<<<xin"] {
    // Không bao giờ sinh chữ rác: bỏ hết dấu thì phải ra đúng các chữ cái đã gõ theo thứ tự
    let app = MockApp(.laggy); let s = InputSession()
    app.type(keys, with: s); s.commit(app)
    let folded = app.string.folding(options: .diacriticInsensitive, locale: nil).replacingOccurrences(of: "đ", with: "d")
    let isSubsequence: Bool = {
        var it = keys.makeIterator()
        return folded.allSatisfy { c in while let k = it.next() { if k == c { return true } }; return false }
    }()
    check(isSubsequence, "không đảo chữ: \(keys) => \(app.string)")
}

suite("App báo nội dung trễ nhưng vị trí đúng (VS Code / Electron)")
do {
    let app = MockApp(.staleText); let s = InputSession()
    var switched: String?
    s.onAutoMarked = { switched = $0 }
    app.type("Vieejt Nam laf nuwowcs, nguowif dduowcj truwowngf ", with: s); s.commit(app)
    check(app.string, "Việt Nam là nước, người được trường ", "câu dài")
    check(switched, nil, "không phải chuyển sang marked text")
    check(run("toans<", app: MockApp(.staleText)).string, "toá", "Delete dời dấu")
    check(run("vieejt <<t", app: MockApp(.staleText)).string, "việt", "Delete qua từ trước")
    check(run("case ", app: MockApp(.staleText)).string, "case ", "khôi phục")
}

print("\n\(failed == 0 ? "✔" : "✘") \(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
