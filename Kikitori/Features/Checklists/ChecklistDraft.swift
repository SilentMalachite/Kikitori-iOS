import Foundation

struct ChecklistItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String
    var isCompleted = false
    let sourceText: String?
    let reviewReason: String?
}

/// 編集中の値。保存が失敗しても画面上の変更は保持する。
struct ChecklistDraft: Identifiable {
    let id: UUID
    let createdAt: Date
    let originalText: String
    var items: [ChecklistItem]

    init(originalText: String) {
        self.init(
            id: UUID(),
            createdAt: .now,
            originalText: originalText,
            items: InstructionParser.parse(originalText).map {
                ChecklistItem(text: $0.text, sourceText: $0.sourceText, reviewReason: $0.reviewReason)
            }
        )
    }

    init(id: UUID, createdAt: Date, originalText: String, items: [ChecklistItem]) {
        self.id = id
        self.createdAt = createdAt
        self.originalText = originalText
        self.items = items
    }

    var completedCount: Int {
        items.count(where: \.isCompleted)
    }

    mutating func resetCompletion() {
        for index in items.indices {
            items[index].isCompleted = false
        }
    }
}
