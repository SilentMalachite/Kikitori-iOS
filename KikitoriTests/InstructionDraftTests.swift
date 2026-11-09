import Testing
@testable import Kikitori

struct InstructionDraftTests {
    @Test("指定された6種類の原文を、消去の取り消しでもそのまま保持する", arguments: [
        "書類を並べて、番号を確認してください",
        "間違いがあったら報告してください",
        "確認が終わるまでファイルを削除しないでください",
        "最初に画像を確認して、それから名前を変更してください",
        "明日の午前10時までに3枚の書類を提出してください",
        "適当に整理しておいてください"
    ])
    func preservesOriginalText(text: String) {
        var draft = InstructionDraft(text: text)
        #expect(draft.canReview)
        draft.clear()
        #expect(draft.text.isEmpty)
        #expect(draft.canUndoClear)
        draft.undoClear()
        #expect(draft.text == text)
        #expect(!draft.canUndoClear)
    }

    @Test("空白だけの入力では確認に進まない", arguments: ["", " \n\t", "　"])
    func cannotReviewBlankText(text: String) {
        let draft = InstructionDraft(text: text)
        #expect(!draft.canReview)
        #expect(draft.text == text)
    }

    @Test("入力の前後の空白と改行を削らない")
    func preservesFormatting() {
        let text = "　書類を3枚確認してください。\n\n終わるまで削除しないでください。 \n"
        var draft = InstructionDraft(text: text)
        #expect(draft.canReview)
        #expect(draft.text == text)
        draft.clear()
        draft.undoClear()
        #expect(draft.text == text)
    }

    @Test("消去後に入力した文章を取り消し操作で上書きしない")
    func doesNotOverwriteNewInput() {
        var draft = InstructionDraft(text: "元の指示")
        draft.clear()
        draft.text = "新しい指示"
        #expect(!draft.canUndoClear)
        draft.undoClear()
        #expect(draft.text == "新しい指示")
        draft.text = ""
        #expect(!draft.canUndoClear)
    }
}

