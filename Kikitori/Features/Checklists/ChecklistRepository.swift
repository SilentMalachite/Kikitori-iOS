import Foundation
import SwiftData

@Model
final class SavedChecklist {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var createdAt: Date
    private(set) var originalText: String
    // 配列を一つの値として保存し、項目の順序と原文との対応を保持する。
    var encodedItems: Data

    init(draft: ChecklistDraft, encodedItems: Data) {
        id = draft.id
        createdAt = draft.createdAt
        originalText = draft.originalText
        self.encodedItems = encodedItems
    }

    func makeDraft() throws -> ChecklistDraft {
        ChecklistDraft(
            id: id,
            createdAt: createdAt,
            originalText: originalText,
            items: try JSONDecoder().decode([ChecklistItem].self, from: encodedItems)
        )
    }
}

@MainActor
final class ChecklistRepository {
    private let configuration: ModelConfiguration
    private var container: ModelContainer?

    init(configuration: ModelConfiguration = ModelConfiguration(cloudKitDatabase: .none)) {
        self.configuration = configuration
    }

    func loadAll() throws -> [ChecklistDraft] {
        let descriptor = FetchDescriptor<SavedChecklist>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try makeContext().fetch(descriptor).map { try $0.makeDraft() }
    }

    func save(_ draft: ChecklistDraft) throws {
        let data = try JSONEncoder().encode(draft.items)
        let context = try makeContext()
        if let saved = try find(draft.id, in: context) {
            saved.encodedItems = data
        } else {
            context.insert(SavedChecklist(draft: draft, encodedItems: data))
        }
        try context.save()
    }

    func delete(_ id: UUID) throws {
        let context = try makeContext()
        guard let saved = try find(id, in: context) else { return }
        context.delete(saved)
        try context.save()
    }

    private func makeContext() throws -> ModelContext {
        if let container {
            return ModelContext(container)
        }
        let opened = try ModelContainer(for: SavedChecklist.self, configurations: configuration)
        container = opened
        // 操作ごとにコンテキストを作る。失敗時に未確定の変更を持ち越さない。
        return ModelContext(opened)
    }

    private func find(_ id: UUID, in context: ModelContext) throws -> SavedChecklist? {
        var descriptor = FetchDescriptor<SavedChecklist>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
