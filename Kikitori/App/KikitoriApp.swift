import SwiftUI

@main
struct KikitoriApp: App {
    private let checklistRepository = ChecklistRepository()

    var body: some Scene {
        WindowGroup {
            InstructionInputView(repository: checklistRepository)
        }
    }
}

