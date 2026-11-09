import SwiftUI

struct ChecklistHistoryView: View {
    let repository: ChecklistRepository

    @State private var saved: [ChecklistDraft] = []
    @State private var editing: ChecklistDraft?
    @State private var deleting: ChecklistDraft?
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
                ForEach(saved) { draft in
                    Button {
                        editing = draft
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.originalText)
                                .lineLimit(2)
                            Text(draft.createdAt, format: .dateTime.year().month().day().hour().minute())
                            Text("\(draft.completedCount)/\(draft.items.count)件完了")
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("savedChecklist")
                    .swipeActions(allowsFullSwipe: false) {
                        Button("削除", role: .destructive) { deleting = draft }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .onAppear(perform: reload)
        .sheet(item: $editing, onDismiss: reload) { draft in
            ChecklistEditorView(draft: draft, repository: repository, isSaved: true)
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
}
