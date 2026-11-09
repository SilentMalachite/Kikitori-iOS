import SwiftUI

struct InstructionInputView: View {
    let repository: ChecklistRepository

    @State private var draft = InstructionDraft()
    @State private var sheet: InputSheet?
    @State private var showsClearConfirmation = false
    @FocusState private var isEditing: Bool
    @ScaledMetric(relativeTo: .body) private var editorHeight = 220

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("伝えられた指示を入力してください。入力した文章は、あとから読み返せます。")
                }

                Section {
                    TextEditor(text: $draft.text)
                        .font(.body)
                        .frame(minHeight: editorHeight)
                        .focused($isEditing)
                        .accessibilityLabel("指示の文章")
                        .accessibilityHint("伝えられた指示を、そのまま入力してください")
                        .accessibilityIdentifier("instructionEditor")
                } header: {
                    Text("指示の文章")
                } footer: {
                    Text("例：書類を並べて、番号を確認してください")
                }

                Section {
                    Button {
                        isEditing = false
                        sheet = .review
                    } label: {
                        Label("入力した指示を確認", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .disabled(!draft.canReview)
                    .accessibilityIdentifier("reviewInstruction")

                    Button {
                        isEditing = false
                        sheet = .checklist(ChecklistDraft(originalText: draft.text))
                    } label: {
                        Label("チェックリストを作る", systemImage: "checklist")
                            .frame(minHeight: 44)
                    }
                    .disabled(!draft.canReview)
                    .accessibilityIdentifier("createChecklist")

                    if draft.canUndoClear {
                        Button {
                            draft.undoClear()
                            AccessibilityNotification.Announcement("消した文章を元に戻しました").post()
                        } label: {
                            Label("消した文章を元に戻す", systemImage: "arrow.uturn.backward")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("undoClear")
                    } else {
                        Button(role: .destructive) {
                            isEditing = false
                            showsClearConfirmation = true
                        } label: {
                            Label("文章を消す", systemImage: "trash")
                                .frame(minHeight: 44)
                        }
                        .disabled(draft.text.isEmpty)
                        .accessibilityIdentifier("clearInstruction")
                    }
                } footer: {
                    Text("入力中の文章は、アプリを終了すると失われます。チェックリスト画面で保存すると、原文も履歴に残ります。")
                }
            }
            .navigationTitle("指示を入力")
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEditing {
                    Button {
                        isEditing = false
                    } label: {
                        Text("入力を終える")
                            .padding(.horizontal)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("履歴") {
                        ChecklistHistoryView(repository: repository)
                    }
                    .accessibilityIdentifier("openChecklistHistory")
                }
            }
            .alert("入力した文章を消しますか？", isPresented: $showsClearConfirmation) {
                Button("文章を消す", role: .destructive) {
                    draft.clear()
                    AccessibilityNotification.Announcement("文章を消しました。元に戻せます").post()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("消したあとに「消した文章を元に戻す」を押すと復元できます。新しく入力すると復元できなくなります。")
            }
            .sheet(item: $sheet) { presented in
                switch presented {
                case .review:
                    InstructionReviewView(text: draft.text)
                case .checklist(let checklist):
                    ChecklistEditorView(draft: checklist, repository: repository)
                }
            }
        }
    }

    private enum InputSheet: Identifiable {
        case review
        case checklist(ChecklistDraft)

        var id: String {
            switch self {
            case .review: "review"
            case .checklist(let checklist): checklist.id.uuidString
            }
        }
    }
}

struct InstructionReviewView: View {
    let text: String
    var returnTitle = "入力に戻る"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("伝えられた内容と合っているか、確認してください。")
                        .foregroundStyle(.secondary)

                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("originalInstruction")

                    Button(returnTitle) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("returnToInput")
                }
                .padding()
            }
            .navigationTitle("指示を確認")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

