import SwiftUI

struct ChecklistHistoryView: View {
    let repository: ChecklistRepository

    @State private var saved: [ChecklistHistoryEntry] = []
    @State private var sheet: HistorySheet?
    @State private var deleting: ChecklistHistoryEntry?
    @State private var loadFailed = false
    @State private var deleteFailed = false

    var body: some View {
        List {
            if loadFailed {
                ContentUnavailableView("履歴を読み込めませんでした", systemImage: "exclamationmark.circle")
                Button("再読み込み", action: reload)
            } else if saved.isEmpty {
                ContentUnavailableView(
                    "保存したチェックリストはありません",
                    systemImage: "checklist",
                    description: Text("チェックリストを保存すると、ここから開けます。")
                )
            } else {
                ForEach(saved) { entry in
                    Button {
                        if let draft = entry.draft {
                            sheet = .checklist(draft)
                        } else {
                            sheet = .original(entry)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.originalText)
                                .lineLimit(2)
                            Text(entry.createdAt, format: .dateTime.year().month().day().hour().minute())
                            if let draft = entry.draft {
                                Text("\(draft.completedCount)/\(draft.items.count)件完了")
                            } else {
                                Text("項目を読み込めません。元の指示を確認できます。")
                            }
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier(entry.draft == nil ? "unreadableChecklist" : "savedChecklist")
                    .swipeActions(allowsFullSwipe: false) {
                        Button("削除", role: .destructive) { deleting = entry }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .onAppear(perform: reload)
        .sheet(item: $sheet, onDismiss: reload) { presented in
            switch presented {
            case .checklist(let draft):
                ChecklistEditorView(draft: draft, repository: repository, isSaved: true)
            case .original(let entry):
                InstructionReviewView(text: entry.originalText, returnTitle: "履歴に戻る")
            }
        }
        .alert("保存したチェックリストを削除しますか？", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        ), presenting: deleting) { draft in
            Button("削除", role: .destructive) {
                do {
                    try repository.delete(draft.id)
                    reload()
                    AccessibilityNotification.Announcement("チェックリストを削除しました").post()
                } catch {
                    deleteFailed = true
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("チェックリストを削除できませんでした", isPresented: $deleteFailed) {
            Button("閉じる", role: .cancel) {}
        }
    }

    private func reload() {
        do {
            saved = try repository.loadAll()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    private enum HistorySheet: Identifiable {
        case checklist(ChecklistDraft)
        case original(ChecklistHistoryEntry)

        var id: UUID {
            switch self {
            case .checklist(let draft): draft.id
            case .original(let entry): entry.id
            }
        }
    }
}
