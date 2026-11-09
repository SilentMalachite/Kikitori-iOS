import Foundation

/// 入力中の原文。表示可否の判定でも本文そのものは加工しない。
struct InstructionDraft {
    var text: String {
        didSet {
            if !text.isEmpty {
                clearedText = nil
            }
        }
    }
    private var clearedText: String?

    init(text: String = "") {
        self.text = text
    }

    var canReview: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUndoClear: Bool {
        text.isEmpty && clearedText != nil
    }

    mutating func clear() {
        guard !text.isEmpty else { return }
        clearedText = text
        text = ""
    }

    mutating func undoClear() {
        guard canUndoClear, let clearedText else { return }
        text = clearedText
        self.clearedText = nil
    }
}

