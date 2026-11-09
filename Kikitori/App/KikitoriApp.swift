import SwiftUI
import SwiftData

@main
struct KikitoriApp: App {
    private let checklistRepository: ChecklistRepository

    init() {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["KIKITORI_UI_TEST_STORE_ID"],
           let storeID = UUID(uuidString: value) {
            let url = URL.temporaryDirectory.appendingPathComponent("Kikitori-UITests-\(storeID.uuidString).store")
            checklistRepository = ChecklistRepository(
                configuration: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            return
        }
        #endif
        checklistRepository = ChecklistRepository()
    }

    var body: some Scene {
        WindowGroup {
            InstructionInputView(repository: checklistRepository)
        }
    }
}

