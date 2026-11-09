import Foundation
import SwiftData
import Testing
@testable import Kikitori

@MainActor
struct ChecklistRepositoryTests {
    @Test("編集、順序、完了状態と原文を再読込し、履歴から削除できる")
    func roundTripAcrossStoreReopen() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("checklists.store"), cloudKitDatabase: .none)
        let original = "書類を並べて、番号を確認してください"
        var draft = ChecklistDraft(originalText: original)
        do {
            let repository = ChecklistRepository(configuration: configuration)
            try repository.save(draft)
            draft.items.swapAt(0, 1)
            draft.items[0].text = "番号をもう一度確認する"
            draft.items[0].isCompleted = true
            draft.items.append(ChecklistItem(text: "職員に確認する", sourceText: nil, reviewReason: nil))
            try repository.save(draft)
        }

        let reopened = ChecklistRepository(configuration: configuration)
        let saved = try reopened.loadAll()
        #expect(saved.count == 1)
        var restored = try #require(saved.first)
        #expect(restored.id == draft.id)
        #expect(restored.createdAt == draft.createdAt)
        #expect(restored.originalText == original)
        #expect(restored.items == draft.items)
        #expect(restored.items[0].sourceText == "番号を確認してください")
        #expect(restored.completedCount == 1)

        restored.resetCompletion()
        restored.items.remove(at: 1)
        try reopened.save(restored)
        try reopened.save(ChecklistDraft(originalText: original))

        let afterRegeneration = try reopened.loadAll()
        #expect(afterRegeneration.count == 2)
        let updated = try #require(afterRegeneration.first { $0.id == restored.id })
        #expect(updated.items == restored.items)
        #expect(updated.completedCount == 0)
        try reopened.delete(updated.id)
        #expect(try reopened.loadAll().allSatisfy { $0.id != updated.id })
    }

    @Test("書き込みが失敗しても編集中の値と保存済みのデータが残る")
    func failedSavePreservesDraftAndPreviousRecord() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("checklists.store")
        var draft = ChecklistDraft(originalText: "適当に整理しておいてください")
        let originalItem = try #require(draft.items.first)
        do {
            let repository = ChecklistRepository(configuration: ModelConfiguration(url: url, cloudKitDatabase: .none))
            try repository.save(draft)
        }

        let readOnly = ChecklistRepository(
            configuration: ModelConfiguration(url: url, allowsSave: false, cloudKitDatabase: .none)
        )
        draft.items[0].text = "確認した内容を整理する"
        #expect(throws: (any Error).self) { try readOnly.save(draft) }
        #expect(draft.items[0].text == "確認した内容を整理する")
        let saved = try readOnly.loadAll()
        #expect(saved.first?.items == [originalItem])
        #expect(saved.first?.items.first?.reviewReason != nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
