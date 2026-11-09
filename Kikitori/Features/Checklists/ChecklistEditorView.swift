import SwiftUI

struct ChecklistEditorView: View {
    let repository: ChecklistRepository

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ChecklistDraft
    @State private var savedItems: [ChecklistItem]?
    @State private var sheet: EditorSheet?
    @State private var alert: EditorAlert?

    init(draft: ChecklistDraft, repository: ChecklistRepository, isSaved: Bool = false) {
        self.repository = repository
        _draft = State(initialValue: draft)
        _savedItems = State(initialValue: isSaved ? draft.items : nil)
    }

    private var hasUnsavedChanges: Bool { savedItems != draft.items }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("元の指示を確認", systemImage: "doc.text.magnifyingglass") {
                        sheet = .original
                    }
                    .accessibilityIdentifier("reviewChecklistOriginal")

                    Text(hasUnsavedChanges ? "未保存の変更があります" : "保存済み")
                        .accessibilityIdentifier("checklistSaveState")
                }

                Section {
                    ForEach($draft.items) { $item in
                        ChecklistRow(item: $item) {
                            sheet = .item(item)
                        }
                    }
                    .onMove { offsets, destination in
                        draft.items.move(fromOffsets: offsets, toOffset: destination)
                    }
                } header: {
                    Text("作業（\(draft.completedCount)/\(draft.items.count)件完了）")
                        .accessibilityIdentifier("checklistProgress")
                }

                Section {
                    Button("項目を追加", systemImage: "plus") {
                        sheet = .item(nil)
                    }
                    .accessibilityIdentifier("addChecklistItem")

                    Button("すべて未完了に戻す") {
                        alert = .reset
                    }
                    .disabled(draft.completedCount == 0)
                }
            }
            .navigationTitle("チェックリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if hasUnsavedChanges {
                            alert = .discard
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("closeChecklist")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                        .disabled(draft.items.count < 2)
                    Button("保存", action: save)
                        .disabled(!hasUnsavedChanges)
                        .accessibilityIdentifier("saveChecklist")
                }
            }
            .sheet(item: $sheet) { presented in
                switch presented {
                case .original:
                    InstructionReviewView(text: draft.originalText, returnTitle: "チェックリストに戻る")
                case .item(let item):
                    ChecklistItemEditor(item: item) { text in
                        if let item {
                            guard let index = draft.items.firstIndex(where: { $0.id == item.id }) else { return }
                            draft.items[index].text = text
                        } else {
                            draft.items.append(ChecklistItem(text: text, sourceText: nil, reviewReason: nil))
                        }
                    } onDelete: {
                        draft.items.removeAll { $0.id == item?.id }
                    }
                }
            }
            .alert(alert?.title ?? "", isPresented: Binding(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            ), presenting: alert) { presented in
                switch presented {
                case .discard:
                    Button("変更を破棄", role: .destructive) { dismiss() }
                    Button("キャンセル", role: .cancel) {}
                case .reset:
                    Button("未完了に戻す", role: .destructive) {
                        draft.resetCompletion()
                        AccessibilityNotification.Announcement("すべて未完了に戻しました").post()
                    }
                    Button("キャンセル", role: .cancel) {}
                case .saveFailed:
                    Button("閉じる", role: .cancel) {}
                }
            } message: { presented in
                Text(presented.message)
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private func save() {
        do {
            try repository.save(draft)
            savedItems = draft.items
            AccessibilityNotification.Announcement("チェックリストを保存しました").post()
        } catch {
            alert = .saveFailed
        }
    }

    private enum EditorSheet: Identifiable {
        case original
        case item(ChecklistItem?)

        var id: String {
            switch self {
            case .original: "original"
            case .item(let item): item?.id.uuidString ?? "newItem"
            }
        }
    }

    private enum EditorAlert {
        case discard, reset, saveFailed

        var title: String {
            switch self {
            case .discard: "未保存の変更を破棄しますか？"
            case .reset: "すべての項目を未完了に戻しますか？"
            case .saveFailed: "保存できませんでした"
            }
        }

        var message: String {
            switch self {
            case .discard: "保存するにはキャンセルして「保存」を押してください。"
            case .reset: "すべての完了チェックを外します。"
            case .saveFailed: "編集中の内容はこの画面に残っています。もう一度「保存」を押してください。"
            }
        }
    }
}

private struct ChecklistRow: View {
    @Binding var item: ChecklistItem
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.text)
                        Text(item.isCompleted ? "完了" : "未完了")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.text)
            .accessibilityValue(item.isCompleted ? "完了" : "未完了")
            .accessibilityHint("完了状態を切り替えます")
            .accessibilityIdentifier("checklistItemCompletion")

            if let reason = item.reviewReason {
                Text("要確認　\(reason)")
                    .font(.subheadline)
                    .accessibilityIdentifier("checklistReviewReason")
            }

            Button("項目を編集", action: edit)
                .buttonStyle(.borderless)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityLabel("\(item.text)を編集")
                .accessibilityIdentifier("editChecklistItem")
        }
    }
}

private struct ChecklistItemEditor: View {
    let item: ChecklistItem?
    let onApply: (String) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var confirmsDeletion = false

    init(item: ChecklistItem?, onApply: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onApply = onApply
        self.onDelete = onDelete
        _text = State(initialValue: item?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("作業の内容") {
                    TextField("作業の内容", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("checklistItemText")
                }
                if let item {
                    Section("元の指示") {
                        if let source = item.sourceText {
                            Text(source)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("checklistItemSource")
                        } else {
                            Text("手動で追加した項目です。")
                        }
                        if let reason = item.reviewReason {
                            Text(reason)
                        }
                    }
                    Button("項目を削除", role: .destructive) {
                        confirmsDeletion = true
                    }
                }
            }
            .navigationTitle(item == nil ? "項目を追加" : "項目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("反映") {
                        onApply(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("applyChecklistItem")
                }
            }
            .alert("この項目を削除しますか？", isPresented: $confirmsDeletion) {
                Button("削除", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(text != (item?.text ?? ""))
    }
}
