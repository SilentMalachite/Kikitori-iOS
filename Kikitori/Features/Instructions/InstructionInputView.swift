import SwiftUI

struct InstructionInputView: View {
    @State private var draft = InstructionDraft()
    @State private var showsReview = false
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
                        showsReview = true
                    } label: {
                        Label("入力した指示を確認", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .disabled(!draft.canReview)
                    .accessibilityIdentifier("reviewInstruction")

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
                    Text("入力内容はまだ保存されません。アプリを終了すると失われます。")
                }
            }
            .navigationTitle("指示を入力")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("入力を終える") {
                        isEditing = false
                    }
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
            .sheet(isPresented: $showsReview) {
                InstructionReviewView(text: draft.text)
            }
        }
    }
}

private struct InstructionReviewView: View {
    let text: String
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

                    Button("入力に戻る") {
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

