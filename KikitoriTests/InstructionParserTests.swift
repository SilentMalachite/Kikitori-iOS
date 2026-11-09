import Testing
@testable import Kikitori

struct InstructionParserTests {
    struct Example: Sendable {
        let source: String
        let items: [String]
        let needsReview: Bool

        init(_ source: String, _ items: [String]? = nil, needsReview: Bool = false) {
            self.source = source
            self.items = items ?? [source]
            self.needsReview = needsReview
        }
    }

    @Test("指定された6例を意味を保って解析する", arguments: [
        Example("書類を並べて、番号を確認してください", ["書類を並べる", "番号を確認する"]),
        Example("間違いがあったら報告してください"),
        Example("確認が終わるまでファイルを削除しないでください"),
        Example("最初に画像を確認して、それから名前を変更してください", ["最初に画像を確認する", "それから名前を変更する"]),
        Example("明日の午前10時までに3枚の書類を提出してください"),
        Example("適当に整理しておいてください", needsReview: true)
    ])
    func parsesRequestedExamples(_ example: Example) {
        let items = InstructionParser.parse(example.source)
        #expect(items.map(\.text) == example.items)
        #expect(items.contains { $0.reviewReason != nil } == example.needsReview)
        #expect(items.map(\.sourceText).joined(separator: "、") == example.source)
    }

    @Test("複雑な構文や動作が明確でない文を原文のまま確認対象にする", arguments: [
        "間違いがあったら、書類を整理して、番号を確認してください",
        "書類を並べて、番号を確認しないでください",
        "書類を日付順に並べて、番号を確認して、終わったら棚に戻してください",
        "番号を確認できた場合のみ提出してください。棚に戻してください",
        "「書類を並べて、番号を確認してください」と報告してください",
        "いいようにやっておいてください"
    ])
    func keepsUncertainScopeTogether(_ original: String) throws {
        let items = InstructionParser.parse(original)
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.text == original)
        #expect(item.sourceText == original)
        #expect(item.reviewReason != nil)
    }
}
