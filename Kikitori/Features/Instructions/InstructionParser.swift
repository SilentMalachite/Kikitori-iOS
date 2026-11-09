import Foundation

enum InstructionParser {
    struct Candidate: Equatable {
        let text: String
        let sourceText: String
        let reviewReason: String?
    }

    // 独立した「対象を＋動作」だけを分割の対象にする。
    private static let objectPattern =
        #"^(?:最初に|まず|次に|それから|その後)?[\p{Han}\p{Katakana}\p{Latin}\p{Nd}々ー]+(?:の[\p{Han}\p{Katakana}\p{Latin}\p{Nd}々ー]+)*を(?:日付順に|番号順に|名前順に)?$"#

    private static let verbs = [
        ("並べて", "並べる"), ("確認して", "確認する"), ("変更して", "変更する"),
        ("提出して", "提出する"), ("整理して", "整理する"), ("保存して", "保存する"),
        ("削除して", "削除する"), ("戻して", "戻す"), ("報告して", "報告する")
    ]

    static func parse(_ original: String) -> [Candidate] {
        let text = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        func keepOriginal(_ reason: String? = nil) -> [Candidate] {
            [Candidate(text: original, sourceText: original, reviewReason: reason)]
        }

        let vague = ["適当に", "いい感じに", "よしなに", "いつものように", "あれを", "それを", "これを"]
        if vague.contains(where: { text.contains($0) }) {
            return keepOriginal("具体的な作業や対象を確認してください。")
        }

        let sentence = withoutFinalPeriod(text)
        let complexPunctuation = CharacterSet(charactersIn: "。！？!?「」『』（）()；;").union(.newlines)
        if sentence.rangeOfCharacter(from: complexPunctuation) != nil {
            return keepOriginal("作業の区切りと前後のつながりを確認してください。")
        }

        let scope = [
            "たら", "なら", "場合", "まで", "とき", "れば", "限り", "のみ", "だけ",
            "次第", "ない", "なく", "ません", "禁止", "ずに", "せず", "以外"
        ]
        let hasScope = scope.contains(where: { text.contains($0) })
        let clauses = text.split(separator: "、", omittingEmptySubsequences: false)
        if clauses.count == 1 {
            let isSimpleRequest = simpleAction(text, isLast: true) != nil
            let isScopedRequest = hasScope && (
                verbs.contains { sentence.hasSuffix($0.0 + "ください") }
                    || sentence.hasSuffix("ないでください")
            )
            return keepOriginal(isSimpleRequest || isScopedRequest ? nil : "どの作業を行うか確認してください。")
        }

        if hasScope {
            return keepOriginal("条件や否定がどの作業にかかるか確認してください。")
        }

        var items: [Candidate] = []
        for (index, clause) in clauses.enumerated() {
            let sourceText = String(clause)
            let isLast = index == clauses.count - 1
            guard let instruction = simpleAction(sourceText, isLast: isLast) else {
                return keepOriginal("作業の区切りと前後のつながりを確認してください。")
            }
            items.append(Candidate(text: instruction, sourceText: sourceText, reviewReason: nil))
        }
        return items
    }

    private static func simpleAction(_ clause: String, isLast: Bool) -> String? {
        let trimmed = clause.trimmingCharacters(in: .whitespaces)
        let text = isLast ? withoutFinalPeriod(trimmed) : trimmed
        for (connectingForm, standaloneForm) in verbs {
            let ending = isLast ? connectingForm + "ください" : connectingForm
            guard text.hasSuffix(ending) else { continue }
            let object = String(text.dropLast(ending.count))
            if object.range(of: objectPattern, options: .regularExpression) != nil {
                return object + standaloneForm
            }
        }
        return nil
    }

    private static func withoutFinalPeriod(_ text: String) -> String {
        text.hasSuffix("。") ? String(text.dropLast()) : text
    }
}
